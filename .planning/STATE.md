---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 03
current_plan: 05
status: in_progress
last_updated: "2026-03-04T00:45:01Z"
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 15
  completed_plans: 13
  percent: 87
---

# Project State: Practice Timer iOS

**Last Updated:** 2026-03-04
**Current Phase:** 03
**Current Plan:** 03-05-PLAN.md (complete)
**Status:** In progress

---

## Project Reference

**Core Value:**
Musicians can reliably track their practice sessions with accurate timing, notes, and history that syncs seamlessly between web and iOS platforms. If the timer works, notes save, and data syncs, everything else is secondary.

**Current Focus:**
Roadmap complete with 7 phases derived from 53 v1 requirements. Next step: Plan Phase 1 (Foundation & Authentication) to establish Firebase setup, auth flows, data models with subcollections, and security rules.

**Key Constraints:**
- iOS 16+ minimum (modern SwiftUI features)
- Native SwiftUI (not React Native/Capacitor)
- Must use existing Firebase backend for cross-platform sync
- Timer must handle iOS backgrounding (date-based calculations)
- Data model must use subcollections (avoid 1MB document limit)
- Sign in with Apple required (App Store guidelines)
- Offline-first with automatic sync when online

---

## Current Position

**Phase:** 03-session-setup-execution
**Plan:** 03-06-PLAN.md (next)
**Status:** Phase 3 In Progress - ActiveSessionView complete
**Progress:** [████████▒▒] 83% (5/6 plans)

**Phase 3 Goal:** Users can plan and execute timed practice sessions with accurate timing that survives backgrounding

**Phase 1 Success Criteria:**
1. User can sign up with email/password and immediately access their account
2. User can sign in with Google OAuth and see their existing data (if migrating from web)
3. User can sign in with Sign in with Apple and account is created successfully
4. User session persists across app restarts (no re-login required)
5. User can sign out from any screen and returns to login
6. User can reset password via email link and receive reset instructions
7. Firebase security rules prevent unauthorized data access (tested and validated)
8. App continues to function when device is offline (auth state persists locally)

---

## Performance Metrics

**Phases:**
- Total: 7
- Completed: 2 (Phases 1-2)
- In Progress: 1 (Phase 3)
- Not Started: 4

**Requirements:**
- Total v1: 53
- Completed: 24 (Phase 1: 8, Phase 2: 10, Phase 3: 6)
- In Progress: 13 (Phase 3 remaining)
- Coverage: 100% (all mapped to phases)

**Velocity:**
- Plans per session: 1-4
- Average plan completion time: 3 minutes
- Blockers encountered: 0

**Recent Plans:**
| Plan | Duration | Tasks | Files | Completed |
|------|----------|-------|-------|-----------|
| 03-05 | 3 min | 2 | 2 | 2026-03-04 |
| 03-04 | 8 min | 2 | 4 | 2026-03-04 |
| 03-03 | 0 min | 1 | 1 | 2026-03-04 |
| 03-02 | 30 min | 1 | 2 | 2026-03-04 |
| 03-01 | 2 min | 2 | 2 | 2026-03-03 |
| 02-04 | 15 min | 4 | 7 | 2026-03-03 |
| 02-03 | 7 min | 3 | 6 | 2026-03-03 |
| 02-02 | 74 min | 3 | 3 | 2026-03-03 |

## Accumulated Context

### Critical Decisions

**Plan 03-05 Decisions:**
- @ObservedObject (not @StateObject) for SessionViewModel because VM created in SessionSetupView - orchestrator doesn't own the ViewModel
- ScrollView layout handles keyboard appearance when adding notes and accommodates long activity queues without layout breaks
- scenePhase .onChange(of:) calls refreshTimerIfNeeded() when returning to foreground (oldPhase == .background && newPhase == .active) - critical for timer survival after iOS backgrounding
- Manual "Start Next Activity" button when sessionState == .inBetween gives user control over break length (not auto-start) - user determines when break is over
- Sheet presentation for SessionSummaryView (dismissible modal after session ends) using @State showingSummary flag
- VStack spacing: 30 provides generous touch targets for operation while holding instrument
- IndexSet.first conversion for reorderActivities callback (ActivityQueueView passes IndexSet from .onMove, SessionViewModel expects Int)
- String.toDate() extension for ISO 8601 timestamp parsing in SessionSummaryView (converts Firestore strings to Date for display)
- Human-readable duration format (10h 15m 30s) instead of HH:MM:SS for better readability in session summary
- Separate sections in summary for total time, activity breakdown, and break time (filter isInBetweenTime activities into distinct "Break Time" section)
- Display notes inline with each activity in summary (no separate section needed for better context)
- ProgressView with viewModel.progress shows session completion percentage (currentActivityIndex / activities.count) throughout practice

**Plan 03-03 Decisions:**
- Tap-to-select interface achieves 3-tap session creation (tap activity 1, tap activity 2, tap Start) vs web app's 6+ interactions through multi-step form
- Selection order becomes session order automatically (orderedActivities array appends on selection) - no manual reorder required for typical use
- EditButton for optional reordering (only shown when activities selected) follows iOS List editing patterns with .onMove modifier
- selectedActivityIds Set provides O(1) selection state lookup (critical performance for 20+ activities) vs O(n) array search
- NavigationLink with isActive binding enables programmatic navigation after async sessionViewModel.startSession() without manual NavigationPath management
- ContentUnavailableView empty state guides first-time users to Activities tab when no activities exist
- .contentShape(Rectangle()) makes entire row tappable (large touch target) for faster selection

**Plan 03-04 Decisions:**
- 80pt font size for timer display (readable from 10 feet per PROJECT.md requirement) combined with .monospaced design and .monospacedDigit() prevents width jitter when digits change
- .controlSize(.large) ensures 60pt+ touch targets necessary for operation while holding instrument (EXEC-14 requirement)
- State-dependent button display (only show relevant actions based on SessionState) prevents showing irrelevant controls to user
- Closure-based callbacks (components receive closures, not ViewModel references) enables testability and prevents tight coupling
- Append mode for notes (doesn't replace existing notes) allows user to add multiple notes during same activity
- EditButton for reorder mode (consistent with iOS patterns) vs custom drag handles for familiar UX
- maxHeight constraint on queue (prevent list from dominating screen) maintains balanced layout during session
- Component Extraction Pattern: < 150 lines per component, single responsibility, clear prop interfaces following research Pattern 4 from 03-RESEARCH.md

**Plan 03-02 Decisions:**
- Date-based timer calculation (pausedElapsedTime + Date().timeIntervalSince(startTime)) survives iOS backgrounding because elapsed time is recalculated from Date difference, not incremented on timer ticks
- Timer.publish(on: .main, in: .common) uses .common RunLoop mode (not .default) to prevent timer freezing during scrolling, typing, and user interaction (critical for iOS UX)
- Immediate Firestore persistence on all state changes (pause, skip, note) enables crash recovery - if app crashes, user can resume from last persisted state
- SessionState enum manages lifecycle transitions (setup → active → paused → inBetween → ended) with state-driven timer control
- pausedElapsedTime preserves accumulated time across multiple pause/resume cycles without drift
- refreshTimerIfNeeded() restarts timer on foreground return if sessionState is active (timer publisher is cancelled when app backgrounds)
- [weak self] in timer sink closure prevents retain cycles (timer publisher holds strong reference to closure)
- reorderActivities(from: Int, to: Int) uses Int indices (not IndexSet) to avoid SwiftUI dependency in ViewModel (separation of concerns)

**Plan 03-01 Decisions:**
- Used string values for Session.state field ("setup", "active", "paused", "inBetween", "ended") matching web app format for cross-platform sync compatibility
- Made SessionActivity.activityId optional to support in-between time tracking where activityId=nil and isInBetweenTime=true
- Denormalized activityName in SessionActivity to enable history display without joining Activity documents
- Implemented getActiveSession() querying state != "ended" to find interrupted sessions on app launch for crash recovery
- Used [String: Any] dictionary in updateSessionState() for flexible atomic updates (can update state alone or multiple fields together)
- Followed Phase 2 ActivityRepository patterns: return ListenerRegistration for memory management, use compactMap for resilience

**Plan 02-04 Decisions:**
- Used Firestore aggregation queries (.sum, .count) for server-side statistics calculation, saving 99% of reads compared to downloading all session documents
- Forced .server source for aggregation to ensure accurate calculation from server data, not stale cache
- Wrapped all listener closure callbacks with MainActor.run to ensure @Published property updates occur on main thread (prevents threading violations)
- Created composite indexes for userId+activityId+archived queries (required for real-time listeners) via firestore.indexes.json
- Documented index deployment in FIREBASE_SETUP.md with verification commands
- Added comprehensive debug logging to trace listener lifecycle (attach/detach/deinit) for memory leak detection

**Plan 02-03 Decisions:**
- Used nonisolated init to allow ActivityRepository() default parameter without actor isolation conflicts
- Created new Activity instance in updateActivity (not mutation) because name and category are immutable let properties
- Used @StateObject for ActivityViewModel ownership in ActivityListView, @ObservedObject for passed ViewModel in ArchivedActivityListView
- Stored ListenerRegistration in ViewModel properties and removed in deinit to prevent memory leaks (critical pattern from Phase 1 research)
- Used [weak self] in listener closures to prevent retain cycles
- Called startListening() in onAppear (not init) to ensure listeners attach when view appears on screen
- Configured allowsFullSwipe: false on delete swipe action to prevent accidental data loss
- Updated ActivityFormView to use onSave closure pattern for clean ViewModel integration

**Plan 02-02 Decisions:**
- Used String rawValues matching web app exactly (Instrument, Piece, Theory, Warm-up with hyphen) for cross-platform sync compatibility
- Chose SF Symbols over custom icons for native iOS feel and accessibility support
- Made ActivityCategory conform to Identifiable with id=rawValue for SwiftUI Picker compatibility without manual tagging
- Used .menu picker style (not .wheel or .segmented) for compact representation with 6 options
- Validated name with .trimmingCharacters(in: .whitespaces).isEmpty to catch whitespace-only input
- Left save action as TODO for Plan 02-03 when ActivityViewModel is created (clear handoff point)

**Plan 02-01 Decisions:**
- Used ListenerRegistration return type (not void) so ViewModels can store handle and call remove() in deinit for proper cleanup
- Implemented archive/restore as separate methods (not generic update) for clear intent and automatic timestamp updates
- Used compactMap in listeners to skip malformed documents rather than failing entire query
- Separated archive (soft delete) from delete (hard delete) for data safety and user experience
- Added missingDocumentId case to shared RepositoryError enum for consistency across repositories
- Used mock repository pattern for unit tests (not Firebase emulator) to avoid external dependencies and enable fast CI/CD

**Plan 01-04 Decisions:**
- Used rules_version = '2' for recursive wildcard support (match /{document=**})
- Implemented field validation helpers (hasRequiredUserFields, etc.) to prevent malicious clients from omitting required fields
- Configured Firebase Emulator Suite for safe local testing before production deployment
- Deployed security rules to production after manual testing via human verification checkpoint

**Plan 01-03 Decisions:**
- Added CLIENT_ID and REVERSED_CLIENT_ID to GoogleService-Info.plist for OAuth redirect configuration
- Used INFOPLIST_KEY_CFBundleURLTypes in project.pbxproj instead of separate Info.plist to avoid build conflicts
- AuthViewModel inherits from NSObject to conform to ASAuthorizationControllerDelegate for Apple Sign-In
- Used withCheckedThrowingContinuation to bridge GIDSignIn callback-based API to async/await pattern
- Used OAuthProvider.appleCredential with fullName parameter to preserve display name on first sign-in

**Plan 01-02 Decisions:**
- Used Combine import for @Published property wrapper in AuthViewModel (required for ObservableObject)
- Made User conform to Equatable for SwiftUI onChange compatibility (automatic synthesis)

**Plan 01-01 Decisions:**
- Used @UIApplicationDelegateAdaptor pattern to ensure Firebase configures before SwiftUI view initialization
- Stored timestamps as ISO 8601 strings (not Date or Firestore Timestamp) to match web app format exactly
- Designed data models for subcollections (users/{userId}/activities, users/{userId}/sessions) to avoid 1MB document limit
- Implemented protocol-based repository pattern for testability (ViewModels depend on protocols, not concrete classes)
- Used async/await throughout (not completion handlers) as Firebase SDK supports it natively

**Architecture Decisions (from research):**
- **Stack:** SwiftUI + Firebase iOS SDK 12.10.0+, Swift 6.x, iOS 16+ minimum
- **Architecture:** MVVM + Repository pattern for data access
- **Persistence:** Firestore offline persistence ONLY (no SwiftData/Core Data dual layer)
- **Timer:** Date-based calculations (not tick counters) to survive backgrounding
- **Data Model:** Use subcollections for scalable collections (avoid 1MB document limit)

**Phase Structure Rationale:**
- Phase 1 establishes critical foundations (auth, timer architecture, data model, security rules) that are expensive/impossible to retrofit later
- Phase 2 validates repository pattern and offline sync before complex features
- Phase 3 delivers core value (timer + sessions) with proper iOS backgrounding
- Phase 4-5 build on session history for statistics and smart suggestions
- Phase 6 adds platform polish (iPad, offline indicators)
- Phase 7 handles App Store submission requirements

### Active TODOs

**Immediate (Next Session):**
- [x] Execute Plan 01-02 (Email/password authentication and auth state routing) - COMPLETED
- [x] Execute Plan 01-03 (Google OAuth and Sign in with Apple) - COMPLETED
- [x] Execute Plan 01-04 (Firestore security rules, emulator testing, human verification) - COMPLETED
- [ ] Plan Phase 2 (Activities & Offline Sync)

**Upcoming:**
- [ ] Phase 2: Establish memory management patterns (Firebase listener cleanup)
- [ ] Phase 3: Timer component architecture (avoid massive view files)
- [ ] Phase 5: Design smart suggestion algorithm (recency/frequency scoring)

**Backlog:**
- [ ] Phase 6: iPad adaptive layout design
- [ ] Phase 7: Create privacy policy content
- [ ] Phase 7: App Store screenshot planning

### Known Blockers

None currently. Roadmap validated with 100% requirement coverage.

### Research Notes

**Critical Pitfalls to Address (from research):**
1. **Timer backgrounding fails** - Store start time as Date, calculate elapsed from difference (Phase 1)
2. **Firestore offline persistence misunderstood** - Monitor 100MB cache limit, use keepSynced() for critical collections (Phase 1-2)
3. **Security rules assume client validation** - Mirror validation in Firestore rules, test with emulator (Phase 1)
4. **Firebase listener memory leaks** - Store ListenerRegistration, call remove() in deinit (Phase 2)
5. **Massive view files** - Extract components under 300 lines each (Phase 3)
6. **Timer RunLoop misconfigured** - Use .common mode explicitly (Phase 3)
7. **Sign in with Apple incomplete** - Handle all error codes, test on device (Phase 1)
8. **Firestore document size limit** - Use subcollections for arrays that could exceed 20 items (Phase 1)

**Research Flags for Planning:**
- Phase 5 smart suggestions need algorithm design (recency, frequency, time-since-last-practice heuristics)
- All other phases use standard patterns with comprehensive documentation

---

## Session Continuity

**Last Session Summary:**
- Completed Plan 03-05 (ActiveSessionView orchestration and SessionSummaryView)
- Created ActiveSessionView composing TimerDisplayView, SessionControlsView, SessionNotesView, ActivityQueueView
- Implemented scenePhase monitoring with .onChange calling refreshTimerIfNeeded() for background survival
- Added ProgressView showing session completion percentage throughout practice
- Manual "Start Next Activity" button provides user control over break duration
- Created SessionSummaryView displaying post-session breakdown with total time, activities, and breaks
- Human-readable duration format (Xh Ym Zs) for better readability in summary
- Sheet presentation for SessionSummaryView after session ends
- Requirements completed: EXEC-10
- **Plan 03-05 Complete:** End-to-end session flow ready from setup through execution to summary

**Next Session Start Here:**
1. Execute Plan 03-06 (Activity Completion & Persistence)
2. Persist completed activities to Firestore when session ends
3. Handle activity completion state transitions
4. Verify crash recovery and data persistence patterns
5. Complete Phase 3 with full session lifecycle implementation

**Context for Handoff:**
- Project type: Native iOS app (SwiftUI) with Firebase backend
- Existing web app with same Firebase backend (must maintain data compatibility)
- Key differentiation: Simplified session setup, smart suggestions, iOS-native timer optimized for practice use
- Target users: Musicians who practice regularly, need timer visible from distance
- Critical constraint: Timer must survive backgrounding (iOS suspends after 30 seconds)

---

*State initialized: 2026-03-01*
*Next action: `/gsd:plan-phase 1`*
