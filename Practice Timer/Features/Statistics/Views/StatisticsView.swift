//
//  StatisticsView.swift
//  Practice Timer
//
//  Created by Claude on 3/4/26.
//

import SwiftUI

struct StatisticsView: View {
    let userId: String
    let sessions: [Session]
    let activities: [Activity]

    private var weekSummary: (totalTime: TimeInterval, sessionCount: Int, averagePerDay: TimeInterval, daysInWeek: Int)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the most recent Sunday (start of week)
        // Sunday = 1, Monday = 2, ... Saturday = 7
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = weekday - 1  // 0 if Sunday, 1 if Monday, etc.
        let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!

        let weekSessions = sessions.filter { session in
            guard session.state == "ended" else { return false }
            guard let startDate = Date(iso8601String: session.startTime) else { return false }
            return startDate >= startOfWeek
        }

        // Return nil if no sessions this week
        guard !weekSessions.isEmpty else { return nil }

        let totalSeconds = weekSessions.reduce(0) { $0 + $1.totalDuration }

        // Calculate days elapsed in the week (Sunday=1, so daysToSubtract+1 gives us days including today)
        let daysElapsed = daysToSubtract + 1
        let averagePerDay = TimeInterval(totalSeconds) / TimeInterval(daysElapsed)

        return (TimeInterval(totalSeconds), weekSessions.count, averagePerDay, daysElapsed)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recent practice summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.headline)

                    if let summary = weekSummary {
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(summary.totalTime.formatted())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sessions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(summary.sessionCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Time Per Day")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(summary.averagePerDay.formatted())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                        }
                    } else {
                        Text("You haven't practiced this week!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Daily practice chart
                DailyPracticeChartView(
                    userId: userId,
                    sessions: sessions,
                    activities: activities
                )

                // Activity breakdown chart
                ActivityBreakdownChartView(userId: userId, activities: activities)

                // Link to detailed activity statistics (reuse from Phase 2)
                NavigationLink {
                    ActivityStatisticsView(userId: userId, activities: activities)
                } label: {
                    HStack {
                        Text("View Detailed Activity Statistics")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StatisticsView(
            userId: "preview-user",
            sessions: [],
            activities: []
        )
    }
}
