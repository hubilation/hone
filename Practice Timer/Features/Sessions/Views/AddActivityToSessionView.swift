//
//  AddActivityToSessionView.swift
//  Practice Timer
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredActivities) { activity in
                    Button(action: {
                        Task {
                            await viewModel.addActivity(activity)
                            isPresented = false
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.name)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Text(activity.category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    .buttonStyle(.plain)
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
}

#Preview {
    AddActivityToSessionView(
        userId: "preview-user",
        viewModel: SessionViewModel(userId: "preview-user"),
        isPresented: .constant(true)
    )
}
