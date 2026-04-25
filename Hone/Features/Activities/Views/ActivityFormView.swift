//
//  ActivityFormView.swift
//  Hone
//
//  Created by Claude on 3/3/26.
//

import SwiftUI
import Charts

struct ActivityFormView: View {
    // MARK: - Properties

    @State private var name: String = ""
    @State private var category: ActivityCategory = .instrument
    @State private var activityStats: ActivityStatistics?
    @State private var chartData: [SessionPracticeData] = []
    @State private var isLoadingStats = false
    @Environment(\.dismiss) var dismiss

    let activity: Activity?
    let userId: String?
    let onSave: (String, ActivityCategory) -> Void

    private let repository = StatisticsRepository.shared

    // MARK: - Initialization

    init(activity: Activity? = nil, userId: String? = nil, onSave: @escaping (String, ActivityCategory) -> Void) {
        self.activity = activity
        self.userId = userId
        self.onSave = onSave
    }

    private var showStats: Bool { activity != nil && userId != nil }

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

                if showStats {
                    statisticsSection
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
            if let activity = activity {
                name = activity.name
                category = ActivityCategory(rawValue: activity.category) ?? .other
            }
        }
        .task {
            guard let activity, let activityId = activity.id, let userId else { return }
            await loadStats(userId: userId, activityId: activityId, activityName: activity.name)
        }
    }

    // MARK: - Statistics Section

    @ViewBuilder
    private var statisticsSection: some View {
        Section("Statistics") {
            if isLoadingStats {
                HStack {
                    Spacer()
                    ProgressView("Loading statistics...")
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let stats = activityStats {
                LabeledContent("Total Time", value: stats.formattedTime)
                LabeledContent("Sessions", value: "\(stats.sessionCount)")
                LabeledContent("Last Practice", value: stats.formattedLastPractice)

                if !chartData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Practice History")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Chart(chartData) { data in
                            BarMark(
                                x: .value("Date", data.date, unit: .day),
                                y: .value("Minutes", data.minutes)
                            )
                            .foregroundStyle(Color.blue.gradient)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(date, format: .dateTime.month(.abbreviated).day())
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let minutes = value.as(Int.self) {
                                        Text("\(minutes)m")
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Text("No practice history yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Data Loading

    private func loadStats(userId: String, activityId: String, activityName: String) async {
        isLoadingStats = true
        do {
            let activitiesToFetch = activity.map { [$0] } ?? []
            let allStats = try await repository.getAllActivityStatistics(
                userId: userId,
                activities: activitiesToFetch
            )
            activityStats = allStats.first { $0.activityId == activityId }
            chartData = try await repository.getActivitySessionHistory(
                userId: userId,
                activityId: activityId
            ).sorted { $0.date < $1.date }
        } catch {
            // Stats are supplementary — fail silently
        }
        isLoadingStats = false
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
