//
//  ActivityStatisticsView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Displays activity statistics using Firestore aggregation queries
///
/// Shows total practice time and session count for each activity,
/// sorted by most-practiced first. Statistics calculate server-side
/// to avoid downloading potentially thousands of session documents.
///
/// **Loading States:**
/// - Loading: ProgressView while fetching statistics
/// - Empty: ContentUnavailableView when no sessions exist yet
/// - Error: ContentUnavailableView with error message
/// - Data: List of activities with total time and session count
///
/// **Performance:**
/// - Uses Firestore aggregation queries (1 read per activity)
/// - Pull-to-refresh gesture for manual updates
/// - Loads automatically on view appear (.task modifier)
struct ActivityStatisticsView: View {
    let userId: String
    let activities: [Activity]

    @State private var statistics: [ActivityStatistics] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let repository: StatisticsRepositoryProtocol

    /// Initialize with dependency injection for testability
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - activities: Array of activities to calculate statistics for
    ///   - repository: Statistics repository (defaults to production implementation)
    init(userId: String, activities: [Activity], repository: StatisticsRepositoryProtocol = StatisticsRepository()) {
        self.userId = userId
        self.activities = activities
        self.repository = repository
    }

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading statistics...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Error Loading Statistics",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if statistics.isEmpty {
                ContentUnavailableView(
                    "No Practice History",
                    systemImage: "chart.bar",
                    description: Text("Start a practice session to see statistics")
                )
            } else {
                ForEach(statistics) { stat in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(stat.activityName)
                                .font(.headline)
                            Spacer()
                            Text(stat.formattedTime)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        HStack {
                            Label("\(stat.sessionCount) sessions", systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Activity Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadStatistics()
        }
        .task {
            await loadStatistics()
        }
    }

    /// Loads statistics from repository using Firestore aggregation queries
    ///
    /// Fetches statistics for all activities and updates UI state.
    /// Shows empty state if no sessions exist (Phase 3 implements session creation).
    /// Handles errors gracefully with error message display.
    private func loadStatistics() async {
        isLoading = true
        errorMessage = nil

        do {
            statistics = try await repository.getAllActivityStatistics(
                userId: userId,
                activities: activities
            )
        } catch {
            errorMessage = "Failed to load statistics: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
