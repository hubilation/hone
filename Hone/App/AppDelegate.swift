//
//  AppDelegate.swift
//  Hone
//
//  Created by Zack Huber on 3/1/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import ActivityKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        endOrphanedLiveActivities()
        return true
    }

    /// End any Live Activities that survived a previous app kill.
    /// SessionViewModel manages the activity during normal use; this handles the crash/kill case.
    private func endOrphanedLiveActivities() {
        guard #available(iOS 16.2, *) else { return }
        for activity in ActivityKit.Activity<HoneLiveActivityAttributes>.activities {
            Task { await activity.end(dismissalPolicy: .immediate) }
        }
    }

    // Required for Google Sign-In URL handling
    func application(_ app: UIApplication, open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
