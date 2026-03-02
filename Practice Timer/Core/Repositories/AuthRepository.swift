//
//  AuthRepository.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import Foundation
import FirebaseAuth

enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case userNotFound
    case wrongPassword
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Invalid email address"
        case .weakPassword: return "Password must be at least 6 characters"
        case .userNotFound: return "No account found with this email"
        case .wrongPassword: return "Incorrect password"
        case .networkError: return "Network connection error"
        case .unknown(let message): return message
        }
    }
}

protocol AuthRepositoryProtocol {
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> User
    func signInWithGoogle() async throws -> User
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> User
    func signOut() throws
    func resetPassword(email: String) async throws
    func getCurrentUser() -> User?
    func addAuthStateListener(_ listener: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle
    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle)
}

final class AuthRepository: AuthRepositoryProtocol {
    // Implementations will be added in Plans 02-03
    // This is the protocol structure for now

    func signIn(email: String, password: String) async throws -> User {
        fatalError("Implemented in Plan 02")
    }

    func signUp(email: String, password: String) async throws -> User {
        fatalError("Implemented in Plan 02")
    }

    func signInWithGoogle() async throws -> User {
        fatalError("Implemented in Plan 03")
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> User {
        fatalError("Implemented in Plan 03")
    }

    func signOut() throws {
        fatalError("Implemented in Plan 02")
    }

    func resetPassword(email: String) async throws {
        fatalError("Implemented in Plan 02")
    }

    func getCurrentUser() -> User? {
        fatalError("Implemented in Plan 02")
    }

    func addAuthStateListener(_ listener: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        fatalError("Implemented in Plan 02")
    }

    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        fatalError("Implemented in Plan 02")
    }
}
