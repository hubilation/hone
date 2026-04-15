//
//  SessionViewModel.swift
//  Hone
//
//  Created by Zack Huber on 3/3/26.
//

import Foundation
import Combine
import FirebaseFirestore
import ActivityKit

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

    /// NOT @Published — updated 10×/s by timer but views must NOT observe directly.
    /// Use activityStartDate + activityPausedElapsed in TimerDisplayView instead.
    var elapsedTime: TimeInterval = 0
    /// NOT @Published — same reason. Use sessionTimerStartDate + sessionPausedElapsed instead.
    var totalSessionTime: TimeInterval = 0
    @Published var sessionState: SessionState = .setup
    @Published var currentActivityIndex: Int = 0
    @Published var activities: [SessionActivity] = []
    @Published var currentSession: Session?
    @Published var historicalNotes: [PracticeNote] = []

    // MARK: - Timer Config (Published — change only on start/pause/resume, not every tick)

    /// When the current activity timer started. Nil when paused.
    @Published private(set) var activityStartDate: Date?
    /// Accumulated activity elapsed time at last pause.
    @Published private(set) var activityPausedElapsed: TimeInterval = 0
    /// When the overall session timer started. Nil when paused.
    @Published private(set) var sessionTimerStartDate: Date?
    /// Accumulated session elapsed time at last pause.
    @Published private(set) var sessionPausedElapsed: TimeInterval = 0

    // MARK: - Dependencies

    private let repository: SessionRepositoryProtocol
    private let activityRepository: ActivityRepositoryProtocol
    let userId: String

    // MARK: - Timer State (CRITICAL: Date-based, not tick counter)

    /// Timer publisher cancellable
    private var timerCancellable: AnyCancellable?

    /// Live Activity reference for updates and dismissal
    private var liveActivity: ActivityKit.Activity<HoneLiveActivityAttributes>?

    // MARK: - Listener Management

    private var sessionListener: ListenerRegistration?

    // MARK: - Initialization

    nonisolated init(
        userId: String,
        repository: SessionRepositoryProtocol = SessionRepository(),
        activityRepository: ActivityRepositoryProtocol = ActivityRepository()
    ) {
        self.userId = userId
        self.repository = repository
        self.activityRepository = activityRepository
    }

    deinit {
        timerCancellable?.cancel()
        sessionListener?.remove()
        // Live Activity cleanup handled by endLiveActivity() in endSession()/resetSession()
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
        // Add milliseconds to createdAt to ensure unique identifiers for SwiftUI
        activities = selectedActivities.enumerated().map { index, activity in
            let uniqueCreatedAt = now.addingTimeInterval(TimeInterval(index) * 0.001).toISO8601String()
            return SessionActivity(
                id: UUID().uuidString,
                activityId: activity.id,
                activityName: activity.name,
                startTime: index == 0 ? nowString : "",
                endTime: nil,
                duration: 0,
                notes: nil,
                isInBetweenTime: false,
                createdAt: uniqueCreatedAt,
                updatedAt: uniqueCreatedAt
            )
        }

        currentActivityIndex = 0
        sessionState = .active

        // Initialize session timer
        sessionTimerStartDate = now
        sessionPausedElapsed = 0
        totalSessionTime = 0

        // Start timer
        startTimer()

        // Load historical notes for first activity
        await loadHistoricalNotes()

        // Start Live Activity (D-06: auto-start when session becomes .active)
        startLiveActivity()
    }

    /// Start date-based timer with .common RunLoop mode
    private func startTimer() {
        let start = Date()
        activityStartDate = start
        sessionState = .active

        // Initialize session start time if not set
        if sessionTimerStartDate == nil {
            sessionTimerStartDate = start
        }

        // CRITICAL: Use .common RunLoop mode (not .default) for smooth updates during interaction
        // Updates elapsedTime/totalSessionTime for internal calculations (endSession, Live Activity)
        // but these are NOT @Published so they do NOT trigger view re-renders.
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let startDate = self.activityStartDate else { return }
                self.elapsedTime = self.activityPausedElapsed + Date().timeIntervalSince(startDate)
                if let sessionStart = self.sessionTimerStartDate {
                    self.totalSessionTime = self.sessionPausedElapsed + Date().timeIntervalSince(sessionStart)
                }
            }
    }

    /// Pause timer and persist state to Firestore
    func pauseTimer() async {
        // Cancel timer
        timerCancellable?.cancel()
        timerCancellable = nil

        // Preserve accumulated time
        activityPausedElapsed = elapsedTime
        sessionPausedElapsed = totalSessionTime
        activityStartDate = nil
        sessionTimerStartDate = nil
        sessionState = .paused

        // Persist to Firestore for crash recovery
        guard let sessionId = currentSession?.id else { return }
        let updates: [String: Any] = [
            "state": "paused",
            "pausedAt": Date().toISO8601String()
        ]
        try? await repository.updateSessionState(userId: userId, sessionId: sessionId, updates: updates)

        // Update Live Activity to paused state with frozen timer (D-08)
        updateLiveActivityPaused()
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

        // Update Live Activity back to active/running state (D-08)
        updateLiveActivityResumed()
    }

    /// Complete current activity and move to next
    func completeCurrentActivity() async {
        guard currentActivityIndex < activities.count else { return }
        guard let sessionId = currentSession?.id else { return }

        let nowString = Date().toISO8601String()
        let duration = Int(elapsedTime)
        activities[currentActivityIndex].endTime = nowString
        activities[currentActivityIndex].duration = duration
        let completedActivity = activities[currentActivityIndex]

        // Persist to Firestore in background — updateActivityStats uses async updateData which
        // hangs offline; fire-and-forget so state transitions happen immediately.
        Task { [weak self] in
            guard let self else { return }
            try? await self.repository.addSessionActivity(userId: self.userId, sessionId: sessionId, activity: completedActivity)
            if let activityId = completedActivity.activityId {
                try? await self.activityRepository.updateActivityStats(
                    userId: self.userId,
                    activityId: activityId,
                    additionalTime: duration,
                    lastUsed: nowString
                )
            }
        }

        // Move to next activity immediately
        currentActivityIndex += 1

        if currentActivityIndex < activities.count {
            activityPausedElapsed = 0
            elapsedTime = 0
            sessionState = .active
            activities[currentActivityIndex].startTime = nowString
            startTimer()
            await loadHistoricalNotes()
            updateLiveActivityNewActivity()
        } else {
            await endSession()
        }
    }

    /// Skip to a specific activity in the queue
    func skipToActivity(_ targetActivity: SessionActivity) async {
        guard currentActivityIndex < activities.count else { return }
        guard let sessionId = currentSession?.id else { return }

        guard let targetIndex = activities.firstIndex(where: { $0.id == targetActivity.id }) else { return }

        let nowString = Date().toISO8601String()
        let duration = Int(elapsedTime)
        activities[currentActivityIndex].endTime = nowString
        activities[currentActivityIndex].duration = duration
        let completedActivity = activities[currentActivityIndex]

        // Persist in background — same offline-safe pattern as completeCurrentActivity
        Task { [weak self] in
            guard let self else { return }
            try? await self.repository.addSessionActivity(userId: self.userId, sessionId: sessionId, activity: completedActivity)
            if let activityId = completedActivity.activityId {
                try? await self.activityRepository.updateActivityStats(
                    userId: self.userId,
                    activityId: activityId,
                    additionalTime: duration,
                    lastUsed: nowString
                )
            }
        }

        // Jump to target activity immediately
        currentActivityIndex = targetIndex
        activityPausedElapsed = 0
        elapsedTime = 0
        sessionState = .active
        activities[currentActivityIndex].startTime = nowString
        startTimer()
        await loadHistoricalNotes()
        updateLiveActivityNewActivity()
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
            startTime: activityStartDate?.toISO8601String() ?? nowString,
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
            activityPausedElapsed = 0
            elapsedTime = 0
            sessionState = .active
            activities[currentActivityIndex].startTime = nowString
            startTimer()

            // Load historical notes for new activity
            await loadHistoricalNotes()

            // Update Live Activity with new activity name (D-10)
            updateLiveActivityNewActivity()
        } else {
            // All activities complete
            await endSession()
        }
    }

    /// Add note to current activity
    /// - Parameter note: Note text to add
    func addNote(_ note: String) async {
        guard currentActivityIndex < activities.count else { return }
        guard let activityId = activities[currentActivityIndex].activityId else { return }
        guard let sessionId = currentSession?.id else { return }

        // Create practice note
        let practiceNote = PracticeNote(
            notes: note,
            sessionId: sessionId,
            timestamp: Date().toISO8601String(),
            timeSpent: Int(elapsedTime)
        )

        // 1. Add to Activity.practiceNotes array (for historical notes across sessions)
        do {
            try await activityRepository.addPracticeNote(
                userId: userId,
                activityId: activityId,
                note: practiceNote
            )
        } catch {
            print("Error adding practice note to Activity: \(error)")
            return
        }

        // 2. Also add to SessionActivity.notes (for current session summary)
        if let existingNotes = activities[currentActivityIndex].notes {
            activities[currentActivityIndex].notes = existingNotes + "\n" + note
        } else {
            activities[currentActivityIndex].notes = note
        }

        // Save SessionActivity to Firestore
        do {
            try await repository.addSessionActivity(
                userId: userId,
                sessionId: sessionId,
                activity: activities[currentActivityIndex]
            )
        } catch {
            print("Error adding note to SessionActivity: \(error)")
        }

        // Reload all notes to show the new one
        await loadHistoricalNotes()
    }

    /// Load all notes for current activity from Activity document
    func loadHistoricalNotes() async {
        // Clear notes first to prevent showing wrong activity's notes
        historicalNotes = []

        guard currentActivityIndex < activities.count else { return }
        guard let activityId = activities[currentActivityIndex].activityId else { return }

        do {
            // Fetch the activity with its practiceNotes array
            guard let activity = try await activityRepository.getActivity(userId: userId, activityId: activityId) else {
                historicalNotes = []
                return
            }

            // Get ALL notes (including current session) and sort by timestamp descending (newest first)
            historicalNotes = (activity.practiceNotes ?? []).sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Error loading notes: \(error)")
            historicalNotes = []
        }
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

        let nowString = Date().toISO8601String()

        // Finalize current activity data locally (no network calls yet)
        var finalActivity: SessionActivity? = nil
        if currentActivityIndex < activities.count && activities[currentActivityIndex].endTime == nil {
            let duration = Int(elapsedTime)
            activities[currentActivityIndex].endTime = nowString
            activities[currentActivityIndex].duration = duration
            finalActivity = activities[currentActivityIndex]
        }

        let totalDuration = activities.reduce(0) { $0 + $1.duration }

        // Transition state immediately — works offline, Firestore syncs in background
        sessionState = .ended
        endLiveActivity()

        // Persist to Firestore in background — Firestore queues writes offline and syncs on reconnect.
        // Firestore's async/await updateData waits for server confirmation, so we must not await
        // these on the main path or session completion blocks when the device is offline.
        guard let sessionId = currentSession?.id else { return }
        Task { [weak self] in
            guard let self else { return }
            if let activity = finalActivity {
                try? await self.repository.addSessionActivity(
                    userId: self.userId,
                    sessionId: sessionId,
                    activity: activity
                )
                if let activityId = activity.activityId {
                    try? await self.activityRepository.updateActivityStats(
                        userId: self.userId,
                        activityId: activityId,
                        additionalTime: activity.duration,
                        lastUsed: nowString
                    )
                }
            }
            try? await self.repository.endSession(
                userId: self.userId,
                sessionId: sessionId,
                endTime: nowString,
                totalDuration: totalDuration
            )
        }
    }

    /// Add a new activity to the session
    /// Can be called during active session to add additional practice items
    /// If no activities are queued, immediately completes current activity and starts the new one
    func addActivity(_ activity: Activity) async {
        guard let activityId = activity.id,
              let sessionId = currentSession?.id else {
            print("❌ AddActivity failed - activityId: \(activity.id ?? "nil"), sessionId: \(currentSession?.id ?? "nil")")
            return
        }

        // Check if there are no upcoming activities (empty queue)
        let shouldStartImmediately = upcomingActivities.isEmpty

        // Add microseconds to ensure unique createdAt even when adding multiple activities rapidly
        let now = Date()
        let uniqueCreatedAt = now.addingTimeInterval(TimeInterval(activities.count) * 0.001).toISO8601String()
        let nowString = now.toISO8601String()

        let newActivity = SessionActivity(
            activityId: activityId,
            activityName: activity.name,
            startTime: "",
            endTime: nil,
            duration: 0,
            notes: nil,
            isInBetweenTime: false,
            createdAt: uniqueCreatedAt,
            updatedAt: nowString
        )

        // Add to activities array
        activities.append(newActivity)

        // Persist to Firestore in background — updateSessionState uses async updateData which
        // hangs offline and would prevent completeCurrentActivity from being called.
        Task { [weak self] in
            guard let self else { return }
            try? await self.repository.addSessionActivity(userId: self.userId, sessionId: sessionId, activity: newActivity)
            try? await self.repository.updateSessionState(userId: self.userId, sessionId: sessionId, updates: ["updatedAt": nowString])
        }

        // If queue was empty, immediately move to this new activity
        if shouldStartImmediately {
            await completeCurrentActivity()
        }
    }

    /// Refresh timer if needed (for foreground return)
    /// Called from ActiveSessionView.onChange(of: scenePhase)
    func refreshTimerIfNeeded() {
        if sessionState == .active && timerCancellable == nil {
            startTimer()
        }
    }

    /// Reset session to setup state (for starting a new session after one has ended)
    func resetSession() {
        // Cancel any existing timer
        timerCancellable?.cancel()
        timerCancellable = nil
        sessionListener?.remove()

        // End Live Activity before resetting state
        endLiveActivity()

        // Reset all state
        elapsedTime = 0
        totalSessionTime = 0
        activityPausedElapsed = 0
        sessionPausedElapsed = 0
        activityStartDate = nil
        sessionTimerStartDate = nil
        sessionState = .setup
        currentActivityIndex = 0
        activities = []
        currentSession = nil
        historicalNotes = []
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

    /// Completed activities (already practiced)
    var completedActivities: [SessionActivity] {
        guard currentActivityIndex > 0 else { return [] }
        return Array(activities[0..<currentActivityIndex])
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

    // MARK: - Live Activity Management

    /// Start a new Live Activity when session becomes active (D-06)
    private func startLiveActivity() {
        // Guard: Live Activities must be available and enabled
        guard #available(iOS 16.2, *),
              ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let attributes = HoneLiveActivityAttributes(
            sessionId: currentSession?.id ?? UUID().uuidString
        )
        let now = Date()
        let initialState = HoneLiveActivityAttributes.ContentState(
            activityStartDate: now,  // session just started, elapsed is 0
            isPaused: false,
            pausedElapsedSeconds: 0,
            activityName: currentActivityName,
            sessionStartDate: now,
            totalPausedSessionSeconds: 0
        )

        do {
            liveActivity = try ActivityKit.Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil)
            )
        } catch {
            // Live Activity failed silently — session continues without it
        }
    }

    /// Update Live Activity to paused state with frozen timer (D-08)
    private func updateLiveActivityPaused() {
        guard #available(iOS 16.2, *) else { return }
        let state = HoneLiveActivityAttributes.ContentState(
            activityStartDate: Date(),  // not used when isPaused=true
            isPaused: true,
            pausedElapsedSeconds: elapsedTime,
            activityName: currentActivityName,
            sessionStartDate: Date(),  // not used when isPaused=true
            totalPausedSessionSeconds: totalSessionTime
        )
        Task {
            await liveActivity?.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Update Live Activity to resumed/active state with live timer (D-08)
    private func updateLiveActivityResumed() {
        guard #available(iOS 16.2, *) else { return }
        let state = HoneLiveActivityAttributes.ContentState(
            activityStartDate: Date() - activityPausedElapsed,
            isPaused: false,
            pausedElapsedSeconds: 0,
            activityName: currentActivityName,
            sessionStartDate: Date() - sessionPausedElapsed,
            totalPausedSessionSeconds: 0
        )
        Task {
            await liveActivity?.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Update Live Activity when switching to a new activity (D-10)
    private func updateLiveActivityNewActivity() {
        guard #available(iOS 16.2, *) else { return }
        let state = HoneLiveActivityAttributes.ContentState(
            activityStartDate: Date(),  // new activity just started, elapsed is 0
            isPaused: false,
            pausedElapsedSeconds: 0,
            activityName: currentActivityName,
            sessionStartDate: Date() - totalSessionTime,
            totalPausedSessionSeconds: 0
        )
        Task {
            await liveActivity?.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// End Live Activity immediately (D-07)
    private func endLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        Task {
            await liveActivity?.end(dismissalPolicy: .immediate)
            liveActivity = nil
        }
    }
}
