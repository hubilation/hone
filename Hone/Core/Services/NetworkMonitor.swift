//
//  NetworkMonitor.swift
//  Hone
//
//  Created by Claude on 4/15/26.
//

import Network
import Combine
import Foundation

/// Monitors network connectivity using NWPathMonitor.
/// Publishes `isConnected` for offline banner and `showBackOnlineBanner` for the 2-second
/// "Back online" indicator that auto-dismisses after reconnect.
@MainActor
final class NetworkMonitor: ObservableObject {

    @Published var isConnected: Bool = true
    @Published var showBackOnlineBanner: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if path.status == .satisfied {
                    if !self.isConnected {
                        // Transition: offline -> online
                        self.isConnected = true
                        self.showBackOnlineBanner = true
                        Task { [weak self] in
                            try? await Task.sleep(for: .seconds(2))
                            await MainActor.run {
                                self?.showBackOnlineBanner = false
                            }
                        }
                    }
                } else {
                    self.isConnected = false
                    self.showBackOnlineBanner = false
                }
            }
        }
        monitor.start(queue: queue)
    }
}
