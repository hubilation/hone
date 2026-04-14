//
//  HoneLiveActivityAttributes.swift
//  HoneLiveActivity
//
//  This file is a copy of Hone/Core/LiveActivity/HoneLiveActivityAttributes.swift.
//  Both targets must define the same struct independently because the widget extension
//  and app compile into separate binaries. The struct definition must be identical.
//

import ActivityKit
import Foundation

/// Shared data model for the Hone Live Activity.
///
/// Attributes hold static data set once at Activity.request() and never changed.
/// ContentState holds dynamic data updated on each Activity.update() call.
///
/// Note: @available(iOS 16.2, *) omitted because the deployment target is iOS 26.2+,
/// making that annotation redundant and harmful (prevents type specialization).
struct HoneLiveActivityAttributes: ActivityAttributes {
    // Static — set once at Activity.request(), never changes
    let sessionId: String

    struct ContentState: Codable, Hashable {
        // For running state: reconstructed start Date for timerInterval
        // Computed as Date() - elapsedTime so iOS renders correct elapsed value
        var activityStartDate: Date

        // For paused state
        var isPaused: Bool
        var pausedElapsedSeconds: TimeInterval  // frozen display value

        // Activity metadata
        var activityName: String

        // Total session timer (secondary display)
        var sessionStartDate: Date
        var totalPausedSessionSeconds: TimeInterval  // for frozen session display
    }
}
