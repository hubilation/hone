//
//  ActivityListView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

struct ActivityListView: View {
    @StateObject private var viewModel: ActivityViewModel
    @State private var showingCreateSheet = false
    @State private var editingActivity: Activity?

    private let userId: String

    init(userId: String) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: ActivityViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.activeActivities) { activity in
                    ActivityRowView(activity: activity)
                        .onTapGesture {
                            editingActivity = activity
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Delete (leftmost, red)
                            Button(role: .destructive) {
                                Task { await viewModel.deleteActivity(activity) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            // Archive (rightmost, orange)
                            Button {
                                Task { await viewModel.archiveActivity(activity) }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                }
            }
            .navigationTitle("Activities")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        ArchivedActivityListView(viewModel: viewModel)
                    } label: {
                        Label("Archived", systemImage: "archivebox")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ActivityStatisticsView(
                            userId: userId,
                            activities: viewModel.activeActivities
                        )
                    } label: {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                ActivityFormView(activity: nil, onSave: { name, category in
                    Task {
                        await viewModel.createActivity(name: name, category: category)
                    }
                })
            }
            .sheet(item: $editingActivity) { activity in
                ActivityFormView(activity: activity, onSave: { name, category in
                    Task {
                        await viewModel.updateActivity(activity, name: name, category: category)
                    }
                })
            }
            .overlay {
                if viewModel.activeActivities.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Activities",
                        systemImage: "music.note.list",
                        description: Text("Tap + to create your first practice activity")
                    )
                }
            }
        }
        .onAppear {
            print("DEBUG: ActivityListView.onAppear called")
            viewModel.startListening()
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityListView(userId: "preview-user-id")
}
