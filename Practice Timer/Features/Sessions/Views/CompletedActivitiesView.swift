//
//  CompletedActivitiesView.swift
//  Practice Timer
//
//  Created by Claude on 3/5/26.
//

import SwiftUI

/// Displays completed activities with checkmarks
/// Shows activities that have already been practiced in the current session
struct CompletedActivitiesView: View {
    let activities: [SessionActivity]

    var body: some View {
        if !activities.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: 8) {
                    ForEach(activities) { activity in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)

                            Text(activity.activityName)
                                .font(.body)
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

#Preview {
    let now = Date().toISO8601String()
    let completedActivities = [
        SessionActivity(
            activityId: "a1",
            activityName: "Triads",
            startTime: now,
            endTime: now,
            duration: 300,
            notes: nil,
            isInBetweenTime: false,
            createdAt: now,
            updatedAt: now
        ),
        SessionActivity(
            activityId: "a2",
            activityName: "Scales",
            startTime: now,
            endTime: now,
            duration: 420,
            notes: nil,
            isInBetweenTime: false,
            createdAt: now,
            updatedAt: now
        )
    ]

    CompletedActivitiesView(activities: completedActivities)
        .padding()
}
