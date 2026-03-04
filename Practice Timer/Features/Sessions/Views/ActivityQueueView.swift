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

    @State private var editMode: EditMode = .inactive

    var body: some View {
        let _ = print("DEBUG ActivityQueueView: Received \(activities.count) activities")
        let _ = activities.forEach { print("  - \($0.activityName) (id: \($0.id ?? "nil"))") }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Upcoming Activities")
                    .font(.headline)

                Spacer()

                if !activities.isEmpty {
                    EditButton()
                        .environment(\.editMode, $editMode)
                }
            }

            if activities.isEmpty {
                Text("No upcoming activities")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(activities) { activity in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(activity.activityName)
                                    .font(.body)
                                if activity.isInBetweenTime {
                                    Text("Break")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Remove button (only in non-edit mode)
                            if editMode == .inactive {
                                Button(action: { onRemove(activity) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onMove(perform: editMode == .active ? onReorder : nil)
                }
                .environment(\.editMode, $editMode)
                .frame(maxHeight: 200)  // Limit height to prevent taking over screen
                .listStyle(.plain)

                // Skip to next button
                Button(action: onSkip) {
                    Label("Skip to Next Activity", systemImage: "forward.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
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
