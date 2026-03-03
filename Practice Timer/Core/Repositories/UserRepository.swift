//
//  UserRepository.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import Foundation
import FirebaseFirestore

enum RepositoryError: LocalizedError {
    case invalidUserId
    case documentNotFound
    case encodingFailed
    case decodingFailed
    case networkError
    case missingDocumentId

    var errorDescription: String? {
        switch self {
        case .invalidUserId: return "Invalid user ID"
        case .documentNotFound: return "Document not found"
        case .encodingFailed: return "Failed to encode data"
        case .decodingFailed: return "Failed to decode data"
        case .networkError: return "Network error"
        case .missingDocumentId: return "Missing document ID"
        }
    }
}

protocol UserRepositoryProtocol {
    func saveUser(_ user: User) async throws
    func getUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

final class UserRepository: UserRepositoryProtocol {
    private let db = Firestore.firestore()

    func saveUser(_ user: User) async throws {
        guard let userId = user.id else { throw RepositoryError.invalidUserId }
        try db.collection("users").document(userId).setData(from: user)
    }

    func getUser(id: String) async throws -> User {
        let document = try await db.collection("users").document(id).getDocument()
        guard document.exists else { throw RepositoryError.documentNotFound }
        return try document.data(as: User.self)
    }

    func updateUser(_ user: User) async throws {
        guard let userId = user.id else { throw RepositoryError.invalidUserId }
        var updatedUser = user
        updatedUser.updatedAt = Date().toISO8601String()
        try db.collection("users").document(userId).setData(from: updatedUser, merge: true)
    }

    func deleteUser(id: String) async throws {
        try await db.collection("users").document(id).delete()
    }
}
