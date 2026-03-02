//
//  SignInView.swift
//  Practice Timer
//
//  Created by Claude on 3/2/26.
//

import SwiftUI

struct SignInView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                Text("Practice Timer")
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
                        .textContentType(.password)
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

                // Sign In button
                Button(action: {
                    Task {
                        await viewModel.signIn()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
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

                // Password reset link
                Button("Forgot password?") {
                    viewModel.showPasswordReset = true
                }
                .font(.caption)

                Divider()
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)

                // OAuth buttons (placeholders - Plan 03 will implement)
                VStack(spacing: 10) {
                    Button(action: {
                        // Implemented in Plan 03
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Sign in with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }
                    .disabled(true)  // Enable in Plan 03

                    Button(action: {
                        // Implemented in Plan 03
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(true)  // Enable in Plan 03
                }
                .padding(.horizontal, 40)

                Spacer()

                // Sign up link
                NavigationLink(destination: SignUpView()) {
                    Text("Don't have an account? Sign up")
                        .font(.caption)
                }
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $viewModel.showPasswordReset) {
                PasswordResetView(viewModel: viewModel)
            }
            .navigationBarHidden(true)
        }
    }
}
