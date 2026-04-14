//
//  SessionRepository.swift
//  Hone
//
//  Created by Claude on 3/3/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Protocol

/// Protocol defining Session repository operations
///
/// Memory Management:
/// Listeners return ListenerRegistration which MUST be stored by caller
/// and removed in deinit to prevent memory leaks:
///
///     private var sessionListener: ListenerRegistration?
///     func startListening() {
///         sessionListener = repository.listenToSession(...) { ... }
///     }
///     deinit {
///         sessionListener?.remove()
///     }
protocol SessionRepositoryProtocol {
    // CRUD operations (async/await)
    func createSession(userId: String, session: Session) async throws -> Session
    func updateSessionState(userId: String, sessionId: String, updates: [String: Any]) async throws
    func getActiveSession(userId: String) async throws -> Session?
    func endSession(userId: String, sessionId: String, endTime: String, totalDuration: Int) async throws
    func addSessionActivity(userId: String, sessionId: String, activity: SessionActivity) async throws

    /// Get historical notes for an activity from previous sessions
    func getHistoricalNotes(userId: String, activityId: String, limit: Int) async throws -> [SessionActivity]

    // Real-time listener methods (return ListenerRegistration for cleanup)
    func listenToSession(userId: String, sessionId: String, completion: @escaping (Session?) -> Void) -> ListenerRegistration
    func listenToSessionActivities(userId: String, sessionId: String, completion: @escaping ([SessionActivity]) -> Void) -> ListenerRegistration

    /// Get ended sessions ordered by most recent first
    func getSessions(userId: String, limit: Int) async throws -> [Session]

    /// Listen to ended sessions with real-time updates
    func listenToSessions(userId: String, limit: Int, completion: @escaping ([Session]) -> Void) -> ListenerRegistration

    /// Get all activities for a specific session
    func getSessionActivities(userId: String, sessionId: String) async throws -> [SessionActivity]

    /// Delete session and all associated activities
    func deleteSession(userId: String, sessionId: String) async throws
}

// MARK: - Implementation

final class SessionRepository: SessionRepositoryProtocol {
    private let db = Firestore.firestore()

    func createSession(userId: String, session: Session) async throws -> Session {
        var newSession = session
        newSession.updatedAt = Date().toISO8601String()

        let docRef = try db.collection("users")
            .document(userId)
            .collection("sessions")
            .addDocument(from: newSession)

        newSession.id = docRef.documentID
        return newSession
    }

    func updateSessionState(userId: String, sessionId: String, updates: [String: Any]) async throws {
        var mutableUpdates = updates
        mutableUpdates["updatedAt"] = Date().toISO8601String()

        try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .updateData(mutableUpdates)
    }

    func getActiveSession(userId: String) async throws -> Session? {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("state", isNotEqualTo: "ended")
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        return try document.data(as: Session.self)
    }

    func endSession(userId: String, sessionId: String, endTime: String, totalDuration: Int) async throws {
        let updates: [String: Any] = [
            "state": "ended",
            "endTime": endTime,
            "totalDuration": totalDuration,
            "updatedAt": Date().toISO8601String()
        ]

        try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .updateData(updates)
    }

    func addSessionActivity(userId: String, sessionId: String, activity: SessionActivity) async throws {
        var newActivity = activity
        newActivity.updatedAt = Date().toISO8601String()

        let docId = activity.createdAt.replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: ".", with: "-")

        try db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .collection("activities")
            .document(docId)
            .setData(from: newActivity, merge: false)
    }

    func listenToSession(userId: String, sessionId: String, completion: @escaping (Session?) -> Void) -> ListenerRegistration {
        return db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("ERROR in session listener: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                guard let snapshot = snapshot, snapshot.exists else {
                    completion(nil)
                    return
                }

                do {
                    let session = try snapshot.data(as: Session.self)
                    completion(session)
                } catch {
                    print("ERROR decoding session: \(error)")
                    completion(nil)
                }
            }
    }

    func listenToSessionActivities(userId: String, sessionId: String, completion: @escaping ([SessionActivity]) -> Void) -> ListenerRegistration {
        return db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .collection("activities")
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("ERROR in session activities listener: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let activities = documents.compactMap { doc -> SessionActivity? in
                    do {
                        return try doc.data(as: SessionActivity.self)
                    } catch {
                        print("ERROR decoding session activity \(doc.documentID): \(error)")
                        return nil
                    }
                }
                completion(activities)
            }
    }

    func getHistoricalNotes(userId: String, activityId: String, limit: Int = 10) async throws -> [SessionActivity] {
        let snapshot = try await db.collectionGroup("activities")
            .whereField("activityId", isEqualTo: activityId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        let activities = snapshot.documents.compactMap { doc -> SessionActivity? in
            do {
                let activity = try doc.data(as: SessionActivity.self)
                guard let notes = activity.notes,
                      !notes.isEmpty,
                      !activity.isInBetweenTime else {
                    return nil
                }
                return activity
            } catch {
                print("Error decoding SessionActivity: \(error)")
                return nil
            }
        }

        return activities
    }

    func getSessions(userId: String, limit: Int = 100) async throws -> [Session] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("state", isEqualTo: "ended")
            .order(by: "startTime", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> Session? in
            do {
                return try doc.data(as: Session.self)
            } catch {
                print("ERROR decoding session \(doc.documentID): \(error)")
                return nil
            }
        }
    }

    func listenToSessions(userId: String, limit: Int = 100, completion: @escaping ([Session]) -> Void) -> ListenerRegistration {
        return db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("state", isEqualTo: "ended")
            .order(by: "startTime", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("ERROR in sessions listener: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let sessions = documents.compactMap { doc -> Session? in
                    do {
                        return try doc.data(as: Session.self)
                    } catch {
                        print("ERROR decoding session \(doc.documentID): \(error)")
                        return nil
                    }
                }
                completion(sessions)
            }
    }

    func getSessionActivities(userId: String, sessionId: String) async throws -> [SessionActivity] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .collection("activities")
            .order(by: "createdAt")
            .getDocuments()

        return snapshot.documents.compactMap { doc -> SessionActivity? in
            do {
                return try doc.data(as: SessionActivity.self)
            } catch {
                print("ERROR decoding activity \(doc.documentID): \(error)")
                return nil
            }
        }
    }

    func deleteSession(userId: String, sessionId: String) async throws {
        let sessionRef = db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)

        let activitiesSnapshot = try await sessionRef
            .collection("activities")
            .getDocuments()

        let batch = db.batch()
        for doc in activitiesSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        batch.deleteDocument(sessionRef)
        try await batch.commit()
    }
}
