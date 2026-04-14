//
//  AuthRepository.swift
//  Hone
//
//  Created by Claude on 3/2/26.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices

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

    func signUp(email: String, password: String) async throws -> User {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = User(from: result.user)

            // Save user profile to Firestore
            let userRepo = UserRepository()
            try await userRepo.saveUser(user)

            return user
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> User {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return User(from: result.user)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch let error as NSError {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    func getCurrentUser() -> User? {
        guard let firebaseUser = Auth.auth().currentUser else { return nil }
        return User(from: firebaseUser)
    }

    func addAuthStateListener(_ listener: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        return Auth.auth().addStateDidChangeListener { _, firebaseUser in
            listener(firebaseUser.map(User.init))
        }
    }

    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }

    func signInWithGoogle() async throws -> User {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.unknown("Firebase client ID not found")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get root view controller for presenting Google Sign-In
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw AuthError.unknown("No root view controller found")
        }

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(throwing: AuthError.unknown("Google Sign-In failed"))
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )

                Task {
                    do {
                        let result = try await Auth.auth().signIn(with: credential)
                        let user = User(from: result.user)

                        // Save user profile to Firestore (auto-creates if new)
                        let userRepo = UserRepository()
                        try await userRepo.saveUser(user)

                        continuation.resume(returning: user)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> User {
        // CRITICAL: Use OAuthProvider.appleCredential with fullName parameter
        // This preserves display name on first sign-in (Apple only provides it once)
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: credential)
            let user = User(from: result.user)

            // Save user profile to Firestore
            let userRepo = UserRepository()
            try await userRepo.saveUser(user)

            return user
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Private Helpers

    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return .unknown(error.localizedDescription)
        }

        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        case .networkError:
            return .networkError
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
