//
//  SuggestionsServiceTests.swift
//  Hone Tests
//
//  Created by Claude on 4/14/26.
//

import XCTest
@testable import Hone

final class SuggestionsServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeDate(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    private func isoString(daysAgo: Int) -> String {
        ISO8601DateFormatter().string(from: makeDate(daysAgo: daysAgo))
    }

    private func makeActivity(
        name: String,
        lastUsed: String? = nil,
        active: Bool = true,
        completed: Bool = false
    ) -> Activity {
        Activity(
            id: name,
            name: name,
            category: "Test",
            createdAt: isoString(daysAgo: 30),
            updatedAt: isoString(daysAgo: 1),
            active: active,
            completed: completed,
            lastUsed: lastUsed
        )
    }

    private func makeSession(daysAgo: Int, state: String = "ended") -> Session {
        let iso = isoString(daysAgo: daysAgo)
        return Session(
            id: nil,
            startTime: iso,
            endTime: nil,
            totalDuration: 60,
            createdAt: iso,
            updatedAt: iso,
            state: state,
            pausedAt: nil,
            currentActivityIndex: nil
        )
    }

    // MARK: - suggestedActivities Tests

    func testSuggestionsEmpty_whenNoActivities() {
        let result = SuggestionsService.suggestedActivities(activities: [], sessions: [])
        XCTAssertTrue(result.isEmpty, "Should return empty array when no activities provided")
    }

    func testSuggestionsEmpty_whenAllLastUsedNil() {
        // New user: no activity has been practiced yet
        let activities = [
            makeActivity(name: "Piano", lastUsed: nil),
            makeActivity(name: "Guitar", lastUsed: nil),
            makeActivity(name: "Violin", lastUsed: nil)
        ]
        let result = SuggestionsService.suggestedActivities(activities: activities, sessions: [])
        XCTAssertTrue(result.isEmpty, "Should return empty for new user with no lastUsed dates")
    }

    func testSuggestionsRankedByRecency() {
        // Activity practiced 10 days ago should rank higher than one practiced 1 day ago
        let moreOverdue = makeActivity(name: "Piano", lastUsed: isoString(daysAgo: 10))
        let lessOverdue = makeActivity(name: "Guitar", lastUsed: isoString(daysAgo: 1))
        let result = SuggestionsService.suggestedActivities(
            activities: [lessOverdue, moreOverdue],
            sessions: []
        )
        XCTAssertEqual(result.first?.name, "Piano", "More overdue activity should rank first")
    }

    func testSuggestionsRespectsLimit() {
        // 6 activities with history, limit=4 should return exactly 4
        let activities = (1...6).map { i in
            makeActivity(name: "Activity\(i)", lastUsed: isoString(daysAgo: i))
        }
        let result = SuggestionsService.suggestedActivities(activities: activities, sessions: [], limit: 4)
        XCTAssertEqual(result.count, 4, "Should respect the limit parameter")
    }

    func testSuggestionsOnlyActiveActivities() {
        // Archived and completed activities should be excluded
        let active = makeActivity(name: "Active", lastUsed: isoString(daysAgo: 5), active: true)
        let archived = makeActivity(name: "Archived", lastUsed: isoString(daysAgo: 1), active: false)
        let completed = makeActivity(name: "Completed", lastUsed: isoString(daysAgo: 1), completed: true)
        let result = SuggestionsService.suggestedActivities(
            activities: [active, archived, completed],
            sessions: []
        )
        XCTAssertEqual(result.count, 1, "Should only include active, non-completed activities")
        XCTAssertEqual(result.first?.name, "Active")
    }

    // MARK: - currentStreak Tests

    func testStreakZero_whenNoSessions() {
        let streak = SuggestionsService.currentStreak(sessions: [])
        XCTAssertEqual(streak, 0, "Streak should be 0 with no sessions")
    }

    func testStreakContinuous_nDays() {
        // Sessions on 3 consecutive days ending with yesterday -> streak = 3
        let sessions = [
            makeSession(daysAgo: 1), // yesterday
            makeSession(daysAgo: 2), // 2 days ago
            makeSession(daysAgo: 3)  // 3 days ago
        ]
        let streak = SuggestionsService.currentStreak(sessions: sessions)
        XCTAssertEqual(streak, 3, "Should count 3 consecutive days")
    }

    func testStreakResets_afterGap() {
        // Sessions on today (daysAgo: 0) and 3 days ago (daysAgo: 3), gap on days 1 and 2
        let sessions = [
            makeSession(daysAgo: 0), // today
            makeSession(daysAgo: 3)  // 3 days ago, gap on days 1 and 2
        ]
        let streak = SuggestionsService.currentStreak(sessions: sessions)
        XCTAssertEqual(streak, 1, "Streak should reset after gap — only today counts")
    }

    func testStreakPreserved_whenNoSessionToday() {
        // Yesterday had a session, today has none -> streak should still be > 0
        let sessions = [
            makeSession(daysAgo: 1), // yesterday
            makeSession(daysAgo: 2)  // 2 days ago
        ]
        let streak = SuggestionsService.currentStreak(sessions: sessions)
        XCTAssertGreaterThan(streak, 0, "Streak should be preserved when today has no session but yesterday does")
        XCTAssertEqual(streak, 2, "Streak walk from yesterday: 2 consecutive days")
    }

    func testStreakDeduplicates_multipleSameDaySessions() {
        // 3 sessions on the same day (yesterday) should count as 1 day
        let sessions = [
            makeSession(daysAgo: 1),
            makeSession(daysAgo: 1),
            makeSession(daysAgo: 1)
        ]
        let streak = SuggestionsService.currentStreak(sessions: sessions)
        XCTAssertEqual(streak, 1, "Multiple sessions on same day should count as 1 streak day")
    }
}
