//
//  TimerDisplayView.swift
//  Hone
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Large, readable timer display for music stand distance (10 feet)
/// SINGLE RESPONSIBILITY: Display elapsed time in MM:SS format
struct TimerDisplayView: View {
    let elapsedTime: TimeInterval
    var isPaused: Bool = false

    @State private var pulseOpacity: Double = 1.0

    private var formattedTime: String {
        let totalMinutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", totalMinutes, seconds)
    }

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 72, weight: .medium, design: .default))
            .monospacedDigit()  // Prevents width changes when digits change
            .opacity(pulseOpacity)
            .onChange(of: isPaused) { oldValue, newValue in
                if newValue {
                    // Start continuous pulsing animation
                    startPulsing()
                } else {
                    // Stop pulsing and reset to full opacity
                    withAnimation(.easeInOut(duration: 0.3)) {
                        pulseOpacity = 1.0
                    }
                }
            }
            .onAppear {
                if isPaused {
                    startPulsing()
                }
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
        TimerDisplayView(elapsedTime: 0)
        TimerDisplayView(elapsedTime: 125)  // 00:02:05
        TimerDisplayView(elapsedTime: 3661) // 01:01:01
    }
}
