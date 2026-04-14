//
//  AddActivityToSessionView.swift
//  Hone
//
//  Created by Claude on 3/5/26.
//

import SwiftUI

/// Sheet for adding activities to an ongoing session
/// Shows list of active activities, tap to add
struct AddActivityToSessionView: View {
    let userId: String
    @ObservedObject var viewModel: SessionViewModel
    @Binding var isPresented: Bool

    @StateObject private var activityViewModel: ActivityViewModel
    @State private var searchText = ""

    init(userId: String, viewModel: SessionViewModel, isPresented: Binding<Bool>) {
        self.userId = userId
        self.viewModel = viewModel
        self._isPresented = isPresented
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

    private var activitiesInSession: Set<String> {
        Set(viewModel.activities.compactMap { $0.activityId })
    }

    private func isActivityInSession(_ activity: Activity) -> Bool {
        guard let activityId = activity.id else { return false }
        return activitiesInSession.contains(activityId)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedActivities, id: \.category) { group in
                    Section(header: Text(group.category)) {
                        ForEach(group.activities) { activity in
                            let alreadyAdded = isActivityInSession(activity)

                            Button(action: {
                                guard !alreadyAdded else { return }
                                Task {
                                    await viewModel.addActivity(activity)
                                    isPresented = false
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: categoryIcon(for: activity))
                                        .foregroundColor(alreadyAdded ? .gray : .blue)
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(activity.name)
                                            .font(.headline)
                                            .foregroundColor(alreadyAdded ? .secondary : .primary)

                                        Text(activity.category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if alreadyAdded {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.title3)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(alreadyAdded)
                            .opacity(alreadyAdded ? 0.5 : 1.0)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search activities")
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
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
}

#Preview {
    AddActivityToSessionView(
        userId: "preview-user",
        viewModel: SessionViewModel(userId: "preview-user"),
        isPresented: .constant(true)
    )
}
