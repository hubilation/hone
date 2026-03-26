//
//  QuickStartView.swift
//  Hone
//
//  Created by Claude on 3/5/26.
//

import SwiftUI

/// Home screen with Quick Start feature
/// Provides fastest path to starting a practice session
struct QuickStartView: View {
    let userId: String
    @ObservedObject var sessionViewModel: SessionViewModel
    @ObservedObject var sessionHistoryViewModel: SessionHistoryViewModel
    @Binding var showActiveSession: Bool

    @State private var showingActivitySelection = false
    @State private var selectedActivity: Activity?

    private var isSessionActive: Bool {
        sessionViewModel.sessionState != .setup && sessionViewModel.sessionState != .ended
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // This Week stats summary
                WeeklySummaryCard(sessions: sessionHistoryViewModel.sessions)
                    .padding(.horizontal)
                    .padding(.top)

                Spacer()

                // Quick Start / Resume Session button - prominent and centered
                Button(action: {
                    showActiveSession = true
                }) {
                    Label(
                        isSessionActive ? "Resume Session" : "Quick Start",
                        systemImage: isSessionActive ? "play.circle.fill" : "bolt.fill"
                    )
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(isSessionActive ? .green : .blue)
                .padding(.horizontal, 40)

                Text(isSessionActive ? "Continue your current practice session" : "Select an activity and start practicing immediately")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Plan Session button - secondary action
                NavigationLink {
                    SessionSetupView(
                        userId: userId,
                        sessionViewModel: sessionViewModel,
                        showActiveSession: $showActiveSession
                    )
                } label: {
                    Label("Plan Session", systemImage: "list.bullet")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                sessionHistoryViewModel.startListening()
            }
        }
    }
}

#Preview {
    QuickStartView(
        userId: "preview-user",
        sessionViewModel: SessionViewModel(userId: "preview-user"),
        sessionHistoryViewModel: SessionHistoryViewModel(userId: "preview-user"),
        showActiveSession: .constant(false)
    )
}
