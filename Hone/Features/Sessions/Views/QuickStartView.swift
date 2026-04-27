//
//  QuickStartView.swift
//  Hone
//
//  Created by Zack Huber on 3/1/26.
//

import SwiftUI

private enum PlanSessionRoute: Hashable {
    case setup(preselectedIds: [String])
}

struct QuickStartView: View {
    let userId: String
    @ObservedObject var sessionViewModel: SessionViewModel
    @ObservedObject var sessionHistoryViewModel: SessionHistoryViewModel
    @Binding var showActiveSession: Bool

    @State private var navigationPath = NavigationPath()

    private let dailyGoalMinutes = 60

    private var isSessionActive: Bool {
        sessionViewModel.sessionState != .setup && sessionViewModel.sessionState != .ended
    }

    private var streak: Int {
        SuggestionsService.currentStreak(sessions: sessionHistoryViewModel.sessions)
    }

    private var todayMinutes: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let seconds = sessionHistoryViewModel.sessions
            .filter { session in
                guard session.state == "ended" else { return false }
                guard let date = Date(iso8601String: session.startTime) else { return false }
                return calendar.startOfDay(for: date) == today
            }
            .reduce(0) { $0 + $1.totalDuration }
        return seconds / 60
    }

    private var weeklyMinutes: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!
        let seconds = sessionHistoryViewModel.sessions
            .filter { session in
                guard session.state == "ended" else { return false }
                guard let date = Date(iso8601String: session.startTime) else { return false }
                return date >= startOfWeek
            }
            .reduce(0) { $0 + $1.totalDuration }
        return seconds / 60
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private var recentSessions: [Session] {
        sessionHistoryViewModel.sessions
            .filter { $0.state == "ended" }
            .prefix(3)
            .filter { session in
                guard let id = session.id else { return false }
                let activities = sessionHistoryViewModel.sessionActivities[id] ?? []
                return activities.contains { !$0.isInBetweenTime && $0.activityId != nil }
            }
    }

    private func orderedActivityIds(for session: Session) -> [String] {
        guard let id = session.id,
              let activities = sessionHistoryViewModel.sessionActivities[id] else { return [] }
        return activities
            .filter { !$0.isInBetweenTime && $0.activityId != nil }
            .sorted { $0.startTime < $1.startTime }
            .compactMap { $0.activityId }
    }

    private func sessionDateLabel(_ session: Session) -> String {
        guard let date = Date(iso8601String: session.startTime) else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func sessionActivityNames(_ session: Session) -> String {
        guard let id = session.id,
              let activities = sessionHistoryViewModel.sessionActivities[id] else { return "" }
        let names = activities
            .filter { !$0.isInBetweenTime && $0.activityId != nil }
            .sorted { $0.startTime < $1.startTime }
            .map { $0.activityName }
        guard !names.isEmpty else { return "" }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return names.prefix(2).joined(separator: ", ") + " +\(names.count - 2)"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 8)

                    DailyGoalRing(minutes: todayMinutes, goalMinutes: dailyGoalMinutes)

                    HStack(spacing: 12) {
                        StatCard(
                            icon: "flame.fill",
                            iconColor: .orange,
                            label: "Streak",
                            value: "\(streak) day\(streak == 1 ? "" : "s")"
                        )
                        StatCard(
                            icon: "chart.bar.fill",
                            iconColor: .green,
                            label: "This week",
                            value: weeklyMinutes > 0 ? formatMinutes(weeklyMinutes) : "0m"
                        )
                    }
                    .padding(.horizontal)

                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Button(action: { showActiveSession = true }) {
                                Label(
                                    isSessionActive ? "Resume Session" : "Quick Start",
                                    systemImage: isSessionActive ? "play.circle.fill" : "bolt.fill"
                                )
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isSessionActive ? Color.green : Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Button {
                                navigationPath.append(PlanSessionRoute.setup(preselectedIds: []))
                            } label: {
                                Label("Plan Session", systemImage: "list.bullet")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        if !recentSessions.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recent Sessions")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                VStack(spacing: 0) {
                                    ForEach(Array(recentSessions.enumerated()), id: \.element.id) { index, session in
                                        Button {
                                            navigationPath.append(PlanSessionRoute.setup(
                                                preselectedIds: orderedActivityIds(for: session)
                                            ))
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(sessionDateLabel(session))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Text(sessionActivityNames(session))
                                                        .font(.subheadline)
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                Image(systemName: "arrow.counterclockwise")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                        }
                                        .buttonStyle(.plain)

                                        if index < recentSessions.count - 1 {
                                            Divider()
                                                .padding(.leading, 14)
                                                .background(Color(uiColor: .secondarySystemBackground))
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Hone")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PlanSessionRoute.self) { route in
                if case .setup(let preselectedIds) = route {
                    SessionSetupView(
                        userId: userId,
                        sessionViewModel: sessionViewModel,
                        showActiveSession: $showActiveSession,
                        sessions: sessionHistoryViewModel.sessions,
                        initialActivityIds: preselectedIds
                    )
                }
            }
            .onAppear {
                sessionHistoryViewModel.startListening()
            }
        }
        .onChange(of: showActiveSession) { _, isShowing in
            guard !isShowing, let ids = sessionViewModel.repeatActivityIds else { return }
            sessionViewModel.repeatActivityIds = nil
            navigationPath.append(PlanSessionRoute.setup(preselectedIds: ids))
        }
        .onChange(of: sessionViewModel.repeatActivityIds) { _, ids in
            guard let ids, !showActiveSession else { return }
            sessionViewModel.repeatActivityIds = nil
            navigationPath.append(PlanSessionRoute.setup(preselectedIds: ids))
        }
    }
}

private struct DailyGoalRing: View {
    let minutes: Int
    let goalMinutes: Int

    private var progress: CGFloat {
        guard goalMinutes > 0 else { return 0 }
        return min(CGFloat(minutes) / CGFloat(goalMinutes), 1.0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(progress >= 1.0 ? .orange : .primary)
                Text("of \(goalMinutes) min today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 210, height: 210)
    }
}

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    QuickStartView(
        userId: "preview-user",
        sessionViewModel: SessionViewModel(userId: "preview-user"),
        sessionHistoryViewModel: SessionHistoryViewModel(userId: "preview-user"),
        showActiveSession: .constant(false)
    )
}
