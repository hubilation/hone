//
//  Activity.swift
//  Hone
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
    let timeSpent: Int     // Seconds spent in session

    enum CodingKeys: String, CodingKey {
        case notes, sessionId, timestamp, timeSpent
    }

    init(notes: String, sessionId: String, timestamp: String, timeSpent: Int) {
        self.notes = notes
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.timeSpent = timeSpent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notes = try container.decode(String.self, forKey: .notes)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        // Default to 0 if timeSpent missing (backward compatibility)
        timeSpent = try container.decodeIfPresent(Int.self, forKey: .timeSpent) ?? 0
    }
}

struct Activity: Codable, Identifiable {
    var id: String?  // Document ID - populated manually from snapshot in repository
    let name: String
    let category: String
    let createdAt: String
    var updatedAt: String

    // Web app compatibility fields - all optional for backward compatibility
    var totalPracticeTime: Int?          // Total seconds across all sessions
    var targetTime: Int?                 // Target minutes per session
    var details: String?                 // Activity description
    var active: Bool?                    // Soft delete flag (replaces archived)
    var completed: Bool?                 // Activity completion marker
    var completedAt: String?             // ISO 8601 completion date
    var lastUsed: String?                // ISO 8601 last practice date
    var practiceNotes: [PracticeNote]?

    // Computed property for backward compatibility - provides non-optional access with defaults
    var archived: Bool {
        get { !(active ?? true) }
        set { active = !newValue }
    }

    // Convenience computed properties for non-optional access with sensible defaults
    var isActive: Bool { active ?? true }
    var isCompleted: Bool { completed ?? false }
    var totalTime: Int { totalPracticeTime ?? 0 }

    enum CodingKeys: String, CodingKey {
        // NOTE: 'id' and 'archived' are NOT included
        // - 'id' is populated manually from snapshot.documentID in repository (not a stored field)
        // - 'archived' is a computed property (inverse of 'active')
        case name, category, createdAt, updatedAt
        case totalPracticeTime, targetTime, details, active
        case completed, completedAt, lastUsed, practiceNotes
    }

    init(id: String? = nil,
         name: String,
         category: String,
         createdAt: String,
         updatedAt: String,
         totalPracticeTime: Int? = 0,
         targetTime: Int? = nil,
         details: String? = nil,
         active: Bool? = true,
         completed: Bool? = false,
         completedAt: String? = nil,
         lastUsed: String? = nil,
         practiceNotes: [PracticeNote]? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.totalPracticeTime = totalPracticeTime
        self.targetTime = targetTime
        self.details = details
        self.active = active
        self.completed = completed
        self.completedAt = completedAt
        self.lastUsed = lastUsed
        self.practiceNotes = practiceNotes
    }

    // NOTE: No custom init(from:) - using synthesized decoder so @DocumentID works
    // Property defaults handle missing fields, and all Firestore docs have 'active' field

    // Path: users/{userId}/activities/{activityId}
}
