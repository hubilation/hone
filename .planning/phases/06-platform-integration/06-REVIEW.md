---
phase: 06-platform-integration
reviewed: 2026-04-15T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - Hone/Core/Services/NetworkMonitor.swift
  - Hone/Core/Services/SyncStateService.swift
  - Hone/Features/Common/Views/OfflineBannerModifier.swift
  - Hone/ContentView.swift
  - Hone/Features/Activities/Views/ActivityListView.swift
  - Hone/Features/Sessions/Views/SessionHistoryView.swift
  - Hone/Features/Sessions/ViewModels/SessionViewModel.swift
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-15
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Seven files were reviewed covering the new platform integration features: `NetworkMonitor`, `SyncStateService`, `OfflineBannerModifier`, `ContentView`/`MainAppView`, `ActivityListView`, `SessionHistoryView`, and `SessionViewModel`. The overall implementation is solid — the date-based timer architecture, offline-safe Firestore write patterns, and Live Activity lifecycle management are all well-structured.

Five warnings were found, all logic correctness issues. The most significant are: (1) a race condition in the "back online" banner dismiss timer that can misfire during rapid connectivity changes, (2) duplicate `ActivityViewModel` and `SessionHistoryViewModel` instances creating redundant Firestore listeners with potential data inconsistency, and (3) silent empty-string userId fallback that generates malformed Firestore paths without any error signal.

No critical security or data-loss issues were found.

---

## Warnings

### WR-01: "Back online" banner dismiss timer not cancelled on subsequent offline transitions

**File:** `Hone/Core/Services/NetworkMonitor.swift:41-45`

**Issue:** When the device goes offline→online, a non-cancellable `Task.sleep(for: .seconds(2))` is spawned to hide the "back online" banner. If the device then goes offline again before the 2-second sleep completes, the outer `Task` at line 34 sets `showBackOnlineBanner = false` (line 51), but the sleeping inner `Task` at line 41 will still fire after its sleep and attempt to set `showBackOnlineBanner = false` again — which is harmless in this case. However, if the device goes offline→online→offline→online rapidly (within 2 seconds), two sleeping inner tasks will be active simultaneously. The second online transition sets `showBackOnlineBanner = true` again on line 40, then the first sleeping task wakes and sets it to `false`, hiding the banner prematurely before the second task's 2-second window elapses.

**Fix:** Track the banner task so it can be cancelled before starting a new one:

```swift
private var backOnlineTask: Task<Void, Never>?

// Inside the path.status == .satisfied branch, before spawning the Task:
if !self.isConnected {
    self.isConnected = true
    self.showBackOnlineBanner = true
    backOnlineTask?.cancel()
    backOnlineTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self?.showBackOnlineBanner = false
        }
    }
}
```

---

### WR-02: Silent empty-string userId propagates to all Firestore paths

**File:** `Hone/ContentView.swift:48,59,75,89,97,114`

**Issue:** `user.id ?? ""` is used in six places as the userId for ViewModels and Firestore calls. If `user.id` is nil at any of these sites, Firestore documents are written to paths like `users//activities/...` rather than failing visibly. The two `print` statements on lines 49-50 confirm this was encountered during development. Since `User.id` is presumably an optional wrapping a Firebase Auth UID, nil should never occur in practice — but the silent fallback masks any regression.

**Fix:** Assert or guard at the earliest point. In `MainAppView.init`, fail loudly if userId is empty rather than propagating the empty string downstream:

```swift
init(user: User) {
    self.user = user
    let userId = user.id ?? ""
    assert(!userId.isEmpty, "MainAppView initialized with nil user.id — check AuthViewModel state")
    _activityViewModel = StateObject(wrappedValue: ActivityViewModel(userId: userId))
    _sessionHistoryViewModel = StateObject(wrappedValue: SessionHistoryViewModel(userId: userId))
    _sessionViewModel = StateObject(wrappedValue: SessionViewModel(userId: userId))
}
```

Also remove the two `print` debug statements on lines 49-50.

---

### WR-03: Duplicate ViewModel instances cause redundant Firestore listeners and potential data inconsistency

**File:** `Hone/ContentView.swift:51-52` and `Hone/Features/Activities/Views/ActivityListView.swift:20`, `Hone/Features/Sessions/Views/SessionHistoryView.swift:14`

**Issue:** `MainAppView` creates `ActivityViewModel` (line 51) and `SessionHistoryViewModel` (line 52) which are passed only to `StatisticsView`. `ActivityListView` and `SessionHistoryView` each independently create their own instances of the same ViewModels via `@StateObject`. This results in:
- Two separate Firestore `addSnapshotListener` calls for the same `activities` collection
- Two separate listeners for the same `sessions` collection
- The Activities tab and Statistics tab are reading from different in-memory state — an activity created in one tab may not reflect immediately in the other

**Fix:** Lift the shared ViewModels to environment objects (passed via `environmentObject`) so all tabs share a single instance and a single listener. Or pass the existing ViewModel instances directly as parameters to `ActivityListView` and `SessionHistoryView`:

```swift
// In MainAppView.body, Activities tab:
ActivityListView(viewModel: activityViewModel)

// ActivityListView: change init to accept existing ViewModel
init(viewModel: ActivityViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
}
```

---

### WR-04: ISO 8601 timestamp string sort is fragile for practiceNotes ordering

**File:** `Hone/Features/Sessions/ViewModels/SessionViewModel.swift:427`

**Issue:** `historicalNotes` is sorted by `$0.timestamp > $1.timestamp` using Swift's default `String` comparison (lexicographic). This is only correct if all timestamps have identical format (same length, UTC, same precision). If any note has a timezone offset (e.g., `+05:30`) instead of `Z`, or a different number of fractional digits, lexicographic order diverges from chronological order.

**Fix:** Parse to `Date` before comparing, or enforce a single ISO 8601 format at the point of creation. A safe sort:

```swift
let formatter = ISO8601DateFormatter()
historicalNotes = (activity.practiceNotes ?? []).sorted { a, b in
    let dateA = formatter.date(from: a.timestamp) ?? .distantPast
    let dateB = formatter.date(from: b.timestamp) ?? .distantPast
    return dateA > dateB
}
```

Alternatively, if `PracticeNote` timestamps are always written by `Date().toISO8601String()` throughout the app with a consistent UTC format, this is low risk in practice — but a comment documenting the assumption would prevent future breakage.

---

### WR-05: `inBetween` session activity timer captures stale `activityStartDate` on paused sessions

**File:** `Hone/Features/Sessions/ViewModels/SessionViewModel.swift:322`

**Issue:** In `startNextActivity()`, the in-between activity's `startTime` is set to `activityStartDate?.toISO8601String() ?? nowString` (line 322). If the session was paused before the user tapped "Start Next Activity" and then resumed, `activityStartDate` reflects the most recent resume time — not the time the in-between period actually began. The in-between period logically begins when `completeCurrentActivity()` was called and `sessionState` transitioned to `.inBetween`. If the session is paused during in-between time, `activityStartDate` is set to nil (line 196 in `pauseTimer`), so the fallback `nowString` would be used — making the in-between `startTime` equal to its `endTime`.

**Fix:** Capture the in-between start time at the moment the state enters `.inBetween`, rather than reading `activityStartDate` at the end. Store it as a private property:

```swift
private var inBetweenStartDate: Date?

// At the start of inBetween phase (wherever sessionState = .inBetween is set):
inBetweenStartDate = Date()

// In startNextActivity():
startTime: inBetweenStartDate?.toISO8601String() ?? nowString,
```

---

## Info

### IN-01: Debug print statements left in production code

**Files:**
- `Hone/ContentView.swift:49-50` — `print("🔍 DEBUG: MainAppView init...")` and `print("🔍 DEBUG: user.id = ...")`
- `Hone/Features/Activities/Views/ActivityListView.swift:155` — `print("DEBUG: ActivityListView.onAppear called")`
- `Hone/Features/Sessions/Views/SessionHistoryView.swift:81` — `print("DEBUG: SessionHistoryView.onAppear called with userId: ...")`

**Fix:** Remove all four `print` debug statements before shipping.

---

### IN-02: `NetworkMonitor.isConnected` initializes to `true` before first path update

**File:** `Hone/Core/Services/NetworkMonitor.swift:18`

**Issue:** `isConnected` defaults to `true` on line 18. The `NWPathMonitor` `pathUpdateHandler` may not fire synchronously on start, so there is a window (typically under 100ms) where the app appears to be online even if the device is offline at launch. The offline banner will not show during this window.

**Fix:** This is acceptable for most use cases since the delay is extremely short and the monitor will correct itself quickly. If a stricter guarantee is needed, initialize to a sentinel/unknown state and handle that in the UI. Document the assumption with a comment.

---

### IN-03: `SyncStateService` does not reset `hasPendingWrites` on `stopListening`

**File:** `Hone/Core/Services/SyncStateService.swift:49-53`

**Issue:** When `stopListening()` is called (e.g., on sign-out), `hasPendingWrites` remains at its last observed value rather than being reset to `false`. If the sync icon was showing at sign-out, it will remain visible until a new listener fires after sign-in.

**Fix:** Reset the state when stopping:

```swift
func stopListening() {
    listener?.remove()
    listener = nil
    hasPendingWrites = false
}
```

---

### IN-04: Live Activity paused-state update passes semantically meaningless dates

**File:** `Hone/Features/Sessions/ViewModels/SessionViewModel.swift:668-671`

**Issue:** In `updateLiveActivityPaused()`, `activityStartDate: Date()` and `sessionStartDate: Date()` are passed with the comment "not used when isPaused=true". These are misleading — `Date()` produces the current timestamp which has no relationship to when the activity or session started. If the Live Activity widget ever renders in an unexpected code path that reads these dates despite `isPaused == true`, it would display a nonsensical "started just now" timer.

**Fix:** Use a clearly intentional sentinel such as `.distantPast` or the actual last-known start dates:

```swift
let state = HoneLiveActivityAttributes.ContentState(
    activityStartDate: activityStartDate ?? .distantPast,  // unused when isPaused=true
    isPaused: true,
    pausedElapsedSeconds: elapsedTime,
    activityName: currentActivityName,
    sessionStartDate: sessionTimerStartDate ?? .distantPast,  // unused when isPaused=true
    totalPausedSessionSeconds: totalSessionTime
)
```

---

_Reviewed: 2026-04-15_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
