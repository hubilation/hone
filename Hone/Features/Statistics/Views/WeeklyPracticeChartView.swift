//
//  WeeklyPracticeChartView.swift
//  Hone
//

import SwiftUI
import Charts

struct WeeklyPracticeChartView: View {
    let userId: String
    let activities: [Activity]

    @State private var chartData: [WeeklyPracticeData] = []
    @State private var isLoading = true

    private let repository = StatisticsRepository.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Practice (Last 16 Weeks)")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if chartData.isEmpty {
                Text("No practice sessions in the last 16 weeks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData) { data in
                    BarMark(
                        x: .value("Week", data.weekStart, unit: .weekOfYear),
                        y: .value("Minutes", data.minutes)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated))
                            }
                        }
                        AxisGridLine()
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
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task(id: activities.count) {
            await loadChartData()
        }
    }

    private func loadChartData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            chartData = try await repository.getWeeklyData(
                userId: userId,
                activities: activities,
                weeks: 16
            )
        } catch {
            chartData = []
        }
    }
}
