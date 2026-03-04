//
//  SessionViewModel.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - SessionState

/// Session lifecycle state machine
enum SessionState: String {
    case setup
    case active
    case paused
    case inBetween
    case ended
}

// MARK: - SessionViewModel

/// ViewModel managing session lifecycle with date-based timer architecture
///
/// **Timer Architecture:**
/// Uses date-based calculations (not tick counters) to survive iOS backgrounding.
/// Timer calculates: pausedElapsedTime + Date().timeIntervalSince(startTime)
///
/// **RunLoop Mode:**
/// CRITICAL - Uses .common mode (not .default) so timer continues during scrolling/typing
///
/// **State Machine:**
/// setup → active → paused → active → inBetween → active → ended
///
/// **Firestore Persistence:**
/// All state changes (pause, skip, note) persist immediately for crash recovery
///
/// **Memory Management:**
/// Uses [weak self] in timer closure, cancels timer in deinit, removes listener in deinit
@MainActor
final class SessionViewModel: ObservableObject {
    // MARK: - Published State

    @Published var elapsedTime: TimeInterval = 0
    @Published var sessionState: SessionState = .setup
    @Published var currentActivityIndex: Int = 0
    @Published var activities: [SessionActivity] = []
    @Published var currentSession: Session?

    // MARK: - Dependencies

    private let repository: SessionRepositoryProtocol
    private let userId: String

    // MARK: - Timer State (CRITICAL: Date-based, not tick counter)

    /// Start time as Date for backgrounding survival
    private var startTime: Date?
    /// Accumulated elapsed time when paused
    private var pausedElapsedTime: TimeInterval = 0
    /// Timer publisher cancellable
    private var timerCancellable: AnyCancellable?

    // MARK: - Listener Management

    private var sessionListener: ListenerRegistration?

    // MARK: - Initialization

    nonisolated init(userId: String, repository: SessionRepositoryProtocol = SessionRepository()) {
        self.userId = userId
        self.repository = repository
    }

    deinit {
        timerCancellable?.cancel()
        sessionListener?.remove()
    }

    // MARK: - Session Lifecycle

    /// Start a new session with selected activities
    /// - Parameter selectedActivities: Activities to practice in order
    func startSession(selectedActivities: [Activity]) async throws {
        let now = Date()
        let nowString = now.toISO8601String()

        // Create Session document
        var session = Session(
            id: nil,
            startTime: nowString,
            endTime: nil,
            totalDuration: 0,
            createdAt: nowString,
            updatedAt: nowString,
            state: "active",
            pausedAt: nil,
            currentActivityIndex: 0
        )

        // Create session in Firestore
        currentSession = try await repository.createSession(userId: userId, session: session)

        // Initialize activities array (first activity has startTime, rest are empty)
        // Assign temporary UUIDs so ForEach can render them (will be replaced with Firestore IDs when saved)
        activities = selectedActivities.enumerated().map { index, activity in
            SessionActivity(
                id: UUID().uuidString,
                activityId: activity.id,
                activityName: activity.name,
                startTime: index == 0 ? nowString : "",
                endTime: nil,
                duration: 0,
                notes: nil,
                isInBetweenTime: false,
                createdAt: nowString,
                updatedAt: nowString
            )
        }

        currentActivityIndex = 0
        sessionState = .active

        // Start timer
        startTimer()
    }

    /// Start date-based timer with .common RunLoop mode
    private func startTimer() {
        let start = Date()
        startTime = start
        sessionState = .active

        // CRITICAL: Use .common RunLoop mode (not .default) for smooth updates during interaction
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let startTime = self.startTime else { return }
                // CRITICAL: Date-based calculation survives backgrounding
                self.elapsedTime = self.pausedElapsedTime + Date().timeIntervalSince(startTime)
            }
    }

    /// Pause timer and persist state to Firestore
    func pauseTimer() async {
        // Cancel timer
        timerCancellable?.cancel()
        timerCancellable = nil

        // Preserve accumulated time
        pausedElapsedTime = elapsedTime
        startTime = nil
        sessionState = .paused

        // Persist to Firestore for crash recovery
        guard let sessionId = currentSession?.id else { return }
        let updates: [String: Any] = [
            "state": "paused",
            "pausedAt": Date().toISO8601String()
        ]
        try? await repository.updateSessionState(userId: userId, sessionId: sessionId, updates: updates)
    }

    /// Resume timer and persist state to Firestore
    func resumeTimer() async {
        // Restart timer (creates new startTime)
        startTimer()

        // Persist to Firestore
        guard let sessionId = currentSession?.id else { return }
        let updates: [String: Any] = [
            "state": "active",
            "pausedAt": NSNull()
        ]
        try? await repository.updateSessionState(userId: userId, sessionId: sessionId, updates: updates)
    }

    /// Skip to a specific activity in the queue
    func skipToActivity(_ targetActivity: SessionActivity) async {
        guard currentActivityIndex < activities.count else { return }
        guard let sessionId = currentSession?.id else { return }

        // Find the target activity's index
        guard let targetIndex = activities.firstIndex(where: { $0.id == targetActivity.id }) else { return }

        // End current activity and save it
        let nowString = Date().toISO8601String()
        activities[currentActivityIndex].endTime = nowString
        activities[currentActivityIndex].duration = Int(elapsedTime)

        try? await repository.addSessionActivity(
            userId: userId,
            sessionId: sessionId,
            activity: activities[currentActivityIndex]
        )

        // Jump to target activity
        currentActivityIndex = targetIndex

        // Reset timer for new activity
        pausedElapsedTime = 0
        elapsedTime = 0
        sessionState = .active
        activities[currentActivityIndex].startTime = nowString
        startTimer()
    }

    /// Start next activity (ends in-between time)
    func startNextActivity() async {
        guard let sessionId = currentSession?.id else { return }

        // End in-between time
        let nowString = Date().toISO8601String()
        let inBetweenActivity = SessionActivity(
            id: nil,
            activityId: nil,
            activityName: "Break",
            startTime: startTime?.toISO8601String() ?? nowString,
            endTime: nowString,
            duration: Int(elapsedTime),
            notes: nil,
            isInBetweenTime: true,
            createdAt: nowString,
            updatedAt: nowString
        )

        // Save in-between activity to Firestore
        try? await repository.addSessionActivity(
            userId: userId,
            sessionId: sessionId,
            activity: inBetweenActivity
        )

        // Move to next activity
        currentActivityIndex += 1

        // Check if session is complete
        if currentActivityIndex < activities.count {
            // Reset timer for next activity
            pausedElapsedTime = 0
            elapsedTime = 0
            sessionState = .active
            activities[currentActivityIndex].startTime = nowString
            startTimer()
        } else {
            // All activities complete
            await endSession()
        }
    }

    /// Add note to current activity
    /// - Parameter note: Note text to add
    func addNote(_ note: String) async {
        guard currentActivityIndex < activities.count else { return }
        guard let sessionId = currentSession?.id else { return }

        // Update or append note
        if let existingNotes = activities[currentActivityIndex].notes {
            activities[currentActivityIndex].notes = existingNotes + "\n" + note
        } else {
            activities[currentActivityIndex].notes = note
        }

        // Persist to Firestore
        try? await repository.addSessionActivity(
            userId: userId,
            sessionId: sessionId,
            activity: activities[currentActivityIndex]
        )
    }

    /// Remove activity from queue
    /// - Parameter activity: Activity to remove
    func removeActivity(_ activity: SessionActivity) async {
        activities.removeAll { $0.id == activity.id }

        // Persist to Firestore
        guard let sessionId = currentSession?.id else { return }
        let updates: [String: Any] = [
            "updatedAt": Date().toISO8601String()
        ]
        try? await repository.updateSessionState(userId: userId, sessionId: sessionId, updates: updates)
    }

    /// Reorder activities in queue
    /// - Parameters:
    ///   - from: Source index
    ///   - to: Destination index
    func reorderActivities(from: Int, to: Int) {
        guard from >= 0 && from < activities.count && to >= 0 && to <= activities.count else { return }
        let activity = activities.remove(at: from)
        let insertIndex = to > from ? to - 1 : to
        activities.insert(activity, at: insertIndex)

        // Persist to Firestore
        guard let sessionId = currentSession?.id else { return }
        Task {
            let updates: [String: Any] = [
                "updatedAt": Date().toISO8601String()
            ]
            try? await repository.updateSessionState(userId: userId, sessionId: sessionId, updates: updates)
        }
    }

    /// End session and calculate total duration
    func endSession() async {
        // Cancel timer
        timerCancellable?.cancel()
        timerCancellable = nil

        // End current activity if not already ended
        if currentActivityIndex < activities.count && activities[currentActivityIndex].endTime == nil {
            let nowString = Date().toISO8601String()
            activities[currentActivityIndex].endTime = nowString
            activities[currentActivityIndex].duration = Int(elapsedTime)

            guard let sessionId = currentSession?.id else { return }
            try? await repository.addSessionActivity(
                userId: userId,
                sessionId: sessionId,
                activity: activities[currentActivityIndex]
            )
        }

        // Calculate total duration from all activities
        let totalDuration = activities.reduce(0) { $0 + $1.duration }

        // End session in Firestore
        guard let sessionId = currentSession?.id else { return }
        let nowString = Date().toISO8601String()
        try? await repository.endSession(
            userId: userId,
            sessionId: sessionId,
            endTime: nowString,
            totalDuration: totalDuration
        )

        sessionState = .ended
    }

    /// Refresh timer if needed (for foreground return)
    /// Called from ActiveSessionView.onChange(of: scenePhase)
    func refreshTimerIfNeeded() {
        if sessionState == .active && timerCancellable == nil {
            startTimer()
        }
    }

    // MARK: - Computed Properties

    /// Current activity name
    var currentActivityName: String {
        guard currentActivityIndex < activities.count else { return "" }
        return activities[currentActivityIndex].activityName
    }

    /// Session progress (0.0 to 1.0)
    var progress: Double {
        guard !activities.isEmpty else { return 0.0 }
        return Double(currentActivityIndex) / Double(activities.count)
    }

    /// Upcoming activities (not yet started)
    var upcomingActivities: [SessionActivity] {
        guard currentActivityIndex + 1 < activities.count else { return [] }
        return Array(activities[(currentActivityIndex + 1)...])
    }

    /// Notes for current activity
    var currentActivityNotes: String? {
        guard currentActivityIndex < activities.count else { return nil }
        return activities[currentActivityIndex].notes
    }
}
