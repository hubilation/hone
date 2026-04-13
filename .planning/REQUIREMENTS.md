# Requirements: Hone iOS

**Defined:** 2026-03-01
**Core Value:** Musicians can reliably track their practice sessions with accurate timing, notes, and history that syncs seamlessly between web and iOS platforms.

## v1 Requirements

Requirements for initial App Store release. Each maps to roadmap phases.

### Authentication

- [x] **AUTH-01**: User can sign up with email and password
- [x] **AUTH-02**: User can sign in with email and password
- [x] **AUTH-03**: User can sign in with Google OAuth
- [x] **AUTH-04**: User can sign in with Sign in with Apple
- [x] **AUTH-05**: User session persists across app restarts
- [x] **AUTH-06**: User can sign out from app
- [x] **AUTH-07**: User can reset password via email

### Activity Management

- [x] **ACT-01**: User can create new practice activity with name
- [x] **ACT-02**: User can assign category to activity (instrument, piece, technique, etc.)
- [x] **ACT-03**: User can edit activity name and category
- [x] **ACT-04**: User can delete activity
- [x] **ACT-05**: User can archive activity (soft delete)
- [x] **ACT-06**: User can restore archived activity
- [x] **ACT-07**: User can view list of all active activities
- [x] **ACT-08**: User can view list of archived activities
- [x] **ACT-09**: Activity changes sync in real-time across web and iOS when online

### Session Setup

- [ ] **SETUP-01**: User can view list of activities to select for practice session
- [ ] **SETUP-02**: User can select multiple activities for practice session
- [ ] **SETUP-03**: User sees smart suggestions of activities based on practice history
- [ ] **SETUP-04**: User can start practice session with selected activities in fewer steps than web app
- [ ] **SETUP-05**: User can reorder activities before starting session

### Session Execution

- [x] **EXEC-01**: User can start timed practice session
- [ ] **EXEC-02**: User sees large, clear time display during practice (readable from distance)
- [ ] **EXEC-03**: User can pause practice session
- [ ] **EXEC-04**: User can resume paused practice session
- [ ] **EXEC-05**: User can add notes for current activity during practice
- [ ] **EXEC-06**: User can view notes added during practice
- [ ] **EXEC-07**: User can skip to next activity during session
- [ ] **EXEC-08**: User can remove upcoming activity from session
- [ ] **EXEC-09**: User can reorder activities during active session
- [ ] **EXEC-10**: User sees visual progress indicator showing session completion
- [ ] **EXEC-11**: App tracks "in between" time (breaks between activities)
- [ ] **EXEC-12**: User can end practice session
- [ ] **EXEC-13**: Timer continues accurately when app is backgrounded
- [ ] **EXEC-14**: Timer displays use simple, obvious controls
- [x] **EXEC-15**: Session state persists if app crashes or is force-quit

### Post-Session

- [ ] **POST-01**: User can view practice session summary after completion
- [ ] **POST-02**: Summary shows total time, per-activity time, and notes
- [ ] **POST-03**: User can view session history (list of past practice sessions)
- [ ] **POST-04**: User can view details of past practice session
- [x] **POST-05**: User can view activity statistics (total time per activity)
- [ ] **POST-06**: Session history syncs in real-time across web and iOS when online

### Platform & Sync

- [x] **PLAT-01**: App works fully offline (can create activities and practice without internet) - Firebase SDK with offline persistence configured
- [ ] **PLAT-02**: Data syncs automatically when internet connection restored
- [ ] **PLAT-03**: User sees offline indicator when not connected
- [ ] **PLAT-04**: Changes made on web app appear on iOS in real-time when online
- [ ] **PLAT-05**: Changes made on iOS appear on web app in real-time when online
- [ ] **PLAT-06**: App handles sync conflicts gracefully (last write wins with user indication)
- [ ] **PLAT-07**: App supports iPhone (all screen sizes)
- [ ] **PLAT-08**: App supports iPad with adaptive layouts

### App Store Readiness

- [ ] **STORE-01**: App passes App Store review guidelines
- [ ] **STORE-02**: Privacy policy created and linked in app
- [ ] **STORE-03**: App includes required privacy manifest
- [ ] **STORE-04**: App icons created for all required sizes
- [ ] **STORE-05**: App screenshots created for required device sizes
- [ ] **STORE-06**: App Store metadata (description, keywords) completed
- [ ] **STORE-07**: Age rating questionnaire completed
- [ ] **STORE-08**: TestFlight beta testing completed successfully

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### iOS Platform Features

- **IOS-01**: Home screen widget showing practice stats
- **IOS-02**: Home screen widget for quick-start session
- **IOS-03**: Lock screen widget for quick stats
- **IOS-04**: Siri Shortcuts support for starting sessions
- **IOS-05**: Handoff support between iPhone and iPad
- **IOS-06**: Apple Watch companion app for timer control

### Engagement Features

- **ENG-01**: Practice streaks tracking
- **ENG-02**: Daily/weekly practice goals
- **ENG-03**: Achievement badges
- **ENG-04**: Practice reminders (local notifications)

### Advanced Features

- **ADV-01**: Session templates (save common practice routines)
- **ADV-02**: Mood tracking for practice sessions
- **ADV-03**: Audio recording during practice
- **ADV-04**: Metronome integration
- **ADV-05**: Voice notes (speech-to-text)
- **ADV-06**: Quick note presets ("Great!", "Need work", etc.)
- **ADV-07**: Export practice data (CSV, PDF)

### Admin Features

- **ADMIN-01**: Admin panel (if applicable from web app)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Push notifications | Explicitly out of scope per PROJECT.md, focus on core experience |
| Social features | Validate solo practice tracking first before adding sharing/community |
| Real-time collaboration | Single-user app, each user has their own data |
| Android version | iOS-only for initial release |
| macOS app | iOS and web sufficient for now |
| Multiple user profiles on one device | Single-user per account model |
| Offline conflict resolution beyond last-write-wins | Added complexity, rare edge case for solo practice tracking |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Complete |
| AUTH-02 | Phase 1 | Complete |
| AUTH-03 | Phase 1 | Complete |
| AUTH-04 | Phase 1 | Complete |
| AUTH-05 | Phase 1 | Complete |
| AUTH-06 | Phase 1 | Complete |
| AUTH-07 | Phase 1 | Complete |
| ACT-01 | Phase 2 | Complete |
| ACT-02 | Phase 2 | Complete |
| ACT-03 | Phase 2 | Complete |
| ACT-04 | Phase 2 | Complete |
| ACT-05 | Phase 2 | Complete |
| ACT-06 | Phase 2 | Complete |
| ACT-07 | Phase 2 | Complete |
| ACT-08 | Phase 2 | Complete |
| ACT-09 | Phase 2 | Complete |
| SETUP-01 | Phase 3 | Pending |
| SETUP-02 | Phase 3 | Pending |
| SETUP-03 | Phase 5 | Pending |
| SETUP-04 | Phase 3 | Pending |
| SETUP-05 | Phase 3 | Pending |
| EXEC-01 | Phase 3 | Complete |
| EXEC-02 | Phase 3 | Pending |
| EXEC-03 | Phase 3 | Pending |
| EXEC-04 | Phase 3 | Pending |
| EXEC-05 | Phase 3 | Pending |
| EXEC-06 | Phase 3 | Pending |
| EXEC-07 | Phase 3 | Pending |
| EXEC-08 | Phase 3 | Pending |
| EXEC-09 | Phase 3 | Pending |
| EXEC-10 | Phase 3 | Pending |
| EXEC-11 | Phase 3 | Pending |
| EXEC-12 | Phase 3 | Pending |
| EXEC-13 | Phase 3 | Pending |
| EXEC-14 | Phase 3 | Pending |
| EXEC-15 | Phase 3 | Complete |
| POST-01 | Phase 4 | Pending |
| POST-02 | Phase 4 | Pending |
| POST-03 | Phase 4 | Pending |
| POST-04 | Phase 4 | Pending |
| POST-05 | Phase 2 | Complete |
| POST-06 | Phase 4 | Pending |
| PLAT-01 | Phase 1 | Complete (01-01) |
| PLAT-02 | Phase 6 | Pending |
| PLAT-03 | Phase 6 | Pending |
| PLAT-04 | Phase 4 | Pending |
| PLAT-05 | Phase 4 | Pending |
| PLAT-06 | Phase 6 | Pending |
| PLAT-07 | Phase 6 | Pending |
| PLAT-08 | Phase 6 | Pending |
| STORE-01 | Phase 7 | Pending |
| STORE-02 | Phase 7 | Pending |
| STORE-03 | Phase 7 | Pending |
| STORE-04 | Phase 7 | Pending |
| STORE-05 | Phase 7 | Pending |
| STORE-06 | Phase 7 | Pending |
| STORE-07 | Phase 7 | Pending |
| STORE-08 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 53 total
- Mapped to phases: 53 (100%)
- Unmapped: 0

**Phase Distribution:**
- Phase 1 (Foundation & Auth): 8 requirements
- Phase 2 (Activity Management): 10 requirements
- Phase 3 (Session Execution): 19 requirements
- Phase 4 (History & Statistics): 7 requirements
- Phase 5 (Smart Features): 2 requirements
- Phase 6 (Platform Integration): 5 requirements
- Phase 7 (App Store Prep): 8 requirements

---
*Requirements defined: 2026-03-01*
*Last updated: 2026-03-01 after roadmap creation*
