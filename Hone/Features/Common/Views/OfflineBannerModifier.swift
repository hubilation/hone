//
//  OfflineBannerModifier.swift
//  Hone
//
//  Created by Claude on 4/15/26.
//

import SwiftUI

/// Global ViewModifier that adds:
/// - A red "No internet connection" banner when offline (D-01, D-02)
/// - A green "Back online" banner for 2 seconds on reconnect (D-03)
/// - A cloud sync toolbar icon when Firestore has pending writes (D-04, D-05, D-06)
///
/// Apply to each tab's root view inside MainAppView so the banner and icon appear on all tabs.
struct OfflineBannerModifier: ViewModifier {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var syncStateService: SyncStateService

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            // Offline banner (red) or back-online banner (green)
            if !networkMonitor.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("No internet connection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.9))
                .foregroundColor(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if networkMonitor.showBackOnlineBanner {
                HStack {
                    Image(systemName: "wifi")
                    Text("Back online")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.9))
                .foregroundColor(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            content
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.showBackOnlineBanner)
        .toolbar {
            // Pending sync icon — visible while Firestore has unflushed local writes (D-04, D-05, D-06)
            if syncStateService.hasPendingWrites {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        .foregroundColor(.secondary)
                        .symbolEffect(.pulse)
                }
            }
        }
    }
}
