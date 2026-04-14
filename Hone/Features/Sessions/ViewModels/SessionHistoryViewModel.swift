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

    var groupedSessions: [DayGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let grouped = Dictionary(grouping: sessions) { session -> String in
            guard let date = Date(iso8601String: session.startTime) else { return "" }
            let dayStart = calendar.startOfDay(for: date)
            return dayStart.toISO8601String()
        }

        let groups = grouped.compactMap { (dateString, sessions) -> DayGroup? in
            guard let date = Date(iso8601String: dateString) else { return nil }
            let dayStart = calendar.startOfDay(for: date)

            let header: String
            if calendar.isDate(dayStart, inSameDayAs: today) {
                header = "Today"
            } else if calendar.isDate(dayStart, inSameDayAs: yesterday) {
                header = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                header = formatter.string(from: date)
            }

            return DayGroup(
                id: dateString,
                dayHeader: header,
                sessions: sessions.sorted { $0.startTime > $1.startTime }
            )
        }

        return groups.sorted { $0.id > $1.id }
    }

    func startListening() {
        guard !listenersStarted else { return }
        listenersStarted = true

        sessionsListener = repository.listenToSessions(userId: userId, limit: 100) { [weak self] sessions in
            Task { @MainActor in
                self?.sessions = sessions
                await self?.loadActivitiesForSessions(sessions)
            }
        }
    }

    private func loadActivitiesForSessions(_ sessions: [Session]) async {
        await withTaskGroup(of: (String, [SessionActivity]).self) { group in
            for session in sessions {
                guard let sessionId = session.id else { continue }
                group.addTask {
                    do {
                        let activities = try await self.repository.getSessionActivities(userId: self.userId, sessionId: sessionId)
                        return (sessionId, activities)
                    } catch {
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
            return []
        }
    }

    deinit {
        sessionsListener?.remove()
    }
}
