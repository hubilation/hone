//
//  SessionControlsView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Session control buttons (Pause/Resume/End)
/// SINGLE RESPONSIBILITY: Display context-appropriate control buttons with large touch targets
struct SessionControlsView: View {
    let state: SessionState
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            // Pause button (shown when active or inBetween)
            if state == .active || state == .inBetween {
                Button(action: onPause) {
                    Label("Pause", systemImage: "pause.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)  // 60pt+ touch target
            }

            // Resume button (shown when paused)
            if state == .paused {
                Button(action: onResume) {
                    Label("Resume", systemImage: "play.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            // End Session button (always shown except in setup)
            if state != .setup {
                Button(action: onEnd) {
                    Label("End Session", systemImage: "stop.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)  // Visual warning for destructive action
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        SessionControlsView(
            state: .active,
            onPause: { print("Pause") },
            onResume: { print("Resume") },
            onEnd: { print("End") }
        )
        SessionControlsView(
            state: .paused,
            onPause: { print("Pause") },
            onResume: { print("Resume") },
            onEnd: { print("End") }
        )
    }
}
