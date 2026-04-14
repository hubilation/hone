//
//  ActivityViewModel.swift
//  Hone
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

    private var activeListener: ListenerRegistration?
    private var archivedListener: ListenerRegistration?
    private var listenersStarted = false

    nonisolated init(userId: String, repository: ActivityRepositoryProtocol = ActivityRepository()) {
        self.userId = userId
        self.repository = repository
    }

    func startListening() {
        guard !listenersStarted else { return }
        listenersStarted = true

        activeListener = repository.listenToActiveActivities(userId: userId) { [weak self] activities in
            Task { @MainActor in
                self?.activeActivities = activities
            }
        }

        archivedListener = repository.listenToArchivedActivities(userId: userId) { [weak self] activities in
            Task { @MainActor in
                self?.archivedActivities = activities
            }
        }
    }

    deinit {
        activeListener?.remove()
        archivedListener?.remove()
    }

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
            active: true
        )

        do {
            _ = try await repository.createActivity(userId: userId, activity: activity)
        } catch {
            errorMessage = "Failed to create activity: \(error.localizedDescription)"
        }
    }

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
            active: activity.active
        )

        do {
            try await repository.updateActivity(userId: userId, activity: updatedActivity)
        } catch {
            errorMessage = "Failed to update activity: \(error.localizedDescription)"
        }
    }

    func archiveActivity(_ activity: Activity) async {
        guard let activityId = activity.id else { return }
        do {
            try await repository.archiveActivity(userId: userId, activityId: activityId)
        } catch {
            errorMessage = "Failed to archive activity: \(error.localizedDescription)"
        }
    }

    func restoreActivity(_ activity: Activity) async {
        guard let activityId = activity.id else { return }
        do {
            try await repository.restoreActivity(userId: userId, activityId: activityId)
        } catch {
            errorMessage = "Failed to restore activity: \(error.localizedDescription)"
        }
    }

    func deleteActivity(_ activity: Activity) async {
        guard let activityId = activity.id else { return }
        do {
            try await repository.deleteActivity(userId: userId, activityId: activityId)
        } catch {
            errorMessage = "Failed to delete activity: \(error.localizedDescription)"
        }
    }
}
