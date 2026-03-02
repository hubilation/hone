//
//  Activity.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import Foundation
import FirebaseFirestore

struct Activity: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let category: String
    let createdAt: String
    var updatedAt: String
    var archived: Bool

    // Path: users/{userId}/activities/{activityId}
}
