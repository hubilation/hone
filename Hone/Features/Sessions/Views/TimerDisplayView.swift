//
//  TimerDisplayView.swift
//  Hone
//
//  Created by Claude on 3/3/26.
//

import SwiftUI
import Combine

/// Large, readable timer display for music stand distance (10 feet)
/// Self-ticking: owns its local timer so SessionViewModel timer ticks
/// do NOT cause parent view re-renders.
struct TimerDisplayView: View {
    /// When the current activity timer started. Nil when paused.
    let startDate: Date?
    /// Elapsed time accumulated before the current run started.
    let pausedElapsed: TimeInterval
    var isPaused: Bool = false

    @State private var displayed: TimeInterval = 0
    @State private var pulseOpacity: Double = 1.0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var formattedTime: String {
        let totalMinutes = Int(displayed) / 60
        let seconds = Int(displayed) % 60
        return String(format: "%02d:%02d", totalMinutes, seconds)
    }

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 72, weight: .medium, design: .default))
            .monospacedDigit()
            .opacity(pulseOpacity)
            .onAppear { updateDisplayed() }
            .onReceive(ticker) { _ in
                guard !isPaused else { return }
                updateDisplayed()
            }
            .onChange(of: isPaused) { _, newValue in
                if newValue {
                    updateDisplayed()
                    startPulsing()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) { pulseOpacity = 1.0 }
                    updateDisplayed()
                }
            }
            .onChange(of: startDate) { _, _ in updateDisplayed() }
            .onChange(of: pausedElapsed) { _, _ in updateDisplayed() }
    }

    private func updateDisplayed() {
        if let startDate, !isPaused {
            displayed = pausedElapsed + Date().timeIntervalSince(startDate)
        } else {
            displayed = pausedElapsed
        }
    }

    private func startPulsing() {
        pulseOpacity = 1.0
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.4
        }
    }
}

#Preview {
    VStack {
        TimerDisplayView(startDate: nil, pausedElapsed: 0)
        TimerDisplayView(startDate: nil, pausedElapsed: 125)
        TimerDisplayView(startDate: nil, pausedElapsed: 3661)
    }
}
