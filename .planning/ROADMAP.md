# Roadmap: Practice Timer iOS

**Project:** Practice Timer iOS App
**Created:** 2026-03-01
**Depth:** Standard (7 phases)
**Coverage:** 53/53 v1 requirements mapped

## Phases

- [x] **Phase 1: Foundation & Authentication** - Firebase setup, auth flows, data models, security rules (completed 2026-03-03)
- [x] **Phase 2: Activity Management** - CRUD operations, categorization, archive/restore, real-time sync (completed 2026-03-03)
- [ ] **Phase 3: Session Setup & Execution** - Timer with backgrounding, session flow, notes, pause/resume
- [ ] **Phase 4: Session History & Statistics** - Past sessions, activity stats, filtering, detail views
- [ ] **Phase 5: Smart Features & Polish** - Smart suggestions, visual progress, in-between time tracking
- [ ] **Phase 6: Platform Integration** - iPad layouts, offline indicators, optimistic UI, performance
- [ ] **Phase 7: App Store Preparation** - Metadata, screenshots, privacy policy, TestFlight testing

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Authentication | 4/4 | Complete   | 2026-03-03 |
| 2. Activity Management | 4/4 | Complete   | 2026-03-03 |
| 3. Session Setup & Execution | 1/6 | In Progress | - |
| 4. Session History & Statistics | 0/? | Not started | - |
| 5. Smart Features & Polish | 0/? | Not started | - |
| 6. Platform Integration | 0/? | Not started | - |
| 7. App Store Preparation | 0/? | Not started | - |

## Phase Details

### Phase 1: Foundation & Authentication
**Goal**: Users can authenticate with multiple methods and app has correct foundational architecture for offline-first sync

**Depends on**: Nothing (first phase)

**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, PLAT-01 (partial - Firebase setup)

**Success Criteria** (what must be TRUE):
1. User can sign up with email/password and immediately access their account
2. User can sign in with Google OAuth and see their existing data (if migrating from web)
3. User can sign in with Sign in with Apple and account is created successfully
4. User session persists across app restarts (no re-login required)
5. User can sign out from any screen and returns to login
6. User can reset password via email link and receive reset instructions
7. Firebase security rules prevent unauthorized data access (tested and validated)
8. App continues to function when device is offline (auth state persists locally)

**Plans:** 4/4 plans complete

Plans:
- [x] 01-01-PLAN.md — Firebase SDK integration, data models, repository pattern (completed 2026-03-02)
- [x] 01-02-PLAN.md — Email/password authentication and auth state routing (completed 2026-03-02)
- [x] 01-03-PLAN.md — Google OAuth and Sign in with Apple (completed 2026-03-02)
- [x] 01-04-PLAN.md — Firestore security rules, emulator testing, human verification checkpoint (completed 2026-03-02)

**Notes**:
- Critical pitfalls addressed: Timer architecture (date-based calculations), data model with subcollections (prevents 1MB document limit), security rules with tests, Sign in with Apple complete implementation
- Establishes repository pattern for all data access
- Firebase offline persistence enabled from day one

---

### Phase 2: Activity Management
**Goal**: Users can create and manage practice activities with real-time sync across devices

**Depends on**: Phase 1 (requires auth and data models)

**Requirements**: ACT-01, ACT-02, ACT-03, ACT-04, ACT-05, ACT-06, ACT-07, ACT-08, ACT-09, POST-05 (activity statistics)

**Success Criteria** (what must be TRUE):
1. User can create new activity with name and category (instrument, piece, technique)
2. User can edit existing activity and changes save immediately
3. User can delete activity and it's removed from active list
4. User can archive activity (soft delete) and restore it later
5. User can view separate lists of active and archived activities
6. User sees activity statistics showing total practice time per activity
7. Changes made on web app appear on iOS in real-time when online
8. Changes made on iOS appear on web app in real-time when online
9. Activity operations work offline and sync automatically when connection restored

**Plans**: 4 plans

Plans:
- [ ] 02-01-PLAN.md — ActivityRepository with CRUD operations and real-time listeners
- [ ] 02-02-PLAN.md — Activity category enum and form views
- [ ] 02-03-PLAN.md — Activity list views with swipe actions and ViewModel
- [ ] 02-04-PLAN.md — Activity statistics with Firestore aggregation queries, human verification

**Notes**:
- Validates repository pattern and offline sync behavior before complex features
- Establishes memory management patterns (Firebase listener cleanup in ViewModels)
- Activity statistics foundation for Phase 4 history features
- Wave structure: 02-01 and 02-02 parallel (Wave 1), 02-03 depends on both (Wave 2), 02-04 depends on 02-03 (Wave 3)

---

### Phase 3: Session Setup & Execution
**Goal**: Users can plan and execute timed practice sessions with accurate timing that survives backgrounding

**Depends on**: Phase 2 (requires activities to select for sessions)

**Requirements**: SETUP-01, SETUP-02, SETUP-04, SETUP-05, EXEC-01, EXEC-02, EXEC-03, EXEC-04, EXEC-05, EXEC-06, EXEC-07, EXEC-08, EXEC-09, EXEC-10, EXEC-11, EXEC-12, EXEC-13, EXEC-14, EXEC-15

**Success Criteria** (what must be TRUE):
1. User can select multiple activities from list and start practice session in 3 taps or fewer
2. User sees large, clear timer display readable from 10 feet away (music stand distance)
3. User can pause practice session and timer stops accurately
4. User can resume paused session and timer continues from paused time
5. User can add notes for current activity during practice
6. User can skip to next activity, remove upcoming activities, and reorder activities during session
7. User sees visual progress indicator showing session completion percentage
8. Timer continues accurately when app is backgrounded or device is locked
9. Session state persists if app crashes or is force-quit (can resume on restart)
10. App tracks "in between" time automatically when switching between activities
11. User can end session and see confirmation with summary preview
12. Session controls are simple and obvious with large touch targets (operable while holding instrument)

**Plans**: 6 plans in 5 waves

Plans:
- [x] 03-01-PLAN.md — Session data models and SessionRepository (Wave 1) (completed 2026-03-03)
- [ ] 03-02-PLAN.md — SessionViewModel with date-based timer architecture (Wave 2)
- [ ] 03-03-PLAN.md — Session setup UI with activity selection and reordering (Wave 3)
- [ ] 03-04-PLAN.md — Timer display and session control components (Wave 3)
- [ ] 03-05-PLAN.md — Active session orchestrator and summary view (Wave 4)
- [ ] 03-06-PLAN.md — Navigation integration and human verification checkpoint (Wave 5)

**Notes**:
- Most complex phase: Timer architecture, backgrounding, component extraction
- Critical pitfalls: Date-based timer calculation (not tick counters), RunLoop .common mode, component architecture (avoid massive view files)
- Session setup streamlined compared to web app (PROJECT.md goal)
- In-between time tracking is unique web app feature to preserve
- Wave structure enables parallel execution: 03-03 and 03-04 can run simultaneously (different files)
- Checkpoint in 03-06 verifies critical behaviors only humans can test (readability from distance, background survival)

---

### Phase 4: Session History & Statistics
**Goal**: Users can review past practice sessions and see progress over time

**Depends on**: Phase 3 (requires completed sessions)

**Requirements**: POST-01, POST-02, POST-03, POST-04, POST-06, PLAT-04, PLAT-05

**Success Criteria** (what must be TRUE):
1. User can view list of past practice sessions sorted by date (most recent first)
2. User can tap session to see full details (activities, times, notes)
3. User sees session summary immediately after completing practice (total time, per-activity breakdown)
4. Session summary shows all notes added during practice
5. Session history syncs in real-time across web and iOS when online
6. User can filter session history by date range or activity
7. Statistics show meaningful practice trends (total time per activity, practice frequency)

**Plans**: TBD

**Notes**:
- Foundation for Phase 5 smart suggestions (requires historical data)
- Performance consideration: Paginate large session collections
- Charts and statistics provide user motivation

---

### Phase 5: Smart Features & Polish
**Goal**: Users experience intelligent suggestions and visual enhancements that differentiate from competitors

**Depends on**: Phase 4 (requires session history for smart suggestions)

**Requirements**: SETUP-03 (smart suggestions), EXEC-10 (visual progress - if not in Phase 3)

**Success Criteria** (what must be TRUE):
1. User sees smart activity suggestions when setting up new session based on practice history
2. Smart suggestions prioritize least recently practiced activities
3. Smart suggestions consider practice frequency patterns (e.g., "daily" activities not practiced today)
4. Visual progress indicators show session completion percentage throughout practice
5. Session setup flow is faster than web app (fewer taps, pre-selected suggestions)

**Plans**: TBD

**Notes**:
- Research flag: Smart suggestion algorithm needs design during planning
- Differentiators from PROJECT.md: Simplified session setup, smart suggestions
- Algorithm approach: Recency (when last practiced), frequency (how often), time-since-last-practice heuristics

---

### Phase 6: Platform Integration
**Goal**: App delivers polished iOS-native experience across all devices with clear offline/sync state

**Depends on**: Phase 3 (core features complete)

**Requirements**: PLAT-02, PLAT-03, PLAT-06, PLAT-07, PLAT-08

**Success Criteria** (what must be TRUE):
1. App runs natively on iPhone (all screen sizes) with optimized layouts
2. App runs on iPad with adaptive layouts that use larger screen space effectively
3. User sees offline indicator when device loses internet connection
4. User sees pending sync indicator when changes are waiting to upload
5. Sync conflicts are handled gracefully (last write wins with timestamp indication)
6. User can continue all core operations (activities, sessions) fully offline
7. Offline changes sync automatically when connection is restored

**Plans**: TBD

**Notes**:
- iPad adaptive layouts use larger screen for side-by-side views (activity list + session timer)
- Optimistic UI: Show changes immediately, sync in background with pending badges
- Performance testing with realistic data volumes (100+ activities, 1000+ sessions)

---

### Phase 7: App Store Preparation
**Goal**: App is ready for App Store submission and passes review on first attempt

**Depends on**: Phase 6 (all features complete)

**Requirements**: STORE-01, STORE-02, STORE-03, STORE-04, STORE-05, STORE-06, STORE-07, STORE-08

**Success Criteria** (what must be TRUE):
1. Privacy policy is hosted and accessible via in-app link
2. App includes required privacy manifest declaring data collection practices
3. App icons are created for all required sizes (AppIcon set complete)
4. App screenshots are created for iPhone 6.7", 5.5", and iPad Pro 12.9"
5. App Store metadata (description, keywords, promotional text) is complete and compelling
6. Age rating questionnaire is completed and appropriate for music practice app
7. TestFlight beta testing completed with at least 10 external testers
8. App passes App Store review guidelines (no rejections for common issues)

**Plans**: TBD

**Notes**:
- Privacy policy must cover Firebase Auth, Firestore data storage, analytics (if used)
- TestFlight testing validates real-world usage before public release
- Screenshots should demonstrate key features: timer display, session setup, activity management, history
- Review guidelines compliance: Sign in with Apple implemented (Phase 1), no misleading metadata

---

## Coverage Validation

All 53 v1 requirements mapped to phases:

**Phase 1 (8 requirements):**
- AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07
- PLAT-01 (partial - Firebase setup)

**Phase 2 (10 requirements):**
- ACT-01, ACT-02, ACT-03, ACT-04, ACT-05, ACT-06, ACT-07, ACT-08, ACT-09
- POST-05 (activity statistics)

**Phase 3 (19 requirements):**
- SETUP-01, SETUP-02, SETUP-04, SETUP-05
- EXEC-01, EXEC-02, EXEC-03, EXEC-04, EXEC-05, EXEC-06, EXEC-07, EXEC-08, EXEC-09, EXEC-10, EXEC-11, EXEC-12, EXEC-13, EXEC-14, EXEC-15

**Phase 4 (7 requirements):**
- POST-01, POST-02, POST-03, POST-04, POST-06
- PLAT-04, PLAT-05

**Phase 5 (2 requirements):**
- SETUP-03 (smart suggestions)
- Visual progress if not completed in Phase 3

**Phase 6 (5 requirements):**
- PLAT-02, PLAT-03, PLAT-06, PLAT-07, PLAT-08

**Phase 7 (8 requirements):**
- STORE-01, STORE-02, STORE-03, STORE-04, STORE-05, STORE-06, STORE-07, STORE-08

**Coverage: 53/53 requirements mapped (100%)**

No orphaned requirements. No duplicates.

---

## Dependencies

```
Phase 1: Foundation & Authentication
  ↓
Phase 2: Activity Management
  ↓
Phase 3: Session Setup & Execution
  ↓
Phase 4: Session History & Statistics
  ↓
Phase 5: Smart Features & Polish

Phase 3 (when core features complete)
  ↓
Phase 6: Platform Integration

Phase 6 (all features complete)
  ↓
Phase 7: App Store Preparation
```

**Critical path:** 1 → 2 → 3 → 4 → 5 → 6 → 7

**Note:** Phase 6 can begin after Phase 3 core features are stable (iPad layouts, offline indicators). Phase 5 requires Phase 4 history data for smart suggestions.

---

## Research Flags

**Phases requiring research during planning:**
- **Phase 5**: Smart suggestion algorithm design (recency, frequency, time-since-last-practice scoring)

**Phases with standard patterns (no additional research needed):**
- Phase 1: Firebase setup, SwiftUI auth patterns (well-documented)
- Phase 2: CRUD with Firestore listeners (standard repository pattern)
- Phase 3: Timer backgrounding patterns (iOS guides, case studies)
- Phase 4: List views with filters, charts (standard iOS patterns)
- Phase 6: iPad adaptive layouts, offline indicators (standard iOS patterns)
- Phase 7: App Store submission (Apple guidelines comprehensive)

---

*Roadmap created: 2026-03-01*
*Phase 1 planned: 2026-03-02*
*Phase 2 planned: 2026-03-02*
*Ready for execution: Phase 2*
