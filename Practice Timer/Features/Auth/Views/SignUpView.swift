//
//  SignUpView.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            // Email/Password fields
            VStack(spacing: 15) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal, 40)

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Sign Up button
            Button(action: {
                Task {
                    await viewModel.signUp()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal, 40)
            .disabled(viewModel.isLoading)

            Divider()
                .padding(.horizontal, 40)
                .padding(.vertical, 10)

            // OAuth buttons
            VStack(spacing: 10) {
                Button(action: {
                    Task {
                        await viewModel.signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Sign up with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
                .disabled(viewModel.isLoading)

                Button(action: {
                    viewModel.signInWithApple()
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Sign up with Apple")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.user) { newValue in
            if newValue != nil {
                dismiss()
            }
        }
    }
}
