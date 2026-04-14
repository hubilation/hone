//
//  HoneApp.swift
//  Hone
//
//  Created by Zack Huber on 3/1/26.
//

import SwiftUI

@main
struct HoneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
