//
//  Session.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import Foundation
import FirebaseFirestore

struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    let startTime: String
    var endTime: String?
    let totalDuration: Int  // seconds
    let createdAt: String
    var updatedAt: String

    // Path: users/{userId}/sessions/{sessionId}
}
