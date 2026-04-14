//
//  HoneLiveActivityWidget.swift
//  HoneLiveActivity
//
//  Created by Claude on 4/13/26.
//

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Helpers

/// Formats a TimeInterval as MM:SS, matching TimerDisplayView.swift pattern.
private func formattedTime(_ seconds: TimeInterval) -> String {
    String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
}

// MARK: - Widget

@available(iOSApplicationExtension 16.2, *)
struct HoneLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HoneLiveActivityAttributes.self) { context in
            // MARK: Lock Screen View
            VStack(alignment: .leading, spacing: 8) {
                // Activity name
                Text(context.state.activityName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Primary timer — current activity elapsed time
                if context.state.isPaused {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedTime(context.state.pausedElapsedSeconds))
                            .font(.system(size: 48, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .opacity(0.8)

                        Text("Paused")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(timerInterval: context.state.activityStartDate...Date.distantFuture,
                         countsDown: false)
                        .font(.system(size: 48, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }

                // Secondary timer — total session elapsed time
                if context.state.isPaused {
                    Text("Session: \(formattedTime(context.state.totalPausedSessionSeconds))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 0) {
                        Text("Session: ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(timerInterval: context.state.sessionStartDate...Date.distantFuture,
                             countsDown: false)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .widgetURL(URL(string: "hone://session/active"))

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Dynamic Island Expanded
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.activityName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if context.state.isPaused {
                            VStack(spacing: 2) {
                                Text(formattedTime(context.state.pausedElapsedSeconds))
                                    .font(.system(size: 32, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                                    .opacity(0.8)

                                Text("Paused")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(timerInterval: context.state.activityStartDate...Date.distantFuture,
                                 countsDown: false)
                                .font(.system(size: 32, weight: .medium))
                                .monospacedDigit()
                                .foregroundColor(.white)
                        }
                    }
                }
            } compactLeading: {
                // MARK: Dynamic Island Compact Leading
                Image(systemName: "music.note")
                    .foregroundColor(.white)
                    .font(.caption2)
            } compactTrailing: {
                // MARK: Dynamic Island Compact Trailing — timer only (D-04)
                if context.state.isPaused {
                    Text(formattedTime(context.state.pausedElapsedSeconds))
                        .monospacedDigit()
                        .font(.caption)
                } else {
                    Text(timerInterval: context.state.activityStartDate...Date.distantFuture,
                         countsDown: false)
                        .monospacedDigit()
                        .font(.caption)
                }
            } minimal: {
                // MARK: Dynamic Island Minimal
                Image(systemName: "timer")
                    .font(.caption2)
            }
        }
    }
}
