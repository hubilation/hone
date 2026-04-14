//
//  StatisticsRepository.swift
//  Hone
//
//  Created by Claude on 3/3/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Models

struct ActivityStatistics: Identifiable {
    let id: String
    let activityId: String
    let activityName: String
    let totalPracticeTime: TimeInterval
    let sessionCount: Int
    let lastPracticeDate: Date?

    var formattedTime: String {
        let hours = Int(totalPracticeTime) / 3600
        let minutes = (Int(totalPracticeTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedLastPractice: String {
        guard let date = lastPracticeDate else { return "Never" }
        let calendar = Calendar.current
        let now = Date()
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

struct SessionPracticeData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
    let sessionId: String
}

struct DailyCategoryPracticeData: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let minutes: Int
}

struct AverageSessionTimeData: Identifiable {
    let id = UUID()
    let activityName: String
    let averageMinutes: Double
    let sessionCount: Int
}

struct WeeklyPracticeData: Identifiable {
    let id = UUID()
    let weekStart: Date
    let minutes: Int
}

protocol StatisticsRepositoryProtocol {
    func getActivityStatistics(userId: String, activityId: String, activityName: String) async throws -> ActivityStatistics
    func getAllActivityStatistics(userId: String, activities: [Activity]) async throws -> [ActivityStatistics]
    func getActivitySessionHistory(userId: String, activityId: String) async throws -> [SessionPracticeData]
    func getDailyCategoryData(userId: String, activities: [Activity], days: Int) async throws -> [DailyCategoryPracticeData]
    func getAverageSessionTimes(userId: String, activities: [Activity], days: Int) async throws -> [AverageSessionTimeData]
    func getWeeklyData(userId: String, activities: [Activity], weeks: Int) async throws -> [WeeklyPracticeData]
    func invalidateCache()
}

// MARK: - Implementation

final class StatisticsRepository: StatisticsRepositoryProtocol {
    static let shared = StatisticsRepository()

    private let db = Firestore.firestore()
    private var cachedStatistics: [String: ActivityStatistics] = [:]
    private var cachedSessionHistory: [String: [SessionPracticeData]] = [:]
    private var cachedDailyCategoryData: [DailyCategoryPracticeData] = []
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 300

    init() {}

    private var isCacheValid: Bool {
        guard let timestamp = cacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < cacheValidityDuration
    }

    func getActivityStatistics(userId: String, activityId: String, activityName: String) async throws -> ActivityStatistics {
        if let cached = cachedStatistics[activityId] {
            return cached
        }
        return ActivityStatistics(id: activityId, activityId: activityId, activityName: activityName, totalPracticeTime: 0, sessionCount: 0, lastPracticeDate: nil)
    }

    func getAllActivityStatistics(userId: String, activities: [Activity]) async throws -> [ActivityStatistics] {
        if activities.isEmpty { return [] }

        var activityCategories: [String: String] = [:]
        for activity in activities {
            if let id = activity.id { activityCategories[id] = activity.category }
        }

        if !isCacheValid || cachedDailyCategoryData.isEmpty {
            try await fetchAllStatistics(userId: userId, activityCategories: activityCategories)
        }

        return cachedStatistics.values
            .filter { $0.totalPracticeTime > 0 }
            .sorted { (stat1, stat2) in
                switch (stat1.lastPracticeDate, stat2.lastPracticeDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case let (date1?, date2?): return date1 > date2
                }
            }
    }

    private func fetchAllStatistics(userId: String, activityCategories: [String: String] = [:]) async throws {
        let sessionsSnapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("state", isEqualTo: "ended")
            .getDocuments()

        let allActivities = await withTaskGroup(of: (sessionId: String, activities: [SessionActivity]).self) { group in
            for sessionDoc in sessionsSnapshot.documents {
                let sessionId = sessionDoc.documentID
                group.addTask {
                    do {
                        let activitiesSnapshot = try await self.db.collection("users")
                            .document(userId)
                            .collection("sessions")
                            .document(sessionId)
                            .collection("activities")
                            .whereField("isInBetweenTime", isEqualTo: false)
                            .getDocuments()

                        let activities = activitiesSnapshot.documents.compactMap { doc in
                            try? doc.data(as: SessionActivity.self)
                        }
                        return (sessionId, activities)
                    } catch {
                        return (sessionId, [])
                    }
                }
            }

            var allActivities: [(sessionId: String, activity: SessionActivity)] = []
            for await (sessionId, activities) in group {
                for activity in activities {
                    allActivities.append((sessionId, activity))
                }
            }
            return allActivities
        }

        let calendar = Calendar.current
        var statsDict: [String: (name: String, totalTime: TimeInterval, sessions: Set<String>, lastPracticeDate: Date?)] = [:]
        var sessionHistoryDict: [String: [SessionPracticeData]] = [:]
        var dailyCategoryDict: [Date: [String: Int]] = [:]

        var sessionDates: [String: Date] = [:]
        for sessionDoc in sessionsSnapshot.documents {
            if let startTime = sessionDoc.data()["startTime"] as? String,
               let date = Date(iso8601String: startTime) {
                sessionDates[sessionDoc.documentID] = calendar.startOfDay(for: date)
            }
        }

        for (sessionId, activity) in allActivities {
            guard let activityId = activity.activityId else { continue }

            if statsDict[activityId] == nil {
                statsDict[activityId] = (name: activity.activityName, totalTime: 0, sessions: Set<String>(), lastPracticeDate: nil)
            }
            statsDict[activityId]?.totalTime += TimeInterval(activity.duration)
            statsDict[activityId]?.sessions.insert(sessionId)

            if let sessionDate = sessionDates[sessionId] {
                if let currentLast = statsDict[activityId]?.lastPracticeDate {
                    if sessionDate > currentLast { statsDict[activityId]?.lastPracticeDate = sessionDate }
                } else {
                    statsDict[activityId]?.lastPracticeDate = sessionDate
                }

                if sessionHistoryDict[activityId] == nil { sessionHistoryDict[activityId] = [] }
                if let existingIndex = sessionHistoryDict[activityId]?.firstIndex(where: { $0.sessionId == sessionId }) {
                    let oldMinutes = sessionHistoryDict[activityId]?[existingIndex].minutes ?? 0
                    sessionHistoryDict[activityId]?[existingIndex] = SessionPracticeData(date: sessionDate, minutes: oldMinutes + activity.duration / 60, sessionId: sessionId)
                } else {
                    sessionHistoryDict[activityId]?.append(SessionPracticeData(date: sessionDate, minutes: activity.duration / 60, sessionId: sessionId))
                }

                if let category = activityCategories[activityId] {
                    if dailyCategoryDict[sessionDate] == nil { dailyCategoryDict[sessionDate] = [:] }
                    dailyCategoryDict[sessionDate]?[category, default: 0] += activity.duration / 60
                }
            }
        }

        cachedStatistics = [:]
        for (activityId, data) in statsDict {
            cachedStatistics[activityId] = ActivityStatistics(id: activityId, activityId: activityId, activityName: data.name, totalPracticeTime: data.totalTime, sessionCount: data.sessions.count, lastPracticeDate: data.lastPracticeDate)
        }

        cachedSessionHistory = sessionHistoryDict

        var dailyData: [DailyCategoryPracticeData] = []
        for (date, categories) in dailyCategoryDict {
            for (category, minutes) in categories {
                dailyData.append(DailyCategoryPracticeData(date: date, category: category, minutes: minutes))
            }
        }
        cachedDailyCategoryData = dailyData.sorted { $0.date < $1.date }
        cacheTimestamp = Date()
    }

    func getActivitySessionHistory(userId: String, activityId: String) async throws -> [SessionPracticeData] {
        if let cached = cachedSessionHistory[activityId] {
            return cached.sorted { $0.date < $1.date }
        }
        return []
    }

    func getDailyCategoryData(userId: String, activities: [Activity], days: Int = 30) async throws -> [DailyCategoryPracticeData] {
        if activities.isEmpty { return [] }
        if !isCacheValid || cachedDailyCategoryData.isEmpty {
            _ = try await getAllActivityStatistics(userId: userId, activities: activities)
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: today)!
        return cachedDailyCategoryData.filter { $0.date >= cutoffDate }
    }

    func getAverageSessionTimes(userId: String, activities: [Activity], days: Int = 30) async throws -> [AverageSessionTimeData] {
        if activities.isEmpty { return [] }
        if !isCacheValid || cachedSessionHistory.isEmpty {
            _ = try await getAllActivityStatistics(userId: userId, activities: activities)
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: today)!

        var activityNames: [String: String] = [:]
        for activity in activities {
            if let id = activity.id { activityNames[id] = activity.name }
        }

        var averageData: [AverageSessionTimeData] = []
        for (activityId, sessions) in cachedSessionHistory {
            let recentSessions = sessions.filter { $0.date >= cutoffDate }
            guard !recentSessions.isEmpty else { continue }
            guard let activityName = activityNames[activityId] else { continue }
            let totalMinutes = recentSessions.reduce(0) { $0 + $1.minutes }
            let averageMinutes = Double(totalMinutes) / Double(recentSessions.count)
            averageData.append(AverageSessionTimeData(activityName: activityName, averageMinutes: averageMinutes, sessionCount: recentSessions.count))
        }

        return averageData.sorted { $0.averageMinutes > $1.averageMinutes }
    }

    func getWeeklyData(userId: String, activities: [Activity], weeks: Int = 16) async throws -> [WeeklyPracticeData] {
        if activities.isEmpty { return [] }
        if !isCacheValid || cachedDailyCategoryData.isEmpty {
            _ = try await getAllActivityStatistics(userId: userId, activities: activities)
        }

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date())!

        var weeklyDict: [Date: Int] = [:]
        for data in cachedDailyCategoryData where data.date >= cutoffDate {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: data.date)?.start ?? data.date
            weeklyDict[weekStart, default: 0] += data.minutes
        }

        return weeklyDict.map { WeeklyPracticeData(weekStart: $0.key, minutes: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    func invalidateCache() {
        cachedStatistics.removeAll()
        cachedSessionHistory.removeAll()
        cachedDailyCategoryData.removeAll()
        cacheTimestamp = nil
    }
}
