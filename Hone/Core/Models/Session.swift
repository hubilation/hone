//
//  Session.swift
//  Hone
//
//  Created by Claude on 3/2/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Session

/// Represents a practice session with state tracking for crash recovery
///
/// Path: users/{userId}/sessions/{sessionId}
struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    let startTime: String
    var endTime: String?
    let totalDuration: Int  // seconds
    let createdAt: String
    var updatedAt: String

    // State tracking fields for crash recovery and pause/resume
    var state: String?  // "setup", "active", "paused", "inBetween", "ended"
    var pausedAt: String?  // ISO 8601 timestamp when session was paused
    var currentActivityIndex: Int?  // Index of currently active activity in queue
}

// MARK: - SessionActivity

/// Represents an activity instance within a session
///
/// Path: users/{userId}/sessions/{sessionId}/activities/{activityId}
struct SessionActivity: Codable, Identifiable {
    @DocumentID var id: String?
    let activityId: String?  // Reference to Activity document (nil for in-between time)
    let activityName: String  // Denormalized for history display
    var startTime: String  // ISO 8601 timestamp when activity started
    var endTime: String?  // ISO 8601 timestamp when activity ended
    var duration: Int  // Elapsed seconds for this activity
    var notes: String?  // User notes added during practice
    var isInBetweenTime: Bool  // True for break periods between activities
    let createdAt: String  // ISO 8601 timestamp
    var updatedAt: String  // ISO 8601 timestamp
}
