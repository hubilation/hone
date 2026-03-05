//
//  ActivityDetailStatisticsView.swift
//  Practice Timer
//
//  Created by Claude on 3/5/26.
//

import SwiftUI
import Charts

/// Detailed statistics view for a single activity
///
/// Shows:
/// - Total practice time and session count
/// - Bar chart of time spent per session from first to last practice
/// - Date range of practice history
struct ActivityDetailStatisticsView: View {
    let userId: String
    let activityId: String
    let activityName: String
    let activityStatistics: ActivityStatistics?  // Pass from parent to show immediately

    @State private var chartData: [SessionPracticeData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var totalTime: TimeInterval = 0
    @State private var sessionCount: Int = 0
    @State private var dateRange: String = ""

    private let repository = StatisticsRepository.shared

    init(userId: String, activityId: String, activityName: String, activityStatistics: ActivityStatistics? = nil) {
        self.userId = userId
        self.activityId = activityId
        self.activityName = activityName
        self.activityStatistics = activityStatistics

        // Initialize totals from passed statistics if available
        if let stats = activityStatistics {
            _totalTime = State(initialValue: stats.totalPracticeTime)
            _sessionCount = State(initialValue: stats.sessionCount)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overview")
                        .font(.headline)

                    HStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedTotalTime)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(sessionCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }

                    if !dateRange.isEmpty {
                        Text(dateRange)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Session-by-session chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Practice History")
                        .font(.headline)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else if let error = errorMessage {
                        Text("Error: \(error)")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else if chartData.isEmpty {
                        Text("No practice sessions yet")
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
                        .frame(height: 250)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(activityName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSessionData()
        }
    }

    private var formattedTotalTime: String {
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func loadSessionData() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await repository.getActivitySessionHistory(
                userId: userId,
                activityId: activityId
            )

            chartData = data.sorted { $0.date < $1.date }

            // Update totals if not already set from parent
            if activityStatistics == nil {
                totalTime = TimeInterval(data.reduce(0) { $0 + $1.minutes * 60 })
                sessionCount = Set(data.map { $0.sessionId }).count
            }

            // Calculate date range
            if let first = chartData.first?.date, let last = chartData.last?.date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                if Calendar.current.isDate(first, inSameDayAs: last) {
                    dateRange = "Practiced on \(formatter.string(from: first))"
                } else {
                    dateRange = "\(formatter.string(from: first)) - \(formatter.string(from: last))"
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ActivityDetailStatisticsView(
            userId: "preview-user",
            activityId: "preview-activity",
            activityName: "Scales"
        )
    }
}
