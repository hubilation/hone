//
//  HoneLiveActivityAttributes.swift
//  Hone
//
//  Created by Claude on 4/13/26.
//

import ActivityKit
import Foundation

/// Shared data model for the Hone Live Activity.
///
/// This file must be added to BOTH the Hone app target AND the HoneLiveActivity
/// widget extension target via Target Membership in Xcode.
///
/// Attributes hold static data set once at Activity.request() and never changed.
/// ContentState holds dynamic data updated on each Activity.update() call.
@available(iOS 16.2, *)
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
