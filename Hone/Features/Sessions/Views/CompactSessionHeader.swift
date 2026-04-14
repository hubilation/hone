//
//  CompactSessionHeader.swift
//  Hone
//
//  Created by Claude on 3/6/26.
//

import SwiftUI

/// View modifier that shows a compact session header at the top when a session is active
/// Allows users to monitor and control session from any view in the app
struct CompactSessionHeader: ViewModifier {
    @ObservedObject var sessionViewModel: SessionViewModel
    @Binding var showActiveSession: Bool
    @State private var showingEndSessionConfirmation = false
    @State private var showingSkipConfirmation = false
    @State private var showingAddActivity = false

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            // Show header if session is active (not in setup or ended state)
            if sessionViewModel.sessionState != .setup && sessionViewModel.sessionState != .ended {
                SessionHeaderView(
                    totalSessionTime: sessionViewModel.totalSessionTime,
                    isPaused: sessionViewModel.sessionState == .paused,
                    currentActivityName: sessionViewModel.currentActivityName,
                    hasNextActivity: !sessionViewModel.upcomingActivities.isEmpty,
                    onPause: { Task { await sessionViewModel.pauseTimer() } },
                    onResume: { Task { await sessionViewModel.resumeTimer() } },
                    onComplete: {
                        showingEndSessionConfirmation = true
                    },
                    onSkipNext: !sessionViewModel.upcomingActivities.isEmpty ? {
                        showingSkipConfirmation = true
                    } : nil,
                    onTap: {
                        showActiveSession = true
                    },
                    onAddActivity: {
                        showingAddActivity = true
                    }
                )
            }

            content
        }
        .alert("End Session?", isPresented: $showingEndSessionConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End Session", role: .destructive) {
                Task { await sessionViewModel.endSession() }
            }
        } message: {
            let queueCount = sessionViewModel.upcomingActivities.count
            if queueCount == 0 {
                Text("Complete \"\(sessionViewModel.currentActivityName)\" and end session?")
            } else {
                Text("Complete \"\(sessionViewModel.currentActivityName)\", skip \(queueCount) \(queueCount == 1 ? "activity" : "activities"), and end session?")
            }
        }
        .alert("Skip to Next Activity?", isPresented: $showingSkipConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete & Start") {
                Task {
                    if let nextActivity = sessionViewModel.upcomingActivities.first {
                        await sessionViewModel.skipToActivity(nextActivity)
                    }
                }
            }
        } message: {
            if let nextActivity = sessionViewModel.upcomingActivities.first {
                Text("Complete \"\(sessionViewModel.currentActivityName)\" and start \"\(nextActivity.activityName)\"?")
            }
        }
        .sheet(isPresented: $showingAddActivity) {
            AddActivityToSessionView(
                userId: sessionViewModel.userId,
                viewModel: sessionViewModel,
                isPresented: $showingAddActivity
            )
        }
    }
}
