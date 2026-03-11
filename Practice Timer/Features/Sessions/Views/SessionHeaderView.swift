//
//  SessionHeaderView.swift
//  Practice Timer
//
//  Created by Claude on 3/5/26.
//

import SwiftUI

/// Docked session header showing total time with pause and complete controls
/// Supports two modes: compact (top of other views) and full (bottom of active session)
struct SessionHeaderView: View {
    let totalSessionTime: TimeInterval
    let isPaused: Bool
    let currentActivityName: String?
    let hasNextActivity: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onComplete: () -> Void
    let onSkipNext: (() -> Void)?
    let onTap: (() -> Void)?
    let onAddActivity: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Pause/Resume button (icon only)
            Button(action: {
                if isPaused {
                    onResume()
                } else {
                    onPause()
                }
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
                    Text(formatTime(totalSessionTime))
                        .font(currentActivityName != nil ? .caption : .title2)
                        .fontWeight(currentActivityName != nil ? .regular : .semibold)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

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
        // Compact mode (shown at top of other views)
        SessionHeaderView(
            totalSessionTime: 3725,
            isPaused: false,
            currentActivityName: "Scales Practice",
            hasNextActivity: true,
            onPause: { print("Pause") },
            onResume: { print("Resume") },
            onComplete: { print("Complete") },
            onSkipNext: { print("Skip") },
            onTap: { print("Tap to open session") },
            onAddActivity: { print("Add activity") }
        )

        // Full mode (shown at bottom of active session)
        SessionHeaderView(
            totalSessionTime: 125,
            isPaused: true,
            currentActivityName: nil,
            hasNextActivity: false,
            onPause: { print("Pause") },
            onResume: { print("Resume") },
            onComplete: { print("Complete") },
            onSkipNext: nil,
            onTap: nil,
            onAddActivity: { print("Add activity") }
        )
    }
}
