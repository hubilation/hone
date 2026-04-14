//
//  SuggestionsService.swift
//  Hone
//
//  Created by Claude on 4/14/26.
//

import Foundation

/// Stateless utility for activity suggestions and streak. Mirrors ActivityGrouping.swift pattern.
struct SuggestionsService {

    // MARK: - Suggestion Scoring (D-01)

    /// Returns top N active, non-completed activities ranked by how overdue they are.
    /// Returns [] when no activity has a lastUsed date (new user guard).
    /// Score = 0.7 * daysSinceLast + 0.3 * max(0, 30 - daysSinceLast)
    static func suggestedActivities(
        activities: [Activity],
        sessions: [Session],
        limit: Int = 4
    ) -> [Activity] {
        let now = Date()
        let calendar = Calendar.current

        let candidates = activities.filter { $0.isActive && !$0.isCompleted }

        // New-user guard: if no activity has been practiced, show nothing
        guard candidates.contains(where: { $0.lastUsed != nil }) else { return [] }

        func score(_ activity: Activity) -> Double {
            let daysSinceLast: Double
            if let lastUsedStr = activity.lastUsed,
               let date = Date(iso8601String: lastUsedStr) {
                let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
                daysSinceLast = Double(max(0, days))
            } else {
                daysSinceLast = 365.0  // Never practiced — highest urgency
            }
            let frequencyScore = max(0.0, 30.0 - daysSinceLast)
            return 0.7 * daysSinceLast + 0.3 * frequencyScore
        }

        return candidates
            .sorted { score($0) > score($1) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Streak Computation (D-03)

    /// Consecutive calendar days with at least one ended session.
    /// Walks from yesterday when today has no session (streak alive until day ends).
    static func currentStreak(sessions: [Session]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let practicedDays: Set<Date> = Set(
            sessions
                .filter { $0.state == "ended" }
                .compactMap { session -> Date? in
                    guard let date = Date(iso8601String: session.startTime) else { return nil }
                    return calendar.startOfDay(for: date)
                }
        )

        guard !practicedDays.isEmpty else { return 0 }

        var checkDay = practicedDays.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)!

        var streak = 0
        while practicedDays.contains(checkDay) {
            streak += 1
            checkDay = calendar.date(byAdding: .day, value: -1, to: checkDay)!
        }
        return streak
    }
}
