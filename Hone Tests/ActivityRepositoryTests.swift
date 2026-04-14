//
//  ActivityRepositoryTests.swift
//  Practice Timer Tests
//
//  Created by Claude on 3/3/26.
//

import XCTest
import FirebaseFirestore
@testable import Hone

// MARK: - Mock Repository

class MockActivityRepository: ActivityRepositoryProtocol {
    private var activities: [String: Activity] = [:]
    private var nextId = 1

    func createActivity(userId: String, activity: Activity) async throws -> Activity {
        var newActivity = activity
        newActivity.id = "mock-id-\(nextId)"
        newActivity.updatedAt = Date().toISO8601String()
        nextId += 1
        activities[newActivity.id!] = newActivity
        return newActivity
    }

    func updateActivity(userId: String, activity: Activity) async throws {
        guard let activityId = activity.id else {
            throw RepositoryError.missingDocumentId
        }
        var updatedActivity = activity
        updatedActivity.updatedAt = Date().toISO8601String()
        activities[activityId] = updatedActivity
    }

    func deleteActivity(userId: String, activityId: String) async throws {
        activities.removeValue(forKey: activityId)
    }

    func archiveActivity(userId: String, activityId: String) async throws {
        guard var activity = activities[activityId] else {
            throw RepositoryError.documentNotFound
        }
        activity.archived = true
        activity.updatedAt = Date().toISO8601String()
        activities[activityId] = activity
    }

    func restoreActivity(userId: String, activityId: String) async throws {
        guard var activity = activities[activityId] else {
            throw RepositoryError.documentNotFound
        }
        activity.archived = false
        activity.updatedAt = Date().toISO8601String()
        activities[activityId] = activity
    }

    func listenToActiveActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        let activeActivities = activities.values
            .filter { !$0.archived }
            .sorted { $0.name < $1.name }
        completion(activeActivities)
        return MockListenerRegistration()
    }

    func listenToArchivedActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        let archivedActivities = activities.values
            .filter { $0.archived }
            .sorted { $0.updatedAt > $1.updatedAt }
        completion(archivedActivities)
        return MockListenerRegistration()
    }

    // Helper for testing
    func getActivity(id: String) -> Activity? {
        return activities[id]
    }
}

// Mock ListenerRegistration
class MockListenerRegistration: ListenerRegistration {
    func remove() {
        // No-op for mock
    }
}

// MARK: - Test Cases

class ActivityRepositoryTests: XCTestCase {
    var repository: MockActivityRepository!
    let testUserId = "test-user-123"

    override func setUp() {
        super.setUp()
        repository = MockActivityRepository()
    }

    override func tearDown() {
        repository = nil
        super.tearDown()
    }

    // MARK: - Create Tests

    func testCreateActivity_generatesId() async throws {
        // Given
        let activity = Activity(
            id: nil,
            name: "Piano Practice",
            category: "Piano",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        )

        // When
        let createdActivity = try await repository.createActivity(userId: testUserId, activity: activity)

        // Then
        XCTAssertNotNil(createdActivity.id, "Created activity should have an ID")
        XCTAssertEqual(createdActivity.name, "Piano Practice")
        XCTAssertEqual(createdActivity.category, "Piano")
        XCTAssertFalse(createdActivity.archived)
    }

    // MARK: - Update Tests

    func testUpdateActivity_mergesChanges() async throws {
        // Given
        let activity = Activity(
            id: nil,
            name: "Guitar Practice",
            category: "Guitar",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        )
        let created = try await repository.createActivity(userId: testUserId, activity: activity)

        // When
        var updated = created
        updated.name = "Guitar Advanced Practice"
        try await repository.updateActivity(userId: testUserId, activity: updated)

        // Then
        let retrieved = repository.getActivity(id: created.id!)
        XCTAssertEqual(retrieved?.name, "Guitar Advanced Practice")
        XCTAssertEqual(retrieved?.id, created.id, "ID should remain the same")
    }

    func testUpdateActivity_throwsWhenIdMissing() async throws {
        // Given
        let activity = Activity(
            id: nil,
            name: "Test",
            category: "Test",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        )

        // When/Then
        do {
            try await repository.updateActivity(userId: testUserId, activity: activity)
            XCTFail("Should have thrown missingDocumentId error")
        } catch RepositoryError.missingDocumentId {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Archive Tests

    func testArchiveActivity_setsFlag() async throws {
        // Given
        let activity = Activity(
            id: nil,
            name: "Drums Practice",
            category: "Drums",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        )
        let created = try await repository.createActivity(userId: testUserId, activity: activity)
        let originalUpdatedAt = created.updatedAt

        // When
        try await repository.archiveActivity(userId: testUserId, activityId: created.id!)

        // Then
        let archived = repository.getActivity(id: created.id!)
        XCTAssertTrue(archived?.archived ?? false, "Activity should be archived")
        XCTAssertNotEqual(archived?.updatedAt, originalUpdatedAt, "updatedAt should be changed")
    }

    // MARK: - Restore Tests

    func testRestoreActivity_clearsFlag() async throws {
        // Given
        let activity = Activity(
            id: nil,
            name: "Violin Practice",
            category: "Violin",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: true
        )
        let created = try await repository.createActivity(userId: testUserId, activity: activity)
        let originalUpdatedAt = created.updatedAt

        // When
        try await repository.restoreActivity(userId: testUserId, activityId: created.id!)

        // Then
        let restored = repository.getActivity(id: created.id!)
        XCTAssertFalse(restored?.archived ?? true, "Activity should not be archived")
        XCTAssertNotEqual(restored?.updatedAt, originalUpdatedAt, "updatedAt should be changed")
    }

    // MARK: - Delete Tests

    func testDeleteActivity_removesDocument() async throws {
        // Given
        let activity = Activity(
            id: nil,
            name: "Flute Practice",
            category: "Flute",
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        )
        let created = try await repository.createActivity(userId: testUserId, activity: activity)

        // When
        try await repository.deleteActivity(userId: testUserId, activityId: created.id!)

        // Then
        let deleted = repository.getActivity(id: created.id!)
        XCTAssertNil(deleted, "Activity should be deleted")
    }

    // MARK: - Listener Tests

    func testListenActiveActivities_excludesArchived() async throws {
        // Given
        let active1 = Activity(id: nil, name: "Active 1", category: "Test", createdAt: Date().toISO8601String(), updatedAt: Date().toISO8601String(), archived: false)
        let active2 = Activity(id: nil, name: "Active 2", category: "Test", createdAt: Date().toISO8601String(), updatedAt: Date().toISO8601String(), archived: false)
        let archived = Activity(id: nil, name: "Archived", category: "Test", createdAt: Date().toISO8601String(), updatedAt: Date().toISO8601String(), archived: true)

        _ = try await repository.createActivity(userId: testUserId, activity: active1)
        _ = try await repository.createActivity(userId: testUserId, activity: active2)
        _ = try await repository.createActivity(userId: testUserId, activity: archived)

        // When
        var receivedActivities: [Activity] = []
        let expectation = XCTestExpectation(description: "Listener callback")

        _ = repository.listenToActiveActivities(userId: testUserId) { activities in
            receivedActivities = activities
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(receivedActivities.count, 2, "Should only include active activities")
        XCTAssertTrue(receivedActivities.allSatisfy { !$0.archived }, "All activities should be non-archived")
        XCTAssertEqual(receivedActivities[0].name, "Active 1", "Should be sorted by name")
        XCTAssertEqual(receivedActivities[1].name, "Active 2", "Should be sorted by name")
    }

    func testListenArchivedActivities_includesOnlyArchived() async throws {
        // Given
        let active = Activity(id: nil, name: "Active", category: "Test", createdAt: Date().toISO8601String(), updatedAt: Date().toISO8601String(), archived: false)
        let archived1 = Activity(id: nil, name: "Archived 1", category: "Test", createdAt: Date().toISO8601String(), updatedAt: "2026-03-01T10:00:00Z", archived: true)
        let archived2 = Activity(id: nil, name: "Archived 2", category: "Test", createdAt: Date().toISO8601String(), updatedAt: "2026-03-02T10:00:00Z", archived: true)

        _ = try await repository.createActivity(userId: testUserId, activity: active)
        _ = try await repository.createActivity(userId: testUserId, activity: archived1)
        _ = try await repository.createActivity(userId: testUserId, activity: archived2)

        // When
        var receivedActivities: [Activity] = []
        let expectation = XCTestExpectation(description: "Listener callback")

        _ = repository.listenToArchivedActivities(userId: testUserId) { activities in
            receivedActivities = activities
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(receivedActivities.count, 2, "Should only include archived activities")
        XCTAssertTrue(receivedActivities.allSatisfy { $0.archived }, "All activities should be archived")
        XCTAssertEqual(receivedActivities[0].name, "Archived 2", "Should be sorted by updatedAt descending")
        XCTAssertEqual(receivedActivities[1].name, "Archived 1", "Should be sorted by updatedAt descending")
    }
}
