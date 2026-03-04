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

    var body: some View {
        Group {
            if viewModel.sessionState == .ended {
                SessionSummaryView(session: viewModel.currentSession, activities: viewModel.activities)
            } else {
                activeSessionContent
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // CRITICAL: Refresh timer when app returns to foreground
            if oldPhase == .background && newPhase == .active {
                viewModel.refreshTimerIfNeeded()
            }
        }
    }

    private var activeSessionContent: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Current activity header
                Text(viewModel.currentActivityName)
                    .font(.title2)
                    .fontWeight(.semibold)

                // Large timer display
                TimerDisplayView(elapsedTime: viewModel.elapsedTime)

                // Session controls (Pause/Resume/End)
                SessionControlsView(
                    state: viewModel.sessionState,
                    onPause: { Task { await viewModel.pauseTimer() } },
                    onResume: { Task { await viewModel.resumeTimer() } },
                    onEnd: { Task { await viewModel.endSession() } }
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
            }
            .padding()
        }
        .navigationTitle("Practice Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActiveSessionView(viewModel: SessionViewModel(userId: "preview-user-id"))
    }
}
