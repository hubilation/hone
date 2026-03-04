//
//  SessionSetupView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

struct SessionSetupView: View {
    @StateObject private var activityViewModel: ActivityViewModel
    @StateObject private var sessionViewModel: SessionViewModel
    @State private var selectedActivityIds: Set<String> = []
    @State private var orderedActivities: [Activity] = []
    @State private var isEditMode: EditMode = .inactive
    @State private var sessionStarted = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let userId: String

    init(userId: String) {
        self.userId = userId
        _activityViewModel = StateObject(wrappedValue: ActivityViewModel(userId: userId))
        _sessionViewModel = StateObject(wrappedValue: SessionViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Activity selection list
                if activityViewModel.activeActivities.isEmpty {
                    // Empty state
                    ContentUnavailableView(
                        "No Activities Yet",
                        systemImage: "music.note.list",
                        description: Text("Create activities in the Activities tab first")
                    )
                } else {
                    List {
                        // Activity selection section
                        Section {
                            ForEach(activityViewModel.activeActivities) { activity in
                                SelectableActivityRow(
                                    activity: activity,
                                    isSelected: selectedActivityIds.contains(activity.id ?? "")
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(activity)
                                }
                            }
                        } header: {
                            Text("Available Activities")
                        }

                        // Session order section (only show if activities selected)
                        if !orderedActivities.isEmpty {
                            Section {
                                ForEach(orderedActivities) { activity in
                                    HStack {
                                        Image(systemName: categoryIcon(for: activity))
                                            .foregroundColor(.blue)
                                            .frame(width: 30)

                                        Text(activity.name)
                                            .font(.headline)

                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .onMove { from, to in
                                    orderedActivities.move(fromOffsets: from, toOffset: to)
                                }
                            } header: {
                                HStack {
                                    Text("Session Order")
                                    Spacer()
                                    if isEditMode == .active {
                                        Text("Drag to reorder")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Selected count badge
                    if !selectedActivityIds.isEmpty {
                        HStack {
                            Text("\(selectedActivityIds.count) \(selectedActivityIds.count == 1 ? "activity" : "activities") selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .systemBackground))
                    }

                    // Start Session button
                    Button {
                        startSession()
                    } label: {
                        Text("Start Practice Session")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedActivityIds.isEmpty)
                    .padding()
                }
            }
            .navigationTitle("Setup Practice Session")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !orderedActivities.isEmpty {
                        EditButton()
                    }
                }
            }
            .environment(\.editMode, $isEditMode)
            .navigationDestination(isPresented: $sessionStarted) {
                ActiveSessionView(viewModel: sessionViewModel)
            }
        }
        .onAppear {
            activityViewModel.startListening()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Helper Methods

    private func toggleSelection(_ activity: Activity) {
        guard let activityId = activity.id else { return }

        if selectedActivityIds.contains(activityId) {
            // Deselect: remove from set and array
            selectedActivityIds.remove(activityId)
            orderedActivities.removeAll { $0.id == activityId }
        } else {
            // Select: add to set and append to array (selection order)
            selectedActivityIds.insert(activityId)
            orderedActivities.append(activity)
        }
    }

    private func startSession() {
        Task {
            do {
                try await sessionViewModel.startSession(selectedActivities: orderedActivities)
                sessionStarted = true
            } catch {
                errorMessage = "Failed to start session: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func categoryIcon(for activity: Activity) -> String {
        ActivityCategory(rawValue: activity.category)?.icon ?? "ellipsis.circle"
    }
}

// MARK: - SelectableActivityRow

struct SelectableActivityRow: View {
    let activity: Activity
    let isSelected: Bool

    var body: some View {
        HStack {
            // Category icon
            Image(systemName: categoryIcon)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.headline)
                Text(activity.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Checkmark if selected
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: String {
        ActivityCategory(rawValue: activity.category)?.icon ?? "ellipsis.circle"
    }
}

// MARK: - Preview

#Preview {
    SessionSetupView(userId: "preview-user-id")
}
