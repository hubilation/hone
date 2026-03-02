# Project Research Summary

**Project:** Practice Timer iOS App
**Domain:** Native iOS Practice Tracking App with SwiftUI + Firebase
**Researched:** 2026-03-01
**Confidence:** HIGH

## Executive Summary

Practice Timer is a native iOS app for musicians to track practice sessions with timer functionality, activity management, and offline-first data sync. Expert guidance points to SwiftUI + Firebase as the standard modern stack for this domain, specifically leveraging MVVM architecture with repository pattern for data access. The recommended approach uses Firebase's built-in offline persistence (not dual persistence layers like SwiftData), date-based timer calculations to handle iOS backgrounding, and iOS 16+ as minimum target for broad device support while maintaining modern SwiftUI APIs.

The competitive landscape shows table stakes include large readable timers, offline support, session history, and activity management, while differentiators come from smart session suggestions based on history and streamlined session setup. The web app already exists with Firebase backend, making Firebase the natural choice for cross-platform data consistency. Research reveals 8 critical pitfalls that must be addressed from day one: timer backgrounding handling, Firestore offline persistence behavior, security rules validation, memory leaks from Firebase listeners, massive view files, timer RunLoop configuration, Sign in with Apple implementation, and Firestore document size limits.

Key risks center on iOS-specific constraints: timers stop in background after 30 seconds (requires date-based calculation), offline sync complexity (cache limits, conflict resolution), and App Store requirements (Sign in with Apple mandatory when offering Google OAuth, privacy policy, metadata requirements). Mitigation strategies are well-documented and follow established iOS patterns: timestamp-based timers, Firestore's native offline mode with proper cache configuration, protocol-based repositories for testability, and component-based view architecture.

## Key Findings

### Recommended Stack

SwiftUI + Firebase represents the industry standard for modern iOS apps with cloud sync requirements in 2026. SwiftUI (iOS 16+) provides declarative UI ideal for reactive timer interfaces with automatic state binding. Firebase iOS SDK 12.10.0+ offers proven real-time sync, offline persistence enabled by default, and matches the existing web app backend. Swift Package Manager is Firebase's recommended dependency management approach as of 2025.

**Core technologies:**
- **SwiftUI (iOS 16+)**: Declarative UI framework — mature as of 2025, excellent for timer interfaces with state binding, NavigationStack replaces deprecated NavigationView
- **Firebase iOS SDK 12.10.0+**: Backend services — matches existing web app, real-time sync, comprehensive auth/database/storage, offline persistence built-in
- **Swift 6.x**: Primary language — latest concurrency features (async/await for Firebase), improved safety, required for Xcode 16+ and App Store submissions
- **Swift Package Manager**: Dependency management — Apple's official tool, best Xcode integration, Firebase's recommended approach
- **Firestore Offline Persistence**: Local caching — enabled by default, automatic sync queue, NO need for SwiftData or Core Data (dual persistence creates conflicts)
- **XCTest with gradual Swift Testing adoption**: Testing framework — proven for unit/UI tests, Swift Testing for new tests (parallel execution, modern syntax)

**Critical: Do NOT use SwiftData or Core Data for sync** — Firestore's offline mode already provides local caching. Adding another persistence layer creates sync conflicts and unnecessary complexity.

### Expected Features

Research across competitor apps (Andante, Modacity) and habit trackers reveals clear feature expectations. Table stakes are features users assume exist, competitive differentiators set the product apart, and anti-features are commonly requested but create problems.

**Must have (table stakes):**
- Start/Stop/Pause Timer with large, readable display — visible from distance on music stand
- Manual time entry — correct mistakes or log past sessions
- Session notes — document insights during/after practice
- Practice history — view past sessions with filters
- Activity/item management — CRUD for practice items
- Offline functionality — practice spaces have poor connectivity
- Daily goals and practice streaks — motivation through target setting
- Basic statistics — total time per activity, charts for progress
- Data export — users want ownership of their data

**Should have (competitive differentiators):**
- Smart session suggestions — reduces setup friction using historical data (PROJECT.md improvement goal)
- In-between time tracking — captures breaks transparently (web app unique feature)
- Simplified session setup — fewer taps than competitors (PROJECT.md goal)
- iOS widgets (home screen) — quick start + glanceable stats without opening app
- Siri Shortcuts integration — "Hey Siri, start piano practice"
- Optimistic UI during sync — shows changes immediately, syncs in background
- Visual progress indicators — session completion percentage, activity progress bars
- Mood & focus tracking — correlate quality with emotional state (Andante feature)
- Activity categorization — group by instrument, piece, technique

**Defer to v2+:**
- Session templates — marked v2 in PROJECT.md, smart suggestions provide similar value
- Metronome integration — common in competitors but out of scope for v1
- Audio recording/playback — Modacity's differentiator, high complexity
- Push notifications — marked out-of-scope in PROJECT.md
- Apple Watch companion app — validate iPhone app first
- Social/sharing features — practice is personal, validate solo use first

### Architecture Approach

iOS SwiftUI apps with Firebase follow MVVM (Model-View-ViewModel) with repository pattern for data access. This provides clear separation of concerns with unidirectional data flow: Views observe ViewModels through @StateObject/@ObservedObject, ViewModels coordinate repositories for data operations, Repositories abstract Firebase SDK details behind protocols for testability.

**Major components:**
1. **Views (SwiftUI)** — Display data and handle user interaction; minimal state, delegates logic to ViewModels; uses @State for local UI, @ObservedObject for ViewModels
2. **ViewModels (ObservableObject)** — Provide data to views and coordinate repositories; contain @Published properties for reactive updates; handle UI logic and state management; must remove Firebase listeners in deinit to prevent memory leaks
3. **Repositories (Protocol-based)** — Abstract data access with CRUD operations; encapsulate Firebase SDK calls; enable dependency injection and testing through protocols; handle real-time listeners and offline sync transparently
4. **Services (Cross-cutting)** — Handle auth (AuthService), analytics, shared concerns; injected via @EnvironmentObject for app-wide access
5. **Models (Codable structs)** — Domain data structures conforming to Identifiable; map directly to Firestore documents

**Critical patterns:**
- **Timer background handling**: Store start time as Date, calculate elapsed time from difference (not timer ticks); iOS suspends timers after ~30 seconds in background
- **Firestore real-time listeners**: Use snapshot listeners for automatic UI updates; MUST store ListenerRegistration and call remove() in deinit to prevent memory leaks
- **Offline-first design**: Firestore writes to local cache first (instant), syncs to server when online; use optimistic UI with pending indicators; never await writes in offline mode
- **Component extraction**: Keep views under 300 lines; extract subviews (TimerDisplayView, ActivityListView, SessionControlsView); prevents massive god-objects and improves compile times

### Critical Pitfalls

The research identified 8 critical pitfalls that must be addressed in Phase 1, plus 4 moderate pitfalls for later phases. These are common failure modes with significant user impact.

1. **Timer backgrounding fails** — iOS suspends timers after 30 seconds. Store start time as Date and calculate elapsed time from date difference, not timer tick counters. Use Timer only for display updates with .common RunLoop mode.

2. **Firestore offline persistence misunderstood** — Default 100MB cache can evict documents; queries fail offline if not cached; "last write wins" silently overwrites multi-device edits. Monitor cache size, use keepSynced() for critical collections, document conflict behavior in UX.

3. **Security rules assume client validation** — Validation in iOS app doesn't protect Firestore. Always mirror validation in security rules. Test with Firebase emulator. Never deploy test mode rules (allow read, write: if true). Validate request.auth.uid == resource.data.userId.

4. **Firebase listener memory leaks** — Firestore listeners not removed accumulate in memory. Store ListenerRegistration, call remove() in deinit or .task modifier. Use [weak self] in closures. Profile memory after each navigation path.

5. **Massive view files (1000+ lines)** — Single PracticeSessionView handling timer, notes, activities becomes unmaintainable. Split into components under 300 lines. Extract ViewModels for business logic. Use view modifiers for reusable styling.

6. **Timer RunLoop misconfigured** — Default RunLoop mode stops during scrolling/gestures. Use .common mode explicitly. Set timer tolerance for tighter accuracy. Still calculate elapsed time from Date, not timer ticks.

7. **Sign in with Apple incomplete** — App Store requires Sign in with Apple when offering Google OAuth. Handle all error codes (credentialAlreadyInUse, emailAlreadyInUse). Test on device, not just simulator. Support anonymous user upgrade.

8. **Firestore document size limit exceeded** — 1MB per document. Session with embedded activities/notes can exceed limit. Use subcollections for arrays that could exceed 20 items. Store session metadata in document, activity details in subcollection. Migrate is very difficult later.

## Implications for Roadmap

Based on combined research, the following phase structure addresses dependencies, groups related features, and mitigates critical pitfalls identified in research.

### Phase 1: Foundation & Authentication
**Rationale:** Auth is a hard dependency for all features; must be complete before any user data. Timer architecture is complex and must be correct from start (Pitfall 1, 6). Data model using subcollections must be established before implementation (Pitfall 8 — very hard to migrate later). Security rules are critical before first user data (Pitfall 3).

**Delivers:**
- Firebase setup with offline persistence enabled
- Core models (Activity, Session, User) using subcollections for scalability
- AuthService with Firebase Auth integration
- Authentication UI (Email/Password, Google OAuth, Sign in with Apple)
- Complete Sign in with Apple implementation with error handling
- Firebase security rules with tests
- Repository pattern established (ActivityRepository, SessionRepository)

**Addresses features:**
- Authentication (table stakes)
- Offline functionality foundation (table stakes)

**Avoids pitfalls:**
- Pitfall 3: Security rules from day one with tests
- Pitfall 7: Sign in with Apple complete before first TestFlight
- Pitfall 8: Data model with subcollections prevents 1MB limit issues

**Research flag:** Standard patterns, well-documented. No additional research needed.

### Phase 2: Activity Management & Core Data
**Rationale:** Activities are prerequisite for session tracking. Repository pattern established in Phase 1 validates data model and offline sync behavior before complex timer features. Memory management patterns must be established early (Pitfall 4).

**Delivers:**
- Activity CRUD (create, edit, delete, archive/restore)
- Activity categorization (instrument, piece, technique)
- Activity statistics (total time, trends)
- Real-time Firestore listeners with proper cleanup
- Offline sync with cache monitoring
- Repository tests with offline/online scenarios

**Addresses features:**
- Activity management (table stakes)
- Activity categorization (differentiator)
- Archive/restore activities (web app feature)
- Basic statistics (table stakes)

**Avoids pitfalls:**
- Pitfall 4: Listener cleanup patterns established with first ViewModels
- Pitfall 2: Offline cache behavior tested with activity operations

**Research flag:** Standard patterns, well-documented. No additional research needed.

### Phase 3: Timer & Session Execution
**Rationale:** Most complex feature with critical iOS constraints. Timer must handle backgrounding, ScenePhase changes, and accurate time calculation. Component architecture prevents massive view files (Pitfall 5). Session setup depends on activities from Phase 2.

**Delivers:**
- Date-based timer calculation (survives backgrounding)
- Timer display with .common RunLoop mode (works during scrolling)
- Large, readable timer display (visible from distance)
- Start/Stop/Pause controls with large touch targets
- Session setup flow (select activities)
- Active session UI with activity navigation
- Session notes per activity
- Session completion and save to Firestore
- Background/foreground lifecycle handling

**Addresses features:**
- Start/Stop/Pause Timer (table stakes)
- Large readable display (table stakes)
- Session notes (table stakes)
- Simplified session setup (differentiator from PROJECT.md)

**Avoids pitfalls:**
- Pitfall 1: Timer uses Date-based calculations from start
- Pitfall 6: Timer configured with .common RunLoop mode and tolerance
- Pitfall 5: Timer split into TimerDisplayView, SessionControlsView, ActivityListView components

**Research flag:** Standard patterns for timer apps, well-documented in iOS guides. No additional research needed.

### Phase 4: Smart Features & Differentiators
**Rationale:** Builds on session history from Phase 3. Smart suggestions use historical data to recommend activities. In-between time tracking is unique web app feature to preserve. These features differentiate from competitors.

**Delivers:**
- Smart activity suggestions based on practice history
- In-between time tracking (captures breaks)
- Visual progress indicators (session completion percentage)
- Session summary view after completion
- Manual time entry (correct mistakes)

**Addresses features:**
- Smart suggestions (PROJECT.md improvement goal, differentiator)
- In-between time tracking (web app unique feature, differentiator)
- Visual progress indicators (differentiator)
- Manual time entry (table stakes)

**Avoids pitfalls:**
- Performance: Use batch queries for activity history (Pitfall 10)

**Research flag:** Smart suggestions algorithm may need research during planning. Standard recommendation engines use recency, frequency, and time-since-last-practice heuristics.

### Phase 5: History & Statistics
**Rationale:** Requires completed sessions from Phase 3. History provides value for users and enables smart suggestions in Phase 4. Statistics aggregate historical data.

**Delivers:**
- Session history view with filters (date, activity)
- Session detail view
- Practice statistics and charts
- Daily goals (if not already implemented)
- Practice streaks (if not already implemented)

**Addresses features:**
- Practice history (table stakes)
- Statistics (table stakes)
- Daily goals (table stakes)
- Practice streaks (table stakes)

**Avoids pitfalls:**
- Pitfall 10: Paginate large collections, use efficient queries

**Research flag:** Standard patterns for list views and charts. No additional research needed.

### Phase 6: iOS Integration & Polish
**Rationale:** Platform-specific features that enhance UX but aren't blocking for core functionality. Widgets and Siri require working session tracking from Phase 3.

**Delivers:**
- Home screen widget (quick start session)
- Home screen widget (glanceable stats/streak)
- Siri Shortcuts integration
- Offline sync status indicators
- Optimistic UI with pending badges
- Error handling and user-friendly messages
- Data export (CSV)

**Addresses features:**
- iOS widgets (differentiator)
- Siri Shortcuts (differentiator)
- Optimistic UI (differentiator)
- Data export (table stakes)

**Avoids pitfalls:**
- Pitfall 12: Offline state indication for user awareness
- Pitfall 2: Visual sync indicators for pending writes

**Research flag:** Standard iOS widget patterns. May need light research on WidgetKit best practices during planning, but well-documented by Apple.

### Phase 7: App Store Preparation
**Rationale:** All features complete, ready for submission. Metadata requirements must be addressed before submission attempt.

**Delivers:**
- Privacy policy hosted and accessible
- App Privacy labels configured
- Screenshots for all device sizes (iPhone 6.7", 5.5", iPad Pro 12.9")
- App icons (all required sizes)
- Age rating questionnaire completed
- TestFlight testing with external testers
- Performance testing and optimization

**Addresses features:**
- App Store requirements (not features, but mandatory)

**Avoids pitfalls:**
- Pitfall 9: Complete metadata checklist prevents submission delays

**Research flag:** Standard submission process. Apple's official guidelines are comprehensive. No additional research needed.

### Phase Ordering Rationale

- **Phase 1 before all others**: Auth is hard dependency; timer architecture must be correct from start (can't retrofit backgrounding); data model with subcollections hard to migrate later; security rules critical before any user data.

- **Phase 2 before Phase 3**: Activities are prerequisite for sessions; repository pattern validation before complex features; memory management patterns established early.

- **Phase 3 before Phase 4**: Smart suggestions require session history; in-between time tracking is part of session execution.

- **Phase 5 parallel to Phase 4 possible**: History and statistics can be built alongside smart features (both use SessionRepository).

- **Phase 6 after core features**: Widgets and Siri require working session tracking to integrate with; polish improves UX but isn't blocking.

- **Phase 7 last**: Submission preparation happens when all features complete.

**Dependency-driven ordering**: Auth → Models → Repositories → ViewModels → Views is critical path. Timer architecture, offline sync, and security rules must be correct from Phase 1 (retrofitting is expensive or impossible).

**Pitfall-driven ordering**: Pitfalls 1, 3, 6, 7, 8 must be addressed in Phase 1; Pitfalls 2, 4 in Phases 1-2; Pitfall 5 throughout; Pitfalls 9, 10, 12 in later phases.

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 4 (Smart Suggestions)**: Algorithm for activity recommendations based on history needs design. Standard approaches use recency (when last practiced), frequency (how often practiced), and time-since-last-practice heuristics. May need research on recommendation scoring during planning.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Foundation & Auth)**: Well-documented Firebase setup, SwiftUI auth patterns, security rules testing. Apple's Sign in with Apple and Firebase's Auth documentation are comprehensive.
- **Phase 2 (Activity Management)**: Standard CRUD operations with Firestore listeners. Repository pattern is established iOS architecture.
- **Phase 3 (Timer & Session)**: Timer backgrounding patterns well-documented in iOS guides and multiple practice timer case studies.
- **Phase 5 (History & Statistics)**: List views with filters and chart libraries are standard iOS patterns.
- **Phase 6 (iOS Integration)**: WidgetKit and Siri Shortcuts have official Apple documentation with examples.
- **Phase 7 (App Store Prep)**: Apple's submission guidelines and requirements are comprehensive and current.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official Firebase docs, Apple developer docs, verified versions as of Feb 2026. SwiftUI + Firebase is proven standard for this domain. |
| Features | MEDIUM | Strong data on table stakes (all apps have), good data on competitor differentiators (Andante, Modacity), moderate data on user preferences (reviews, not interviews). iOS best practices well-documented. |
| Architecture | HIGH | MVVM + Repository pattern is industry consensus. Multiple authoritative sources (Firebase Developer Advocate, architecture guides). Timer backgrounding patterns documented in case studies. |
| Pitfalls | MEDIUM | High confidence on iOS-specific pitfalls (official Apple forums, developer blogs). High confidence on Firebase pitfalls (official docs). Medium confidence on practice-timer-specific patterns (community sources, case studies, not extensive first-hand research). |

**Overall confidence: HIGH**

Stack and architecture recommendations are based on official documentation and verified versions. Feature expectations come from competitor analysis and iOS platform norms. Pitfall identification draws from official sources (Apple, Firebase) and established community knowledge. The main uncertainty is in practice-timer-specific user preferences (medium confidence), but table stakes and iOS platform expectations are well-established.

### Gaps to Address

**Smart suggestion algorithm design** — Phase 4 requires algorithm for recommending activities based on history. Standard approaches use recency, frequency, and time-since-last-practice, but specific scoring mechanism needs design during planning. Consider: (1) Least recently practiced items, (2) Items approaching goal cadence (e.g., "practice daily"), (3) Items with low recent totals. Simple rule-based approach likely sufficient for v1; can enhance with ML in v2.

**Offline conflict resolution UX** — Research identified "last write wins" as Firestore's default conflict resolution. For v1, document this behavior and show last-synced time. Future enhancement: detect conflicts (compare local vs server timestamps), present resolution UI for critical data. Not blocking for MVP but flagged for future improvement.

**Cache size monitoring strategy** — Firestore default 100MB cache can evict documents with heavy usage. Need to determine appropriate cache size limit based on expected usage (sessions with notes). Implement monitoring during Phase 2 testing to validate assumptions. Consider: unlimited cache for v1 if device storage permits, or 500MB-1GB limit with explicit user notification when approaching.

**Widget implementation scope** — Research shows widgets are differentiator for iOS apps. Phase 6 includes home screen widgets. Determine during planning: (1) Quick-start widget that launches app to session setup, or (2) Quick-start that initiates session directly from widget using app intents. Option 2 is more complex but matches best-in-class habit tracker behavior.

**Performance benchmarks** — Research identified N+1 query problem and excessive listeners as common pitfalls (Pitfall 10). Establish performance benchmarks during Phase 2: acceptable query time, max simultaneous listeners, acceptable cache size. Test with realistic data volumes (100+ activities, 1000+ sessions) before scaling.

## Sources

### Primary (HIGH confidence)
- **Firebase iOS Documentation** — Official setup, offline persistence, security rules (https://firebase.google.com/docs/ios/setup, https://firebase.google.com/docs/firestore/manage-data/enable-offline) — Updated Feb 2026
- **Apple Developer Documentation** — SwiftUI, NavigationStack, timer guidance, app lifecycle (https://developer.apple.com/documentation/swiftui/) — Current as of 2026
- **Firebase iOS SDK Release Notes** — Version 12.10.0 features and requirements (https://github.com/firebase/firebase-ios-sdk/releases) — Feb 25, 2026
- **Peter Friese (Firebase Developer Advocate)** — SwiftUI + Firebase architecture tutorials (https://peterfriese.dev/) — Authoritative source on Firebase iOS patterns
- **Apple App Store Review Guidelines** — Sign in with Apple requirements, privacy requirements, submission requirements (https://developer.apple.com/app-store/review/guidelines/) — Updated 2026

### Secondary (MEDIUM confidence)
- **Competitor App Analysis** — Andante Music Practice Journal (https://andante.app/), Modacity Pro (https://www.modacity.co/), Streaks habit tracker — Official app sites, feature documentation
- **iOS Architecture Guides** — Clean Architecture for SwiftUI by Alexey Naumov (https://nalexn.github.io/clean-architecture-swiftui/), Modern MVVM + Repository Pattern articles — Community best practices, 2025-2026
- **iOS Timer Case Studies** — "Overcoming iOS Background Limits" time tracker case study (https://medium.com/deuk/overcoming-ios-background-limits-a-time-tracker-app-in-swift-ui-5d157a58df68) — Directly relevant timer patterns
- **Developer Community** — DEV Community SwiftUI project structure guide, Medium articles on MVVM patterns — Multiple sources converge on recommendations
- **Apple Developer Forums** — Background timer limitations, RunLoop configuration — Official Apple forum discussions

### Tertiary (LOW confidence)
- **App Store Reviews** — User feedback on Modacity, Andante (complaints about auto-start timers, rating prompts, complexity) — Anecdotal but informative
- **Practice Timer Feature Research** — Web searches for "best music practice tracker apps iOS 2026," habit tracker comparisons — Aggregated but not comprehensive user research
- **Mood tracking features** — Inferred from Andante app description, not hands-on tested

---
*Research completed: 2026-03-01*
*Ready for roadmap: yes*
