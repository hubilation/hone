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
    let onSave: (String, ActivityCategory) -> Void

    // MARK: - Initialization

    init(activity: Activity? = nil, onSave: @escaping (String, ActivityCategory) -> Void) {
        self.activity = activity
        self.onSave = onSave
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
                        onSave(name, category)
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
    ActivityFormView { name, category in
        print("Creating activity: \(name), \(category.rawValue)")
    }
}

#Preview("Edit Mode") {
    let sampleActivity = Activity(
        id: "123",
        name: "Scales Practice",
        category: "Technique",
        createdAt: "2026-03-03T10:00:00Z",
        updatedAt: "2026-03-03T10:00:00Z",
        active: true
    )

    return ActivityFormView(activity: sampleActivity) { name, category in
        print("Updating activity: \(name), \(category.rawValue)")
    }
}
