//
//  DailyPracticeChartView.swift
//  Practice Timer
//
//  Created by Claude on 3/4/26.
//

import SwiftUI
import Charts

struct DailyPracticeChartView: View {
    let userId: String
    let sessions: [Session]
    let activities: [Activity]

    @State private var chartData: [DailyCategoryPracticeData] = []
    @State private var isLoading = true

    private let repository = StatisticsRepository.shared

    private var categories: [String] {
        let uniqueCategories = Set(chartData.map { $0.category })
        let categoryOrder = ["Warm-up", "Piece", "Technique"]

        // Return ordered categories
        var result = categoryOrder.filter { uniqueCategories.contains($0) }
        result.append(contentsOf: uniqueCategories.filter { !categoryOrder.contains($0) }.sorted())
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Practice (Last 30 Days)")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if chartData.isEmpty {
                Text("No practice sessions in the last 30 days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData) { data in
                    BarMark(
                        x: .value("Date", data.date, unit: .day),
                        y: .value("Minutes", data.minutes)
                    )
                    .foregroundStyle(by: .value("Category", data.category))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
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
                .chartForegroundStyleScale(
                    domain: categories,
                    range: categoryColors(for: categories)
                )
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task(id: activities.count) {
            await loadChartData()
        }
    }

    private func categoryColors(for categories: [String]) -> [Color] {
        categories.map { category in
            switch category {
            case "Warm-up": return .orange
            case "Piece": return .blue
            case "Technique": return .green
            default: return .purple
            }
        }
    }

    private func loadChartData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            chartData = try await repository.getDailyCategoryData(
                userId: userId,
                activities: activities,
                days: 30
            )
        } catch {
            print("Error loading daily category data: \(error)")
            chartData = []
        }
    }
}

#Preview {
    let sessions = [
        Session(
            id: "s1",
            startTime: Date().addingTimeInterval(-86400).toISO8601String(),
            endTime: Date().addingTimeInterval(-82800).toISO8601String(),
            totalDuration: 3600,
            createdAt: Date().addingTimeInterval(-86400).toISO8601String(),
            updatedAt: Date().addingTimeInterval(-86400).toISO8601String(),
            state: "ended",
            pausedAt: nil,
            currentActivityIndex: nil
        )
    ]

    let activities = [
        Activity(
            id: "a1",
            name: "Scales",
            category: "Warm-up",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            active: true
        )
    ]

    DailyPracticeChartView(
        userId: "preview-user",
        sessions: sessions,
        activities: activities
    )
    .padding()
}
