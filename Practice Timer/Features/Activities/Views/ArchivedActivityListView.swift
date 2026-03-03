//
//  ArchivedActivityListView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

struct ArchivedActivityListView: View {
    @ObservedObject var viewModel: ActivityViewModel

    var body: some View {
        List {
            ForEach(viewModel.archivedActivities) { activity in
                ActivityRowView(activity: activity)
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task { await viewModel.restoreActivity(activity) }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
            }
        }
        .navigationTitle("Archived")
        .overlay {
            if viewModel.archivedActivities.isEmpty {
                ContentUnavailableView(
                    "No Archived Activities",
                    systemImage: "archivebox",
                    description: Text("Archived activities will appear here")
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ArchivedActivityListView(viewModel: ActivityViewModel(userId: "preview-user-id"))
    }
}
