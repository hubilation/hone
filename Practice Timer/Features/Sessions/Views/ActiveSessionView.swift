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
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompleteConfirmation = false
    @State private var showingSkipConfirmation = false
    @State private var showingEndSessionConfirmation = false
    @State private var showingAddActivity = false
    @State private var showingQuickStartSelection = false
    @State private var activityNameScale: CGFloat = 1.0
    @State private var isKeyboardVisible = false
    @FocusState private var isNotesFocused: Bool

    var body: some View {
        Group {
            if viewModel.sessionState == .ended {
                SessionSummaryViewLoader(session: viewModel.currentSession, userId: viewModel.userId)
            } else if viewModel.sessionState == .setup {
                // Show setup state (for quick start flow)
                setupContent
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
        .onAppear {
            // Reset to setup state if session has ended (for starting a new session)
            if viewModel.sessionState == .ended {
                viewModel.resetSession()
                showingQuickStartSelection = true
            }
            // If in setup state, immediately show activity selection for quick start
            else if viewModel.sessionState == .setup {
                showingQuickStartSelection = true
            }
        }
    }

    private var setupContent: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Getting ready...")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top)
            Spacer()
        }
        .navigationTitle("Practice Session")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingQuickStartSelection) {
            QuickStartActivitySelectionView(
                userId: viewModel.userId,
                isPresented: $showingQuickStartSelection,
                sessionViewModel: viewModel,
                dismissParent: dismiss
            )
        }
    }

    private var activeSessionContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 30) {
                        // Completed activities (shown above current activity)
                        CompletedActivitiesView(activities: viewModel.completedActivities)
                            .id("completedActivities")

                        // Current activity header
                        Text(viewModel.currentActivityName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .scaleEffect(activityNameScale)
                            .id("currentActivity")
                            .onChange(of: viewModel.currentActivityIndex) { oldValue, newValue in
                                // Animate when moving between activities
                                guard oldValue != newValue else { return }

                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

                                    // Pop animation: scale up
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.3)) {
                                        activityNameScale = 1.2
                                    }

                                    // Then spring back
                                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                                        activityNameScale = 1.0
                                    }
                                }
                            }

                        // Large timer display - tap to pause/resume
                        VStack(spacing: 8) {
                            TimerDisplayView(
                                elapsedTime: viewModel.elapsedTime,
                                isPaused: viewModel.sessionState == .paused
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    if viewModel.sessionState == .paused {
                                        await viewModel.resumeTimer()
                                    } else {
                                        await viewModel.pauseTimer()
                                    }
                                }
                            }

                            Text(viewModel.sessionState == .paused ? "Tap to resume" : "Tap to pause")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        // Notes for current activity (only show when paused)
                        if viewModel.sessionState == .paused {
                            Divider()

                            SessionNotesView(
                                notes: viewModel.currentActivityNotes,
                                historicalNotes: viewModel.historicalNotes,
                                onAddNote: { note in Task { await viewModel.addNote(note) } },
                                isFocused: $isNotesFocused
                            )
                            .padding(.horizontal)
                            .id("notes")

                            Divider()
                        }

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

                    // Add Activity button (bigger)
                    Button(action: {
                        showingAddActivity = true
                    }) {
                        Label(
                            viewModel.upcomingActivities.isEmpty ? "Add and Start Activity" : "Add Activity",
                            systemImage: "plus.circle"
                        )
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.blue.opacity(0.7))
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                    // Spacer to ensure enough scroll space for completed activities
                    Spacer(minLength: 300)
                    }
                    .padding([.vertical, .leading])
                }
                .onChange(of: viewModel.completedActivities.count) { oldValue, newValue in
                    // Auto-scroll to keep current activity/timer near top when activities complete
                    guard newValue > oldValue && newValue > 0 else { return }

                    Task { @MainActor in
                        // Wait for the slide-in animation to complete
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                        withAnimation(.easeInOut(duration: 0.4)) {
                            // Scroll to current activity but position it slightly down from top
                            // This shows more completed activities above while keeping timer stable
                            proxy.scrollTo("currentActivity", anchor: UnitPoint(x: 0.5, y: 0.08))
                        }
                    }
                }
            }

            // Docked session header at bottom (replacing tab bar)
            // Hide when keyboard is visible to prevent confusion with save note button
            if !isNotesFocused {
                SessionHeaderView(
                    totalSessionTime: viewModel.totalSessionTime,
                    isPaused: viewModel.sessionState == .paused,
                    currentActivityName: nil,
                    hasNextActivity: !viewModel.upcomingActivities.isEmpty,
                    onPause: { Task { await viewModel.pauseTimer() } },
                    onResume: { Task { await viewModel.resumeTimer() } },
                    onComplete: { showingEndSessionConfirmation = true },
                    onSkipNext: !viewModel.upcomingActivities.isEmpty ? {
                        showingSkipConfirmation = true
                    } : nil,
                    onTap: nil,
                    onAddActivity: { showingAddActivity = true }
                )
            }
        }
        .navigationTitle("Practice Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingAddActivity) {
            AddActivityToSessionView(userId: viewModel.userId, viewModel: viewModel, isPresented: $showingAddActivity)
        }
        .alert("Complete Activity?", isPresented: $showingCompleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete") {
                Task { await viewModel.completeCurrentActivity() }
            }
        } message: {
            if viewModel.upcomingActivities.isEmpty {
                Text("Complete \"\(viewModel.currentActivityName)\" and end session?")
            } else {
                Text("Mark \"\(viewModel.currentActivityName)\" as complete and move to next activity?")
            }
        }
        .alert("Skip to Next Activity?", isPresented: $showingSkipConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete & Start") {
                Task {
                    if let nextActivity = viewModel.upcomingActivities.first {
                        await viewModel.skipToActivity(nextActivity)
                    }
                }
            }
        } message: {
            if let nextActivity = viewModel.upcomingActivities.first {
                Text("Complete \"\(viewModel.currentActivityName)\" and start \"\(nextActivity.activityName)\"?")
            }
        }
        .alert("End Session?", isPresented: $showingEndSessionConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End Session", role: .destructive) {
                Task { await viewModel.endSession() }
            }
        } message: {
            let queueCount = viewModel.upcomingActivities.count
            if queueCount == 0 {
                Text("Complete \"\(viewModel.currentActivityName)\" and end session?")
            } else {
                Text("Complete \"\(viewModel.currentActivityName)\", skip \(queueCount) \(queueCount == 1 ? "activity" : "activities"), and end session?")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActiveSessionView(viewModel: SessionViewModel(userId: "preview-user-id"))
    }
}
