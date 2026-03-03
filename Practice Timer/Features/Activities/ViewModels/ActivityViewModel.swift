//
//  ActivityViewModel.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class ActivityViewModel: ObservableObject {
    @Published var activeActivities: [Activity] = []
    @Published var archivedActivities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: ActivityRepositoryProtocol
    private let userId: String

    // CRITICAL: Store listeners to remove in deinit (prevents memory leaks)
    private var activeListener: ListenerRegistration?
    private var archivedListener: ListenerRegistration?
    private var listenersStarted = false

    nonisolated init(userId: String, repository: ActivityRepositoryProtocol = ActivityRepository()) {
        self.userId = userId
        self.repository = repository
        print("DEBUG: ActivityViewModel initialized for userId: \(userId)")
    }

    // MARK: - Listener Management

    /// Attach Firestore listeners for real-time updates
    /// MUST be called in onAppear (not init) to ensure listeners attach when view appears
    func startListening() {
        print("DEBUG: startListening() called - listenersStarted: \(listenersStarted)")

        // Prevent attaching multiple listeners
        guard !listenersStarted else {
            print("DEBUG: Listeners already started, skipping startListening()")
            return
        }

        listenersStarted = true
        print("DEBUG: Attaching Firestore listeners for userId: \(userId)")

        // Listen to active activities (sorted alphabetically by name)
        activeListener = repository.listenToActiveActivities(userId: userId) { [weak self] activities in
            print("DEBUG: Active listener callback fired - received \(activities.count) activities")
            activities.forEach { print("  - \($0.name) (id: \($0.id ?? "nil"))") }
            self?.activeActivities = activities
            print("DEBUG: activeActivities array updated to \(self?.activeActivities.count ?? 0) items")
        }

        // Listen to archived activities (sorted by recently archived)
        archivedListener = repository.listenToArchivedActivities(userId: userId) { [weak self] activities in
            print("DEBUG: Archived listener callback fired - received \(activities.count) activities")
            self?.archivedActivities = activities
        }

        print("DEBUG: Listeners attached successfully")
    }

    deinit {
        // CRITICAL: Remove listeners to prevent memory leaks
        activeListener?.remove()
        archivedListener?.remove()
        print("ActivityViewModel deinitialized")
    }

    // MARK: - CRUD Operations

    /// Create a new activity
    /// - Parameters:
    ///   - name: Activity name (will be trimmed)
    ///   - category: Activity category
    func createActivity(name: String, category: ActivityCategory) async {
        isLoading = true
        defer { isLoading = false }

        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Activity name cannot be empty"
            return
        }

        let activity = Activity(
            id: nil,
            name: trimmedName,
            category: category.rawValue,
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        )

        do {
            _ = try await repository.createActivity(userId: userId, activity: activity)
            // Listener automatically updates activeActivities - no manual update needed
        } catch {
            errorMessage = "Failed to create activity: \(error.localizedDescription)"
        }
    }

    /// Update an existing activity
    /// - Parameters:
    ///   - activity: The activity to update
    ///   - name: New name (will be trimmed)
    ///   - category: New category
    func updateActivity(_ activity: Activity, name: String, category: ActivityCategory) async {
        isLoading = true
        defer { isLoading = false }

        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Activity name cannot be empty"
            return
        }

        let updatedActivity = Activity(
            id: activity.id,
            name: trimmedName,
            category: category.rawValue,
            createdAt: activity.createdAt,
            updatedAt: Date().toISO8601String(),
            archived: activity.archived
        )

        do {
            try await repository.updateActivity(userId: userId, activity: updatedActivity)
            // Listener automatically updates activeActivities - no manual update needed
        } catch {
            errorMessage = "Failed to update activity: \(error.localizedDescription)"
        }
    }

    /// Archive an activity (soft delete - restorable)
    /// - Parameter activity: The activity to archive
    func archiveActivity(_ activity: Activity) async {
        guard let activityId = activity.id else {
            errorMessage = "Cannot archive activity without ID"
            return
        }

        do {
            try await repository.archiveActivity(userId: userId, activityId: activityId)
            // Listener automatically moves activity from active to archived list
        } catch {
            errorMessage = "Failed to archive activity: \(error.localizedDescription)"
        }
    }

    /// Restore an archived activity
    /// - Parameter activity: The activity to restore
    func restoreActivity(_ activity: Activity) async {
        guard let activityId = activity.id else {
            errorMessage = "Cannot restore activity without ID"
            return
        }

        do {
            try await repository.restoreActivity(userId: userId, activityId: activityId)
            // Listener automatically moves activity from archived to active list
        } catch {
            errorMessage = "Failed to restore activity: \(error.localizedDescription)"
        }
    }

    /// Delete an activity permanently (hard delete - not restorable)
    /// - Parameter activity: The activity to delete
    func deleteActivity(_ activity: Activity) async {
        guard let activityId = activity.id else {
            errorMessage = "Cannot delete activity without ID"
            return
        }

        do {
            try await repository.deleteActivity(userId: userId, activityId: activityId)
            // Listener automatically removes activity from list
        } catch {
            errorMessage = "Failed to delete activity: \(error.localizedDescription)"
        }
    }
}
