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
    @State private var activitiesWithBackground: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !activities.isEmpty {
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: 8) {
                    ForEach(activities, id: \.createdAt) { activity in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)

                            Text(activity.activityName)
                                .font(.body)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(formatTime(activity.duration))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                                .padding(.trailing, 8)
                        }
                        .padding()
                        .background(
                            Color.green.opacity(activitiesWithBackground.contains(activity.createdAt) ? 0.1 : 0.0)
                        )
                        .cornerRadius(12)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .bottom)),
                            removal: .identity
                        ))
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: activities.count)
                .onChange(of: activities.count) { oldValue, newValue in
                    // When a new activity is added, delay showing its background
                    if newValue > oldValue, let latestActivity = activities.last {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds (after slide-in completes)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                activitiesWithBackground.insert(latestActivity.createdAt)
                            }
                        }
                    }
                }
                .onAppear {
                    // Initialize background for any existing activities (like the first one)
                    Task { @MainActor in
                        // Small delay to let the view settle
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                        // Fade in background for existing activities
                        for activity in activities {
                            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds per activity
                            withAnimation(.easeInOut(duration: 0.3)) {
                                activitiesWithBackground.insert(activity.createdAt)
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let totalMinutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", totalMinutes, remainingSeconds)
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
