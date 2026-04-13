# Phase 4: Session History & Statistics - Research

**Research Date:** 2026-03-04
**Phase:** 04-session-history-statistics
**Dependencies:** Phase 3 (requires completed sessions)

---

## Overview

Phase 4 delivers retrospective views of practice sessions through a session history list, detailed session views, and basic statistics with charts. This phase enables users to review past practice patterns and see progress over time, providing foundation for Phase 5's smart suggestions.

**Core Challenge:** Efficiently query and display session history with real-time sync while handling potentially large collections (100+ sessions) through pagination.

**Key Technologies:**
- Swift Charts framework (iOS 16+ native) for visualizations
- Firestore queries with ordering, filtering, and limiting
- SwiftUI List with sections for day-grouped display
- Real-time Firestore listeners for cross-platform sync

---

## 1. Implementation Approach

### 1.1 History List Architecture

**Pattern: Follow ActivityListView Structure**

The session history view should mirror the established pattern from ActivityListView:

```swift
struct SessionHistoryView: View {
    @StateObject private var viewModel: SessionHistoryViewModel
    private let userId: String

    var body: some View {
        NavigationStack {
            List {
                // Day-grouped sections (computed from sessions array)
                ForEach(viewModel.groupedSessions) { group in
                    Section(header: Text(group.dayHeader)) {
                        ForEach(group.sessions) { session in
                            SessionHistoryRow(session: session)
                                .onTapGesture {
                                    // Navigate to SessionSummaryView
                                }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .overlay {
                if viewModel.sessions.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Practice History",
                        systemImage: "calendar",
                        description: Text("Start a practice session to see your history")
                    )
                }
            }
        }
        .onAppear {
            viewModel.startListening()
        }
    }
}
```

**Day Grouping Logic:**

Group sessions by calendar day using SwiftUI's List sections:

```swift
struct DayGroup: Identifiable {
    let id: String  // ISO date string (e.g., "2026-03-04")
    let dayHeader: String  // Display text (e.g., "Today", "Yesterday", "Monday, Mar 3")
    let sessions: [Session]
}

// In ViewModel:
var groupedSessions: [DayGroup] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

    // Group sessions by calendar day
    let grouped = Dictionary(grouping: sessions) { session -> String in
        guard let date = session.startTime.toDate() else { return "" }
        let dayStart = calendar.startOfDay(for: date)
        return dayStart.toISO8601String()
    }

    // Map to DayGroup with human-readable headers
    return grouped.map { (dateString, sessions) in
        let date = Date(iso8601String: dateString)!
        let dayStart = calendar.startOfDay(for: date)

        let header: String
        if calendar.isDate(dayStart, inSameDayAs: today) {
            header = "Today"
        } else if calendar.isDate(dayStart, inSameDayAs: yesterday) {
            header = "Yesterday"
        } else {
            // Format as "Monday, Mar 3"
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            header = formatter.string(from: date)
        }

        return DayGroup(
            id: dateString,
            dayHeader: header,
            sessions: sessions.sorted { $0.startTime > $1.startTime }  // Newest first within day
        )
    }
    .sorted { $0.id > $1.id }  // Newest days first
}
```

### 1.2 Session History Row Design

**Compact 2-line layout matching Phase 4 context decisions:**

```swift
struct SessionHistoryRow: View {
    let session: Session
    let activities: [SessionActivity]  // Fetched separately or passed in

    private var activityPreview: String {
        let names = activities
            .filter { !$0.isInBetweenTime }
            .prefix(3)
            .map { $0.activityName }

        let count = activities.filter { !$0.isInBetweenTime }.count
        if names.count < count {
            return "\(count) activities: \(names.joined(separator: ", "))..."
        } else {
            return "\(count) \(count == 1 ? "activity" : "activities"): \(names.joined(separator: ", "))"
        }
    }

    private var hasNotes: Bool {
        activities.contains { $0.notes != nil && !$0.notes!.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Line 1: Time and duration
            HStack {
                if let startDate = session.startTime.toDate() {
                    Text(startDate, style: .time)  // e.g., "3:45 PM"
                        .font(.headline)
                }

                Spacer()

                Text(formatDuration(TimeInterval(session.totalDuration)))
                    .font(.headline)
                    .foregroundColor(.blue)

                if hasNotes {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            // Line 2: Activity preview
            Text(activityPreview)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    // Reuse formatDuration from SessionSummaryView
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
```

**Key Pattern:** Reuse formatDuration helper from SessionSummaryView (extract to shared extension if needed).

### 1.3 Navigation to Session Detail

**Reuse SessionSummaryView unchanged** (Phase 4 context decision):

```swift
// In SessionHistoryView:
@State private var selectedSession: Session?
@State private var selectedActivities: [SessionActivity] = []

// In List:
.onTapGesture {
    selectedSession = session
    selectedActivities = viewModel.getActivities(for: session)
}

// Navigation:
.sheet(item: $selectedSession) { session in
    SessionSummaryView(
        session: session,
        activities: selectedActivities
    )
}
```

**Pattern Match:** This follows the same pattern as ActivityListView using sheet presentation for edit forms.

### 1.4 Swipe-to-Delete Implementation

**Follow ActivityListView swipe action pattern:**

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
        sessionToDelete = session
        showingDeleteConfirmation = true
    } label: {
        Label("Delete", systemImage: "trash")
    }
}

// Confirmation dialog:
.alert("Delete Session?", isPresented: $showingDeleteConfirmation) {
    Button("Delete", role: .destructive) {
        Task {
            await viewModel.deleteSession(sessionToDelete)
        }
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This will permanently delete this practice session. This action cannot be undone.")
}
```

**Security Note:** allowsFullSwipe: false prevents accidental deletion (critical pattern from Phase 2).

---

## 2. Swift Charts Integration

### 2.1 Framework Setup

**Swift Charts is iOS 16+ native** - no third-party dependencies needed.

**Import in files using charts:**

```swift
import SwiftUI
import Charts
```

**Note:** Charts framework is built into iOS 16+, not separately linked in Xcode project (confirmed by pbxproj search showing no Charts.framework reference).

### 2.2 Daily Practice Chart

**Bar chart showing practice time per day over last 30 days:**

```swift
struct DailyPracticeChart: View {
    let practiceData: [DailyPracticeData]

    var body: some View {
        Chart(practiceData) { data in
            BarMark(
                x: .value("Date", data.date, unit: .day),
                y: .value("Minutes", data.minutes)
            )
            .foregroundStyle(Color.blue.gradient)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let minutes = value.as(Int.self) {
                        Text("\(minutes)m")
                    }
                }
            }
        }
        .frame(height: 200)
    }
}

struct DailyPracticeData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int  // Total practice minutes for the day
}
```

**Data Preparation:**

```swift
// In ViewModel:
func getDailyPracticeData() async -> [DailyPracticeData] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!

    // Filter sessions to last 30 days
    let recentSessions = sessions.filter { session in
        guard let startDate = session.startTime.toDate() else { return false }
        return startDate >= thirtyDaysAgo
    }

    // Group by day and sum durations
    let grouped = Dictionary(grouping: recentSessions) { session -> Date in
        guard let date = session.startTime.toDate() else { return Date() }
        return calendar.startOfDay(for: date)
    }

    // Map to chart data
    return grouped.map { (date, sessions) in
        let totalSeconds = sessions.reduce(0) { $0 + $1.totalDuration }
        return DailyPracticeData(
            date: date,
            minutes: totalSeconds / 60
        )
    }
    .sorted { $0.date < $1.date }
}
```

### 2.3 Activity Breakdown Chart

**Horizontal bar chart showing total time per activity:**

```swift
struct ActivityBreakdownChart: View {
    let activityData: [ActivityPracticeData]

    var body: some View {
        Chart(activityData) { data in
            BarMark(
                x: .value("Hours", data.hours),
                y: .value("Activity", data.activityName)
            )
            .foregroundStyle(by: .value("Activity", data.activityName))
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text(String(format: "%.1fh", hours))
                    }
                }
            }
        }
        .frame(height: 300)
    }
}

struct ActivityPracticeData: Identifiable {
    let id = UUID()
    let activityName: String
    let hours: Double
}
```

**Data Source:** Use existing ActivityStatistics from StatisticsRepository (already aggregates server-side):

```swift
// In ViewModel:
func getActivityBreakdownData() async throws -> [ActivityPracticeData] {
    let stats = try await statisticsRepository.getAllActivityStatistics(
        userId: userId,
        activities: activities
    )

    return stats.map { stat in
        ActivityPracticeData(
            activityName: stat.activityName,
            hours: stat.totalPracticeTime / 3600
        )
    }
}
```

**Pattern Reuse:** Leverage existing StatisticsRepository server-side aggregation (99% read savings from Phase 2).

### 2.4 Chart Customization Best Practices

**From Swift Charts research:**

1. **Gradient fills** for visual polish: `.foregroundStyle(Color.blue.gradient)`
2. **Axis customization** for readability: Use AxisMarks with custom formatters
3. **Height constraints** to prevent layout issues: `.frame(height: 200)`
4. **Identifiable data structs** for proper SwiftUI updates
5. **Color scales** for categorical data: `.foregroundStyle(by: .value(...))`

**Performance Note:** Swift Charts optimizes rendering automatically - no manual performance tuning needed for 30 data points.

---

## 3. Firestore Queries

### 3.1 Session History Query Pattern

**Query ended sessions ordered by most recent:**

```swift
// In SessionRepository:
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
```

**Query Characteristics:**
- **Filter:** state == "ended" (excludes active/setup sessions)
- **Order:** startTime descending (newest first)
- **Limit:** 100 sessions default (Phase 4 context decision)
- **Index Required:** Composite index on (state, startTime) - add to firestore.indexes.json

### 3.2 Real-time Listener for History

**Pattern: Follow SessionRepository.listenToSession approach:**

```swift
// In SessionRepository:
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
```

**Memory Management (CRITICAL):**

```swift
// In SessionHistoryViewModel:
private var sessionsListener: ListenerRegistration?

func startListening() {
    guard !listenersStarted else { return }
    listenersStarted = true

    sessionsListener = repository.listenToSessions(userId: userId, limit: 100) { [weak self] sessions in
        Task { @MainActor in
            self?.sessions = sessions
        }
    }
}

deinit {
    sessionsListener?.remove()  // CRITICAL: Prevent memory leaks
}
```

**Pattern Match:** Same listener cleanup pattern as ActivityViewModel (Phase 2).

### 3.3 Fetching Session Activities

**Two approaches based on use case:**

**Approach 1: On-demand fetch** (for detail view):

```swift
// In SessionRepository:
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
```

**Approach 2: Embedded in Session** (for history rows):

Alternative: Store activity summary (names, count) in Session document to avoid N+1 query problem. This trades storage space for query efficiency.

**Recommendation:** Use Approach 1 initially (simpler), optimize to Approach 2 if performance becomes issue with 100+ sessions.

### 3.4 Delete Session

**Cascade delete session and all activities:**

```swift
// In SessionRepository:
func deleteSession(userId: String, sessionId: String) async throws {
    let sessionRef = db.collection("users")
        .document(userId)
        .collection("sessions")
        .document(sessionId)

    // 1. Delete all activities subcollection documents
    let activitiesSnapshot = try await sessionRef
        .collection("activities")
        .getDocuments()

    let batch = db.batch()
    for doc in activitiesSnapshot.documents {
        batch.deleteDocument(doc.reference)
    }

    // 2. Delete session document
    batch.deleteDocument(sessionRef)

    // Commit batch
    try await batch.commit()
}
```

**Firestore Limitation:** No automatic cascade delete - must manually delete subcollection documents before parent.

**Security Rules:** Already permit deletion (from Phase 1 firestore.rules):

```javascript
match /sessions/{sessionId} {
  allow delete: if isOwner(userId);

  match /activities/{activityId} {
    allow delete: if isOwner(userId);
  }
}
```

### 3.5 Required Firestore Index

**Add to firestore.indexes.json:**

```json
{
  "indexes": [
    {
      "collectionGroup": "sessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "state", "order": "ASCENDING" },
        { "fieldPath": "startTime", "order": "DESCENDING" }
      ]
    }
  ]
}
```

**Deployment:**

```bash
firebase deploy --only firestore:indexes
```

**Verification:**

```bash
firebase firestore:indexes
```

**Pattern Match:** Same index deployment process as Phase 2 (userId+activityId+archived indexes).

---

## 4. Data Model & Schema

### 4.1 Existing Session Model

**From Hone/Core/Models/Session.swift:**

```swift
struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    let startTime: String  // ISO 8601
    var endTime: String?   // ISO 8601
    let totalDuration: Int  // seconds
    let createdAt: String  // ISO 8601
    var updatedAt: String  // ISO 8601
    var state: String?  // "setup", "active", "paused", "inBetween", "ended"
    var pausedAt: String?
    var currentActivityIndex: Int?
}
```

**Path:** users/{userId}/sessions/{sessionId}

**Fields Used in Phase 4:**
- `id`: Session identifier
- `startTime`: For sorting and display
- `endTime`: For display in detail view
- `totalDuration`: For row duration display
- `state`: Filter for "ended" sessions only

**Fields NOT Used:** pausedAt, currentActivityIndex (only relevant during active session)

### 4.2 Existing SessionActivity Model

**From Hone/Core/Models/Session.swift:**

```swift
struct SessionActivity: Codable, Identifiable {
    @DocumentID var id: String?
    let activityId: String?  // nil for in-between time
    let activityName: String  // Denormalized for history display
    var startTime: String
    var endTime: String?
    var duration: Int
    var notes: String?
    var isInBetweenTime: Bool
    let createdAt: String
    var updatedAt: String
}
```

**Path:** users/{userId}/sessions/{sessionId}/activities/{activityId}

**Denormalization:** activityName stored in SessionActivity enables history display without joining Activity documents (critical for performance).

**Filter Pattern:** Use isInBetweenTime to separate practice activities from breaks in SessionSummaryView.

### 4.3 Schema Validation

**Existing Firestore Rules (from firestore.rules):**

```javascript
function hasRequiredSessionFields() {
  return request.resource.data.keys().hasAll(['startTime', 'totalDuration', 'createdAt', 'updatedAt']);
}

match /sessions/{sessionId} {
  allow read: if isOwner(userId);
  allow create: if isOwner(userId) && hasRequiredSessionFields();
  allow update: if isOwner(userId) && hasRequiredSessionFields();
  allow delete: if isOwner(userId);

  match /activities/{activityId} {
    allow read: if isOwner(userId);
    allow create: if isOwner(userId);
    allow update: if isOwner(userId);
    allow delete: if isOwner(userId);
  }
}
```

**Security Posture:** Validates required fields, enforces user ownership, prevents unauthorized access.

**No Schema Changes Needed:** Existing Session and SessionActivity models support all Phase 4 requirements.

---

## 5. Reusable Components

### 5.1 SessionSummaryView (Existing)

**Location:** Hone/Features/Sessions/Views/SessionSummaryView.swift

**Purpose:** Post-session summary showing total time, activity breakdown, and notes.

**Reuse Strategy:** Pass Session and [SessionActivity] to display historical session details.

**Key Features Already Implemented:**
- Total session time with formatted duration
- Start and end time display
- Activity breakdown with per-activity times
- Inline notes display with each activity
- Break time section (filters isInBetweenTime activities)
- NavigationView with toolbar dismiss button

**Integration Pattern:**

```swift
// In SessionHistoryView:
.sheet(item: $selectedSession) { session in
    SessionSummaryView(
        session: session,
        activities: viewModel.getActivities(for: session)
    )
}
```

**No modifications needed** - SessionSummaryView already designed for both post-session and history viewing.

### 5.2 formatDuration Helper (Existing)

**Location:** Hone/Features/Sessions/Views/SessionSummaryView.swift (lines 117-129)

**Implementation:**

```swift
private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = Int(duration) / 60 % 60
    let seconds = Int(duration) % 60

    if hours > 0 {
        return String(format: "%dh %dm %ds", hours, minutes, seconds)
    } else if minutes > 0 {
        return String(format: "%dm %ds", minutes, seconds)
    } else {
        return String(format: "%ds", seconds)
    }
}
```

**Reuse Options:**

1. **Shared extension** (recommended):

```swift
// Create Hone/Core/Extensions/TimeInterval+Formatting.swift
extension TimeInterval {
    func formatted() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// Usage:
Text(TimeInterval(session.totalDuration).formatted())
```

2. **Copy-paste** (simpler, acceptable for small helper):
   - Duplicate in SessionHistoryRow
   - Keep in SessionSummaryView

**Recommendation:** Create shared extension to avoid duplication (DRY principle).

### 5.3 String.toDate() Extension (Existing)

**Location:** Hone/Features/Sessions/Views/SessionSummaryView.swift (lines 133-137)

**Implementation:**

```swift
extension String {
    func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)
    }
}
```

**Already Available:** Can use directly for parsing session startTime/endTime ISO 8601 strings.

**Alternative:** Use Date+ISO8601.swift extension with init(iso8601String:) initializer for consistency.

### 5.4 Date+ISO8601 Extension (Existing)

**Location:** Hone/Core/Extensions/Date+ISO8601.swift

**Implementation:**

```swift
extension Date {
    func toISO8601String() -> String {
        return ISO8601DateFormatter().string(from: self)
    }

    init?(iso8601String: String) {
        guard let date = ISO8601DateFormatter().date(from: iso8601String) else {
            return nil
        }
        self = date
    }
}
```

**Usage Pattern:**

```swift
// Parse session timestamp:
if let startDate = Date(iso8601String: session.startTime) {
    Text(startDate, style: .time)  // "3:45 PM"
}
```

**Consistency:** Prefer Date+ISO8601 extension over String.toDate() for uniformity across codebase.

### 5.5 ActivityStatisticsView (Existing)

**Location:** Hone/Features/Activities/Views/ActivityStatisticsView.swift

**Purpose:** Displays activity-level stats using Firestore aggregation.

**Reuse Strategy:** Continue using for activity statistics (Phase 4 context decision).

**Already Implements:**
- Server-side aggregation queries (99% read savings)
- Total practice time per activity
- Session count per activity
- Pull-to-refresh gesture
- Empty state handling
- Error state handling

**Integration:** Link from Statistics tab/section to show per-activity totals alongside session history.

### 5.6 ActivityListView Patterns (Existing)

**Location:** Hone/Features/Activities/Views/ActivityListView.swift

**Reusable Patterns:**

1. **NavigationStack + List structure**
2. **ContentUnavailableView for empty state**
3. **Swipe actions with allowsFullSwipe: false**
4. **Sheet presentation for detail views**
5. **onAppear lifecycle for listener attachment**
6. **Toolbar items for navigation links**

**Direct Application:**

```swift
struct SessionHistoryView: View {
    // Follow same structure as ActivityListView:
    @StateObject private var viewModel: SessionHistoryViewModel

    var body: some View {
        NavigationStack {
            List {
                // Content
            }
            .navigationTitle("History")
            .toolbar {
                // Actions
            }
            .overlay {
                if viewModel.sessions.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(...)
                }
            }
        }
        .onAppear {
            viewModel.startListening()
        }
    }
}
```

**Pattern Consistency:** Maintaining established patterns reduces cognitive load and ensures predictable behavior.

---

## 6. Performance Considerations

### 6.1 Pagination Strategy

**Initial Load:** 100 sessions (Phase 4 context decision)

**Session-based Limit Rationale:**
- Average user: 2-3 sessions per week = 100-150 sessions per year
- 100 sessions covers 6-12 months of practice history
- Sufficient for most users without pagination complexity

**Pagination Implementation (if needed):**

```swift
// In SessionRepository:
func getNextPage(userId: String, after lastSession: Session, limit: Int = 50) async throws -> [Session] {
    guard let lastStartTime = lastSession.startTime.toDate() else {
        throw RepositoryError.invalidData
    }

    let snapshot = try await db.collection("users")
        .document(userId)
        .collection("sessions")
        .whereField("state", isEqualTo: "ended")
        .order(by: "startTime", descending: true)
        .start(after: [lastStartTime])  // Cursor-based pagination
        .limit(to: limit)
        .getDocuments()

    return snapshot.documents.compactMap { try? $0.data(as: Session.self) }
}
```

**Trigger:** Load next page when user scrolls to bottom 10 rows:

```swift
// In List:
.onAppear {
    if session == viewModel.sessions.suffix(10).first {
        Task { await viewModel.loadNextPage() }
    }
}
```

**Firestore Efficiency:** Cursor-based pagination with start(after:) uses Firestore's efficient range queries.

### 6.2 Cache Management

**Firestore Offline Persistence (already enabled from Phase 1):**

```swift
// In AppDelegate (existing):
let settings = FirestoreSettings()
settings.isPersistenceEnabled = true
settings.cacheSizeBytes = FirestoreCacheSizeUnlimited  // Monitor in production
Firestore.firestore().settings = settings
```

**Cache Benefits:**
- History loads instantly from cache when offline
- Reduced network bandwidth for repeated views
- Real-time listener updates cache automatically

**Cache Monitoring:**

```swift
// Use source metadata to check cache vs server:
snapshot.metadata.isFromCache  // true if loaded from cache
```

**Cache Limit Consideration:** 100 sessions × 10 activities × 1KB ≈ 1MB. Well within default cache limits.

### 6.3 Query Optimization

**Indexed Query Performance:**

```
users/{userId}/sessions
  .whereField("state", isEqualTo: "ended")
  .order(by: "startTime", descending: true)
  .limit(to: 100)
```

**Performance Characteristics:**
- **Composite Index:** (state, startTime) - must create via firestore.indexes.json
- **Query Time:** O(log N + K) where N = total sessions, K = limit (100)
- **Read Cost:** 100 document reads (initial load)
- **Listener Cost:** Only changed documents (incremental updates)

**Optimization:** Limit always applied before reading documents (Firestore server-side optimization).

### 6.4 Activity Summary Loading

**N+1 Query Problem:**

Loading 100 sessions + fetching activities for each = 101 queries (inefficient).

**Solution Options:**

**Option 1: Lazy Load** (recommended for v1):
- Only fetch activities when user taps session row
- Reduces initial load to 1 query
- Acceptable UX for detail view

```swift
// In SessionHistoryView:
.onTapGesture {
    Task {
        let activities = try await viewModel.getActivities(for: session)
        selectedActivities = activities
        selectedSession = session
    }
}
```

**Option 2: Batch Fetch** (future optimization):
- Fetch all activities for visible sessions using collection group query
- More complex but eliminates N+1 problem
- Defer to Phase 6 if needed

**Recommendation:** Start with Option 1 (lazy load), profile in production, optimize if needed.

### 6.5 Real-time Sync Performance

**Listener Bandwidth:**

```swift
// Listener only receives changed documents (Firestore optimization):
.addSnapshotListener { snapshot, error in
    guard let snapshot = snapshot else { return }

    // snapshot.documentChanges contains only:
    // - .added (new sessions)
    // - .modified (updated sessions)
    // - .removed (deleted sessions)

    // Full document set NOT re-downloaded on every change
}
```

**Cross-Platform Sync:**
- Session created on web → iOS listener receives .added event → UI updates automatically
- Session deleted on iOS → web listener receives .removed event → web UI updates
- Near real-time latency: 50-500ms (Firestore typical)

**Pattern Match:** Same listener pattern as ActivityViewModel (proven in Phase 2).

---

## 7. Real-time Sync

### 7.1 Listener Architecture

**MVVM Pattern with ListenerRegistration:**

```swift
@MainActor
final class SessionHistoryViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var isLoading = false

    private let repository: SessionRepositoryProtocol
    private let userId: String
    private var sessionsListener: ListenerRegistration?
    private var listenersStarted = false

    nonisolated init(userId: String, repository: SessionRepositoryProtocol = SessionRepository()) {
        self.userId = userId
        self.repository = repository
    }

    func startListening() {
        guard !listenersStarted else { return }
        listenersStarted = true

        sessionsListener = repository.listenToSessions(userId: userId, limit: 100) { [weak self] sessions in
            Task { @MainActor in
                self?.sessions = sessions
            }
        }
    }

    deinit {
        sessionsListener?.remove()  // CRITICAL: Prevent memory leaks
    }
}
```

**Pattern Consistency:** Matches ActivityViewModel (Phase 2), SessionViewModel (Phase 3).

### 7.2 MainActor Threading

**CRITICAL Pattern (from Phase 2 accumulated context):**

```swift
// Wrap listener callbacks with MainActor.run:
sessionsListener = repository.listenToSessions(...) { sessions in
    Task { @MainActor in
        self?.sessions = sessions  // Update @Published on main thread
    }
}
```

**Why:** Firestore listeners fire on background thread. @Published property updates must occur on main thread to prevent SwiftUI threading violations.

**Pattern Source:** Established in Plan 02-04 (Firestore aggregation queries).

### 7.3 Cross-Platform Sync Testing

**Test Scenarios:**

1. **Web → iOS:**
   - Complete session on web app
   - iOS listener receives new session
   - Session appears in history list automatically

2. **iOS → Web:**
   - Complete session on iOS
   - Web listener receives new session
   - Web history updates automatically

3. **Concurrent Edits:**
   - Edit session notes on web
   - Edit same session notes on iOS
   - Last write wins (Firestore default)

**Validation Method:**

```bash
# Terminal 1: Monitor Firestore locally
firebase emulators:start --only firestore

# Terminal 2: iOS Simulator
# Terminal 3: Web app localhost

# Test: Create session in web, verify appears in iOS within 1 second
```

**Pattern Match:** Same real-time sync validation as Phase 2 (activity create/archive/restore).

### 7.4 Offline Sync Behavior

**Scenario: User Completes Session Offline**

1. Session writes to local Firestore cache
2. Listener fires with cached data
3. UI updates immediately
4. When online: Firestore syncs to server automatically
5. Other devices receive real-time update

**Firestore Guarantees:**
- Write succeeds immediately to cache (optimistic UI)
- Automatic retry on network restore
- Conflict resolution: last write wins

**User Experience:**
- No visible difference between online/offline
- History always shows completed sessions
- Sync happens transparently in background

**Pattern Match:** Same offline-first behavior as Phase 2 activity management.

---

## 8. Validation Architecture

### 8.1 Testing Strategy

**Unit Tests (Mock Repository Pattern):**

Follow established pattern from ActivityRepositoryTests.swift:

```swift
// MARK: - Mock SessionRepository

class MockSessionRepository: SessionRepositoryProtocol {
    private var sessions: [String: Session] = [:]
    private var activities: [String: [SessionActivity]] = [:]

    func getSessions(userId: String, limit: Int) async throws -> [Session] {
        return sessions.values
            .filter { $0.state == "ended" }
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit)
            .map { $0 }
    }

    func getSessionActivities(userId: String, sessionId: String) async throws -> [SessionActivity] {
        return activities[sessionId] ?? []
    }

    func deleteSession(userId: String, sessionId: String) async throws {
        sessions.removeValue(forKey: sessionId)
        activities.removeValue(forKey: sessionId)
    }

    func listenToSessions(userId: String, limit: Int, completion: @escaping ([Session]) -> Void) -> ListenerRegistration {
        let filtered = try! getSessions(userId: userId, limit: limit)
        completion(filtered)
        return MockListenerRegistration()
    }
}

// MARK: - Test Cases

class SessionHistoryViewModelTests: XCTestCase {
    var repository: MockSessionRepository!
    var viewModel: SessionHistoryViewModel!
    let testUserId = "test-user-123"

    override func setUp() {
        super.setUp()
        repository = MockSessionRepository()
        viewModel = SessionHistoryViewModel(userId: testUserId, repository: repository)
    }

    func testLoadSessions_filtersEndedOnly() async throws {
        // Given: Mix of ended and active sessions
        // When: Load sessions
        // Then: Only ended sessions returned
    }

    func testDeleteSession_removesFromList() async throws {
        // Given: Session in list
        // When: Delete session
        // Then: Session no longer in list
    }

    func testGroupedSessions_groupsByDay() async throws {
        // Given: Sessions on different days
        // When: Access groupedSessions
        // Then: Grouped by day with correct headers
    }
}
```

**Test Coverage:**
- Session filtering (ended vs active)
- Session ordering (descending startTime)
- Pagination (if implemented)
- Day grouping logic
- Delete cascade (session + activities)
- Listener cleanup (memory leak prevention)

### 8.2 Integration Tests

**Firestore Emulator Tests:**

```swift
class SessionHistoryIntegrationTests: XCTestCase {
    var db: Firestore!
    var repository: SessionRepository!
    let testUserId = "integration-test-user"

    override func setUp() {
        super.setUp()
        // Connect to emulator
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        db = Firestore.firestore()
        db.settings = settings

        repository = SessionRepository()
    }

    func testRealTimeSync_receivesUpdates() async throws {
        // Given: Listener attached
        // When: Add session in parallel
        // Then: Listener receives update
    }

    func testQueryPerformance_under100ms() async throws {
        // Given: 100 sessions in Firestore
        // When: Query sessions
        // Then: Completes in <100ms
    }
}
```

**Performance Benchmarks:**
- Query 100 sessions: <100ms
- Listener initial snapshot: <200ms
- Delete session with 20 activities: <500ms

### 8.3 UI Tests

**SwiftUI Preview Tests:**

```swift
#Preview("History with Sessions") {
    SessionHistoryView(userId: "preview-user")
        .environmentObject(MockAuthViewModel())
}

#Preview("Empty History") {
    SessionHistoryView(userId: "preview-user-empty")
}

#Preview("Session Row") {
    List {
        SessionHistoryRow(
            session: Session(...),
            activities: [...]
        )
    }
}
```

**Manual Test Cases:**

1. **Empty State:**
   - New user with no sessions
   - Verify ContentUnavailableView appears
   - Verify message: "Start a practice session to see your history"

2. **Session Display:**
   - User with 5 sessions across 3 days
   - Verify day grouping ("Today", "Yesterday", "Monday, Mar 3")
   - Verify newest first within each day
   - Verify time, duration, activity preview correct

3. **Navigation:**
   - Tap session row
   - Verify SessionSummaryView appears
   - Verify all activities and notes displayed
   - Verify "Done" dismisses sheet

4. **Swipe Delete:**
   - Swipe session row
   - Verify delete button appears (red)
   - Verify allowsFullSwipe: false (can't swipe all the way)
   - Tap delete
   - Verify confirmation dialog appears
   - Confirm delete
   - Verify session removed from list

5. **Real-time Sync:**
   - Complete session on iOS
   - Verify appears in history within 1 second
   - Open web app
   - Verify session appears on web within 1 second

6. **Charts:**
   - Navigate to Statistics section
   - Verify daily practice chart shows last 30 days
   - Verify bars align with actual practice days
   - Verify activity breakdown chart shows all activities
   - Verify totals match ActivityStatisticsView

### 8.4 Validation Checklist

**Functional Requirements:**

- [ ] POST-01: Session summary displayed after completion (already in Phase 3)
- [ ] POST-02: Summary shows total time, per-activity breakdown, notes (already in Phase 3)
- [ ] POST-03: User can view session history list
- [ ] POST-04: User can tap session to see full details
- [ ] POST-06: Session history syncs real-time across web and iOS
- [ ] PLAT-04: Changes made on web appear on iOS in real-time
- [ ] PLAT-05: Changes made on iOS appear on web in real-time

**Phase 4 Success Criteria:**

1. [ ] User can view list of past practice sessions sorted by date (most recent first)
2. [ ] User can tap session to see full details (activities, times, notes)
3. [ ] User sees session summary immediately after completing practice (Phase 3)
4. [ ] Session summary shows all notes added during practice (Phase 3)
5. [ ] Session history syncs in real-time across web and iOS when online
6. [ ] User can filter session history by date range or activity (deferred - Phase 4 context says "no filtering in v1")
7. [ ] Statistics show meaningful practice trends (total time per activity, practice frequency)

**Non-Functional Requirements:**

- [ ] Query 100 sessions in <100ms
- [ ] Listener initial load in <200ms
- [ ] Delete session in <500ms
- [ ] Real-time sync latency <1 second
- [ ] No memory leaks (verified with Instruments)
- [ ] Offline-first behavior (cache-then-network)

---

## 9. Implementation Summary

### 9.1 New Components to Create

**Views:**
1. `SessionHistoryView.swift` - Main history list with day grouping
2. `SessionHistoryRow.swift` - Compact 2-line row component
3. `DailyPracticeChartView.swift` - Bar chart for daily practice time
4. `ActivityBreakdownChartView.swift` - Bar chart for activity totals
5. `StatisticsView.swift` - Container for charts and statistics

**ViewModels:**
1. `SessionHistoryViewModel.swift` - Manages session list and real-time sync

**Extensions:**
1. `TimeInterval+Formatting.swift` - Shared formatDuration helper

**Repository Methods (add to SessionRepository.swift):**
1. `getSessions(userId:limit:)` - Fetch ended sessions
2. `listenToSessions(userId:limit:completion:)` - Real-time listener
3. `getSessionActivities(userId:sessionId:)` - Fetch activities for session
4. `deleteSession(userId:sessionId:)` - Cascade delete session + activities

**Navigation Updates:**
1. Update `ContentView.swift` MainAppView to add History tab

### 9.2 Reused Components (No Changes)

**From Phase 3:**
- `SessionSummaryView.swift` - Display session details
- `String.toDate()` extension - Parse ISO 8601 timestamps

**From Phase 2:**
- `ActivityStatisticsView.swift` - Activity-level statistics
- `StatisticsRepository.swift` - Server-side aggregation queries

**From Phase 1:**
- `Date+ISO8601.swift` - Date/string conversion
- Firestore configuration with offline persistence

### 9.3 Configuration Changes

**firestore.indexes.json:**

Add composite index for session history query:

```json
{
  "collectionGroup": "sessions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "state", "order": "ASCENDING" },
    { "fieldPath": "startTime", "order": "DESCENDING" }
  ]
}
```

**No Firestore Rules Changes:** Existing rules already support session queries and deletion.

**No Data Model Changes:** Session and SessionActivity models support all requirements.

### 9.4 Dependencies

**Swift Charts Framework:**
- Built into iOS 16+ (no external dependencies)
- Import with `import Charts`
- Use BarMark for bar charts
- Customize with AxisMarks for labels

**Firebase iOS SDK:**
- Already integrated (Phase 1)
- Firestore queries: `.whereField()`, `.order(by:)`, `.limit(to:)`
- Real-time listeners: `.addSnapshotListener()`
- Batch operations: `db.batch()`

---

## 10. Critical Pitfalls to Avoid

### 10.1 Memory Leaks (from Phase 2 Research)

**PITFALL:** Forgetting to remove Firestore listeners in deinit

**SOLUTION:**

```swift
private var sessionsListener: ListenerRegistration?

deinit {
    sessionsListener?.remove()  // ALWAYS remove listeners
}
```

**VALIDATION:** Use Xcode Instruments > Leaks to verify no memory leaks during navigation.

### 10.2 Threading Violations (from Phase 2 Research)

**PITFALL:** Updating @Published properties from background thread

**SOLUTION:**

```swift
sessionsListener = repository.listenToSessions(...) { sessions in
    Task { @MainActor in  // Force main thread
        self?.sessions = sessions
    }
}
```

**VALIDATION:** Enable Thread Sanitizer in scheme settings, test for warnings.

### 10.3 N+1 Query Problem

**PITFALL:** Fetching activities for every session row in history list

**SOLUTION:** Lazy load activities only when user taps session (defer to detail view)

```swift
// DON'T: Fetch all activities upfront
for session in sessions {
    let activities = await repository.getSessionActivities(...)  // N queries!
}

// DO: Fetch on demand
.onTapGesture {
    let activities = await repository.getSessionActivities(...)  // 1 query
}
```

### 10.4 Missing Composite Index

**PITFALL:** Running query without creating Firestore index first

**SYMPTOM:** Error: "The query requires an index"

**SOLUTION:**

1. Add index to firestore.indexes.json
2. Deploy: `firebase deploy --only firestore:indexes`
3. Verify: `firebase firestore:indexes`

**PREVENTION:** Create index before implementing query (not after runtime error).

### 10.5 Cascade Delete Incomplete

**PITFALL:** Deleting session document without deleting activities subcollection

**SYMPTOM:** Orphaned activity documents remain in Firestore

**SOLUTION:** Always use batch delete:

```swift
let batch = db.batch()
// Delete all activities
for doc in activitiesSnapshot.documents {
    batch.deleteDocument(doc.reference)
}
// Delete session
batch.deleteDocument(sessionRef)
// Commit atomically
try await batch.commit()
```

### 10.6 Chart Data Preparation

**PITFALL:** Passing unsorted or incomplete data to Swift Charts

**SYMPTOM:** Chart displays with gaps or incorrect order

**SOLUTION:** Always sort data before charting:

```swift
// Daily practice chart: sort by date ascending (left to right)
.sorted { $0.date < $1.date }

// Activity breakdown: sort by hours descending (most-practiced first)
.sorted { $0.hours > $1.hours }
```

### 10.7 Listener Attachment Timing

**PITFALL:** Attaching listener in init instead of onAppear

**SYMPTOM:** Listener fires before view appears, multiple attachments on navigation

**SOLUTION:** Follow established pattern:

```swift
.onAppear {
    viewModel.startListening()  // NOT in init
}

func startListening() {
    guard !listenersStarted else { return }  // Prevent duplicates
    listenersStarted = true
    // Attach listener
}
```

**PATTERN SOURCE:** ActivityViewModel (Phase 2), SessionViewModel (Phase 3).

---

## RESEARCH COMPLETE

**Research Coverage:**

1. ✅ Implementation Approach - Session history list with day grouping, SwiftUI List patterns
2. ✅ Swift Charts Integration - BarMark, axis customization, data preparation
3. ✅ Firestore Queries - Query patterns, real-time listeners, delete cascade
4. ✅ Data Model & Schema - Session/SessionActivity structure, no changes needed
5. ✅ Reusable Components - SessionSummaryView, formatDuration, ActivityStatisticsView
6. ✅ Performance Considerations - Pagination, caching, N+1 prevention, query optimization
7. ✅ Real-time Sync - Listener architecture, MainActor threading, cross-platform validation
8. ✅ Validation Architecture - Unit tests, integration tests, UI tests, checklist

**Key Takeaways:**

- **Leverage existing patterns:** ActivityListView structure, SessionSummaryView reuse, StatisticsRepository aggregation
- **Swift Charts is simple:** BarMark + Chart container, built into iOS 16+
- **Real-time sync proven:** Same listener pattern as Phase 2/3, works cross-platform
- **Performance optimized:** Lazy load activities, server-side aggregation, indexed queries
- **No schema changes:** Session/SessionActivity models support all requirements
- **Memory management critical:** Always remove listeners in deinit

**Ready for Planning:** All research complete. Phase 4 can be planned with confidence using established patterns and proven approaches.
