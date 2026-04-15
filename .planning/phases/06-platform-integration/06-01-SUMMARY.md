---
phase: 06-platform-integration
plan: 01
subsystem: platform-services
tags: [networking, offline, sync, firestore, swiftui]
dependency_graph:
  requires: []
  provides: [NetworkMonitor, SyncStateService, OfflineBannerModifier]
  affects: [Hone/ContentView.swift]
tech_stack:
  added: [Network framework (NWPathMonitor), Firestore metadata listener (includeMetadataChanges)]
  patterns: [ObservableObject + EnvironmentObject injection, ViewModifier composition]
key_files:
  created:
    - Hone/Core/Services/NetworkMonitor.swift
    - Hone/Core/Services/SyncStateService.swift
    - Hone/Features/Common/Views/OfflineBannerModifier.swift
  modified:
    - Hone/ContentView.swift
decisions:
  - NetworkMonitor uses @MainActor dispatch in pathUpdateHandler closure (avoids MainActor.run nesting) - NWPathMonitor callbacks arrive on background queue
  - showBackOnlineBanner auto-dismisses via nested Task with Task.sleep(for: .seconds(2)) inside @MainActor context
  - SyncStateService listens on user document (not collection) since hasPendingWrites reflects local cache state globally
  - OfflineBannerModifier applied per-tab before CompactSessionHeader so offline banner renders above compact session header
  - syncStateService.startListening wired to TabView.onAppear (not MainAppView init) to ensure userId is available
  - Pre-existing HoneLiveActivity build error (ambiguous HoneLiveActivityAttributes type) logged as deferred - not caused by this plan
metrics:
  duration: 7 min
  completed: 2026-04-15
  tasks_completed: 2
  files_created: 3
  files_modified: 1
---

# Phase 6 Plan 1: Offline Banner and Sync State Services Summary

Network connectivity monitoring and Firestore sync state tracking with global offline banner and pending-writes toolbar icon wired to all app tabs.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create NetworkMonitor and SyncStateService | 592a09a | NetworkMonitor.swift, SyncStateService.swift |
| 2 | Create OfflineBannerModifier and wire into MainAppView | b2b7efa | OfflineBannerModifier.swift, ContentView.swift |

## What Was Built

**NetworkMonitor** (`Hone/Core/Services/NetworkMonitor.swift`): `@MainActor ObservableObject` wrapping `NWPathMonitor`. Publishes `isConnected` (true/false) and `showBackOnlineBanner` (true for 2 seconds on offline→online transition). Cancels monitor in `deinit` to prevent resource leaks.

**SyncStateService** (`Hone/Core/Services/SyncStateService.swift`): `@MainActor ObservableObject` using Firestore metadata listener with `includeMetadataChanges: true` on the user document. Publishes `hasPendingWrites`. Exposes `startListening(userId:)` and `stopListening()`. Removes listener in `deinit`.

**OfflineBannerModifier** (`Hone/Features/Common/Views/OfflineBannerModifier.swift`): `ViewModifier` consuming both services as `@EnvironmentObject`. Shows red "No internet connection" banner when offline, green "Back online" banner on reconnect, both with animated slide-in/out. Shows `arrow.triangle.2.circlepath.icloud` toolbar icon with `.symbolEffect(.pulse)` while Firestore has pending writes.

**ContentView.swift** updated: Both services injected as `@StateObject` in `ContentView` and passed as `.environmentObject()` to both `MainAppView` and `SignInView`. `MainAppView` receives them as `@EnvironmentObject`. Each of the 5 tabs gets `.modifier(OfflineBannerModifier())` applied before `CompactSessionHeader`. `syncStateService.startListening(userId:)` called on `TabView.onAppear`.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. All functionality is fully wired end-to-end.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundaries introduced. Threat model from plan (T-06-01, T-06-02, T-06-03) fully addressed: `listener?.remove()` in `deinit` mitigates T-06-02.

## Deferred Issues

**Pre-existing build failure (out of scope):** `HoneLiveActivity/HoneLiveActivityLiveActivity.swift` defines `HoneLiveActivityAttributes` which conflicts with `Hone/Core/LiveActivity/HoneLiveActivityAttributes.swift`, causing an "ambiguous type lookup" error that fails the full scheme build. This error exists before any changes in this plan. The Hone app target itself compiles with zero errors from this plan's files.

## Self-Check: PASSED

All 3 created files verified on disk. Both task commits (592a09a, b2b7efa) confirmed in git log.
