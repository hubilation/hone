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
    @DocumentID var id: String?
    let name: String
    let category: String
    let createdAt: String
    var updatedAt: String

    // Web app compatibility fields
    var totalPracticeTime: Int      // Total seconds across all sessions
    var targetTime: Int?             // Target minutes per session
    var details: String?             // Activity description
    var active: Bool                 // Soft delete flag (replaces archived)
    var completed: Bool              // Activity completion marker
    var completedAt: String?         // ISO 8601 completion date
    var lastUsed: String?            // ISO 8601 last practice date

    var practiceNotes: [PracticeNote]?

    // Computed property for backward compatibility
    var archived: Bool {
        get { !active }
        set { active = !newValue }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, createdAt, updatedAt
        case totalPracticeTime, targetTime, details, active, archived
        case completed, completedAt, lastUsed, practiceNotes
    }

    init(id: String? = nil,
         name: String,
         category: String,
         createdAt: String,
         updatedAt: String,
         totalPracticeTime: Int = 0,
         targetTime: Int? = nil,
         details: String? = nil,
         active: Bool = true,
         completed: Bool = false,
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode @DocumentID manually
        id = try container.decodeIfPresent(String.self, forKey: .id)

        // Required fields
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)

        // Web app fields with defaults
        totalPracticeTime = try container.decodeIfPresent(Int.self, forKey: .totalPracticeTime) ?? 0
        targetTime = try container.decodeIfPresent(Int.self, forKey: .targetTime)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        lastUsed = try container.decodeIfPresent(String.self, forKey: .lastUsed)

        // Handle both 'active' and 'archived' fields (backward compatibility)
        if let activeValue = try? container.decode(Bool.self, forKey: .active) {
            active = activeValue
        } else if let archivedValue = try? container.decode(Bool.self, forKey: .archived) {
            active = !archivedValue
        } else {
            active = true  // Default to active
        }

        // Optional fields
        practiceNotes = try container.decodeIfPresent([PracticeNote].self, forKey: .practiceNotes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode all fields
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(totalPracticeTime, forKey: .totalPracticeTime)
        try container.encodeIfPresent(targetTime, forKey: .targetTime)
        try container.encodeIfPresent(details, forKey: .details)

        // Write BOTH active and archived for backward compatibility
        try container.encode(active, forKey: .active)
        try container.encode(!active, forKey: .archived)  // Mirror of active for web app

        try container.encode(completed, forKey: .completed)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(lastUsed, forKey: .lastUsed)
        try container.encodeIfPresent(practiceNotes, forKey: .practiceNotes)
    }

    // Path: users/{userId}/activities/{activityId}
}
