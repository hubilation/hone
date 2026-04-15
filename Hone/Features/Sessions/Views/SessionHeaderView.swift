//
//  SessionHeaderView.swift
//  Hone
//
//  Created by Claude on 3/5/26.
//

import SwiftUI
import Combine

/// Docked session header showing total time with pause and complete controls
/// Self-ticking: owns its local timer so SessionViewModel timer ticks
/// do NOT cause parent view re-renders.
struct SessionHeaderView: View {
    /// When the overall session timer started. Nil when paused.
    let sessionStartDate: Date?
    /// Session elapsed time accumulated before the current run started.
    let sessionPausedElapsed: TimeInterval
    let isPaused: Bool
    let currentActivityName: String?
    let hasNextActivity: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onComplete: () -> Void
    let onSkipNext: (() -> Void)?
    let onTap: (() -> Void)?
    let onAddActivity: (() -> Void)?

    @State private var displayed: TimeInterval = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // Pause/Resume button (icon only)
            Button(action: {
                if isPaused { onResume() } else { onPause() }
            }) {
                Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            // Session info (tappable area to return to session)
            VStack(alignment: .leading, spacing: 2) {
                if let activityName = currentActivityName {
                    Text(activityName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(currentActivityName != nil ? "Session" : "Session Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(displayed))
                        .font(currentActivityName != nil ? .caption : .title2)
                        .fontWeight(currentActivityName != nil ? .regular : .semibold)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            // Add activity button
            if let addActivity = onAddActivity {
                Button(action: addActivity) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            // Skip to next button (only if there's a next activity)
            if hasNextActivity, let skipNext = onSkipNext {
                Button(action: skipNext) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }

            // Complete activity button (icon only)
            Button(action: onComplete) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .overlay(
            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .background(Color(uiColor: .separator)),
            alignment: currentActivityName != nil ? .bottom : .top
        )
        .onAppear { updateDisplayed() }
        .onReceive(ticker) { _ in
            guard !isPaused else { return }
            updateDisplayed()
        }
        .onChange(of: isPaused) { _, _ in updateDisplayed() }
        .onChange(of: sessionStartDate) { _, _ in updateDisplayed() }
        .onChange(of: sessionPausedElapsed) { _, _ in updateDisplayed() }
    }

    private func updateDisplayed() {
        if let sessionStartDate, !isPaused {
            displayed = sessionPausedElapsed + Date().timeIntervalSince(sessionStartDate)
        } else {
            displayed = sessionPausedElapsed
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SessionHeaderView(
            sessionStartDate: Date().addingTimeInterval(-3725),
            sessionPausedElapsed: 0,
            isPaused: false,
            currentActivityName: "Scales Practice",
            hasNextActivity: true,
            onPause: {},
            onResume: {},
            onComplete: {},
            onSkipNext: {},
            onTap: { print("Tap") },
            onAddActivity: {}
        )
        SessionHeaderView(
            sessionStartDate: nil,
            sessionPausedElapsed: 125,
            isPaused: true,
            currentActivityName: nil,
            hasNextActivity: false,
            onPause: {},
            onResume: {},
            onComplete: {},
            onSkipNext: nil,
            onTap: nil,
            onAddActivity: {}
        )
    }
}
