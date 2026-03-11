//
//  QuickStartView.swift
//  Practice Timer
//
//  Created by Claude on 3/5/26.
//

import SwiftUI

/// Home screen with Quick Start feature
/// Provides fastest path to starting a practice session
struct QuickStartView: View {
    let userId: String
    @ObservedObject var sessionViewModel: SessionViewModel
    @Binding var showActiveSession: Bool

    @State private var showingActivitySelection = false
    @State private var selectedActivity: Activity?

    private var isSessionActive: Bool {
        sessionViewModel.sessionState != .setup && sessionViewModel.sessionState != .ended
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // App title/logo area
                VStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("Practice Timer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

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

                Spacer()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    QuickStartView(
        userId: "preview-user",
        sessionViewModel: SessionViewModel(userId: "preview-user"),
        showActiveSession: .constant(false)
    )
}
