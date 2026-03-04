//
//  ActiveSessionView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Placeholder for ActiveSessionView (to be implemented in plan 03-04)
struct ActiveSessionView: View {
    @ObservedObject var viewModel: SessionViewModel

    var body: some View {
        VStack {
            Text("Active Session View")
                .font(.largeTitle)
            Text("To be implemented in plan 03-04")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Practice Session")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActiveSessionView(viewModel: SessionViewModel(userId: "preview-user-id"))
    }
}
