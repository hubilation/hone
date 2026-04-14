//
//  ActivityRepository.swift
//  Hone
//
//  Created by Claude on 3/3/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Protocol

protocol ActivityRepositoryProtocol {
    func createActivity(userId: String, activity: Activity) async throws -> Activity
    func updateActivity(userId: String, activity: Activity) async throws
    func deleteActivity(userId: String, activityId: String) async throws
    func archiveActivity(userId: String, activityId: String) async throws
    func restoreActivity(userId: String, activityId: String) async throws
    func addPracticeNote(userId: String, activityId: String, note: PracticeNote) async throws
    func updateActivityStats(userId: String, activityId: String, additionalTime: Int, lastUsed: String) async throws
    func listenToActiveActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration
    func listenToArchivedActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration
    func getActivity(userId: String, activityId: String) async throws -> Activity?
}

// MARK: - Implementation

final class ActivityRepository: ActivityRepositoryProtocol {
    private let db = Firestore.firestore()

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

    func deleteActivity(userId: String, activityId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .delete()
    }

    func archiveActivity(userId: String, activityId: String) async throws {
        let updates: [String: Any] = [
            "active": false,
            "archived": true,
            "updatedAt": Date().toISO8601String()
        ]

        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .updateData(updates)
    }

    func restoreActivity(userId: String, activityId: String) async throws {
        let updates: [String: Any] = [
            "active": true,
            "archived": false,
            "updatedAt": Date().toISO8601String()
        ]

        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .updateData(updates)
    }

    func addPracticeNote(userId: String, activityId: String, note: PracticeNote) async throws {
        let noteData: [String: Any] = [
            "notes": note.notes,
            "sessionId": note.sessionId,
            "timestamp": note.timestamp,
            "timeSpent": note.timeSpent
        ]

        let updates: [String: Any] = [
            "practiceNotes": FieldValue.arrayUnion([noteData]),
            "updatedAt": Date().toISO8601String(),
            "lastUsed": Date().toISO8601String()
        ]

        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .updateData(updates)
    }

    func updateActivityStats(userId: String, activityId: String, additionalTime: Int, lastUsed: String) async throws {
        let updates: [String: Any] = [
            "totalPracticeTime": FieldValue.increment(Int64(additionalTime)),
            "lastUsed": lastUsed,
            "updatedAt": Date().toISO8601String()
        ]

        try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .updateData(updates)
    }

    func getActivity(userId: String, activityId: String) async throws -> Activity? {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId)
            .getDocument()

        guard snapshot.exists else {
            return nil
        }

        var activity = try snapshot.data(as: Activity.self)
        activity.id = snapshot.documentID
        return activity
    }

    func listenToActiveActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        return db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("active", isEqualTo: true)
            .order(by: "name")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("ERROR in active activities listener: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let activities = documents.compactMap { doc -> Activity? in
                    do {
                        var activity = try doc.data(as: Activity.self)
                        activity.id = doc.documentID
                        return activity
                    } catch {
                        print("ERROR decoding document \(doc.documentID): \(error)")
                        return nil
                    }
                }
                completion(activities)
            }
    }

    func listenToArchivedActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        return db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("active", isEqualTo: false)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("ERROR in archived activities listener: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let activities = documents.compactMap { doc -> Activity? in
                    do {
                        var activity = try doc.data(as: Activity.self)
                        activity.id = doc.documentID
                        return activity
                    } catch {
                        print("ERROR decoding archived document \(doc.documentID): \(error)")
                        return nil
                    }
                }
                completion(activities)
            }
    }
}
