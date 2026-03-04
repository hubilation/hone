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
            if let user = authViewModel.user {
                // User is signed in - show main app
                MainAppView(user: user)
                    .environmentObject(authViewModel)
            } else {
                // User not signed in - show auth
                SignInView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

struct MainAppView: View {
    let user: User
    @EnvironmentObject var authViewModel: AuthViewModel

    @StateObject private var activityViewModel: ActivityViewModel
    @StateObject private var sessionHistoryViewModel: SessionHistoryViewModel

    init(user: User) {
        self.user = user
        let userId = user.id ?? ""
        _activityViewModel = StateObject(wrappedValue: ActivityViewModel(userId: userId))
        _sessionHistoryViewModel = StateObject(wrappedValue: SessionHistoryViewModel(userId: userId))
    }

    var body: some View {
        TabView {
            ActivityListView(userId: user.id ?? "")
                .tabItem {
                    Label("Activities", systemImage: "list.bullet")
                }

            SessionSetupView(userId: user.id ?? "")
                .tabItem {
                    Label("Practice", systemImage: "play.circle")
                }

            SessionHistoryView(userId: user.id ?? "")
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            NavigationStack {
                StatisticsView(
                    userId: user.id ?? "",
                    sessions: sessionHistoryViewModel.sessions,
                    activities: activityViewModel.activeActivities
                )
                .onAppear {
                    activityViewModel.startListening()
                    sessionHistoryViewModel.startListening()
                }
            }
            .tabItem {
                Label("Statistics", systemImage: "chart.bar")
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Sign Out", role: .destructive) {
                        authViewModel.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}
