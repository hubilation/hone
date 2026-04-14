---
phase: 05-smart-features-polish
plan: "02"
subsystem: sessions
tags: [suggestions, ux, session-setup]
dependency_graph:
  requires: [05-01]
  provides: [suggested-section-session-setup, suggested-section-add-activity]
  affects: [SessionSetupView, AddActivityToSessionView, QuickStartView]
tech_stack:
  added: []
  patterns: [stateless-service-computed-property, default-parameter-backward-compat]
key_files:
  created: []
  modified:
    - Hone/Features/Sessions/Views/SessionSetupView.swift
    - Hone/Features/Sessions/Views/AddActivityToSessionView.swift
    - Hone/Features/Sessions/Views/QuickStartView.swift
decisions:
  - Used default parameter `sessions: [Session] = []` to maintain backward compatibility at all call sites
  - AddActivityToSessionView call sites (ActiveSessionView, CompactSessionHeader) left with default sessions: [] since SessionHistoryViewModel is not in scope there; suggestions still surface via Activity.lastUsed alone
metrics:
  duration: "~10 minutes"
  completed: "2026-04-14"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 3
---

# Phase 05 Plan 02: Suggested Activity Sections Summary

Surfaced SuggestionsService rankings in both session entry points by adding a "Suggested" section above the category list in SessionSetupView and AddActivityToSessionView. Section is hidden for new users (no lastUsed data).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add sessions parameter and Suggested section to SessionSetupView | 3c4ceae | SessionSetupView.swift, QuickStartView.swift |
| 2 | Add sessions parameter and Suggested section to AddActivityToSessionView | 3c4ceae | AddActivityToSessionView.swift |

## What Was Built

**SessionSetupView** — Added `sessions: [Session] = []` parameter and `suggestedActivities` computed property backed by `SuggestionsService.suggestedActivities`. Inserted a conditional `Section(header: Text("Suggested"))` before the category `ForEach` loop. Tapping a suggested activity calls the existing `toggleSelection()` — no new selection logic.

**AddActivityToSessionView** — Same pattern. Suggested section rows replicate the existing Button/HStack/disabled pattern from the category list so styling is consistent. Tapping calls `viewModel.addActivity()` and dismisses the sheet.

**QuickStartView** — Updated the `SessionSetupView` NavigationLink to pass `sessions: sessionHistoryViewModel.sessions`. `sessionHistoryViewModel` was already an `@ObservedObject` in scope — no new wiring required.

## Decisions Made

- **Default `sessions: []`**: Prevents compile errors at call sites not updated in this plan (ActiveSessionView, CompactSessionHeader). Suggestions still work via `Activity.lastUsed` when sessions is empty — the new-user guard (`contains(where: { $0.lastUsed != nil })`) is the only gate.
- **No sessions wired for mid-session add**: ActiveSessionView and CompactSessionHeader don't hold SessionHistoryViewModel; passing `sessions: []` is safe — `SuggestionsService` degrades gracefully to lastUsed-only ranking.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. Both views are fully wired to live data from ActivityViewModel and SuggestionsService.

## Threat Flags

None. The Suggested section reuses existing tap handlers (`toggleSelection`, `viewModel.addActivity`) that are already guarded. T-05-06 mitigation (archived activity filter) is enforced inside SuggestionsService, not in these views.

## Self-Check: PASSED

- `Hone/Features/Sessions/Views/SessionSetupView.swift` — modified, contains `Section(header: Text("Suggested"))`
- `Hone/Features/Sessions/Views/AddActivityToSessionView.swift` — modified, contains `Section(header: Text("Suggested"))`
- `Hone/Features/Sessions/Views/QuickStartView.swift` — modified, passes `sessions: sessionHistoryViewModel.sessions`
- Commit `3c4ceae` exists and build succeeded
