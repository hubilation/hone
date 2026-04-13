---
phase: 03-session-setup-execution
plan: 02
subsystem: viewmodel
tags: [timer, combine, state-machine, backgrounding, crash-recovery]

# Dependency graph
requires:
  - phase: 03-01
    provides: Session/SessionActivity models, SessionRepository with state management
  - phase: 02-activity-management
    provides: ActivityViewModel pattern, real-time listeners, memory management
provides:
  - SessionViewModel with date-based timer architecture
  - State machine managing session lifecycle
  - Firestore persistence on all state changes
  - Background/foreground handling
affects: [03-03, 03-04, 03-05, 03-06, 04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Date-based timer calculation (survives backgrounding)"
    - "Timer.publish(in: .common) for smooth updates during interaction"
    - "State machine with 5 states (setup/active/paused/inBetween/ended)"
    - "Immediate Firestore persistence for crash recovery"
    - "[weak self] in timer closure to prevent retain cycles"

key-files:
  created:
    - Hone/Features/Sessions/ViewModels/SessionViewModel.swift
  modified:
    - Hone.xcodeproj/project.pbxproj

key-decisions:
  - "Date-based timer calculation: pausedElapsedTime + Date().timeIntervalSince(startTime) survives iOS backgrounding"
  - "Timer.publish(on: .main, in: .common): Uses .common RunLoop mode (not .default) to prevent freezing during scrolling/typing"
  - "Immediate Firestore persistence: All state changes (pause, skip, note) write to Firestore immediately for crash recovery"
  - "SessionState enum: Manages lifecycle transitions (setup → active → paused → inBetween → ended)"
  - "refreshTimerIfNeeded(): Restarts timer on foreground return if state is active"
  - "[weak self] in timer closure: Prevents retain cycles between timer publisher and ViewModel"
  - "reorderActivities: Uses Int indices (not IndexSet) to avoid SwiftUI dependency in ViewModel"

patterns-established:
  - "Date-based timer: Store startTime as Date, calculate elapsed from timeIntervalSince() for backgrounding survival"
  - "RunLoop .common mode: Critical for iOS timer smoothness during user interaction"
  - "pausedElapsedTime: Preserve accumulated time across pause/resume cycles"
  - "State-driven timer management: Timer lifecycle controlled by sessionState enum"

requirements-completed: [EXEC-01, EXEC-03, EXEC-04, EXEC-11, EXEC-12, EXEC-13]

# Metrics
duration: 30 min
completed: 2026-03-04
---

# Phase 3 Plan 2: SessionViewModel with Date-Based Timer Summary

**SessionViewModel implementing date-based timer architecture with .common RunLoop mode, state machine lifecycle management, and immediate Firestore persistence for crash recovery**

## Performance

- **Duration:** 30 min
- **Started:** 2026-03-03T23:49:13Z
- **Completed:** 2026-03-04T00:19:04Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Implemented SessionViewModel with @MainActor isolation following ActivityViewModel pattern from Phase 2
- Created date-based timer using Timer.publish(every: 0.1, on: .main, in: .common) for backgrounding survival
- Built state machine managing 5 lifecycle states (setup/active/paused/inBetween/ended)
- Integrated immediate Firestore persistence on all state changes (pause, skip, note) for crash recovery
- Added refreshTimerIfNeeded() for foreground return handling
- Implemented activity queue management (add, remove, reorder)
- Used [weak self] in timer closure and listener cleanup in deinit for memory safety

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement SessionViewModel with date-based timer and state machine** - `b9a94e2` (feat)

## Files Created/Modified

- `Hone/Features/Sessions/ViewModels/SessionViewModel.swift` - SessionViewModel with date-based timer, state machine, and Firestore persistence (371 lines)
- `Hone.xcodeproj/project.pbxproj` - Added SessionViewModel to build phases

## Decisions Made

**Date-based timer architecture:**
- Stores startTime as Date (not TimeInterval counter)
- Calculates elapsed time: `pausedElapsedTime + Date().timeIntervalSince(startTime)`
- Rationale: Date-based calculation survives iOS backgrounding (app suspension after 30 seconds). Tick-based counters would freeze when app is suspended.

**RunLoop .common mode:**
- Uses `Timer.publish(on: .main, in: .common)` instead of `.default`
- Rationale: .default mode freezes timer during scrolling, typing, and other user interactions. .common mode continues timer updates smoothly during all UI interactions (critical for practice timer UX).

**Immediate Firestore persistence:**
- pauseTimer() writes state="paused" to Firestore immediately
- skipToNext() writes completed activity to Firestore immediately
- addNote() writes note to Firestore immediately
- Rationale: Enables crash recovery. If app crashes or is force-quit, user can resume session from last persisted state.

**State machine design:**
- SessionState enum with 5 states: setup, active, paused, inBetween, ended
- Transitions: setup → active → paused → active → inBetween → active → ended
- Rationale: Clear lifecycle management with explicit state transitions. State drives timer behavior (start/stop) and UI rendering.

**pausedElapsedTime pattern:**
- Stores accumulated elapsed time when timer is paused
- On resume: new startTime is created, elapsed = pausedElapsedTime + timeIntervalSince(new startTime)
- Rationale: Preserves accurate elapsed time across multiple pause/resume cycles without drift.

**refreshTimerIfNeeded() for foreground return:**
- Called from ActiveSessionView.onChange(of: scenePhase)
- Checks if sessionState == .active && timerCancellable == nil
- Restarts timer if needed
- Rationale: Timer publisher is cancelled when app enters background. On foreground return, timer must be restarted to continue updates. Date-based calculation ensures no time is lost.

**Memory management:**
- [weak self] in timer sink closure to prevent retain cycles
- timerCancellable?.cancel() and sessionListener?.remove() in deinit
- Rationale: Prevents memory leaks. Timer publisher holds strong reference to closure, which would hold strong reference to ViewModel, creating cycle. Listeners must be removed to prevent Firestore from keeping ViewModel alive.

**reorderActivities signature:**
- Changed from `func reorderActivities(from: IndexSet, to: Int)` to `func reorderActivities(from: Int, to: Int)`
- Rationale: Avoids SwiftUI dependency in ViewModel. ViewModels should not import SwiftUI (separation of concerns). Views can convert IndexSet to Int before calling ViewModel.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed array reorder method signature**
- **Found during:** Task 1 (SessionViewModel implementation)
- **Issue:** Plan specified `reorderActivities(from: IndexSet, to: Int)` which requires `activities.move(fromOffsets:toOffset:)` - a SwiftUI-only method. This caused compilation error: "instance method 'move(fromOffsets:toOffset:)' is not available due to missing import of defining module 'SwiftUI'"
- **Fix:** Changed signature to `reorderActivities(from: Int, to: Int)` and used standard Swift array operations: `remove(at:)` and `insert(at:)`. ViewModels should not import SwiftUI (separation of concerns).
- **Files modified:** Hone/Features/Sessions/ViewModels/SessionViewModel.swift
- **Verification:** Project builds successfully with no errors
- **Committed in:** b9a94e2 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Method signature change maintains same functionality while following proper MVVM separation (ViewModels should not depend on SwiftUI). Views can convert IndexSet to Int before calling ViewModel.

## Issues Encountered

None - implementation followed plan exactly after fixing method signature for compilation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

SessionViewModel complete and ready for Plan 03-03 (ActiveSessionView).

**Core timer architecture validated:**
- Date-based calculation survives backgrounding
- .common RunLoop mode prevents freezing during interaction
- State machine manages lifecycle transitions correctly
- Firestore persistence enables crash recovery
- Memory management prevents leaks

**Ready for UI integration:**
- SessionViewModel exposes @Published properties for SwiftUI observation
- State-driven architecture enables declarative UI rendering
- Computed properties (currentActivityName, progress, upcomingActivities) ready for display
- All session lifecycle methods (start, pause, resume, skip, end) ready for button actions

**Wave 3 parallelization ready:**
- Plan 03-03 (ActiveSessionView) depends on 03-02 (this plan) - can start now
- Plan 03-04 (SessionSetupView) depends on 03-02 (this plan) - can start now
- Plans 03-03 and 03-04 have no dependencies on each other - can run in parallel

---
*Phase: 03-session-setup-execution*
*Completed: 2026-03-04*
