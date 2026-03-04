//
//  Activity.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import Foundation
import FirebaseFirestore

struct PracticeNote: Codable, Identifiable {
    var id: String { timestamp }
    let notes: String
    let sessionId: String
    let timestamp: String  // ISO 8601
}

struct Activity: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let category: String
    let createdAt: String
    var updatedAt: String
    var archived: Bool
    var practiceNotes: [PracticeNote]?

    // Path: users/{userId}/activities/{activityId}
}
