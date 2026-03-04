//
//  ActivityBreakdownChartView.swift
//  Practice Timer
//
//  Created by Claude on 3/4/26.
//

import SwiftUI
import Charts

/// Data point for activity practice time
struct ActivityPracticeData: Identifiable {
    let id = UUID()
    let activityName: String
    let hours: Double
}

struct ActivityBreakdownChartView: View {
    let userId: String
    let activities: [Activity]

    @State private var chartData: [ActivityPracticeData] = []
    @State private var isLoading = false

    private let statisticsRepository = StatisticsRepository()

    private func loadChartData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let stats = try await statisticsRepository.getAllActivityStatistics(
                userId: userId,
                activities: activities
            )

            chartData = stats.map { stat in
                ActivityPracticeData(
                    activityName: stat.activityName,
                    hours: stat.totalPracticeTime / 3600.0
                )
            }
            .sorted { $0.hours > $1.hours }  // Most-practiced first
        } catch {
            print("ERROR loading activity statistics: \(error)")
            chartData = []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Practice Time by Activity")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if chartData.isEmpty {
                Text("No practice data yet. Complete a session to see activity breakdown.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData) { data in
                    BarMark(
                        x: .value("Hours", data.hours),
                        y: .value("Activity", data.activityName)
                    )
                    .foregroundStyle(by: .value("Activity", data.activityName))
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text(String(format: "%.1fh", hours))
                            }
                        }
                    }
                }
                .frame(height: max(50.0 * Double(chartData.count), 150))  // Dynamic height based on activity count
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task {
            await loadChartData()
        }
    }
}

#Preview {
    let activities = [
        Activity(
            id: "a1",
            name: "Scales",
            category: "Technique",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        ),
        Activity(
            id: "a2",
            name: "Sight Reading",
            category: "Warm-up",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        )
    ]

    ActivityBreakdownChartView(userId: "preview-user", activities: activities)
        .padding()
}
