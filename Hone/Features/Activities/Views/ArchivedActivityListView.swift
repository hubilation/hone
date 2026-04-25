//
//  ArchivedActivityListView.swift
//  Hone
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

struct ArchivedActivityListView: View {
    @ObservedObject var viewModel: ActivityViewModel
    let userId: String
    @State private var editingActivity: Activity?

    var body: some View {
        List {
            ForEach(viewModel.archivedActivities) { activity in
                ActivityRowView(activity: activity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingActivity = activity
                    }
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
        .sheet(item: $editingActivity) { activity in
            ActivityFormView(
                activity: activity,
                userId: userId,
                onSave: { name, category in
                    Task {
                        await viewModel.updateActivity(activity, name: name, category: category)
                    }
                },
                onRestore: {
                    Task {
                        await viewModel.restoreActivity(activity)
                    }
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ArchivedActivityListView(
            viewModel: ActivityViewModel(userId: "preview-user-id"),
            userId: "preview-user-id"
        )
    }
}
