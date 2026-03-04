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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Group sessions by calendar day
        let grouped = Dictionary(grouping: sessions) { session -> String in
            guard let date = Date(iso8601String: session.startTime) else { return "" }
            let dayStart = calendar.startOfDay(for: date)
            return dayStart.toISO8601String()
        }

        // Map to DayGroup with human-readable headers
        let groups = grouped.compactMap { (dateString, sessions) -> DayGroup? in
            guard let date = Date(iso8601String: dateString) else { return nil }
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

        return groups.sorted { $0.id > $1.id }  // Newest days first
    }

    func startListening() {
        guard !listenersStarted else { return }
        listenersStarted = true

        sessionsListener = repository.listenToSessions(userId: userId, limit: 100) { [weak self] sessions in
            Task { @MainActor in
                self?.sessions = sessions
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
