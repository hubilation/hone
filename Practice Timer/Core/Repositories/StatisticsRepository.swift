//
//  StatisticsRepository.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Models

/// Activity statistics aggregated from session data
///
/// Calculates total practice time and session count per activity using
/// Firestore server-side aggregation queries. This avoids downloading
/// potentially thousands of session documents (99% read savings at scale).
struct ActivityStatistics: Identifiable {
    let id: String  // activityId
    let activityId: String
    let activityName: String
    let totalPracticeTime: TimeInterval  // seconds
    let sessionCount: Int

    /// Formats total practice time as human-readable string
    /// Examples: "2h 15m", "45m", "0m" (if no sessions)
    var formattedTime: String {
        let hours = Int(totalPracticeTime) / 3600
        let minutes = (Int(totalPracticeTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Protocol

/// Protocol defining Statistics repository operations
///
/// Uses Firestore aggregation queries to calculate statistics server-side
/// without downloading session documents. Critical for scalability.
protocol StatisticsRepositoryProtocol {
    /// Gets statistics for a single activity
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - activityId: The activity's document ID
    ///   - activityName: The activity's display name
    /// - Returns: Activity statistics with total time and session count
    /// - Throws: Firestore error if query fails
    func getActivityStatistics(userId: String, activityId: String, activityName: String) async throws -> ActivityStatistics

    /// Gets statistics for all activities, sorted by most-practiced first
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - activities: Array of activities to calculate statistics for
    /// - Returns: Array of statistics sorted by total practice time descending
    /// - Throws: Firestore error if any query fails
    func getAllActivityStatistics(userId: String, activities: [Activity]) async throws -> [ActivityStatistics]
}

// MARK: - Implementation

/// Repository for calculating activity statistics using Firestore aggregation queries
///
/// **Firestore Aggregation Queries:**
/// - Introduced in Firebase iOS SDK 12.10.0+
/// - Calculates sum, count, average server-side (not in client)
/// - Returns single result document (not downloading all session documents)
/// - Read cost: 1 aggregation query ≈ 1 document read (regardless of session count)
/// - Savings: For 1000 sessions, saves 999 reads vs downloading all documents
///
/// **Performance:**
/// - Uses .server source to force server-side calculation (not cache)
/// - Handles nil results when no sessions exist for an activity
/// - Efficient for large session histories (100s-1000s of sessions per activity)
///
/// **Data Model:**
/// - Queries sessions subcollection: users/{userId}/sessions
/// - Filters by activityId field
/// - Aggregates duration field (sum) and count
final class StatisticsRepository: StatisticsRepositoryProtocol {
    private let db = Firestore.firestore()

    /// Gets statistics for a single activity using Firestore aggregation
    func getActivityStatistics(userId: String, activityId: String, activityName: String) async throws -> ActivityStatistics {
        let sessionsRef = db.collection("users").document(userId)
            .collection("sessions")
            .whereField("activityId", isEqualTo: activityId)

        // Firestore aggregation query - calculates server-side
        // Returns single aggregated result (not downloading session documents)
        let snapshot = try await sessionsRef
            .aggregate([
                AggregateField.sum("duration"),
                AggregateField.count()
            ])
            .getAggregation(source: .server)

        // Handle nil results when no sessions exist for this activity
        let totalTime = snapshot.get(AggregateField.sum("duration")) as? Double ?? 0.0
        let count = snapshot.get(AggregateField.count()) as? Int ?? 0

        return ActivityStatistics(
            id: activityId,
            activityId: activityId,
            activityName: activityName,
            totalPracticeTime: totalTime,
            sessionCount: count
        )
    }

    /// Gets statistics for all activities, sorted by most-practiced first
    ///
    /// Executes one aggregation query per activity. For N activities, this is
    /// N aggregation queries. Still efficient because each query is server-side.
    /// Alternative would be downloading all sessions and grouping client-side,
    /// which costs M document reads for M total sessions (could be 1000s).
    func getAllActivityStatistics(userId: String, activities: [Activity]) async throws -> [ActivityStatistics] {
        var statistics: [ActivityStatistics] = []

        for activity in activities {
            guard let activityId = activity.id else { continue }

            let stats = try await getActivityStatistics(
                userId: userId,
                activityId: activityId,
                activityName: activity.name
            )
            statistics.append(stats)
        }

        // Sort by most-practiced first (descending total time)
        return statistics.sorted { $0.totalPracticeTime > $1.totalPracticeTime }
    }
}
