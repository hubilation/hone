# Project State: Practice Timer iOS

**Last Updated:** 2026-03-01
**Current Phase:** Not started
**Current Plan:** None
**Status:** Roadmap created, ready to plan Phase 1

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

**Phase:** Roadmap planning complete
**Plan:** None yet
**Status:** Ready to plan Phase 1
**Progress:** `[>                                             ] 0/7 phases`

**Phase 1 Goal:** Users can authenticate with multiple methods and app has correct foundational architecture for offline-first sync

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
- Completed: 0
- In Progress: 0
- Not Started: 7

**Requirements:**
- Total v1: 53
- Completed: 0
- In Progress: 0
- Coverage: 100% (all mapped to phases)

**Velocity:**
- Plans per session: N/A (no sessions yet)
- Average plan completion time: N/A
- Blockers encountered: 0

---

## Accumulated Context

### Critical Decisions

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
- [ ] Run `/gsd:plan-phase 1` to create execution plans for Foundation & Authentication
- [ ] Address critical pitfalls in Phase 1 plans: Timer architecture, data model subcollections, security rules, Sign in with Apple

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
- Roadmap created with 7 phases
- All 53 v1 requirements mapped to phases (100% coverage)
- Phase dependencies validated
- Success criteria derived for each phase (2-8 observable behaviors per phase)
- Research context integrated (pitfalls, stack recommendations)

**Next Session Start Here:**
1. Review Phase 1 goal and success criteria above
2. Run `/gsd:plan-phase 1` to decompose Phase 1 into executable plans
3. Phase 1 focus areas: Firebase setup, auth flows (email/password, Google OAuth, Sign in with Apple), data models with subcollections, security rules with tests, repository pattern establishment

**Context for Handoff:**
- Project type: Native iOS app (SwiftUI) with Firebase backend
- Existing web app with same Firebase backend (must maintain data compatibility)
- Key differentiation: Simplified session setup, smart suggestions, iOS-native timer optimized for practice use
- Target users: Musicians who practice regularly, need timer visible from distance
- Critical constraint: Timer must survive backgrounding (iOS suspends after 30 seconds)

---

*State initialized: 2026-03-01*
*Next action: `/gsd:plan-phase 1`*
