//
//  QuickStartActivitySelectionView.swift
//  Hone
//
//  Created by Claude on 3/5/26.
//

import SwiftUI

/// Sheet for selecting a single activity for Quick Start
/// Displays active activities grouped by category with search functionality
struct QuickStartActivitySelectionView: View {
    let userId: String
    @Binding var isPresented: Bool
    @ObservedObject var sessionViewModel: SessionViewModel
    let dismissParent: DismissAction

    @StateObject private var activityViewModel: ActivityViewModel
    @State private var searchText = ""

    init(userId: String, isPresented: Binding<Bool>, sessionViewModel: SessionViewModel, dismissParent: DismissAction) {
        self.userId = userId
        self._isPresented = isPresented
        self.sessionViewModel = sessionViewModel
        self.dismissParent = dismissParent
        _activityViewModel = StateObject(wrappedValue: ActivityViewModel(userId: userId))
    }

    var filteredActivities: [Activity] {
        if searchText.isEmpty {
            return activityViewModel.activeActivities
        } else {
            return activityViewModel.activeActivities.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var groupedActivities: [(category: String, activities: [Activity])] {
        ActivityGrouping.grouped(filteredActivities)
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredActivities.isEmpty {
                    ContentUnavailableView(
                        "No Activities",
                        systemImage: "list.bullet",
                        description: Text("Create an activity in the Activities tab to get started")
                    )
                } else {
                    List {
                        ForEach(groupedActivities, id: \.category) { group in
                            Section(header: Text(group.category)) {
                                ForEach(group.activities) { activity in
                                    Button(action: {
                                        Task {
                                            await startQuickSession(with: activity)
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: categoryIcon(for: activity))
                                                .foregroundColor(.blue)
                                                .frame(width: 30)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(activity.name)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)

                                                Text(activity.category)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: "play.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title2)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search activities")
            .navigationTitle("Select Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Dismiss both this sheet and the parent active session
                        isPresented = false
                        dismissParent()
                    }
                }
            }
        }
        .onAppear {
            activityViewModel.startListening()
        }
    }

    private func categoryIcon(for activity: Activity) -> String {
        ActivityCategory(rawValue: activity.category)?.icon ?? "ellipsis.circle"
    }

    /// Start session immediately with selected activity
    private func startQuickSession(with activity: Activity) async {
        do {
            try await sessionViewModel.startSession(selectedActivities: [activity])
            // Dismiss this selection sheet, revealing the now-active session underneath
            isPresented = false
        } catch {
            print("Error starting quick session: \(error)")
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @Environment(\.dismiss) var dismiss
    QuickStartActivitySelectionView(
        userId: "preview-user",
        isPresented: $isPresented,
        sessionViewModel: SessionViewModel(userId: "preview-user"),
        dismissParent: dismiss
    )
}
