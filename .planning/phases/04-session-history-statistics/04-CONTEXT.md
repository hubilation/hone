# Phase 4: Session History & Statistics - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can review past practice sessions in a chronological history list, see detailed breakdowns of each session, and view practice statistics with basic charts showing practice patterns over time. This phase delivers retrospective views - not real-time session tracking (that's Phase 3).

</domain>

<decisions>
## Implementation Decisions

### History List Layout
- Compact rows with 2 lines per session (balance of info and density)
  - Line 1: date/time and duration
  - Line 2: activity preview (e.g., "3 activities: Scales, Arpeggios...")
- Show date & time (relative for recent: "Today, 3:45 PM", absolute for older: "Mar 2, 10:00 AM")
- Show total duration using existing formatDuration helper (e.g., "1h 15m 30s")
- Show activity count and preview (first 2-3 activities then "..." for longer lists)
- Include notes indicator (icon/badge) if session has notes
- Follow iOS List patterns (like ActivityListView in Phase 2)

### Session Organization
- Grouped by day with iOS-native sections ("Today", "Yesterday", "Monday, Mar 3")
- No filtering in v1 - keep simple with chronological display
- No search capability in v1 - day grouping sufficient for finding sessions
- Load last 100 sessions by default (session-based limit, not date-based)
- Newest sessions first within each day section

### Statistics Visualization
- Include basic bar charts using Swift Charts (iOS 16+ native)
- Two separate chart views:
  1. Daily practice chart: Practice time by day over last 30 days
  2. Activity breakdown chart: Total practice time per activity
- Display charts in dedicated Statistics section/tab
- Continue using Phase 2's ActivityStatisticsView for activity-level stats (already implemented with Firestore aggregation)
- Recent practice summary with simple numbers: "This Week: 5h 30m, 8 sessions"

### Session Detail Interaction
- Tap session row to show SessionSummaryView (reuse existing view from Phase 3 for consistency)
- Swipe to delete with confirmation dialog (prevent accidental deletion)
- Allow editing activity notes in past sessions (add "Edit" button in SessionSummaryView when viewing history)
- Update updatedAt timestamp when notes are edited
- Navigation: Add "History" tab to main TabView alongside Activities and Sessions

### Claude's Discretion
- Exact grouping logic for "Today", "Yesterday" vs absolute dates
- Empty state message when no session history exists yet
- Loading states while fetching session history
- Error handling for failed Firestore queries
- Pagination implementation if user has >100 sessions
- Chart axis labels and formatting details
- Color scheme for charts (follow iOS native palette)
- Confirmation dialog text for session deletion

</decisions>

<specifics>
## Specific Ideas

- Reuse SessionSummaryView from Phase 3 unchanged - consistency between post-session view and history detail
- Phase 2's ActivityStatisticsView already shows total time per activity - keep using that pattern
- Swift Charts is iOS 16+ native - fits our iOS 16+ minimum requirement
- formatDuration helper already exists in SessionSummaryView - reuse for history rows
- Follow ActivityListView pattern: NavigationStack + List + sections + swipe actions

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- **SessionSummaryView** (Practice Timer/Features/Sessions/Views/SessionSummaryView.swift): Already displays post-session breakdown with total time, per-activity times, notes, and break time. Reuse unchanged for session detail view.
- **formatDuration helper** (in SessionSummaryView): Converts TimeInterval to human-readable format ("1h 15m 30s"). Use for history row durations.
- **ActivityListView pattern** (Practice Timer/Features/Activities/Views/ActivityListView.swift): NavigationStack + List + swipe actions + empty state with ContentUnavailableView. Follow same pattern for history list.
- **ActivityStatisticsView** (Practice Timer/Features/Activities/Views/ActivityStatisticsView.swift): Already displays activity-level stats using Firestore aggregation. Continue using for activity statistics.
- **Date+ISO8601 extension** (Practice Timer/Core/Extensions/Date+ISO8601.swift): Converts ISO 8601 strings to Date for display formatting.
- **String.toDate() extension** (in SessionSummaryView): Parses ISO 8601 timestamps for date formatting.

### Established Patterns
- **Repository pattern**: SessionRepository already exists with async/await operations and real-time listeners
- **MVVM architecture**: ViewModels with @Published properties, SwiftUI views as observers
- **List-based navigation**: NavigationStack with List, NavigationLink for drill-down
- **Listener cleanup**: Store ListenerRegistration in ViewModel, call remove() in deinit
- **Empty states**: ContentUnavailableView for empty lists (see ActivityListView)
- **Swipe actions**: .swipeActions(edge: .trailing, allowsFullSwipe: false) for delete/archive
- **ISO 8601 timestamps**: All Firestore dates stored as ISO 8601 strings matching web app

### Integration Points
- **SessionRepository**: Add new methods for fetching session history:
  - `func getSessions(userId: String, limit: Int) async throws -> [Session]` (ordered by startTime descending, filtered by state == "ended")
  - `func listenToSessions(userId: String, limit: Int, completion: @escaping ([Session]) -> Void) -> ListenerRegistration` (real-time updates)
  - `func deleteSession(userId: String, sessionId: String) async throws` (for swipe-to-delete)
  - `func updateSessionActivityNotes(userId: String, sessionId: String, activityId: String, notes: String) async throws` (for editing notes)
- **Main TabView**: Add new "History" tab (currently has Activities and Sessions tabs)
- **Swift Charts framework**: Import Charts framework for bar chart visualizations
- **Session model**: Already has all needed fields (startTime, endTime, totalDuration, state)
- **SessionActivity model**: Already has notes field that can be updated

### Data Model Reference
```swift
// Session path: users/{userId}/sessions/{sessionId}
// Query: .whereField("state", isEqualTo: "ended")
//        .order(by: "startTime", descending: true)
//        .limit(to: 100)

// SessionActivity path: users/{userId}/sessions/{sessionId}/activities/{activityId}
// Fields needed: activityName, duration, notes, isInBetweenTime
```

</code_context>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---

*Phase: 04-session-history-statistics*
*Context gathered: 2026-03-03*
