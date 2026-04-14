//
//  GroupedActivityListView.swift
//  Hone
//
//  Created by Claude on 3/5/26.
//

import SwiftUI

/// Reusable grouped activity list with customizable row content
/// Displays activities grouped by category with consistent styling
struct GroupedActivityListView<RowContent: View>: View {
    let activities: [Activity]
    let rowContent: (Activity) -> RowContent

    private var groupedActivities: [(category: String, activities: [Activity])] {
        ActivityGrouping.grouped(activities)
    }

    var body: some View {
        List {
            ForEach(groupedActivities, id: \.category) { group in
                Section(header: Text(group.category)) {
                    ForEach(group.activities) { activity in
                        rowContent(activity)
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleActivities = [
        Activity(
            id: "1",
            name: "Scales",
            category: "Warm-up",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String()
        ),
        Activity(
            id: "2",
            name: "Sonata",
            category: "Piece",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String()
        ),
        Activity(
            id: "3",
            name: "Arpeggios",
            category: "Technique",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String()
        )
    ]

    GroupedActivityListView(activities: sampleActivities) { activity in
        ActivityRowView(activity: activity)
    }
}
