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

    private var todaySessionCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return sessionHistoryViewModel.sessions.filter { session in
            guard session.state == "ended" else { return false }
            guard let startDate = Date(iso8601String: session.startTime) else { return false }
            let sessionDay = calendar.startOfDay(for: startDate)
            return sessionDay == today
        }.count
    }

    private var streak: Int {
        SuggestionsService.currentStreak(sessions: sessionHistoryViewModel.sessions)
    }

    private var greetingMessage: String {
        switch todaySessionCount {
        case 0:
            return "Time for your daily practice!"
        case 1:
            return "You've already practiced once today, how about another session?"
        default:
            return "You've practiced \(todaySessionCount) times today, back for more?"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Dynamic greeting based on today's practice count
                Text(greetingMessage)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

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
                        showActiveSession: $showActiveSession,
                        sessions: sessionHistoryViewModel.sessions
                    )
                } label: {
                    Label("Plan Session", systemImage: "list.bullet")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 40)

                // Streak — own element, only shown when > 0
                if streak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(streak) day streak")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // This Week stats summary
                WeeklySummaryCard(sessions: sessionHistoryViewModel.sessions)
                    .padding(.horizontal)

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
