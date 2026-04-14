//
//  ActivityGrouping.swift
//  Hone
//
//  Created by Claude on 3/5/26.
//

import Foundation

/// Utility for grouping and sorting activities by category
struct ActivityGrouping {
    /// Default category order used throughout the app
    static let categoryOrder = ["Warm-up", "Piece", "Technique"]

    /// Groups activities by category with custom ordering
    /// - Parameter activities: Array of activities to group
    /// - Returns: Array of tuples containing category name and sorted activities
    static func grouped(_ activities: [Activity]) -> [(category: String, activities: [Activity])] {
        // Group activities by category
        let grouped = Dictionary(grouping: activities) { activity in
            activity.category
        }

        // Sort by custom order
        var result: [(category: String, activities: [Activity])] = []

        // Add ordered categories first
        for category in categoryOrder {
            if let activities = grouped[category], !activities.isEmpty {
                result.append((category: category, activities: activities.sorted { $0.name < $1.name }))
            }
        }

        // Add remaining categories alphabetically
        for (category, activities) in grouped.sorted(by: { $0.key < $1.key }) {
            if !categoryOrder.contains(category) {
                result.append((category: category, activities: activities.sorted { $0.name < $1.name }))
            }
        }

        return result
    }
}
