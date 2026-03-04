//
//  TimerDisplayView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Large, readable timer display for music stand distance (10 feet)
/// SINGLE RESPONSIBILITY: Display elapsed time in MM:SS format
struct TimerDisplayView: View {
    let elapsedTime: TimeInterval

    private var formattedTime: String {
        let totalMinutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", totalMinutes, seconds)
    }

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 72, weight: .medium, design: .default))
            .monospacedDigit()  // Prevents width changes when digits change
    }
}

#Preview {
    VStack {
        TimerDisplayView(elapsedTime: 0)
        TimerDisplayView(elapsedTime: 125)  // 00:02:05
        TimerDisplayView(elapsedTime: 3661) // 01:01:01
    }
}
