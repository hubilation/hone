//
//  User.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    let email: String
    var displayName: String?
    let createdAt: String  // ISO 8601 string
    var updatedAt: String

    init(id: String, email: String, displayName: String?) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = Date().toISO8601String()
        self.updatedAt = Date().toISO8601String()
    }

    // Initialize from Firebase User
    init(from firebaseUser: FirebaseAuth.User) {
        self.id = firebaseUser.uid
        self.email = firebaseUser.email ?? ""
        self.displayName = firebaseUser.displayName
        self.createdAt = Date().toISO8601String()
        self.updatedAt = Date().toISO8601String()
    }
}
