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
    @State private var showingCompleteConfirmation = false

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

                // Complete Activity button
                Button(action: {
                    showingCompleteConfirmation = true
                }) {
                    Label("Complete Activity", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)

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
                    historicalNotes: viewModel.historicalNotes,
                    onAddNote: { note in Task { await viewModel.addNote(note) } }
                )
                .padding(.horizontal)

                Divider()

                // Upcoming activities queue
                ActivityQueueView(
                    activities: viewModel.upcomingActivities,
                    currentActivityName: viewModel.currentActivityName,
                    onSkip: { activity in
                        Task { await viewModel.skipToActivity(activity) }
                    },
                    onRemove: { activity in
                        Task { await viewModel.removeActivity(activity) }
                    },
                    onReorder: { from, to in
                        // Offset indices by currentActivityIndex + 1 since upcoming activities
                        // are a slice of the full activities array
                        let offset = viewModel.currentActivityIndex + 1
                        if let fromIndex = from.first {
                            viewModel.reorderActivities(from: fromIndex + offset, to: to + offset)
                        }
                    }
                )
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Practice Session")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Complete Activity?", isPresented: $showingCompleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete") {
                Task { await viewModel.completeCurrentActivity() }
            }
        } message: {
            Text("Mark \"\(viewModel.currentActivityName)\" as complete and move to next activity?")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActiveSessionView(viewModel: SessionViewModel(userId: "preview-user-id"))
    }
}
