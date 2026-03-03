//
//  ActivityRepository.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Protocol

/// Protocol defining Activity repository operations
///
/// CRITICAL: Listener methods return ListenerRegistration for proper memory management.
/// ViewModels MUST store the returned ListenerRegistration and call remove() in deinit
/// to prevent memory leaks when views are deallocated.
protocol ActivityRepositoryProtocol {
    // CRUD operations (async/await)
    func createActivity(userId: String, activity: Activity) async throws -> Activity
    func updateActivity(userId: String, activity: Activity) async throws
    func deleteActivity(userId: String, activityId: String) async throws
    func archiveActivity(userId: String, activityId: String) async throws
    func restoreActivity(userId: String, activityId: String) async throws

    // Real-time listener methods (return ListenerRegistration for cleanup)
    func listenToActiveActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration
    func listenToArchivedActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration
}

// MARK: - Implementation

/// Repository for managing Activity data in Firestore
///
/// **Path Structure:** Uses subcollection path users/{userId}/activities per Phase 1 data model
/// to avoid 1MB document limit. Each user's activities are stored in their own subcollection.
///
/// **Archive vs Delete:**
/// - Archive sets archived=true (soft delete, restorable via restoreActivity)
/// - Delete removes document permanently (hard delete, not restorable)
///
/// **Timestamp Updates:** Always update updatedAt when modifying activity to maintain
/// correct sort order in archived list (most recently updated appears first).
///
/// **Listener Memory Management:** CRITICAL - Store returned ListenerRegistration in
/// ViewModel property and call remove() in deinit to prevent memory leaks.
final class ActivityRepository: ActivityRepositoryProtocol {
    private let db = Firestore.firestore()

    // MARK: - CRUD Operations

    /// Creates a new activity in Firestore
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - activity: The activity to create (id will be generated)
    /// - Returns: The created activity with generated id
    /// - Throws: RepositoryError if creation fails
    func createActivity(userId: String, activity: Activity) async throws -> Activity {
        var newActivity = activity
        newActivity.updatedAt = Date().toISO8601String()

        let docRef = try db.collection("users")
            .document(userId)
            .collection("activities")
            .addDocument(from: newActivity)

        newActivity.id = docRef.documentID
        return newActivity
    }

    /// Updates an existing activity in Firestore
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - activity: The activity to update (must have valid id)
    /// - Throws: RepositoryError.missingDocumentId if activity.id is nil
    func updateActivity(userId: String, activity: Activity) async throws {
        guard let activityId = activity.id else {
            throw RepositoryError.missingDocumentId
        }

        var updatedActivity = activity
        updatedActivity.updatedAt = Date().toISO8601String()

        try db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .setData(from: updatedActivity, merge: true)
    }

    /// Deletes an activity permanently from Firestore
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - activityId: The activity's document ID
    /// - Throws: Firestore error if deletion fails
    func deleteActivity(userId: String, activityId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .delete()
    }

    /// Archives an activity (soft delete - restorable)
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - activityId: The activity's document ID
    /// - Throws: Firestore error if update fails
    func archiveActivity(userId: String, activityId: String) async throws {
        let updates: [String: Any] = [
            "archived": true,
            "updatedAt": Date().toISO8601String()
        ]

        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .updateData(updates)
    }

    /// Restores an archived activity (un-archives)
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - activityId: The activity's document ID
    /// - Throws: Firestore error if update fails
    func restoreActivity(userId: String, activityId: String) async throws {
        let updates: [String: Any] = [
            "archived": false,
            "updatedAt": Date().toISO8601String()
        ]

        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .updateData(updates)
    }

    // MARK: - Real-time Listeners

    /// Listens to active (non-archived) activities in real-time
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - completion: Called with updated activity list whenever data changes
    /// - Returns: ListenerRegistration that MUST be stored and removed in deinit
    func listenToActiveActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        print("DEBUG: Repository creating active activities listener for userId: \(userId)")
        return db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("archived", isEqualTo: false)
            .order(by: "name")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("DEBUG: ERROR in active activities listener: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("DEBUG: Active activities snapshot has no documents")
                    completion([])
                    return
                }

                print("DEBUG: Active activities snapshot received \(documents.count) documents")
                let activities = documents.compactMap { doc -> Activity? in
                    do {
                        let activity = try doc.data(as: Activity.self)
                        print("  - Successfully decoded: \(activity.name)")
                        return activity
                    } catch {
                        print("  - ERROR decoding document \(doc.documentID): \(error)")
                        return nil
                    }
                }
                print("DEBUG: Repository calling completion with \(activities.count) activities")
                completion(activities)
            }
    }

    /// Listens to archived activities in real-time
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - completion: Called with updated activity list whenever data changes
    /// - Returns: ListenerRegistration that MUST be stored and removed in deinit
    func listenToArchivedActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        print("DEBUG: Repository creating archived activities listener for userId: \(userId)")
        return db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("archived", isEqualTo: true)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("DEBUG: ERROR in archived activities listener: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("DEBUG: Archived activities snapshot has no documents")
                    completion([])
                    return
                }

                print("DEBUG: Archived activities snapshot received \(documents.count) documents")
                let activities = documents.compactMap { doc -> Activity? in
                    do {
                        let activity = try doc.data(as: Activity.self)
                        return activity
                    } catch {
                        print("  - ERROR decoding archived document \(doc.documentID): \(error)")
                        return nil
                    }
                }
                completion(activities)
            }
    }
}
