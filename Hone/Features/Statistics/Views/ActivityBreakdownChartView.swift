//
//  ActivityBreakdownChartView.swift
//  Hone
//
//  Created by Claude on 3/4/26.
//

import SwiftUI
import Charts

struct ActivityBreakdownChartView: View {
    let userId: String
    let activities: [Activity]

    @State private var chartData: [AverageSessionTimeData] = []
    @State private var isLoading = false

    private let statisticsRepository = StatisticsRepository.shared

    private func loadChartData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            chartData = try await statisticsRepository.getAverageSessionTimes(
                userId: userId,
                activities: activities,
                days: 30
            )
        } catch {
            print("ERROR loading average session times: \(error)")
            chartData = []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Average Session Time (Last 30 Days)")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if chartData.isEmpty {
                Text("No practice sessions in the last 30 days.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData) { data in
                    BarMark(
                        x: .value("Minutes", data.averageMinutes),
                        y: .value("Activity", data.activityName)
                    )
                    .foregroundStyle(by: .value("Activity", data.activityName))
                    .annotation(position: .trailing) {
                        Text(String(format: "%.0f min", data.averageMinutes))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(String(format: "%.0f min", minutes))
                            }
                        }
                    }
                }
                .chartLegend(.hidden)  // Hide legend since we have annotations
                .frame(height: max(50.0 * Double(chartData.count), 150))  // Dynamic height based on activity count
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task(id: activities.count) {
            await loadChartData()
        }
    }
}

#Preview {
    ActivityBreakdownChartView(userId: "preview-user", activities: [])
        .padding()
}
