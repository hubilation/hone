import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

/// Groups sessions by calendar day for section headers
struct DayGroup: Identifiable {
    let id: String  // ISO date string (e.g., "2026-03-04")
    let dayHeader: String  // Display text (e.g., "Today", "Yesterday", "Monday, Mar 3")
    let sessions: [Session]
}

@MainActor
final class SessionHistoryViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var sessionActivities: [String: [SessionActivity]] = [:]
    @Published var isLoading = false

    private let repository: SessionRepositoryProtocol
    private let userId: String
    private var sessionsListener: ListenerRegistration?
    private var listenersStarted = false

    init(userId: String, repository: SessionRepositoryProtocol = SessionRepository()) {
        self.userId = userId
        self.repository = repository
    }

    /// Computed property that groups sessions by calendar day
    var groupedSessions: [DayGroup] {
        print("🔍 DEBUG: groupedSessions computed - sessions.count = \(sessions.count)")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Group sessions by calendar day
        let grouped = Dictionary(grouping: sessions) { session -> String in
            guard let date = Date(iso8601String: session.startTime) else {
                print("🔍 DEBUG: Failed to parse date for session startTime: '\(session.startTime)'")
                return ""
            }
            let dayStart = calendar.startOfDay(for: date)
            return dayStart.toISO8601String()
        }
        print("🔍 DEBUG: Grouped into \(grouped.count) day groups")

        // Map to DayGroup with human-readable headers
        let groups = grouped.compactMap { (dateString, sessions) -> DayGroup? in
            guard let date = Date(iso8601String: dateString) else {
                print("🔍 DEBUG: Failed to parse dateString for DayGroup: '\(dateString)'")
                return nil
            }
            let dayStart = calendar.startOfDay(for: date)

            let header: String
            if calendar.isDate(dayStart, inSameDayAs: today) {
                header = "Today"
            } else if calendar.isDate(dayStart, inSameDayAs: yesterday) {
                header = "Yesterday"
            } else {
                // Format as "Monday, Mar 3"
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                header = formatter.string(from: date)
            }

            return DayGroup(
                id: dateString,
                dayHeader: header,
                sessions: sessions.sorted { $0.startTime > $1.startTime }  // Newest first within day
            )
        }

        let sortedGroups = groups.sorted { $0.id > $1.id }  // Newest days first
        print("🔍 DEBUG: Returning \(sortedGroups.count) day groups")
        return sortedGroups
    }

    func startListening() {
        print("🔍 DEBUG: SessionHistoryViewModel.startListening() called for userId: '\(userId)'")
        guard !listenersStarted else {
            print("🔍 DEBUG: Listeners already started, skipping")
            return
        }
        listenersStarted = true
        print("🔍 DEBUG: Attaching sessions listener...")

        sessionsListener = repository.listenToSessions(userId: userId, limit: 100) { [weak self] sessions in
            Task { @MainActor in
                print("🔍 DEBUG: Sessions listener callback fired - received \(sessions.count) sessions")
                self?.sessions = sessions
                // Load activities for all sessions
                await self?.loadActivitiesForSessions(sessions)
            }
        }
        print("🔍 DEBUG: Sessions listener attached")
    }

    private func loadActivitiesForSessions(_ sessions: [Session]) async {
        // Load activities for each session in parallel
        await withTaskGroup(of: (String, [SessionActivity]).self) { group in
            for session in sessions {
                guard let sessionId = session.id else { continue }

                group.addTask {
                    do {
                        let activities = try await self.repository.getSessionActivities(userId: self.userId, sessionId: sessionId)
                        return (sessionId, activities)
                    } catch {
                        print("ERROR loading activities for session \(sessionId): \(error)")
                        return (sessionId, [])
                    }
                }
            }

            for await (sessionId, activities) in group {
                sessionActivities[sessionId] = activities
            }
        }
    }

    func deleteSession(_ session: Session) async {
        guard let sessionId = session.id else { return }

        do {
            try await repository.deleteSession(userId: userId, sessionId: sessionId)
        } catch {
            print("ERROR deleting session: \(error)")
        }
    }

    func getActivities(for session: Session) async -> [SessionActivity] {
        guard let sessionId = session.id else { return [] }

        do {
            return try await repository.getSessionActivities(userId: userId, sessionId: sessionId)
        } catch {
            print("ERROR loading session activities: \(error)")
            return []
        }
    }

    deinit {
        sessionsListener?.remove()  // CRITICAL: Prevent memory leaks
    }
}
