//
//  ActivityQueueView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Upcoming activities with skip/remove actions
/// SINGLE RESPONSIBILITY: Display and manage activity queue during session
struct ActivityQueueView: View {
    let activities: [SessionActivity]
    let currentActivityName: String
    let onSkip: (SessionActivity) -> Void
    let onRemove: (SessionActivity) -> Void
    let onReorder: (IndexSet, Int) -> Void

    @State private var activityToSkipTo: SessionActivity?
    @State private var showingSkipConfirmation = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    ForEach(activities, id: \.createdAt) { activity in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.activityName)
                                    .font(.title3)
                                    .fontWeight(.medium)
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
                                        .font(.title2)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if editMode == .inactive {
                                activityToSkipTo = activity
                                showingSkipConfirmation = true
                            }
                        }
                    }
                    .onMove(perform: onReorder)
                }
                .environment(\.editMode, $editMode)
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(activities.count) * 70)
            }
        }
        .alert("Complete Activity?", isPresented: $showingSkipConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete & Start") {
                if let activity = activityToSkipTo {
                    onSkip(activity)
                }
            }
        } message: {
            if let activity = activityToSkipTo {
                Text("Complete \"\(currentActivityName)\" and start \"\(activity.activityName)\"?")
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
        currentActivityName: "Current Activity",
        onSkip: { activity in print("Skip to \(activity.activityName)") },
        onRemove: { print("Remove \($0.activityName)") },
        onReorder: { print("Reorder \($0) to \($1)") }
    )
}
