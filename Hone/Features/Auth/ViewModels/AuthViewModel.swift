//
//  AuthViewModel.swift
//  Hone
//
//  Created by Claude on 3/2/26.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import GoogleSignIn

@MainActor
final class AuthViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    @Published var user: User?
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var showPasswordReset = false
    @Published var passwordResetSent = false

    private let repository: AuthRepositoryProtocol
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
        super.init()

        // Listen for auth state changes
        authStateHandle = repository.addAuthStateListener { [weak self] user in
            self?.user = user
        }
    }

    deinit {
        if let handle = authStateHandle {
            repository.removeAuthStateListener(handle)
        }
    }

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await repository.signIn(email: email, password: password)
            clearFields()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await repository.signUp(email: email, password: password)
            clearFields()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try repository.signOut()
            user = nil
            clearFields()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repository.resetPassword(email: email)
            passwordResetSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }

    // MARK: - OAuth Methods

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await repository.signInWithGoogle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            Task { @MainActor in
                errorMessage = "Apple Sign-In failed"
            }
            return
        }

        Task { @MainActor in
            guard let nonce = currentNonce else {
                errorMessage = "Invalid nonce state"
                return
            }

            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                user = try await repository.signInWithApple(
                    idToken: idTokenString,
                    nonce: nonce,
                    fullName: appleIDCredential.fullName
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
