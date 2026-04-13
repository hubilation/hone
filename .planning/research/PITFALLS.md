# Domain Pitfalls

**Domain:** iOS Hone App (SwiftUI + Firebase)
**Researched:** 2026-03-01
**Confidence:** MEDIUM

## Critical Pitfalls

### Pitfall 1: Relying on Timers in Background Mode

**What goes wrong:**
iOS suspends apps shortly after moving to the background (typically 30 seconds maximum). Traditional Timer objects stop firing, causing practice sessions to lose accuracy or completely fail when users switch apps or lock their device.

**Why it happens:**
Developers assume timers work like traditional desktop applications. iOS strictly limits background execution to preserve battery life, and timer apps don't qualify for special background modes.

**Consequences:**
- Practice sessions lose track of elapsed time when app backgrounded
- Users return to find session stuck or incorrect
- App Store rejection if attempting to abuse background modes for timer functionality
- Poor user reviews citing "timer doesn't work"

**Prevention:**
- Store session start time as Date, calculate elapsed time from date difference (not counter increments)
- Use local notifications to alert users when timer/session expires
- For iOS 17+, consider AlarmKit framework for timer expiry notifications
- Never rely on background timer execution for accuracy
- Test extensively with app backgrounding scenarios

**Warning signs:**
- Timer stops updating when app backgrounded
- Elapsed time calculation uses incremented counter instead of date math
- Background modes capability enabled for "timer functionality"
- No local notification implementation for session completion

**Phase to address:**
Phase 1 (Core Timer Architecture) - Timer implementation must use date-based calculations from the start, not retrofitted later.

---

### Pitfall 2: Misunderstanding Firestore Offline Persistence Behavior

**What goes wrong:**
Offline writes appear successful to users but fail to sync when connection restored. Queries return stale data. Cache evicts recently-used data, losing user's practice session. Conflict resolution silently overwrites user data with "last write wins."

**Why it happens:**
Developers enable offline persistence without understanding cache limits (100MB default on iOS), query behavior, or conflict resolution. Firestore's automatic behavior seems "magic" until edge cases emerge.

**Consequences:**
- Users lose practice session data when cache evicts documents
- Multiple device sessions overwrite each other (last write wins)
- Queries fail offline if documents not in cache
- Users confused why data doesn't sync as expected
- Force-quit required to see updated data from other devices

**Prevention:**
- Monitor cache size - practice sessions with notes can accumulate quickly
- Implement cache size limits appropriate to app needs (default 100MB may be insufficient)
- Use `keepSynced()` on critical collections to ensure availability offline
- Never use `await` on Firestore writes in offline mode (blocks UI until server confirms)
- Document "last write wins" behavior in UX - warn users about multi-device conflicts
- Implement optimistic updates with rollback on conflict detection
- Test extensively: offline → online transitions, cache eviction, multi-device scenarios

**Warning signs:**
- Using `await` on Firestore set/update operations
- No cache size monitoring or limits configured
- Queries fail with empty results offline (not in cache)
- No conflict detection or user warning for multi-device edits
- Session data structure could exceed 100MB with typical usage

**Phase to address:**
Phase 2 (Offline & Sync) - Core offline behavior must be architected correctly before users depend on it.

---

### Pitfall 3: Firestore Security Rules Assumed Client-Side Validation

**What goes wrong:**
Developers implement validation in iOS app (SwiftUI, ViewModel) but fail to mirror rules in Firestore Security Rules. Malicious users bypass client validation using Firebase SDK directly, corrupting data or accessing unauthorized information.

**Consequences:**
- Data corruption from invalid writes (negative practice times, invalid user IDs, etc.)
- Users access/modify other users' practice sessions
- App Store rejection or removal if security breach discovered
- GDPR/privacy violations if user data exposed
- Complete database compromise in worst case

**Prevention:**
- Treat Firestore Security Rules as primary validation, client validation as UX enhancement
- Every validation rule in iOS must have equivalent security rule in Firestore
- Use Firebase emulator to test security rules locally
- Write security rule tests in CI/CD pipeline
- Never deploy with test mode rules (`allow read, write: if true`) - #1 cause of Firebase breaches
- Validate user owns data: `request.auth.uid == resource.data.userId`
- Validate data types, ranges, required fields in security rules
- Consider Cloud Functions for complex validation (security rules have limitations)

**Warning signs:**
- Validation only exists in SwiftUI views or ViewModels
- No security rules tests
- Test mode rules (`allow read, write: if true`) in production
- Security rules last updated during initial setup
- No validation of request.auth.uid matches data owner
- Complex business logic validation only in client

**Phase to address:**
Phase 1 (Firebase Setup) - Security rules must be correct from day one, before any real user data exists.

---

### Pitfall 4: ObservableObject Memory Leaks with Firebase Listeners

**What goes wrong:**
SwiftUI views subscribe to Firebase Firestore listeners via @ObservedObject or @StateObject. Views navigate away but listeners stay active, accumulating memory. Nested ObservableObjects don't trigger view updates. App slows down, eventually crashes with memory warnings.

**Consequences:**
- Memory usage grows unbounded during session (20-30 simultaneous listeners reported)
- App crashes during long practice sessions
- UI doesn't update despite data changes (nested observable problem)
- Performance degrades with each navigation
- App Store rejection for excessive memory usage or crashes

**Prevention:**
- Use @StateObject (iOS 14+) for lifecycle ownership, never @ObservedObject for Firebase listeners
- Store listener handles, call `remove()` in deinit or view disappear
- Use `.task {}` modifier for listener lifecycle tied to view appearance
- Avoid nested ObservableObjects - flatten structure or use iOS 17 @Observable
- Use `[weak self]` in closures to break retain cycles
- Instruments Memory Graph: verify views/listeners dealloc after navigation
- Limit simultaneous listeners: paginate, unsubscribe from off-screen data

**Warning signs:**
- Memory usage grows during app session, never decreases
- Listener count increases with each navigation, doesn't decrease
- Nested ObservableObject (Activity inside Session inside ViewModel)
- No .task usage or manual listener removal
- @ObservedObject used where @StateObject appropriate
- No memory profiling in testing

**Phase to address:**
Phase 1 (Core Architecture) - Memory management patterns must be established in initial ViewModel/View setup.

---

### Pitfall 5: Massive SwiftUI View Files (1000+ Lines)

**What goes wrong:**
Single PracticeSessionView file grows to 1000+ lines handling timer, notes, activity management, navigation, etc. Becomes unmaintainable, difficult to test, accumulates state management bugs, slows down Xcode previews and compilation.

**Why it happens:**
Web app experience (React component of 1000+ lines cited in PROJECT.md). SwiftUI's declarative syntax encourages putting everything in one file. Refactoring feels harder than adding "just one more feature."

**Consequences:**
- Xcode previews fail or timeout on large files
- Compile times increase significantly
- Difficult to test individual features
- State bugs from unintended interactions
- New developers can't understand code
- Merge conflicts on every feature branch

**Prevention:**
- Split views into components < 300 lines as rule of thumb
- Extract subviews: TimerDisplayView, ActivityListView, SessionNotesView, SessionControlsView
- Use view modifiers for reusable styling
- Extract ViewModels for business logic (MVVM pattern)
- One ViewModel per major feature, not one ViewModel for entire app
- Xcode Preview separate components independently
- Keep session state in separate StateObject, pass via @EnvironmentObject

**Warning signs:**
- Any view file > 500 lines
- Xcode previews slow or failing
- Difficult to understand view hierarchy
- Single ViewModel managing timer + activities + notes + navigation
- Preview requires full app initialization to work

**Phase to address:**
Phase 1 (Core Architecture) - Component structure must be modular from start, not refactored later under deadline pressure.

---

### Pitfall 6: Incorrect Timer Tolerance and RunLoop Configuration

**What goes wrong:**
Timer fires inconsistently - skips seconds, stops during scrolling, varies by 200-300ms, or doesn't fire at all. Users see timer skip from 1:00 to 1:02, or freeze during interaction.

**Why it happens:**
iOS optimizes timer tolerance for battery life. Default RunLoop mode stops during scrolling/gestures. Developers use 1-second Timer intervals expecting perfect accuracy. Timer.publish not configured correctly for SwiftUI.

**Consequences:**
- Practice session times inaccurate (off by minutes in long sessions)
- Users lose trust in app accuracy
- Timer appears frozen during scrolling/interaction
- Negative app reviews citing "timer doesn't work correctly"

**Prevention:**
- Use Timer.publish with `.common` RunLoop mode (not default mode which stops during interaction)
- Reduce timer interval to 0.1 seconds for smoother display updates
- Still calculate elapsed time from Date difference, not timer ticks
- Set timer tolerance explicitly: `timer.tolerance = 0.05` for tighter accuracy
- Never use timer ticks to count elapsed seconds (accumulates drift)
- For critical accuracy, use CADisplayLink (60fps) or date-based calculations
- Test while scrolling, interacting with UI elements

**Warning signs:**
- Timer.publish without explicit RunLoop mode
- Timer interval = 1.0 with no tolerance setting
- Elapsed time = counter++ (not Date calculations)
- Timer stops firing during list scrolling
- No testing with active UI interaction

**Phase to address:**
Phase 1 (Core Timer Architecture) - Timer configuration must be correct from initial implementation.

---

### Pitfall 7: Sign in with Apple Incomplete Implementation

**What goes wrong:**
App has Google OAuth but missing/broken Sign in with Apple. App Store rejects submission because Apple requires Sign in with Apple when offering any third-party authentication. Edge cases not handled: credential conflicts, email already in use, user cancellation, anonymous upgrade.

**Why it happens:**
Developers add Google OAuth first (easier), forget Sign in with Apple is App Store requirement. Implementation seems simple but edge cases are complex. Firebase error codes not properly handled.

**Consequences:**
- App Store rejection: "Guideline 4.8 - Sign in with Apple required"
- Users can't authenticate on first launch
- Account linking fails, user loses data
- Crashes on error paths not tested
- Privacy issues if not properly configured

**Prevention:**
- Implement Sign in with Apple before Google OAuth submission
- Handle all Firebase auth error codes: credentialAlreadyInUse, emailAlreadyInUse, providerAlreadyLinked
- Wrap ASAuthorizationAppleIDButton in UIViewRepresentable for SwiftUI
- Test user flows: new user, existing email, credential conflict, cancellation
- Support anonymous user upgrade to permanent account
- Configure Apple Developer Account capabilities correctly
- Verify user email verification status (emails not always verified with Apple sign-in)
- Test on device, not just simulator (simulator has limitations)

**Warning signs:**
- Google OAuth implemented, Sign in with Apple missing or "TODO"
- No error handling for credential/email conflicts
- No anonymous user upgrade flow
- Not tested on physical device
- No handling of user cancellation (user taps "Cancel" in Apple dialog)
- Missing team/capabilities configuration in Xcode

**Phase to address:**
Phase 1 (Authentication) - Sign in with Apple must be complete before first TestFlight build or submission.

---

### Pitfall 8: Firestore Document Size Limits Exceeded

**What goes wrong:**
Practice session document grows beyond 1MB limit as user adds notes, activity details, or embeds data. Firestore write fails with document size error. User loses entire session. Historical sessions can't be loaded.

**Why it happens:**
Developers structure session as single document with embedded arrays of activities, notes, timestamps. Arrays grow unbounded over long practice sessions (2+ hours with detailed notes).

**Consequences:**
- Session save fails silently or with cryptic error
- User loses all practice session data
- App crashes when loading large session
- Query performance degrades as documents approach limit
- Can't add more activities/notes mid-session

**Prevention:**
- Use subcollections for arrays that could exceed 20 items: activities, notes, milestones
- Store session metadata in document, activity details in subcollection
- Calculate document size before write: rough estimate text size + overhead
- Enforce client-side limits well below 1MB (e.g., 500KB warning, 800KB hard limit)
- Use references for related data instead of embedding
- Test with realistic data: 3-hour session, 20 activities, 200 words notes per activity
- Monitor document sizes in production, alert on growth trends

**Warning signs:**
- Session document contains arrays of activities with notes
- No document size validation before write
- Arrays can grow unbounded (no pagination/subcollections)
- Embedding user profile data in session document
- No testing with large realistic sessions

**Phase to address:**
Phase 1 (Data Model) - Data model must use subcollections from start; very difficult to migrate later.

---

## Moderate Pitfalls

### Pitfall 9: Missing App Store Metadata Requirements

**What goes wrong:**
App ready to submit but blocked by missing privacy policy, terms of service, screenshots for all device sizes, app icons (all sizes), App Privacy labels, or age rating questionnaire.

**Prevention:**
- Privacy policy hosted and accessible (required for all apps since Oct 2018)
- Terms of service if using Sign in with Apple or in-app purchases
- App Privacy labels accurately describe data collection
- Screenshots: iPhone 6.7", iPhone 5.5", iPad Pro 12.9" minimum
- App icons: all sizes required by Xcode asset catalog
- Age rating questionnaire completed by Jan 31, 2026 (new requirement)
- Korea-specific: Server-to-server notification endpoint if using Sign in with Apple (required Jan 1, 2026)
- Test submission on TestFlight first to catch metadata issues

**Phase to address:**
Phase 4 (Pre-Launch) - Metadata preparation before first submission attempt.

---

### Pitfall 10: Performance Issues from Excessive Firestore Queries

**What goes wrong:**
App makes separate query per activity in session (N+1 query problem). Offline query scans all cached documents. Real-time listeners on collections re-fetch entire dataset on each change. App becomes slow, burns battery, generates excessive Firestore costs.

**Prevention:**
- Batch reads: single query with document ID array, not loop of individual gets
- Use collection group queries when querying across users/subcollections
- Limit real-time listeners to actively visible data
- Offline: use index-backed queries (Firestore only scans indexed docs, not all cache)
- Paginate large collections (activities, sessions) - 20-50 items per page
- Cache non-changing data in memory (user profile, activity metadata)
- Monitor Firestore usage in Firebase console, set budget alerts

**Phase to address:**
Phase 2 (Performance Optimization) - After core features work, before scale testing.

---

### Pitfall 11: Ignoring Swift 6 / Xcode 16 Breaking Changes

**What goes wrong:**
Code written with iOS 16+ target uses ObservableObject without importing Combine. Builds fail in Xcode 16+ because SWIFT_MEMBER_IMPORT_VISIBILITY changed to private by default.

**Prevention:**
- Explicitly `import Combine` when using ObservableObject
- Test build with latest Xcode version, not just minimum supported
- Migrate to @Observable (iOS 17+) for new code when possible
- Set minimum iOS version intentionally: iOS 16 for broader reach vs iOS 17 for modern APIs
- Review Xcode 16 migration guide before updating

**Phase to address:**
Phase 1 (Project Setup) - Target iOS version and import statements must be correct from start.

---

### Pitfall 12: No Offline State Indication to User

**What goes wrong:**
User practices offline, sees session saving successfully (optimistic update). Comes online later, data never synced (conflict or error). No indication data not persisted. User loses trust.

**Prevention:**
- Show network connectivity indicator
- Differentiate UI: "Saved" vs "Saved locally, syncing..."
- Use Firestore metadata: hasPendingWrites property
- Alert user before critical actions if offline
- Retry failed writes when connection restored
- Show sync status: "Synced 5 minutes ago" vs "Syncing now"

**Phase to address:**
Phase 2 (Offline & Sync) - After offline persistence working, add user feedback.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Test mode security rules in dev | Fast iteration, no auth setup | Accidentally deploy to prod, major breach | Local emulator only, never deploy |
| @ObservedObject instead of @StateObject | One less line of code | Memory leaks, undefined lifecycle | Never in production code |
| Embedded arrays instead of subcollections | Simpler queries, less code | Hit 1MB limit, can't paginate, slow queries | Arrays guaranteed < 20 items |
| Timer tick counter instead of Date math | Simpler logic | Drift accumulates, background fails | Never for user-visible timers |
| Single massive ViewModel | No file switching, "everything in one place" | Unmaintainable, slow compile, hard to test | Never - always split |
| No security rule tests | Faster initial development | Production data breach | Never - write tests day 1 |
| Skipping memory profiling | Faster feature development | Crashes in production | Only in prototypes, never production |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Firebase Auth + Sign in with Apple | Assume email verified | Check user.emailVerified, don't trust email without verification |
| Firestore offline persistence | Use `await` on writes | Never await writes offline; use optimistic updates, listen for completion |
| Firebase listeners in SwiftUI | Store in @Published var, no cleanup | Store listener handle, call remove() in .task or deinit |
| Timer.publish in SwiftUI | Default RunLoop mode | Use .common mode: `.autoconnect().runLoop(.common, mode: .common)` |
| Firestore security rules | Copy client validation logic | Rewrite for security rule syntax, test independently |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| N+1 queries (fetch each activity individually) | Slow session load, high Firestore costs | Batch fetch: getDocuments(documentIds) | > 10 activities per session |
| Offline query scanning all cache | Slow queries offline, battery drain | Use index-backed queries, limit cache size | Cache > 50MB or 1000s of docs |
| Real-time listeners on root collections | High bandwidth, battery drain, excessive updates | Query only user's data, paginate listeners | > 100 documents in collection |
| Large document sizes (> 500KB) | Slow writes, approaching 1MB limit | Use subcollections, separate documents | Session notes > 10KB |
| Unbounded array growth | Memory leaks, document size limit | Paginate, use subcollections | Arrays > 100 items |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Test mode rules in production | Complete data breach, all users access all data | Never deploy `allow read, write: if true`; use Firebase rules emulator + tests |
| No validation of user ownership | Users access/modify others' practice sessions | Always check `request.auth.uid == resource.data.userId` |
| Client-side-only validation | Malicious users bypass validation, corrupt data | Mirror all validation in Firestore security rules |
| Trusting email without verification | Account takeover, impersonation | Check `request.auth.token.email_verified == true` |
| Hardcoded API keys in code | API abuse, quota exhaustion | Use iOS bundle restrictions in Firebase console |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No indication of offline state | User confused why data not syncing | Show connectivity status, pending sync indicator |
| Timer resets when app backgrounded | Lost practice session, user frustration | Use date-based calculations, warn user before backgrounding |
| Silent sync failures | Data loss without user awareness | Show sync errors, retry automatically, persist locally until success |
| No conflict resolution UX | Last write wins silently, data overwritten | Warn user about multi-device conflicts, show last-synced time |
| Optimistic updates with no rollback | User sees success, but write failed | Listen for write confirmation, rollback on error with explanation |

## "Looks Done But Isn't" Checklist

- [ ] **Timer accuracy:** Often missing RunLoop .common mode — verify timer continues during scrolling
- [ ] **Offline writes:** Often missing conflict detection — verify multi-device write scenario
- [ ] **Sign in with Apple:** Often missing error handling — verify credentialAlreadyInUse flow
- [ ] **Memory management:** Often missing listener cleanup — verify listeners removed when view disappears
- [ ] **Security rules:** Often missing tests — verify rules tested in CI, not just client validation
- [ ] **Background timer:** Often missing date-based calculation — verify timer accurate after app backgrounded
- [ ] **Document size:** Often missing size validation — verify session with 20+ activities doesn't exceed 1MB
- [ ] **Offline queries:** Often missing cache monitoring — verify queries work after cache eviction
- [ ] **Privacy policy:** Often missing or placeholder — verify actual hosted privacy policy before submission
- [ ] **App Store screenshots:** Often missing iPad sizes — verify all required device sizes present

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Test mode security rules deployed | **HIGH** | Immediately deploy secure rules; audit all data for unauthorized access; notify affected users if breach confirmed; may require full security review |
| Hit 1MB document limit | **HIGH** | Migrate to subcollections; write migration script; requires app update + backend migration; may lose some data if over limit |
| Memory leaks in production | **MEDIUM** | Add listener cleanup; release patch update; may require architecture refactor if deeply embedded |
| Timer accuracy issues | **MEDIUM** | Refactor to date-based calculations; release update; existing sessions may need recalculation |
| Missing Sign in with Apple | **MEDIUM** | Implement and test; delay submission; requires Apple Developer Account configuration |
| Offline sync failures | **LOW** | Add error handling and retry logic; most data eventually syncs when fixed |
| Large document sizes (approaching limit) | **MEDIUM** | Refactor to subcollections; provide migration for existing data; release update before hitting limit |
| Background mode rejection | **LOW** | Remove background modes; refactor to local notifications; resubmit |

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: Authentication | Missing Sign in with Apple or incomplete error handling | Implement Apple sign-in first, test all error codes, test on device |
| Phase 1: Data Model | Document structure allows exceeding 1MB limit | Use subcollections for activities/notes from day 1; hard to migrate later |
| Phase 1: Timer Architecture | Timer using background execution or tick counting | Date-based calculations + .common RunLoop mode from start |
| Phase 1: Security Rules | Test mode rules or no validation | Write security rules + tests before first user data |
| Phase 2: Offline Sync | Assuming offline "just works" | Test cache limits, conflict scenarios, offline→online transitions |
| Phase 2: Performance | N+1 queries or unbounded listeners | Batch queries, paginate, monitor Firestore usage |
| Phase 3: Memory Management | ObservableObject leaks accumulate | Profile memory after every navigation path; verify listener cleanup |
| Phase 4: App Store Submission | Missing metadata or privacy policy | Complete metadata checklist 2 weeks before target submission |

## Sources

- Firebase Firestore Offline Documentation (Updated Feb 2026): https://firebase.google.com/docs/firestore/manage-data/enable-offline
- Apple Developer Forums: Background Timer Limitations (2026): https://developer.apple.com/forums/thread/113177
- Medium: Overcoming iOS Background Limits (2026): https://medium.com/deuk/overcoming-ios-background-limits-a-time-tracker-app-in-swift-ui-5d157a58df68
- HackingWithSwift: Timer in SwiftUI: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-a-timer-with-swiftui
- Firebase Developers: Sign in with Apple (2026): https://medium.com/firebase-developers/firebase-authentication-in-swiftui-part-3-80be99dbc63d
- App Store Review Guidelines (2026): https://developer.apple.com/app-store/review/guidelines/
- DEV Community: Memory Leaks in SwiftUI (2026): https://dev.to/vnayak_hejib/memory-leaks-in-swiftui-where-they-hide-how-to-catch-them-real-world-examples-84i
- Firebase: Firestore Data Model (Updated Feb 2026): https://firebase.google.com/docs/firestore/data-model
- Medium: Why I Quit Using ObservableObject: https://nalexn.github.io/swiftui-observableobject/
- Fireship: Firestore Data Modeling Course: https://fireship.io/courses/firestore-data-modeling/
- Apple Developer News: Sign in with Apple Requirements (2026): https://developer.apple.com/news/?id=j9zukcr6

---
*Pitfalls research for: iOS Hone App (SwiftUI + Firebase)*
*Researched: 2026-03-01*
*Confidence: MEDIUM - Findings based on official Firebase docs (HIGH), Apple Developer forums (MEDIUM), and community sources (MEDIUM). Specific practice timer domain patterns from community (LOW-MEDIUM).*
