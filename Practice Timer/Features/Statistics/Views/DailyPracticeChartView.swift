//
//  DailyPracticeChartView.swift
//  Practice Timer
//
//  Created by Claude on 3/4/26.
//

import SwiftUI
import Charts

/// Data point for daily practice time
struct DailyPracticeData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int  // Total practice minutes for the day
}

struct DailyPracticeChartView: View {
    let sessions: [Session]

    private var chartData: [DailyPracticeData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!

        // Filter sessions to last 30 days
        let recentSessions = sessions.filter { session in
            guard session.state == "ended" else { return false }
            guard let startDate = Date(iso8601String: session.startTime) else { return false }
            return startDate >= thirtyDaysAgo
        }

        // Group by day and sum durations
        let grouped = Dictionary(grouping: recentSessions) { session -> Date in
            guard let date = Date(iso8601String: session.startTime) else { return Date() }
            return calendar.startOfDay(for: date)
        }

        // Map to chart data
        let data = grouped.map { (date, sessions) in
            let totalSeconds = sessions.reduce(0) { $0 + $1.totalDuration }
            return DailyPracticeData(
                date: date,
                minutes: totalSeconds / 60
            )
        }

        return data.sorted { $0.date < $1.date }  // Ascending for left-to-right chart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Practice (Last 30 Days)")
                .font(.headline)

            if chartData.isEmpty {
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
                    .foregroundStyle(Color.blue.gradient)
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
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    let sessions = [
        Session(
            id: "s1",
            startTime: Date().addingTimeInterval(-86400).toISO8601String(),  // 1 day ago
            endTime: Date().addingTimeInterval(-82800).toISO8601String(),
            totalDuration: 3600,
            createdAt: Date().addingTimeInterval(-86400).toISO8601String(),
            updatedAt: Date().addingTimeInterval(-86400).toISO8601String(),
            state: "ended",
            pausedAt: nil,
            currentActivityIndex: nil
        ),
        Session(
            id: "s2",
            startTime: Date().addingTimeInterval(-172800).toISO8601String(),  // 2 days ago
            endTime: Date().addingTimeInterval(-169200).toISO8601String(),
            totalDuration: 5400,
            createdAt: Date().addingTimeInterval(-172800).toISO8601String(),
            updatedAt: Date().addingTimeInterval(-172800).toISO8601String(),
            state: "ended",
            pausedAt: nil,
            currentActivityIndex: nil
        )
    ]

    DailyPracticeChartView(sessions: sessions)
        .padding()
}
