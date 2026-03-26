//
//  StatisticsView.swift
//  Hone
//
//  Created by Claude on 3/4/26.
//

import SwiftUI

struct StatisticsView: View {
    let userId: String
    let sessions: [Session]
    let activities: [Activity]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recent practice summary
                WeeklySummaryCard(sessions: sessions)

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
