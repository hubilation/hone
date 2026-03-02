//
//  AuthViewModel.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
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

    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository

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
}
