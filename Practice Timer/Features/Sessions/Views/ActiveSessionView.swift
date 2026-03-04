//
//  ActiveSessionView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Orchestrator view for active practice session
/// Composes timer display, controls, notes, and activity queue
/// Monitors scenePhase for background/foreground transitions
struct ActiveSessionView: View {
    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSummary = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Current activity header
                Text(viewModel.currentActivityName)
                    .font(.title2)
                    .fontWeight(.semibold)

                // Large timer display
                TimerDisplayView(elapsedTime: viewModel.elapsedTime)

                // Session progress bar
                VStack(alignment: .leading, spacing: 5) {
                    Text("Session Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
                .padding(.horizontal)

                // Session controls (Pause/Resume/End)
                SessionControlsView(
                    state: viewModel.sessionState,
                    onPause: { Task { await viewModel.pauseTimer() } },
                    onResume: { Task { await viewModel.resumeTimer() } },
                    onEnd: {
                        Task {
                            await viewModel.endSession()
                            showingSummary = true
                        }
                    }
                )

                Divider()

                // Notes for current activity
                SessionNotesView(
                    notes: viewModel.currentActivityNotes,
                    onAddNote: { note in Task { await viewModel.addNote(note) } }
                )
                .padding(.horizontal)

                Divider()

                // Upcoming activities queue
                ActivityQueueView(
                    activities: viewModel.upcomingActivities,
                    onSkip: {
                        Task {
                            await viewModel.skipToNext()
                        }
                    },
                    onRemove: { activity in
                        Task { await viewModel.removeActivity(activity) }
                    },
                    onReorder: { from, to in
                        // Convert IndexSet to Int for first index
                        if let fromIndex = from.first {
                            viewModel.reorderActivities(from: fromIndex, to: to)
                        }
                    }
                )
                .padding(.horizontal)

                // Manual "Start Next Activity" button when in inBetween state
                if viewModel.sessionState == .inBetween {
                    Button(action: {
                        Task { await viewModel.startNextActivity() }
                    }) {
                        Label("Start Next Activity", systemImage: "play.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .navigationTitle("Practice Session")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // CRITICAL: Refresh timer when app returns to foreground
            if oldPhase == .background && newPhase == .active {
                viewModel.refreshTimerIfNeeded()
            }
        }
        .sheet(isPresented: $showingSummary) {
            SessionSummaryView(session: viewModel.currentSession, activities: viewModel.activities)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActiveSessionView(viewModel: SessionViewModel(userId: "preview-user-id"))
    }
}
