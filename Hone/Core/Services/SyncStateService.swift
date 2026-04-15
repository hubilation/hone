//
//  SyncStateService.swift
//  Hone
//
//  Created by Claude on 4/15/26.
//

import FirebaseFirestore
import Combine
import Foundation

/// Tracks whether Firestore has local pending writes that have not yet been flushed to the server.
/// Uses a metadata-changes listener on the user document to detect `hasPendingWrites`.
@MainActor
final class SyncStateService: ObservableObject {

    @Published var hasPendingWrites: Bool = false

    private var listener: ListenerRegistration?

    init() {}

    deinit {
        listener?.remove()
    }

    /// Attaches a Firestore metadata listener on the user document.
    /// Call this after sign-in when the userId is known.
    func startListening(userId: String) {
        stopListening()
        guard !userId.isEmpty else { return }

        listener = Firestore.firestore()
            .collection("users")
            .document(userId)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("[SyncStateService] Listener error: \(error.localizedDescription)")
                    return
                }
                let pending = snapshot?.metadata.hasPendingWrites ?? false
                Task { @MainActor [weak self] in
                    self?.hasPendingWrites = pending
                }
            }
    }

    /// Detaches the Firestore listener. Call on sign-out or when user changes.
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
