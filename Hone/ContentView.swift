//
//  ContentView.swift
//  Hone
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
    @StateObject private var sessionViewModel: SessionViewModel
    @State private var selectedTab = 0
    @State private var showActiveSession = false

    init(user: User) {
        self.user = user
        let userId = user.id ?? ""
        print("🔍 DEBUG: MainAppView init with userId: '\(userId)'")
        print("🔍 DEBUG: user.id = \(user.id ?? "nil")")
        _activityViewModel = StateObject(wrappedValue: ActivityViewModel(userId: userId))
        _sessionHistoryViewModel = StateObject(wrappedValue: SessionHistoryViewModel(userId: userId))
        _sessionViewModel = StateObject(wrappedValue: SessionViewModel(userId: userId))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            QuickStartView(
                userId: user.id ?? "",
                sessionViewModel: sessionViewModel,
                sessionHistoryViewModel: sessionHistoryViewModel,
                showActiveSession: $showActiveSession
            )
                .modifier(CompactSessionHeader(sessionViewModel: sessionViewModel, showActiveSession: $showActiveSession))
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

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
            .modifier(CompactSessionHeader(sessionViewModel: sessionViewModel, showActiveSession: $showActiveSession))
            .tabItem {
                Label("Statistics", systemImage: "chart.bar")
            }
            .tag(1)

            ActivityListView(userId: user.id ?? "")
                .modifier(CompactSessionHeader(sessionViewModel: sessionViewModel, showActiveSession: $showActiveSession))
                .tabItem {
                    Label("Activities", systemImage: "list.bullet")
                }
                .tag(2)

            SessionHistoryView(userId: user.id ?? "")
                .modifier(CompactSessionHeader(sessionViewModel: sessionViewModel, showActiveSession: $showActiveSession))
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(3)

            SettingsView()
                .modifier(CompactSessionHeader(sessionViewModel: sessionViewModel, showActiveSession: $showActiveSession))
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .sheet(isPresented: $showActiveSession) {
            NavigationStack {
                ActiveSessionView(viewModel: sessionViewModel)
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
