//
//  ActivityFormView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

struct ActivityFormView: View {
    // MARK: - Properties

    @State private var name: String = ""
    @State private var category: ActivityCategory = .instrument
    @Environment(\.dismiss) var dismiss

    let activity: Activity?

    // MARK: - Initialization

    init(activity: Activity? = nil) {
        self.activity = activity
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Activity Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $category) {
                        ForEach(ActivityCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(activity == nil ? "New Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // TODO: Call viewModel.createActivity or updateActivity
                        // This will be wired in Plan 02-03 when ActivityViewModel is created
                        // Save action will be connected to ActivityViewModel in Plan 02-03. Form validation ready.
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            // If editing, populate fields
            if let activity = activity {
                name = activity.name
                category = ActivityCategory(rawValue: activity.category) ?? .other
            }
        }
    }
}

// MARK: - Preview

#Preview("Create Mode") {
    ActivityFormView()
}

#Preview("Edit Mode") {
    let sampleActivity = Activity(
        id: "123",
        name: "Scales Practice",
        category: "Technique",
        createdAt: "2026-03-03T10:00:00Z",
        updatedAt: "2026-03-03T10:00:00Z",
        archived: false
    )

    return ActivityFormView(activity: sampleActivity)
}
