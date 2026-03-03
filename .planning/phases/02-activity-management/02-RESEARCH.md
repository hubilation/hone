# Phase 2: Activity Management - Research

**Researched:** 2026-03-02
**Domain:** SwiftUI CRUD operations with Firestore real-time listeners and offline-first sync
**Confidence:** HIGH

## Summary

Phase 2 establishes activity management using Firestore CRUD operations with real-time listeners for cross-device sync. The phase implements create, read, update, delete, and archive operations using the repository pattern established in Phase 1, extending it with real-time snapshot listeners that enable automatic sync between web and iOS when online.

The research confirms Firestore's offline persistence is enabled by default on iOS with a 100MB cache, handling automatic sync when connection is restored without additional configuration. Critical patterns include proper listener cleanup using ListenerRegistration.remove() in deinit to prevent memory leaks, SwiftUI swipeActions for archive/restore interactions, and Firestore where queries to filter active vs. archived activities. Activity statistics use Firestore aggregation queries (sum, count, average) to calculate total practice time per activity without downloading all session documents, reducing cost and latency.

**Primary recommendation:** Use ActivityRepository with async/await CRUD methods plus real-time listener methods that return ListenerRegistration, implement SwiftUI List with swipeActions for archive/restore, use Firestore where(field:isEqualTo:) queries to filter archived status, store listeners in ViewModel properties and remove in deinit with [weak self] closures to prevent memory leaks, and leverage Firestore aggregation queries for statistics computation server-side.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ACT-01 | User can create new practice activity with name | Firestore addDocument(data:) or setData(from:) with Codable Activity model in repository pattern |
| ACT-02 | User can assign category to activity (instrument, piece, technique) | Swift enum conforming to CaseIterable, Identifiable, Hashable with SwiftUI Picker for category selection |
| ACT-03 | User can edit activity name and category | Firestore updateData(_:) or setData(from:merge:true) for partial updates, sheet presentation with form validation |
| ACT-04 | User can delete activity | Firestore document.delete() with SwiftUI onDelete modifier or swipeActions trailing button |
| ACT-05 | User can archive activity (soft delete) | Firestore updateData(["archived": true]) toggling boolean field, keeps data but filters from active list |
| ACT-06 | User can restore archived activity | Firestore updateData(["archived": false]) toggling field back, swipeActions on archived list |
| ACT-07 | User can view list of all active activities | Firestore whereField("archived", isEqualTo: false) query with real-time addSnapshotListener |
| ACT-08 | User can view list of archived activities | Firestore whereField("archived", isEqualTo: true) query with separate listener for archived view |
| ACT-09 | Activity changes sync in real-time across web and iOS when online | Firestore addSnapshotListener provides real-time updates, offline persistence syncs automatically when online |
| POST-05 | User can view activity statistics (total time per activity) | Firestore aggregation queries using sum() on session duration grouped by activityId, calculated server-side |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FirebaseFirestore | 12.10.0+ | Real-time database with CRUD and listeners | Native iOS SDK with automatic offline sync, real-time listeners, query indexing, and cross-platform compatibility with web app |
| SwiftUI List | iOS 16+ | Activity list UI with built-in edit/delete | Native declarative list component with swipeActions, onDelete, ForEach, and automatic diffing for smooth updates |
| Combine | iOS 16+ | ObservableObject @Published for reactive updates | Built-in framework for publishing Firestore listener updates to SwiftUI views, automatic view invalidation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Firestore Aggregation Queries | Firestore 10.7.0+ (iOS SDK) | Server-side sum/count/average calculations | Required for activity statistics (POST-05) - calculates total practice time per activity without downloading all sessions |
| FirestoreQuery Property Wrapper | Firestore 10.0+ | SwiftUI-native listener binding | Optional alternative to manual listeners - simpler syntax but less control over lifecycle |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Real-time listeners | Periodic polling with getDocuments() | Listeners provide instant updates with lower latency, polling wastes reads and battery, real-time essential for cross-device sync requirement |
| Soft delete (archive flag) | Hard delete with separate archived subcollection | Soft delete simpler (single toggle, easy restore), hard delete better for data isolation but requires moving documents between collections |
| Firestore aggregation queries | Download all sessions and calculate in-app | Aggregation saves 90%+ of reads and bandwidth for statistics, critical at scale (1000+ sessions), in-app calculation only viable for demo data |
| SwiftUI swipeActions | Custom gesture recognizers | swipeActions native iOS pattern users expect, handles edge cases (bounce, cancellation), custom gestures require UIKit interop and extensive testing |

**Installation:**
```bash
# Already installed in Phase 1 - no additional packages needed
# Aggregation queries available in FirebaseFirestore 10.7.0+ (bundled in Firebase iOS SDK 12.10.0+)
```

## Architecture Patterns

### Recommended Project Structure
```
PracticeTimer/
├── Features/
│   ├── Activities/
│   │   ├── Views/
│   │   │   ├── ActivityListView.swift          # Main active activities list
│   │   │   ├── ArchivedActivityListView.swift  # Archived activities list
│   │   │   ├── ActivityFormView.swift          # Create/edit form (sheet)
│   │   │   └── ActivityRowView.swift           # Individual row component
│   │   ├── ViewModels/
│   │   │   └── ActivityViewModel.swift         # @MainActor ObservableObject with listener
│   │   └── Models/
│   │       └── ActivityCategory.swift          # Enum: instrument, piece, technique, etc.
├── Core/
│   ├── Repositories/
│   │   └── ActivityRepository.swift            # CRUD + listener methods
│   └── Models/
│       └── Activity.swift                       # Already exists from Phase 1
```

### Pattern 1: Repository with Real-Time Listener Methods
**What:** Extend repository pattern to include methods that return ListenerRegistration for real-time sync
**When to use:** All list views that need live updates (ACT-07, ACT-08, ACT-09)
**Example:**
```swift
// Source: Firebase iOS SDK official patterns + Phase 1 established repository pattern

import FirebaseFirestore
import Foundation

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

class ActivityRepository: ActivityRepositoryProtocol {
    private let db = Firestore.firestore()

    func createActivity(userId: String, activity: Activity) async throws -> Activity {
        let ref = try db.collection("users").document(userId)
            .collection("activities")
            .addDocument(from: activity)

        var createdActivity = activity
        createdActivity.id = ref.documentID
        return createdActivity
    }

    func updateActivity(userId: String, activity: Activity) async throws {
        guard let activityId = activity.id else {
            throw RepositoryError.missingDocumentId
        }

        try db.collection("users").document(userId)
            .collection("activities").document(activityId)
            .setData(from: activity, merge: true)
    }

    func archiveActivity(userId: String, activityId: String) async throws {
        try await db.collection("users").document(userId)
            .collection("activities").document(activityId)
            .updateData([
                "archived": true,
                "updatedAt": Date().toISO8601String()
            ])
    }

    func restoreActivity(userId: String, activityId: String) async throws {
        try await db.collection("users").document(userId)
            .collection("activities").document(activityId)
            .updateData([
                "archived": false,
                "updatedAt": Date().toISO8601String()
            ])
    }

    func deleteActivity(userId: String, activityId: String) async throws {
        try await db.collection("users").document(userId)
            .collection("activities").document(activityId)
            .delete()
    }

    // Real-time listener - CRITICAL: Returns ListenerRegistration for cleanup
    func listenToActiveActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        return db.collection("users").document(userId)
            .collection("activities")
            .whereField("archived", isEqualTo: false)
            .order(by: "name")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let activities = documents.compactMap { doc -> Activity? in
                    try? doc.data(as: Activity.self)
                }
                completion(activities)
            }
    }

    func listenToArchivedActivities(userId: String, completion: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        return db.collection("users").document(userId)
            .collection("activities")
            .whereField("archived", isEqualTo: true)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let activities = documents.compactMap { doc -> Activity? in
                    try? doc.data(as: Activity.self)
                }
                completion(activities)
            }
    }
}

enum RepositoryError: Error {
    case missingDocumentId
}
```

### Pattern 2: ViewModel with Proper Listener Cleanup
**What:** Store ListenerRegistration in ViewModel, remove in deinit with [weak self] to prevent memory leaks
**When to use:** All ViewModels that use Firestore listeners (established in Phase 1, critical for Phase 2+)
**Example:**
```swift
// Source: https://github.com/firebase/firebase-ios-sdk/issues/2607 (memory leak prevention)

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

    // CRITICAL: Store listeners to remove in deinit
    private var activeListener: ListenerRegistration?
    private var archivedListener: ListenerRegistration?

    init(userId: String, repository: ActivityRepositoryProtocol = ActivityRepository()) {
        self.userId = userId
        self.repository = repository
    }

    func startListening() {
        // CRITICAL: Use [weak self] to break retain cycle
        activeListener = repository.listenToActiveActivities(userId: userId) { [weak self] activities in
            self?.activeActivities = activities
        }

        archivedListener = repository.listenToArchivedActivities(userId: userId) { [weak self] activities in
            self?.archivedActivities = activities
        }
    }

    func createActivity(name: String, category: ActivityCategory) async {
        isLoading = true
        defer { isLoading = false }

        let activity = Activity(
            id: nil,
            name: name,
            category: category.rawValue,
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String(),
            archived: false
        )

        do {
            _ = try await repository.createActivity(userId: userId, activity: activity)
            // Listener automatically updates activeActivities
        } catch {
            errorMessage = "Failed to create activity: \(error.localizedDescription)"
        }
    }

    func archiveActivity(_ activity: Activity) async {
        guard let activityId = activity.id else { return }

        do {
            try await repository.archiveActivity(userId: userId, activityId: activityId)
            // Listener automatically moves activity to archived list
        } catch {
            errorMessage = "Failed to archive activity: \(error.localizedDescription)"
        }
    }

    // CRITICAL: Always remove listeners in deinit to prevent memory leaks
    deinit {
        activeListener?.remove()
        archivedListener?.remove()
    }
}
```

### Pattern 3: SwiftUI List with Archive/Restore SwipeActions
**What:** Native iOS swipeActions for archive and restore with proper visual indicators
**When to use:** Activity list views (ACT-04, ACT-05, ACT-06)
**Example:**
```swift
// Source: SwiftUI List Complete Guide 2025 + iOS HIG swipe patterns

import SwiftUI

struct ActivityListView: View {
    @StateObject private var viewModel: ActivityViewModel
    @State private var showingCreateSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.activeActivities) { activity in
                    ActivityRowView(activity: activity)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteActivity(activity)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                Task {
                                    await viewModel.archiveActivity(activity)
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                }
            }
            .navigationTitle("Activities")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        ArchivedActivityListView(viewModel: viewModel)
                    } label: {
                        Label("Archived", systemImage: "archivebox")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                ActivityFormView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.startListening()
        }
    }
}

struct ArchivedActivityListView: View {
    @ObservedObject var viewModel: ActivityViewModel

    var body: some View {
        List {
            ForEach(viewModel.archivedActivities) { activity in
                ActivityRowView(activity: activity)
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task {
                                await viewModel.restoreActivity(activity)
                            }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
            }
        }
        .navigationTitle("Archived")
    }
}
```

### Pattern 4: Activity Category Enum with Picker
**What:** Swift enum with CaseIterable, Identifiable, Hashable for type-safe category selection
**When to use:** Activity creation and editing forms (ACT-02)
**Example:**
```swift
// Source: https://sarunw.com/posts/swiftui-picker-enum/ + SwiftUI Picker best practices 2025

import SwiftUI

enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case instrument = "Instrument"
    case piece = "Piece"
    case technique = "Technique"
    case theory = "Theory"
    case warmup = "Warm-up"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .instrument: return "guitars"
        case .piece: return "music.note"
        case .technique: return "hand.raised"
        case .theory: return "book"
        case .warmup: return "flame"
        case .other: return "ellipsis.circle"
        }
    }
}

struct ActivityFormView: View {
    @ObservedObject var viewModel: ActivityViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var category: ActivityCategory = .instrument

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Activity Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(ActivityCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.createActivity(name: name, category: category)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
```

### Pattern 5: Firestore Aggregation Queries for Statistics
**What:** Server-side sum() calculation of total practice time per activity without downloading sessions
**When to use:** Activity statistics view (POST-05)
**Example:**
```swift
// Source: https://firebase.google.com/docs/firestore/query-data/aggregation-queries

import FirebaseFirestore

struct ActivityStatistics {
    let activityId: String
    let activityName: String
    let totalPracticeTime: TimeInterval // seconds
    let sessionCount: Int
}

class StatisticsRepository {
    private let db = Firestore.firestore()

    func getActivityStatistics(userId: String, activityId: String) async throws -> ActivityStatistics {
        let sessionsRef = db.collection("users").document(userId)
            .collection("sessions")
            .whereField("activityId", isEqualTo: activityId)

        // Firestore aggregation query - calculates server-side
        let snapshot = try await sessionsRef
            .count()
            .getAggregation(source: .server)

        let count = snapshot.get(AggregateField.count()) as? Int ?? 0

        // Note: sum() aggregation requires numeric field
        // If session has duration field (in seconds):
        let sumSnapshot = try await sessionsRef
            .aggregate([
                AggregateField.sum("duration")
            ])
            .getAggregation(source: .server)

        let totalTime = sumSnapshot.get(AggregateField.sum("duration")) as? Double ?? 0.0

        return ActivityStatistics(
            activityId: activityId,
            activityName: "", // Fetch from activity document separately
            totalPracticeTime: totalTime,
            sessionCount: count
        )
    }

    func getAllActivityStatistics(userId: String) async throws -> [ActivityStatistics] {
        // For multiple activities: fetch activity list, then aggregate for each
        // Alternative: Use collection group query if sessions have activityId field

        let activitiesSnapshot = try await db.collection("users").document(userId)
            .collection("activities")
            .whereField("archived", isEqualTo: false)
            .getDocuments()

        var statistics: [ActivityStatistics] = []

        for doc in activitiesSnapshot.documents {
            let activity = try doc.data(as: Activity.self)
            guard let activityId = activity.id else { continue }

            let stats = try await getActivityStatistics(userId: userId, activityId: activityId)
            statistics.append(ActivityStatistics(
                activityId: activityId,
                activityName: activity.name,
                totalPracticeTime: stats.totalPracticeTime,
                sessionCount: stats.sessionCount
            ))
        }

        return statistics.sorted { $0.totalPracticeTime > $1.totalPracticeTime }
    }
}
```

### Anti-Patterns to Avoid
- **Not removing listeners:** Always call listener?.remove() in deinit or memory leaks accumulate indefinitely
- **Strong self in listener closures:** Always use [weak self] in addSnapshotListener closures to prevent retain cycles
- **Polling instead of listeners:** getDocuments() polling wastes reads and battery, use addSnapshotListener for live data
- **Downloading all data for statistics:** Use aggregation queries (sum, count, average) instead of fetching all documents
- **Hard-coding categories:** Use enum for type-safety and consistency with web app's category system
- **Not handling listener errors:** Always check error parameter in listener callback and update UI accordingly
- **Forgetting to filter archived:** Active list must use whereField("archived", isEqualTo: false) to exclude archived items

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Real-time sync | Custom polling loop checking for updates | Firestore addSnapshotListener | Listeners use WebSocket connection with sub-second latency, handle reconnection automatically, batch updates, and cost same as single read per update batch - custom polling wastes 90%+ of reads |
| Activity statistics | Download all sessions and sum in-app | Firestore aggregation queries (sum, count, average) | Aggregation calculates server-side, transmits only result, saves 99% of bandwidth and reads (1000 sessions = 1 aggregation read vs 1000 document reads), essential at scale |
| Archive/restore UI | Custom gesture recognizers with UIKit | SwiftUI swipeActions modifier | swipeActions provides native iOS feel, handles bounce/cancellation/accessibility, matches system apps (Mail, Reminders), custom gestures require hundreds of lines and extensive edge case testing |
| Offline queue | Custom queue tracking pending writes | Firestore offline persistence with automatic sync | Firestore queues writes automatically, retries on failure, resolves conflicts with last-write-wins, syncs when online - custom queue needs transaction handling, conflict resolution, retry logic, persistence layer |
| Category validation | String validation in multiple places | Swift enum with Codable conformance | Enum provides compile-time safety, autocomplete, prevents typos, matches web app categories exactly, string validation scattered across codebase is error-prone and inconsistent |

**Key insight:** Firestore's real-time listeners and aggregation queries are production-hardened at Google scale, handling edge cases like network interruptions mid-update, partial write failures, concurrent modifications, and cache invalidation that would take months to discover and fix in custom implementations. Offline persistence especially difficult - Firestore handles cache eviction, conflict resolution, and transaction ordering automatically.

## Common Pitfalls

### Pitfall 1: Firestore Listener Memory Leaks
**What goes wrong:** ViewModels with Firestore listeners never deallocate, memory usage grows indefinitely, app slows down
**Why it happens:** ListenerRegistration keeps strong reference to closure, closure captures self strongly, creating retain cycle that prevents deallocation
**How to avoid:**
1. Store listener as property: `private var listener: ListenerRegistration?`
2. Always use [weak self] in listener closures: `addSnapshotListener { [weak self] snapshot, error in ... }`
3. Call `listener?.remove()` in deinit
4. Do NOT use weak for ListenerRegistration itself (makes it nil and prevents removal)
**Warning signs:** Memory usage increases when navigating between screens, ViewModels never print deinit logs, Xcode Instruments shows accumulating closures

### Pitfall 2: Forgetting to Filter Archived Activities
**What goes wrong:** Archived activities appear in active list, users confused why "deleted" items still show
**Why it happens:** Missing whereField("archived", isEqualTo: false) in query for active list
**How to avoid:**
1. Always use whereField filter in listenToActiveActivities: `.whereField("archived", isEqualTo: false)`
2. Default archived to false in Activity model initialization
3. Separate methods for active vs archived: listenToActiveActivities vs listenToArchivedActivities
4. Test with mix of archived and active activities during development
**Warning signs:** Activities that should be archived appearing in main list, archive count mismatch with actual archived items

### Pitfall 3: Aggregation Queries on Non-Indexed Fields
**What goes wrong:** Statistics queries fail with "requires an index" error or timeout
**Why it happens:** Firestore aggregation queries need composite indexes when filtering + aggregating (e.g., where activityId = X AND sum duration)
**How to avoid:**
1. Follow Firestore Console error links to create required indexes (automatic)
2. Test statistics with realistic data (100+ sessions) to trigger index requirements early
3. Use Firebase Emulator to catch index errors before production
4. Order matters: where clauses before aggregation, order by before limit
**Warning signs:** Queries work with small data but fail in production, "missing index" errors in console, slow query performance

### Pitfall 4: SwipeActions Triggering Unintended Deletes
**What goes wrong:** User accidentally swipes all the way and activity deletes without confirmation
**Why it happens:** Default swipeActions allows full swipe to trigger primary (first) action, which is delete
**How to avoid:**
1. Set `allowsFullSwipe: false` on swipeActions with destructive actions
2. Order actions: delete last (leftmost), archive first (rightmost) so full swipe archives not deletes
3. Add confirmation alert for delete: `.confirmationDialog("Delete activity?")`
4. Use role: .destructive for delete button to get red color warning
**Warning signs:** User reports "accidental deletes", support requests for data recovery, negative app reviews mentioning data loss

### Pitfall 5: Not Updating updatedAt Timestamp on Archive/Restore
**What goes wrong:** Archived activities list shows wrong order, recently archived items appear at bottom
**Why it happens:** Archive/restore only updates archived field, not updatedAt timestamp
**How to avoid:**
1. Always update updatedAt in archiveActivity and restoreActivity: `"updatedAt": Date().toISO8601String()`
2. Order archived list by updatedAt descending: `.order(by: "updatedAt", descending: true)`
3. Include updatedAt in all update operations, not just name/category changes
4. Match web app timestamp format exactly (ISO 8601 strings from Phase 1)
**Warning signs:** Archived activities in random order, recently archived items hard to find, inconsistent sort between platforms

### Pitfall 6: Activity Form Allows Empty Names
**What goes wrong:** User creates activity with blank name, shows as empty row in list, breaks sorting
**Why it happens:** Save button enabled when name is empty or only whitespace
**How to avoid:**
1. Disable save button when name is empty: `.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)`
2. Trim whitespace before saving: `let trimmedName = name.trimmingCharacters(in: .whitespaces)`
3. Validate minimum length (e.g., 1 character after trim): `guard !trimmedName.isEmpty else { return }`
4. Show inline validation message: "Activity name is required"
**Warning signs:** Empty rows in activity list, Firestore documents with name: "", sort order broken

### Pitfall 7: Listener Fires Multiple Times on Initial Load
**What goes wrong:** Activity list flashes/reloads multiple times when view appears, janky animation
**Why it happens:** Firestore listener fires immediately with cached data, then again with server data, causing double update
**How to avoid:**
1. Check snapshot.metadata.isFromCache to distinguish cache vs server updates
2. Use includeMetadataChanges: false (default) to only get data changes, not metadata changes
3. Only call startListening() once in onAppear, not on every view update
4. Use @StateObject for ViewModel (not @ObservedObject) in parent view to prevent recreating listener
**Warning signs:** List "jumps" on load, duplicate animations, network indicator flashes twice, higher than expected read counts

### Pitfall 8: Category Mismatch Between iOS and Web
**What goes wrong:** Activity created on iOS shows wrong category on web or vice versa
**Why it happens:** iOS enum rawValue doesn't match web app's category string values
**How to avoid:**
1. Coordinate enum rawValue with web app exactly: `case instrument = "Instrument"` must match web's "Instrument"
2. Document category values in shared spec (e.g., REQUIREMENTS.md or data model doc)
3. Test round-trip: create on iOS, verify on web, edit on web, verify on iOS
4. Use Firestore console to inspect actual stored values and confirm match
**Warning signs:** Categories appear as "other" or missing on opposite platform, category filter mismatches, user confusion about activity types

## Code Examples

Verified patterns from official sources:

### Firestore CRUD Operations
```swift
// Source: https://github.com/firebase/snippets-ios/blob/master/firestore/swift/firestore-smoketest/ViewController.swift

import FirebaseFirestore

// Create document with auto-generated ID
let ref = try await db.collection("users").document(userId)
    .collection("activities")
    .addDocument(data: [
        "name": "Piano Practice",
        "category": "Instrument",
        "archived": false,
        "createdAt": Date().toISO8601String(),
        "updatedAt": Date().toISO8601String()
    ])
print("Activity created with ID: \(ref.documentID)")

// Create document with Codable
let activity = Activity(...)
try db.collection("users").document(userId)
    .collection("activities").document(activityId)
    .setData(from: activity)

// Update specific fields
try await db.collection("users").document(userId)
    .collection("activities").document(activityId)
    .updateData([
        "name": "Updated Name",
        "updatedAt": Date().toISO8601String()
    ])

// Delete document
try await db.collection("users").document(userId)
    .collection("activities").document(activityId)
    .delete()

// Delete single field
try await db.collection("users").document(userId)
    .collection("activities").document(activityId)
    .updateData([
        "category": FieldValue.delete()
    ])
```

### Firestore Where Queries
```swift
// Source: https://github.com/firebase/snippets-ios/blob/master/firestore/swift/firestore-smoketest/ViewController.swift

// Filter active activities
db.collection("users").document(userId)
    .collection("activities")
    .whereField("archived", isEqualTo: false)
    .order(by: "name")
    .getDocuments()

// Filter by category
db.collection("users").document(userId)
    .collection("activities")
    .whereField("category", isEqualTo: "Instrument")
    .whereField("archived", isEqualTo: false)
    .getDocuments()

// Array contains (if categories stored as array)
db.collection("users").document(userId)
    .collection("activities")
    .whereField("tags", arrayContains: "daily")
    .getDocuments()
```

### Real-Time Listener Setup and Teardown
```swift
// Source: https://github.com/firebase/snippets-ios/blob/master/firestore/swift/firestore-smoketest/ViewController.swift

// Attach listener
let listener = db.collection("users").document(userId)
    .collection("activities")
    .whereField("archived", isEqualTo: false)
    .addSnapshotListener { querySnapshot, error in
        guard let snapshot = querySnapshot else {
            print("Error fetching activities: \(error?.localizedDescription ?? "Unknown")")
            return
        }

        let activities = snapshot.documents.compactMap { doc -> Activity? in
            try? doc.data(as: Activity.self)
        }

        print("Current activities: \(activities.map { $0.name })")
    }

// Remove listener (critical for memory management)
listener.remove()
```

### Update with Conditional Create or Update
```swift
// Source: https://peterfriese.dev/posts/swiftui-firebase-update-data

private func updateOrAddActivity(_ activity: Activity) async {
    if let _ = activity.id {
        // Update existing
        try? await repository.updateActivity(userId: userId, activity: activity)
    } else {
        // Create new
        try? await repository.createActivity(userId: userId, activity: activity)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| getDocuments() polling | addSnapshotListener real-time | Always recommended | Listeners reduce read costs (1 read per update vs polling every N seconds), provide sub-second latency, handle reconnection automatically |
| Manual statistics calculation | Firestore aggregation queries (sum, count, average) | Firestore 10.7.0+ (2022) | Server-side aggregation saves 99% of reads for stats, essential at scale, reduces bandwidth and compute costs dramatically |
| Hard delete only | Soft delete with archived flag | App design decision | Soft delete allows restore, better UX, simpler than separate collections, standard pattern in modern apps (Mail, Reminders) |
| Custom category strings | Swift enum with Codable | iOS best practice | Enum provides type-safety, autocomplete, prevents typos, easier to maintain and extend categories |
| Completion handlers | async/await | Swift 5.5 (2021) | Cleaner syntax, better error handling, easier to chain operations, all Firebase methods support async/await |
| @ObservedObject everywhere | @StateObject for owners, @ObservedObject for passed objects | SwiftUI best practice (2020+) | Prevents recreating ViewModels on view updates, fixes listener lifecycle bugs, reduces memory leaks |

**Deprecated/outdated:**
- **Polling with getDocuments():** Use addSnapshotListener for live data - polling wastes reads and battery
- **@Published var listener:** Don't publish ListenerRegistration, store as private property only
- **Ignoring snapshot.metadata:** Modern apps should check isFromCache to optimize UX (show "syncing" indicator)
- **FieldValue.serverTimestamp():** Use ISO 8601 strings (from Phase 1) to match web app and allow client-side timestamp display
- **Custom archive subcollection:** Use archived boolean field with where query - simpler and more standard pattern in 2025

## Open Questions

1. **Activity Statistics Performance at Scale**
   - What we know: Firestore aggregation queries calculate server-side, cost 1 read per 1000 index entries matched
   - What's unclear: Performance with 10,000+ sessions per user, whether to pre-calculate and cache statistics in user document
   - Recommendation: Start with real-time aggregation queries, add caching in later phase if performance degrades (unlikely before 5000+ sessions)

2. **Category List Coordination with Web App**
   - What we know: iOS enum must match web app's category values exactly for cross-platform consistency
   - What's unclear: Whether web app has fixed category list or allows custom categories, how to handle category evolution
   - Recommendation: Document current web app categories during planning, coordinate any category additions with web team, use enum for v1 with fixed list

3. **Archive vs Delete UX Decision**
   - What we know: Requirements include both archive (ACT-05) and delete (ACT-04)
   - What's unclear: When users should archive vs delete, whether delete is permanent or also soft-delete, if delete should have confirmation
   - Recommendation: Archive primary action (swipeActions rightmost), delete with confirmation dialog, consider delete as "permanent archive" that requires multi-step restore in settings

4. **Activity Ordering Preferences**
   - What we know: Active list orders by name alphabetically, archived list by updatedAt descending
   - What's unclear: Whether users want custom sort (manual order, most-used first, recent first), if preferences should sync across devices
   - Recommendation: Start with fixed ordering (name for active, updatedAt for archived), add user preference in Phase 5 if feedback indicates need

## Sources

### Primary (HIGH confidence)
- Firebase Firestore iOS SDK 12.10.0 official docs - https://firebase.google.com/docs/firestore/ (accessed 2026-03-02)
- Firebase iOS code snippets repository - https://github.com/firebase/snippets-ios/blob/master/firestore/swift/firestore-smoketest/ViewController.swift (accessed 2026-03-02)
- Firestore aggregation queries official docs - https://firebase.google.com/docs/firestore/query-data/aggregation-queries (accessed 2026-03-02)
- Firebase iOS SDK memory leak issue #2607 - https://github.com/firebase/firebase-ios-sdk/issues/2607 (accessed 2026-03-02)
- Firestore offline persistence official docs - https://firebase.google.com/docs/firestore/manage-data/enable-offline (accessed 2026-03-02)

### Secondary (MEDIUM confidence)
- Peter Friese: Updating Data in Firestore from SwiftUI - https://peterfriese.dev/posts/swiftui-firebase-update-data (accessed 2026-03-02)
- SwiftUI List Complete Guide 2025 - https://dev.to/swift_pal/swiftui-list-complete-guide-move-delete-pin-custom-actions-2025-edition-429o (2025-07)
- Understanding SwiftUI Picker Complete Guide 2025 - https://devin-rosario.medium.com/understanding-swiftui-picker-complete-guide-from-basics-to-advanced-2025-dd7028288700 (2025)
- SwiftUI Picker with Enum - https://sarunw.com/posts/swiftui-picker-enum/ (accessed 2026-03-02)
- Firestore Query Best Practices 2026 - https://estuary.dev/blog/firestore-query-best-practices/ (2026)

### Tertiary (LOW confidence)
- Firebase + SwiftUI Medium article (September 2025) - Access denied during fetch, pattern descriptions from search results only
- Various Firestore repository pattern GitHub packages - Reviewed descriptions but not full implementations

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries from Phase 1, aggregation queries in Firebase SDK since 2022, officially documented
- Architecture: HIGH - Repository pattern established in Phase 1, listener cleanup verified in Firebase issue tracker, swipeActions native SwiftUI
- Pitfalls: HIGH - Memory leak pattern documented in Firebase GitHub issues, other pitfalls from official docs and iOS HIG
- Statistics: MEDIUM - Aggregation query pattern verified but Phase 2 may only show basic stats, full statistics in Phase 4

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (30 days - Firestore patterns stable, SwiftUI swipeActions mature API)

**Notes:**
- Phase 2 establishes critical real-time listener patterns reused in Phase 3 (session execution) and Phase 4 (history)
- Memory leak prevention pattern from Phase 1 research must be emphasized in planning - very common pitfall
- Activity statistics (POST-05) may be simplified in Phase 2 (just total time per activity) with full statistics dashboard in Phase 4
- All patterns coordinate with Phase 1 data model (Activity.swift already exists with archived field)
- Category enum values must be coordinated with web app during planning - critical for cross-platform consistency
