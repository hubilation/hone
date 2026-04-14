//
//  SessionSummaryView.swift
//  Hone
//
//  Created by Claude on 3/4/26.
//

import SwiftUI

/// Post-session summary displaying activity breakdown and notes
/// Shows total time, per-activity times, and all notes
struct SessionSummaryView: View {
    let session: Session?
    let activities: [SessionActivity]
    @Environment(\.dismiss) private var dismiss

    private var totalDuration: TimeInterval {
        TimeInterval(activities.reduce(0) { $0 + $1.duration })
    }

    private var formattedTotalTime: String {
        formatDuration(totalDuration)
    }

    var body: some View {
        NavigationView {
            List {
                // Total session time
                Section(header: Text("Session Complete")) {
                    HStack {
                        Text("Total Practice Time")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formattedTotalTime)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    if let session = session, let startTime = session.startTime.toDate() {
                        HStack {
                            Text("Started")
                            Spacer()
                            Text(startTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let session = session, let endTime = session.endTime?.toDate() {
                        HStack {
                            Text("Ended")
                            Spacer()
                            Text(endTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Activity breakdown
                Section(header: Text("Activity Breakdown")) {
                    ForEach(activities.filter { !$0.isInBetweenTime }) { activity in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(activity.activityName)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(formatDuration(TimeInterval(activity.duration)))
                                    .foregroundColor(.secondary)
                            }

                            if let notes = activity.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // In-between time (if any)
                let inBetweenActivities = activities.filter { $0.isInBetweenTime }
                if !inBetweenActivities.isEmpty {
                    Section(header: Text("Break Time")) {
                        ForEach(inBetweenActivities) { activity in
                            HStack {
                                Text("Break")
                                Spacer()
                                Text(formatDuration(TimeInterval(activity.duration)))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Total Break Time")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(formatDuration(TimeInterval(inBetweenActivities.reduce(0) { $0 + $1.duration })))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

/// Wrapper view for reactive session summary with SessionHistoryViewModel
/// Observes ViewModel's sessionActivities dictionary and updates when activities load
struct ReactiveSessionSummaryView: View {
    let session: Session?
    @ObservedObject var viewModel: SessionHistoryViewModel

    var body: some View {
        SessionSummaryView(
            session: session,
            activities: viewModel.sessionActivities[session?.id ?? ""] ?? []
        )
    }
}

/// Loader view that fetches activities from Firestore for session summary
/// Ensures summary always shows accurate data from database, not in-memory array
struct SessionSummaryViewLoader: View {
    let session: Session?
    let userId: String
    @State private var activities: [SessionActivity] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                SessionSummaryView(session: session, activities: activities)
            }
        }
        .task {
            await loadActivities()
        }
    }

    private func loadActivities() async {
        guard let sessionId = session?.id else {
            isLoading = false
            return
        }

        do {
            let repository = SessionRepository()
            activities = try await repository.getSessionActivities(userId: userId, sessionId: sessionId)
            isLoading = false
        } catch {
            print("Error loading session activities: \(error)")
            isLoading = false
        }
    }
}

#Preview {
    let session = Session(
        id: "s1",
        startTime: Date().addingTimeInterval(-1620).toISO8601String(),
        endTime: Date().toISO8601String(),
        totalDuration: 1620,
        createdAt: Date().toISO8601String(),
        updatedAt: Date().toISO8601String(),
        state: "ended",
        pausedAt: nil,
        currentActivityIndex: 2
    )

    let activities = [
        SessionActivity(
            id: "1",
            activityId: "a1",
            activityName: "Scales",
            startTime: "",
            endTime: "",
            duration: 600,  // 10 minutes
            notes: "Focused on C major",
            isInBetweenTime: false,
            createdAt: "",
            updatedAt: ""
        ),
        SessionActivity(
            id: "2",
            activityId: nil,
            activityName: "Break",
            startTime: "",
            endTime: "",
            duration: 120,  // 2 minutes
            notes: nil,
            isInBetweenTime: true,
            createdAt: "",
            updatedAt: ""
        ),
        SessionActivity(
            id: "3",
            activityId: "a2",
            activityName: "Piece Practice",
            startTime: "",
            endTime: "",
            duration: 900,  // 15 minutes
            notes: "Worked on measures 32-48",
            isInBetweenTime: false,
            createdAt: "",
            updatedAt: ""
        )
    ]

    return SessionSummaryView(session: session, activities: activities)
}
