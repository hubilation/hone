//
//  SessionRepository.swift
//  Practice Timer
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

    // Real-time listener methods (return ListenerRegistration for cleanup)
    func listenToSession(userId: String, sessionId: String, completion: @escaping (Session?) -> Void) -> ListenerRegistration
    func listenToSessionActivities(userId: String, sessionId: String, completion: @escaping ([SessionActivity]) -> Void) -> ListenerRegistration
}

// MARK: - Implementation

/// Repository for managing Session data in Firestore
///
/// **Path Structure:**
/// - Sessions: users/{userId}/sessions/{sessionId}
/// - Activities: users/{userId}/sessions/{sessionId}/activities/{activityId}
///
/// **State Management:**
/// Sessions track state for crash recovery and pause/resume:
/// - "setup": Session created, activities being selected
/// - "active": Practice timer running
/// - "paused": Timer paused (pausedAt timestamp set)
/// - "inBetween": Break between activities
/// - "ended": Session completed
///
/// **Crash Recovery:**
/// Use getActiveSession() to find sessions where state != "ended" on app launch.
/// This enables resuming interrupted sessions after crashes or force-quit.
///
/// **Timestamp Updates:**
/// All write operations automatically update updatedAt using Date().toISO8601String()
/// to maintain accurate modification tracking.
///
/// **Listener Memory Management:**
/// CRITICAL - Store returned ListenerRegistration in ViewModel property and call
/// remove() in deinit to prevent memory leaks.
final class SessionRepository: SessionRepositoryProtocol {
    private let db = Firestore.firestore()

    // MARK: - CRUD Operations

    /// Creates a new session in Firestore
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - session: The session to create (id will be generated)
    /// - Returns: The created session with generated id
    /// - Throws: Firestore error if creation fails
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

    /// Updates session state atomically (state, pausedAt, currentActivityIndex)
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - sessionId: The session's document ID
    ///   - updates: Dictionary of fields to update
    /// - Throws: RepositoryError.missingDocumentId if sessionId is nil
    func updateSessionState(userId: String, sessionId: String, updates: [String: Any]) async throws {
        var mutableUpdates = updates
        mutableUpdates["updatedAt"] = Date().toISO8601String()

        try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .updateData(mutableUpdates)
    }

    /// Finds active session for crash recovery
    /// - Parameter userId: The user's unique identifier
    /// - Returns: Session where state != "ended", or nil if none found
    /// - Throws: Firestore error if query fails
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

    /// Marks session as complete
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - sessionId: The session's document ID
    ///   - endTime: ISO 8601 timestamp when session ended
    ///   - totalDuration: Total elapsed seconds
    /// - Throws: Firestore error if update fails
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

    /// Adds activity to session activities subcollection
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - sessionId: The session's document ID
    ///   - activity: The session activity to add
    /// - Throws: Firestore error if creation fails
    func addSessionActivity(userId: String, sessionId: String, activity: SessionActivity) async throws {
        var newActivity = activity
        newActivity.updatedAt = Date().toISO8601String()

        _ = try db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .collection("activities")
            .addDocument(from: newActivity)
    }

    // MARK: - Real-time Listeners

    /// Listens to a specific session in real-time
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - sessionId: The session's document ID
    ///   - completion: Called with updated session whenever data changes
    /// - Returns: ListenerRegistration that MUST be stored and removed in deinit
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

    /// Listens to session activities in real-time
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - sessionId: The session's document ID
    ///   - completion: Called with updated activity list whenever data changes
    /// - Returns: ListenerRegistration that MUST be stored and removed in deinit
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
}
