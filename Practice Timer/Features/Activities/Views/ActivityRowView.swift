//
//  ActivityRowView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

struct ActivityRowView: View {
    let activity: Activity

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
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: String {
        ActivityCategory(rawValue: activity.category)?.icon ?? "ellipsis.circle"
    }
}

// MARK: - Preview

#Preview {
    List {
        ActivityRowView(activity: Activity(
            id: "1",
            name: "Scales Practice",
            category: "Technique",
            createdAt: "2026-03-03T10:00:00Z",
            updatedAt: "2026-03-03T10:00:00Z",
            active: true
        ))

        ActivityRowView(activity: Activity(
            id: "2",
            name: "Piano",
            category: "Instrument",
            createdAt: "2026-03-03T10:00:00Z",
            updatedAt: "2026-03-03T10:00:00Z",
            active: true
        ))
    }
}
