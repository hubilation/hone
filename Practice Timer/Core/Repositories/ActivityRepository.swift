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
///
/// **FIRESTORE INDEX REQUIREMENTS:**
///
/// This repository requires composite indexes for efficient querying. Firestore cannot
/// efficiently execute queries that combine WHERE filters with ORDER BY on different fields
/// without a composite index.
///
/// **Required Indexes:**
///
/// 1. **Active Activities Query** (listenToActiveActivities)
///    - Collection: `users/{userId}/activities`
///    - Fields: `archived` (ascending), `name` (ascending)
///    - Query: `.whereField("archived", isEqualTo: false).order(by: "name")`
///    - Why needed: Sorting active activities alphabetically
///
/// 2. **Archived Activities Query** (listenToArchivedActivities)
///    - Collection: `users/{userId}/activities`
///    - Fields: `archived` (ascending), `updatedAt` (descending)
///    - Query: `.whereField("archived", isEqualTo: true).order(by: "updatedAt", descending: true)`
///    - Why needed: Sorting archived activities by most recently updated
///
/// **Index Deployment:**
///
/// Indexes are defined in `firestore.indexes.json` at project root.
/// Deploy indexes using Firebase CLI:
/// ```bash
/// firebase deploy --only firestore:indexes
/// ```
///
/// **What Happens Without Indexes:**
///
/// If indexes are missing, queries will fail at runtime with error:
/// "The query requires an index. You can create it here: [Firebase Console URL]"
///
/// Firestore will provide a direct link to create the index in the console, but it's
/// better to define indexes in firestore.indexes.json for:
/// - Version control tracking
/// - Reproducible deployments across environments
/// - Automatic deployment in CI/CD pipelines
///
/// **Testing Index Requirements:**
///
/// 1. **Local Emulator:** Firestore emulator auto-creates indexes, so missing indexes
///    won't be caught during local development. Always test against production Firestore
///    before releasing.
///
/// 2. **Production Testing:** Create test account, run app, verify all queries execute
///    without "requires an index" errors.
///
/// 3. **CI/CD:** Include `firebase deploy --only firestore:indexes` in deployment scripts
///    to ensure indexes are always deployed before app releases.
///
/// See `FIREBASE_SETUP.md` for complete Firebase setup and deployment instructions.
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

        // COMPOSITE INDEX REQUIRED: archived (ascending) + name (ascending)
        // This query filters by archived=false AND sorts by name, which requires
        // a composite index. Without it, query fails with "requires an index" error.
        // Index defined in firestore.indexes.json, deployed via: firebase deploy --only firestore:indexes
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

        // COMPOSITE INDEX REQUIRED: archived (ascending) + updatedAt (descending)
        // This query filters by archived=true AND sorts by updatedAt descending, which requires
        // a composite index. Without it, query fails with "requires an index" error.
        // Index defined in firestore.indexes.json, deployed via: firebase deploy --only firestore:indexes
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
