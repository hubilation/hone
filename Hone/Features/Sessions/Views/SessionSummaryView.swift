//
//  SessionSummaryView.swift
//  Hone
//
//  Created by Claude on 3/4/26.
//

import SwiftUI
import Charts

/// Post-session summary displaying activity breakdown and notes
/// Shows total time, per-activity times, and all notes
struct SessionSummaryView: View {
    let session: Session?
    let activities: [SessionActivity]
    var onStartNewPractice: (([String]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    private var totalDuration: TimeInterval {
        TimeInterval(activities.reduce(0) { $0 + $1.duration })
    }

    private var formattedTotalTime: String {
        formatDuration(totalDuration)
    }

    private let chartColors: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .pink, .cyan]

    @State private var selectedActivityName: String? = nil

    private var practiceActivities: [SessionActivity] {
        activities.filter { !$0.isInBetweenTime }
    }

    private var repeatActivityIds: [String] {
        practiceActivities.compactMap { $0.activityId }
    }

    private func activityName(at location: CGPoint, chartSize: CGSize) -> String? {
        let center = CGPoint(x: chartSize.width / 2, y: chartSize.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let maxRadius = min(chartSize.width, chartSize.height) / 2
        let innerRadius = maxRadius * 0.4
        guard distance >= innerRadius, distance <= maxRadius else { return nil }
        let angle = (atan2(dy, dx) + .pi / 2 + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let total = Double(practiceActivities.reduce(0) { $0 + $1.duration })
        guard total > 0 else { return nil }
        var cumulative: Double = 0
        for activity in practiceActivities {
            cumulative += Double(activity.duration) / total * 2 * .pi
            if angle < cumulative { return activity.activityName }
        }
        return practiceActivities.last?.activityName
    }

    var body: some View {
        NavigationView {
            List {
                // Total session time
                Section(header: Text("Session Complete")) {
                    if let onStartNewPractice, !repeatActivityIds.isEmpty {
                        Button {
                            onStartNewPractice(repeatActivityIds)
                        } label: {
                            Label("Start New Practice", systemImage: "arrow.clockwise")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Total Practice Time")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formattedTotalTime)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    if let session = session, let startTime = session.startTime.toDate() {
                        HStack {
                            Text("Started")
                            Spacer()
                            Text(startTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let session = session, let endTime = session.endTime?.toDate() {
                        HStack {
                            Text("Ended")
                            Spacer()
                            Text(endTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Pie chart of activity time distribution
                if !practiceActivities.isEmpty {
                    Section(header: Text("Time Distribution")) {
                        VStack(spacing: 0) {
                            Chart(practiceActivities) { activity in
                                SectorMark(
                                    angle: .value("Duration", activity.duration),
                                    innerRadius: .ratio(0.4),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("Activity", activity.activityName))
                                .opacity(selectedActivityName == nil || selectedActivityName == activity.activityName ? 1.0 : 0.4)
                                .cornerRadius(4)
                            }
                            .chartForegroundStyleScale(
                                domain: practiceActivities.map { $0.activityName },
                                range: practiceActivities.indices.map { chartColors[$0 % chartColors.count] }
                            )
                            .chartLegend(.hidden)
                            .frame(height: 200)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .animation(.easeInOut(duration: 0.2), value: selectedActivityName)
                            .chartOverlay { _ in
                                GeometryReader { geo in
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture { location in
                                            let name = activityName(at: location, chartSize: geo.size)
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedActivityName = (selectedActivityName == name) ? nil : name
                                            }
                                        }
                                }
                            }

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(Array(practiceActivities.enumerated()), id: \.offset) { index, activity in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(chartColors[index % chartColors.count])
                                            .frame(width: 10, height: 10)
                                        Text(activity.activityName)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .opacity(selectedActivityName == nil || selectedActivityName == activity.activityName ? 1.0 : 0.4)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedActivityName = (selectedActivityName == activity.activityName) ? nil : activity.activityName
                                        }
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: selectedActivityName)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedActivityName = nil
                            }
                        }
                    }
                }

                // Activity breakdown
                Section(header: Text("Activity Breakdown")) {
                    ForEach(activities.filter { !$0.isInBetweenTime }) { activity in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(activity.activityName)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(formatDuration(TimeInterval(activity.duration)))
                                    .foregroundColor(.secondary)
                            }

                            if let notes = activity.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // In-between time (if any)
                let inBetweenActivities = activities.filter { $0.isInBetweenTime }
                if !inBetweenActivities.isEmpty {
                    Section(header: Text("Break Time")) {
                        ForEach(inBetweenActivities) { activity in
                            HStack {
                                Text("Break")
                                Spacer()
                                Text(formatDuration(TimeInterval(activity.duration)))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Total Break Time")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(formatDuration(TimeInterval(inBetweenActivities.reduce(0) { $0 + $1.duration })))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

/// Wrapper view for reactive session summary with SessionHistoryViewModel
/// Observes ViewModel's sessionActivities dictionary and updates when activities load
struct ReactiveSessionSummaryView: View {
    let session: Session?
    @ObservedObject var viewModel: SessionHistoryViewModel

    var body: some View {
        SessionSummaryView(
            session: session,
            activities: viewModel.sessionActivities[session?.id ?? ""] ?? []
        )
    }
}

/// Loader view that fetches activities from Firestore for session summary
/// Ensures summary always shows accurate data from database, not in-memory array
struct SessionSummaryViewLoader: View {
    let session: Session?
    let userId: String
    var onStartNewPractice: (([String]) -> Void)? = nil
    @State private var activities: [SessionActivity] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                SessionSummaryView(session: session, activities: activities, onStartNewPractice: onStartNewPractice)
            }
        }
        .task {
            await loadActivities()
        }
    }

    private func loadActivities() async {
        guard let sessionId = session?.id else {
            isLoading = false
            return
        }

        do {
            let repository = SessionRepository()
            activities = try await repository.getSessionActivities(userId: userId, sessionId: sessionId)
            isLoading = false
        } catch {
            print("Error loading session activities: \(error)")
            isLoading = false
        }
    }
}

#Preview {
    let session = Session(
        id: "s1",
        startTime: Date().addingTimeInterval(-1620).toISO8601String(),
        endTime: Date().toISO8601String(),
        totalDuration: 1620,
        createdAt: Date().toISO8601String(),
        updatedAt: Date().toISO8601String(),
        state: "ended",
        pausedAt: nil,
        currentActivityIndex: 2
    )

    let activities = [
        SessionActivity(
            id: "1",
            activityId: "a1",
            activityName: "Scales",
            startTime: "",
            endTime: "",
            duration: 600,  // 10 minutes
            notes: "Focused on C major",
            isInBetweenTime: false,
            createdAt: "",
            updatedAt: ""
        ),
        SessionActivity(
            id: "2",
            activityId: nil,
            activityName: "Break",
            startTime: "",
            endTime: "",
            duration: 120,  // 2 minutes
            notes: nil,
            isInBetweenTime: true,
            createdAt: "",
            updatedAt: ""
        ),
        SessionActivity(
            id: "3",
            activityId: "a2",
            activityName: "Piece Practice",
            startTime: "",
            endTime: "",
            duration: 900,  // 15 minutes
            notes: "Worked on measures 32-48",
            isInBetweenTime: false,
            createdAt: "",
            updatedAt: ""
        )
    ]

    return SessionSummaryView(session: session, activities: activities)
}
