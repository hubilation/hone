//
//  ActivityQueueView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Upcoming activities with skip/remove/reorder actions
/// SINGLE RESPONSIBILITY: Display and manage activity queue during session
struct ActivityQueueView: View {
    let activities: [SessionActivity]
    let onSkip: () -> Void
    let onRemove: (SessionActivity) -> Void
    let onReorder: (IndexSet, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming Activities")
                .font(.headline)

            if activities.isEmpty {
                Text("No upcoming activities")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(activities) { activity in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.activityName)
                                    .font(.body)
                                if activity.isInBetweenTime {
                                    Text("Break")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Remove button
                            Button(action: { onRemove(activity) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }

                // Skip to next button
                Button(action: onSkip) {
                    Label("Skip to Next Activity", systemImage: "forward.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 4)
            }
        }
    }
}

#Preview {
    let activities = [
        SessionActivity(
            id: "1",
            activityId: "a1",
            activityName: "Scales",
            startTime: "",
            endTime: nil,
            duration: 0,
            notes: nil,
            isInBetweenTime: false,
            createdAt: "",
            updatedAt: ""
        ),
        SessionActivity(
            id: "2",
            activityId: "a2",
            activityName: "Piece Practice",
            startTime: "",
            endTime: nil,
            duration: 0,
            notes: nil,
            isInBetweenTime: false,
            createdAt: "",
            updatedAt: ""
        )
    ]

    ActivityQueueView(
        activities: activities,
        onSkip: { print("Skip") },
        onRemove: { print("Remove \($0.activityName)") },
        onReorder: { print("Reorder \($0) to \($1)") }
    )
}
