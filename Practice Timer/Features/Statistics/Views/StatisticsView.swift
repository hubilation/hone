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

    private var weekSummary: (totalTime: TimeInterval, sessionCount: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        let weekSessions = sessions.filter { session in
            guard session.state == "ended" else { return false }
            guard let startDate = Date(iso8601String: session.startTime) else { return false }
            return startDate >= oneWeekAgo
        }

        let totalSeconds = weekSessions.reduce(0) { $0 + $1.totalDuration }
        return (TimeInterval(totalSeconds), weekSessions.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recent practice summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.headline)

                    HStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(weekSummary.totalTime.formatted())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(weekSummary.sessionCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
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
