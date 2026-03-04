# Phase 4: Session History & Statistics - Planning Summary

**Created:** 2026-03-04
**Phase:** 04-session-history-statistics
**Status:** Ready for execution

## Overview

Phase 4 delivers retrospective views of practice sessions through session history, detailed session views, and statistics visualizations. This phase enables users to review past practice patterns and see progress over time.

**Goal:** Users can review past practice sessions and see progress over time

**Success Criteria:**
1. User can view list of past practice sessions sorted by date (most recent first)
2. User can tap session to see full details (activities, times, notes)
3. User sees session summary immediately after completing practice (total time, per-activity breakdown)
4. Session summary shows all notes added during practice
5. Session history syncs in real-time across web and iOS when online
6. User can filter session history by date range or activity (deferred to v2 per 04-CONTEXT.md)
7. Statistics show meaningful practice trends (total time per activity, practice frequency)

## Phase Structure

### Plans Created: 4 plans in 3 waves

**Wave 1 (Foundation):**
- 04-01: Repository layer with query methods, TimeInterval extension, Firestore indexes

**Wave 2 (UI Layer - Parallel execution):**
- 04-02: Session history ViewModel and Views (list, row)
- 04-03: Statistics charts and container view

**Wave 3 (Integration & Verification):**
- 04-04: Navigation integration, index deployment, human verification checkpoint

### Plan Details

#### 04-01-PLAN: Repository Layer & Data Access (Wave 1)
**Type:** execute (autonomous)
**Dependencies:** None
**Files Modified:**
- Practice Timer/Core/Extensions/TimeInterval+Formatting.swift (new)
- Practice Timer/Core/Repositories/SessionRepository.swift
- firestore.indexes.json

**What It Does:**
- Creates shared TimeInterval.formatted() extension for duration display
- Adds SessionRepository methods: getSessions, listenToSessions, getSessionActivities, deleteSession
- Adds composite index for session history query (state + startTime)
- Implements cascade delete (session + activities subcollection)

**Key Patterns:**
- Async/await for all queries
- ListenerRegistration return for cleanup
- compactMap for resilient decoding
- Batch operations for cascade delete
- Composite index for efficient queries

**Requirements Addressed:** POST-03, POST-04, POST-06, PLAT-04, PLAT-05

---

#### 04-02-PLAN: Session History ViewModel & Views (Wave 2)
**Type:** execute (autonomous)
**Dependencies:** 04-01
**Files Modified:**
- Practice Timer/Features/Sessions/ViewModels/SessionHistoryViewModel.swift (new)
- Practice Timer/Features/Sessions/Views/SessionHistoryView.swift (new)
- Practice Timer/Features/Sessions/Views/SessionHistoryRow.swift (new)

**What It Does:**
- Creates SessionHistoryViewModel with day grouping logic (Today, Yesterday, date)
- Creates SessionHistoryView with day-grouped list, swipe-to-delete, navigation
- Creates SessionHistoryRow with compact 2-line display (time, duration, activity preview, notes indicator)
- Implements lazy loading of activities to avoid N+1 queries
- Reuses SessionSummaryView from Phase 3 for session detail

**Key Patterns:**
- DayGroup computed property for reactive UI updates
- Dictionary(grouping:) for efficient day grouping
- Calendar.current for timezone-aware date comparison
- LazySessionHistoryRow for on-demand activity loading
- NavigationStack + List + sections pattern from Phase 2
- Sheet presentation for detail view
- allowsFullSwipe: false on delete action

**Requirements Addressed:** POST-03, POST-04, POST-06, PLAT-04, PLAT-05

---

#### 04-03-PLAN: Statistics Charts & Visualization (Wave 2)
**Type:** execute (autonomous)
**Dependencies:** 04-01
**Files Modified:**
- Practice Timer/Features/Statistics/Views/DailyPracticeChartView.swift (new)
- Practice Timer/Features/Statistics/Views/ActivityBreakdownChartView.swift (new)
- Practice Timer/Features/Statistics/Views/StatisticsView.swift (new)

**What It Does:**
- Creates DailyPracticeChartView: bar chart showing practice time per day (last 30 days)
- Creates ActivityBreakdownChartView: horizontal bar chart showing total time per activity
- Creates StatisticsView: combines charts with "This Week" summary (total time + session count)
- Links to existing ActivityStatisticsView from Phase 2

**Key Patterns:**
- Swift Charts framework (iOS 16+ native)
- BarMark with gradient fills
- Dictionary(grouping:) for data aggregation
- Calendar arithmetic for date ranges
- Dynamic chart height based on data count
- Empty states for no data scenarios
- Card-like layout with padding and backgrounds

**Requirements Addressed:** POST-01, POST-02

---

#### 04-04-PLAN: Navigation Integration & Verification (Wave 3)
**Type:** execute (requires human verification)
**Dependencies:** 04-02, 04-03
**Files Modified:**
- Practice Timer/ContentView.swift
- firestore.indexes.json (deployment)

**What It Does:**
- Adds History and Statistics tabs to MainAppView
- Integrates SessionHistoryView and StatisticsView into TabView navigation
- Creates shared ViewModels for data reuse between tabs
- Deploys Firestore indexes to Firebase
- Human verification checkpoint tests all Phase 4 features

**Key Patterns:**
- Shared @StateObject ViewModels across tabs
- NavigationStack wrapper for StatisticsView
- Tab order: Activities, Practice, History, Statistics, Settings
- Firebase index deployment and verification
- Comprehensive human testing checklist

**Human Verification Tests:**
1. Session history list display and day grouping
2. Session detail navigation (SessionSummaryView)
3. Swipe-to-delete with confirmation
4. Empty states
5. Statistics view with charts and week summary
6. Real-time sync between iOS and web
7. Offline mode with cached data
8. Memory leak detection with Instruments

**Requirements Addressed:** POST-01, POST-02, POST-03, POST-04, POST-06, PLAT-04, PLAT-05

---

## Requirements Coverage

### Phase 4 Requirements (7 total)

**POST-01:** User can view practice session summary after completion
- Addressed in: 04-03 (StatisticsView week summary), Phase 3 (SessionSummaryView)

**POST-02:** Summary shows total time, per-activity time, and notes
- Addressed in: 04-03 (charts), Phase 3 (SessionSummaryView detail)

**POST-03:** User can view session history (list of past practice sessions)
- Addressed in: 04-01 (queries), 04-02 (SessionHistoryView), 04-04 (navigation)

**POST-04:** User can view details of past practice session
- Addressed in: 04-01 (getSessionActivities), 04-02 (SessionSummaryView navigation), 04-04 (integration)

**POST-06:** Session history syncs in real-time across web and iOS when online
- Addressed in: 04-01 (listenToSessions), 04-02 (real-time listener), 04-04 (human verification)

**PLAT-04:** Changes made on web app appear on iOS in real-time when online
- Addressed in: 04-01 (listener), 04-02 (ViewModel), 04-04 (verification)

**PLAT-05:** Changes made on iOS appear on web app in real-time when online
- Addressed in: 04-01 (Firestore writes), 04-02 (deleteSession), 04-04 (verification)

**Coverage:** 7/7 requirements mapped (100%)

---

## Technical Decisions

### Data Access
- **Session history query:** Filter by state == "ended", order by startTime descending, limit 100
- **Real-time sync:** Firestore snapshot listeners with ListenerRegistration cleanup
- **Cascade delete:** Batch operation deletes activities subcollection then session document
- **Lazy loading:** Fetch session activities on-demand when row tapped (avoid N+1 queries)
- **Composite index:** Required for whereField + order query (state + startTime)

### UI/UX
- **Day grouping:** Today, Yesterday, or "Monday, Mar 3" format
- **Session rows:** Compact 2-line layout (time/duration, activity preview)
- **Notes indicator:** Icon badge if session contains notes
- **Navigation:** Sheet presentation for SessionSummaryView (reuse from Phase 3)
- **Delete confirmation:** Alert dialog prevents accidental deletion (allowsFullSwipe: false)
- **Empty states:** Friendly messages guide users when no data exists

### Statistics
- **Charts:** Swift Charts framework (iOS 16+ native, no third-party dependencies)
- **Daily practice:** Bar chart, last 30 days, grouped by calendar day
- **Activity breakdown:** Horizontal bar chart, sorted by most-practiced first
- **Week summary:** Total time + session count for last 7 days
- **Data aggregation:** Dictionary(grouping:) for efficient grouping
- **Colors:** Blue for time metrics, green for counts, gradient fills for visual polish

### Memory Management
- **Listener cleanup:** Remove ListenerRegistration in ViewModel deinit
- **Weak self:** [weak self] in listener closures to prevent retain cycles
- **MainActor:** Task { @MainActor } wrapper for background listener callbacks
- **Shared ViewModels:** @StateObject in MainAppView persists across tab switches

### Performance
- **Firestore offline cache:** Sessions cached locally for instant offline access
- **Pagination ready:** getSessions supports limit parameter (default 100, expandable)
- **Lazy loading:** Activities fetched only when needed (not all upfront)
- **Server-side filtering:** Firestore filters by state before returning documents
- **Indexed queries:** Composite index enables fast filtering + ordering

---

## Reused Components

### From Phase 3
- **SessionSummaryView:** Display session details (reused unchanged)
- **Session/SessionActivity models:** Data structures for sessions
- **Date+ISO8601 extension:** ISO 8601 string parsing

### From Phase 2
- **ActivityStatisticsView:** Server-side aggregation for activity stats
- **ActivityListView patterns:** NavigationStack + List + sections structure
- **ActivityViewModel patterns:** Listener management and cleanup
- **StatisticsRepository:** Firestore aggregation queries

### From Phase 1
- **Repository pattern:** Protocol + concrete implementation
- **Async/await:** No completion handlers
- **Firestore offline persistence:** Already enabled
- **ISO 8601 timestamps:** Consistent date format

---

## New Components Created

### Extensions
- TimeInterval+Formatting.swift: Shared duration formatting (e.g., "1h 15m 30s")

### Repository Methods
- SessionRepository.getSessions: Query ended sessions
- SessionRepository.listenToSessions: Real-time listener for history
- SessionRepository.getSessionActivities: Fetch activities for session
- SessionRepository.deleteSession: Cascade delete session + activities

### ViewModels
- SessionHistoryViewModel: State management, day grouping, listener cleanup
- DayGroup struct: Day grouping data structure

### Views
- SessionHistoryView: Day-grouped list with navigation
- SessionHistoryRow: Compact 2-line session display
- DailyPracticeChartView: 30-day practice bar chart
- ActivityBreakdownChartView: Activity totals horizontal bar chart
- StatisticsView: Charts + week summary container

### Navigation
- History tab in MainAppView
- Statistics tab in MainAppView
- Shared ViewModels across tabs

### Configuration
- Composite Firestore index: sessions (state + startTime)

---

## Dependencies & Execution Order

### Wave 1 (Foundation)
```
04-01-PLAN (Repository & Extensions)
```

### Wave 2 (UI - Parallel Execution)
```
04-01 → 04-02-PLAN (History Views)
04-01 → 04-03-PLAN (Statistics Views)
```

### Wave 3 (Integration)
```
04-02 + 04-03 → 04-04-PLAN (Navigation & Verification)
```

**Total estimated execution time:** 60-90 minutes
- Wave 1: 20 minutes (repository methods, extension)
- Wave 2: 30-40 minutes (parallel: history views + charts)
- Wave 3: 10-30 minutes (navigation integration + human verification)

---

## Known Limitations & Future Enhancements

### Deferred to Future Phases
1. **Session filtering:** Date range and activity filters (Phase 4 context says "no filtering in v1")
2. **Session search:** Search by activity name or notes content
3. **Pagination:** Load more than 100 sessions (infrastructure ready, UI not needed yet)
4. **Session editing:** Edit past session notes or activities (read-only in v1)
5. **Export:** Export session history as CSV/PDF

### Phase 3 Dependencies
- **ActivityBreakdownChartView:** May show empty state initially because it needs SessionActivity subcollection data (structure ready for when data available)
- **Session activity details:** Full session breakdown requires Phase 3's SessionActivity subcollection

### Performance Considerations
- **N+1 queries:** Mitigated with lazy loading (activities fetched on tap, not upfront)
- **Large datasets:** 100-session limit prevents performance issues, pagination ready if needed
- **Chart rendering:** Swift Charts optimized automatically, no manual tuning needed

---

## Critical Patterns to Maintain

### Memory Management
```swift
// ALWAYS remove listeners in deinit
deinit {
    sessionsListener?.remove()
}
```

### Threading
```swift
// ALWAYS wrap listener callbacks with MainActor
sessionsListener = repository.listenToSessions(...) { sessions in
    Task { @MainActor in
        self?.sessions = sessions
    }
}
```

### Data Grouping
```swift
// Use Dictionary(grouping:) for efficient grouping
let grouped = Dictionary(grouping: sessions) { session -> String in
    // Grouping logic
}
```

### Cascade Delete
```swift
// ALWAYS use batch for cascade operations
let batch = db.batch()
for doc in activitiesSnapshot.documents {
    batch.deleteDocument(doc.reference)
}
batch.deleteDocument(sessionRef)
try await batch.commit()
```

### Empty States
```swift
// ALWAYS provide helpful empty state messages
ContentUnavailableView(
    "No Practice History",
    systemImage: "calendar",
    description: Text("Start a practice session to see your history")
)
```

---

## Verification Checklist

### Functional Requirements
- [ ] Session history displays with day grouping (Today, Yesterday, dates)
- [ ] Sessions sorted newest first within each day
- [ ] Tap session opens SessionSummaryView with full details
- [ ] Swipe-to-delete works with confirmation dialog
- [ ] Empty state shown when no sessions exist
- [ ] Daily practice chart shows last 30 days
- [ ] Activity breakdown chart shows activity totals (if data available)
- [ ] Week summary shows accurate time and session count
- [ ] Navigation to ActivityStatisticsView works
- [ ] Real-time sync updates history when sessions added/deleted

### Non-Functional Requirements
- [ ] Real-time sync latency < 1 second
- [ ] Query 100 sessions in < 100ms
- [ ] Delete session in < 500ms
- [ ] No memory leaks (verified with Instruments)
- [ ] Offline-first behavior (cache-then-network)
- [ ] Smooth 60fps scrolling in history list
- [ ] Firestore indexes deployed and enabled

### Cross-Platform Sync
- [ ] Session created on web appears on iOS
- [ ] Session created on iOS appears on web
- [ ] Session deleted on web removed from iOS
- [ ] Session deleted on iOS removed from web
- [ ] Sync works within 1-2 seconds when online

---

## Next Steps After Phase 4

1. **Execute Phase 4 plans:**
   - Run `/gsd:execute-phase 4` to start wave-based execution
   - Plans will run in order: 04-01 → (04-02 + 04-03) → 04-04
   - Human verification checkpoint in 04-04 must be approved

2. **Update STATE.md:**
   - Mark Phase 4 as complete
   - Update progress metrics (4/7 phases complete)
   - Update accumulated context with Phase 4 decisions

3. **Proceed to Phase 5:**
   - Plan Phase 5: Smart Features & Polish
   - Smart suggestions based on practice history
   - Visual progress enhancements
   - Session setup optimizations

---

## Planning Notes

**Phase 4 Structure Rationale:**
- Wave 1 establishes data access foundation (queries, indexes)
- Wave 2 enables parallel development of history views and statistics (different file sets)
- Wave 3 integrates both features into navigation and verifies complete system
- Human verification checkpoint ensures real-time sync and performance meet requirements

**Key Research Insights Applied:**
- Swift Charts framework (iOS 16+) eliminates third-party chart dependencies
- Lazy loading prevents N+1 query problem in history list
- Dictionary(grouping:) provides efficient day grouping
- Composite indexes required for multi-field queries (state + startTime)
- Batch operations ensure atomic cascade deletes

**Pattern Consistency:**
- Follows ActivityListView structure for familiar UX
- Reuses SessionSummaryView from Phase 3 (no duplication)
- Maintains Phase 2 listener cleanup patterns
- Continues Phase 1 async/await and repository patterns

---

*Planning complete: 2026-03-04*
*Ready for execution: Phase 4*
