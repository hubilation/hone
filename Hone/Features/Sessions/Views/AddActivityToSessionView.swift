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
    /// Snapshot of activity IDs already in the session — captured at sheet-open time.
    /// Passed as a value so this view never observes SessionViewModel (whose timer
    /// fires 10×/s and would cause constant re-renders).
    let sessionActivityIds: Set<String>
    let onAdd: (Activity) async -> Void
    @Binding var isPresented: Bool

    @StateObject private var activityViewModel: ActivityViewModel
    @State private var searchText = ""
    /// Frozen on first load — never re-sorted mid-session to avoid list instability
    @State private var frozenGroupedActivities: [(category: String, activities: [Activity])] = []

    init(userId: String, sessionActivityIds: Set<String>, onAdd: @escaping (Activity) async -> Void, isPresented: Binding<Bool>) {
        self.userId = userId
        self.sessionActivityIds = sessionActivityIds
        self.onAdd = onAdd
        self._isPresented = isPresented
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

    private var displayedGroups: [(category: String, activities: [Activity])] {
        guard !searchText.isEmpty else { return frozenGroupedActivities }
        return frozenGroupedActivities.compactMap { group in
            let filtered = group.activities.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            return filtered.isEmpty ? nil : (category: group.category, activities: filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(displayedGroups, id: \.category) { group in
                    Section(header: Text(group.category)) {
                        ForEach(group.activities) { activity in
                            activityRow(activity)
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
        .onChange(of: activityViewModel.activeActivities) { newActivities in
            guard frozenGroupedActivities.isEmpty else { return }
            frozenGroupedActivities = buildGroupedActivities(newActivities)
        }
    }

    @ViewBuilder
    private func activityRow(_ activity: Activity) -> some View {
        let alreadyAdded = activity.id.map { sessionActivityIds.contains($0) } ?? false
        let iconName = alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill"
        let iconColor: Color = alreadyAdded ? .gray : .blue
        Button(action: {
            guard !alreadyAdded else { return }
            Task {
                await onAdd(activity)
                isPresented = false
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: categoryIcon(for: activity))
                    .foregroundColor(alreadyAdded ? .gray : .blue)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.name)
                        .font(.headline)
                        .foregroundColor(alreadyAdded ? .secondary : .primary)
                    Text(lastPracticedText(activity.lastUsed))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.title3)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded)
        .opacity(alreadyAdded ? 0.5 : 1.0)
    }

    private func categoryIcon(for activity: Activity) -> String {
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

#Preview {
    AddActivityToSessionView(
        userId: "preview-user",
        sessionActivityIds: [],
        onAdd: { _ in },
        isPresented: .constant(true)
    )
}
