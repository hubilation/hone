//
//  SessionSetupView.swift
//  Hone
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

struct SessionSetupView: View {
    @StateObject private var activityViewModel: ActivityViewModel
    @ObservedObject var sessionViewModel: SessionViewModel
    @Binding var showActiveSession: Bool
    @State private var selectedActivityIds: Set<String> = []
    @State private var orderedActivities: [Activity] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    /// Frozen on first load — never re-sorted mid-session to avoid list instability
    @State private var frozenGroupedActivities: [(category: String, activities: [Activity])] = []
    /// Tracks whether a session was started from this screen, so we know to pop on completion
    @State private var sessionStartedFromHere = false
    @Environment(\.dismiss) private var dismiss

    private let userId: String
    private let sessions: [Session]
    private let initialActivityIds: [String]

    init(userId: String, sessionViewModel: SessionViewModel, showActiveSession: Binding<Bool>, sessions: [Session] = [], initialActivityIds: [String] = []) {
        self.userId = userId
        self.sessions = sessions
        self.initialActivityIds = initialActivityIds
        self._sessionViewModel = ObservedObject(wrappedValue: sessionViewModel)
        self._showActiveSession = showActiveSession
        _activityViewModel = StateObject(wrappedValue: ActivityViewModel(userId: userId))
    }

    private func buildGroupedActivities(_ activities: [Activity]) -> [(category: String, activities: [Activity])] {
        ActivityGrouping.grouped(activities).map { group in
            let sorted = group.activities.sorted { a, b in
                switch (a.lastUsed, b.lastUsed) {
                case (nil, nil): return false
                case (nil, _): return true
                case (_, nil): return false
                case (let la?, let lb?): return la < lb
                }
            }
            return (category: group.category, activities: sorted)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if activityViewModel.activeActivities.isEmpty {
                ContentUnavailableView(
                    "No Activities Yet",
                    systemImage: "music.note.list",
                    description: Text("Create activities in the Activities tab first")
                )
            } else {
                // Activity selection list (scrollable)
                List {
                    ForEach(frozenGroupedActivities, id: \.category) { group in
                        Section(header: Text(group.category)) {
                            ForEach(group.activities) { activity in
                                SelectableActivityRow(
                                    activity: activity,
                                    isSelected: selectedActivityIds.contains(activity.id ?? "")
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(activity)
                                }
                            }
                        }
                    }
                }

                // Selected activities — fixed section above Start button
                if !orderedActivities.isEmpty {
                    VStack(spacing: 0) {
                        Divider()

                        HStack {
                            Text("Session Order")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(orderedActivities.count) \(orderedActivities.count == 1 ? "activity" : "activities")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .systemGroupedBackground))

                        List {
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
                            .onDelete { indices in
                                for index in indices {
                                    if let id = orderedActivities[index].id {
                                        selectedActivityIds.remove(id)
                                    }
                                }
                                orderedActivities.remove(atOffsets: indices)
                            }
                        }
                        .environment(\.editMode, .constant(.active))
                        .frame(height: min(CGFloat(orderedActivities.count) * 52, 208))
                        .listStyle(.plain)
                    }
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
        .onAppear {
            activityViewModel.startListening()
        }
        .onChange(of: activityViewModel.activeActivities) { newActivities in
            guard frozenGroupedActivities.isEmpty else { return }
            frozenGroupedActivities = buildGroupedActivities(newActivities)
            guard !initialActivityIds.isEmpty else { return }
            var ordered: [Activity] = []
            var selected: Set<String> = []
            for id in initialActivityIds {
                if let activity = newActivities.first(where: { $0.id == id }) {
                    ordered.append(activity)
                    selected.insert(id)
                }
            }
            orderedActivities = ordered
            selectedActivityIds = selected
        }
        .onChange(of: showActiveSession) { _, isShowing in
            // When the session sheet closes after a completed session, pop back to Home
            guard !isShowing && sessionStartedFromHere else { return }
            if sessionViewModel.sessionState == .ended {
                selectedActivityIds = []
                orderedActivities = []
                sessionStartedFromHere = false
                dismiss()
            }
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
            selectedActivityIds.remove(activityId)
            orderedActivities.removeAll { $0.id == activityId }
        } else {
            selectedActivityIds.insert(activityId)
            orderedActivities.append(activity)
        }
    }

    private func startSession() {
        sessionStartedFromHere = true
        Task {
            do {
                try await sessionViewModel.startSession(selectedActivities: orderedActivities)
                showActiveSession = true
            } catch {
                sessionStartedFromHere = false
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

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.headline)
                Text(lastPracticedText(activity.lastUsed))
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

    private func lastPracticedText(_ lastUsed: String?) -> String {
        guard let str = lastUsed, let date = Date(iso8601String: str) else {
            return "Never practiced"
        }
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: date),
            to: Calendar.current.startOfDay(for: Date())).day ?? 0
        switch days {
        case 0: return "Practiced today"
        case 1: return "Practiced yesterday"
        default: return "Practiced \(days) days ago"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionSetupView(
            userId: "preview-user-id",
            sessionViewModel: SessionViewModel(userId: "preview-user-id"),
            showActiveSession: .constant(false)
        )
    }
}
