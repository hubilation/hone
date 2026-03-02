//
//  ContentView.swift
//  Practice Timer
//
//  Created by Zack Huber on 3/1/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.user != nil {
                // User is signed in - show main app
                MainAppView()
                    .environmentObject(authViewModel)
            } else {
                // User not signed in - show auth
                SignInView()
            }
        }
    }
}

// Placeholder for main app (Phase 2 will expand)
struct MainAppView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to Practice Timer!")
                    .font(.title)
                    .padding()

                if let user = authViewModel.user {
                    Text("Signed in as: \(user.email)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Sign Out") {
                    authViewModel.signOut()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)

                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
