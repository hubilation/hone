//
//  ActivityQueueView.swift
//  Hone
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !activities.isEmpty {
                List {
                    ForEach(activities, id: \.createdAt) { activity in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.activityName)
                                    .font(.body)
                                    .fontWeight(.medium)
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
                                    .font(.title3)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activityToSkipTo = activity
                            showingSkipConfirmation = true
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onMove(perform: onReorder)
                }
                .environment(\.editMode, .constant(.active))
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(activities.count) * 80)
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
