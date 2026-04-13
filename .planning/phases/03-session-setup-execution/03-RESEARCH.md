# Phase 3: Session Setup & Execution - Research

**Researched:** 2026-03-03
**Domain:** iOS timer architecture with backgrounding, session state management, SwiftUI component organization
**Confidence:** HIGH

## Summary

Phase 3 implements the core value proposition of Hone: accurate timed practice sessions that survive iOS backgrounding. The primary technical challenges are iOS background execution limits (30-second suspension), timer accuracy across app lifecycle transitions, and session state persistence for crash recovery.

**Key architectural decisions:**
- **Timer approach:** Date-based calculation using `Date().timeIntervalSince(startTime)` instead of tick-based counters
- **State persistence:** Firestore for session data + @SceneStorage for UI state (pause/resume flags)
- **Backgrounding strategy:** scenePhase monitoring with automatic pause/resume, no background modes needed
- **Component architecture:** Extract timer display, session controls, activity queue, and notes UI into separate views (< 300 lines each)

**Primary recommendation:** Store session state in Firestore immediately on each state change (pause, activity skip, note add) with optimistic UI updates. Calculate elapsed time from date differences, not timer ticks. Use .common RunLoop mode for Timer.publish to fire during user interaction. Extract SessionViewModel from view layer to own all session business logic.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SETUP-01 | User can view list of activities to select for practice session | Use ActivityRepository.listenToActiveActivities (Phase 2), display in selectable list |
| SETUP-02 | User can select multiple activities for practice session | SwiftUI List with EditButton and selection binding, store selected IDs |
| SETUP-04 | User can start practice session with selected activities in fewer steps than web app | Single "Start Session" button creates session document and navigates to timer view |
| SETUP-05 | User can reorder activities before starting session | EditButton + onMove modifier on List, update local array |
| EXEC-01 | User can start timed practice session | Create session document, store startTime as ISO8601, transition to active state |
| EXEC-02 | User sees large, clear time display during practice (readable from distance) | Large text (80-100pt), monospace font, high contrast, custom timer display component |
| EXEC-03 | User can pause practice session | Store pausedAt timestamp, calculate elapsed, transition to paused state |
| EXEC-04 | User can resume paused practice session | Calculate new startTime accounting for paused duration, transition to active state |
| EXEC-05 | User can add notes for current activity during practice | Text field bound to temporary note state, save to session.activities[current].notes on submit |
| EXEC-06 | User can view notes added during practice | Display notes below timer for current activity |
| EXEC-07 | User can skip to next activity during session | End current activity (save elapsed time), increment currentActivityIndex, start next |
| EXEC-08 | User can remove upcoming activity from session | Remove from activities array, update Firestore session document |
| EXEC-09 | User can reorder activities during active session | EditButton + onMove on upcoming activities list |
| EXEC-10 | User sees visual progress indicator showing session completion | ProgressView with value = completedActivities / totalActivities |
| EXEC-11 | App tracks "in between" time (breaks between activities) | Start in-between timer when activity ends, end when next starts, store as separate sessionActivity |
| EXEC-12 | User can end practice session | Set session.endTime, calculate totalDuration, transition to summary view |
| EXEC-13 | Timer continues accurately when app is backgrounded | scenePhase observer calculates elapsed time on foreground return, updates timer state |
| EXEC-14 | Timer displays use simple, obvious controls | Large buttons (min 60pt), clear labels, single-action per control |
| EXEC-15 | Session state persists if app crashes or force-quit | All state changes write to Firestore immediately, resume logic reconstructs from Firestore on launch |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Firebase iOS SDK | 12.10.0+ | Session persistence, real-time sync | Already integrated in Phase 1-2, handles offline persistence |
| SwiftUI | iOS 16+ | UI framework | Native iOS framework, excellent timer integration |
| Combine | iOS 16+ | Timer publisher, scenePhase observation | Built-in reactive framework, Timer.publish integration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| XCTest | iOS 16+ | Unit testing timer logic | Test date calculations, state transitions, session ViewModel |

### No Additional Dependencies Required

Phase 3 uses only standard iOS frameworks and the Firebase SDK already integrated in Phase 1. No third-party timer libraries needed - SwiftUI's Timer.publish with date-based calculations handles all requirements.

**Installation:**
No additional packages needed. All frameworks available via Xcode and Firebase iOS SDK 12.10.0+ from Phase 1.

## Architecture Patterns

### Recommended Project Structure
```
Hone/
├── Features/
│   └── Sessions/
│       ├── ViewModels/
│       │   └── SessionViewModel.swift        # Session business logic (timer, state, Firestore operations)
│       ├── Views/
│       │   ├── SessionSetupView.swift        # Activity selection, reordering
│       │   ├── ActiveSessionView.swift       # Main session view (orchestrator)
│       │   ├── TimerDisplayView.swift        # Large timer display component (< 200 lines)
│       │   ├── SessionControlsView.swift     # Pause/Resume/End buttons
│       │   ├── ActivityQueueView.swift       # Upcoming activities with skip/remove/reorder
│       │   ├── SessionNotesView.swift        # Notes input and display
│       │   └── SessionSummaryView.swift      # Post-session summary
│       └── Models/
│           └── SessionState.swift            # Session state enum (setup, active, paused, inBetween, ended)
├── Core/
│   ├── Repositories/
│   │   └── SessionRepository.swift           # Session CRUD + listeners (mirrors ActivityRepository pattern)
│   └── Models/
│       └── Session.swift                     # Already exists, may need extension for SessionActivity subcollection
```

### Pattern 1: Date-Based Timer Calculation

**What:** Store start time as Date, calculate elapsed time from difference between current time and start time
**When to use:** All timer implementations where accuracy across backgrounding is required
**Why:** iOS suspends apps ~30 seconds after backgrounding, stopping all timers. Date-based calculation survives suspension.

**Example:**
```swift
// SessionViewModel.swift
@MainActor
final class SessionViewModel: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    @Published var sessionState: SessionState = .setup

    private var startTime: Date?
    private var pausedElapsedTime: TimeInterval = 0
    private var timerCancellable: AnyCancellable?

    // CRITICAL: Use date-based calculation, not tick counter
    func startTimer() {
        startTime = Date()
        sessionState = .active

        // Timer fires every 0.1s for smooth display, but uses date difference for accuracy
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.startTime else { return }
                self.elapsedTime = self.pausedElapsedTime + Date().timeIntervalSince(start)
            }
    }

    func pauseTimer() {
        timerCancellable?.cancel()
        pausedElapsedTime = elapsedTime
        startTime = nil
        sessionState = .paused
    }

    func resumeTimer() {
        // Start new timer with existing elapsed time
        startTimer()
    }
}
```

**Source:** Hacking with Swift forums, Medium article on background timers (Feb 2024)

### Pattern 2: scenePhase Monitoring for Background Handling

**What:** Use SwiftUI's scenePhase environment value to detect background/foreground transitions
**When to use:** When timer must update correctly after backgrounding (iOS suspends after ~30s)
**Why:** Timer.publish stops firing when app is suspended. Must recalculate on foreground return.

**Example:**
```swift
// ActiveSessionView.swift
struct ActiveSessionView: View {
    @StateObject var viewModel: SessionViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimerDisplayView(elapsedTime: viewModel.elapsedTime)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if oldPhase == .background && newPhase == .active {
                    // App returned to foreground - timer state already correct via date calculation
                    // No action needed if using date-based approach
                    // If timer was cancelled on background, restart it here
                    viewModel.refreshTimerIfNeeded()
                }
            }
    }
}
```

**Source:** Apple Developer Documentation on scenePhase

### Pattern 3: Firestore Session State Persistence

**What:** Write session state to Firestore on every state change (pause, resume, activity skip, note add)
**When to use:** When session must survive app crashes, force-quits, or device reboots
**Why:** @SceneStorage only persists UI state. Firestore provides durable, cross-device session state.

**Example:**
```swift
// SessionRepository.swift
protocol SessionRepositoryProtocol {
    func createSession(userId: String, session: Session) async throws -> Session
    func updateSessionState(userId: String, sessionId: String, updates: [String: Any]) async throws
    func getActiveSession(userId: String) async throws -> Session?
    func endSession(userId: String, sessionId: String, endTime: String, totalDuration: Int) async throws
}

// SessionViewModel.swift
func pauseTimer() async {
    pauseTimer() // Local state update

    // Persist to Firestore immediately for crash recovery
    guard let sessionId = currentSession?.id else { return }
    let updates: [String: Any] = [
        "state": "paused",
        "pausedAt": Date().toISO8601String(),
        "elapsedSeconds": Int(elapsedTime)
    ]
    try? await repository.updateSessionState(userId: userId, sessionId: sessionId, updates: updates)
}
```

**Data Model Extension Needed:**
```swift
// Session.swift - Add session state fields
struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    let startTime: String
    var endTime: String?
    var state: String?  // "active", "paused", "inBetween", "ended"
    var pausedAt: String?
    var currentActivityIndex: Int?
    let totalDuration: Int  // seconds
    let createdAt: String
    var updatedAt: String

    // Path: users/{userId}/sessions/{sessionId}
    // Subcollection: users/{userId}/sessions/{sessionId}/activities
}

struct SessionActivity: Codable, Identifiable {
    @DocumentID var id: String?
    let activityId: String?  // Reference to Activity, nil for "in-between" time
    let activityName: String
    var startTime: String
    var endTime: String?
    var duration: Int  // seconds
    var notes: String?
    var isInBetweenTime: Bool  // true for break periods
    let createdAt: String
    var updatedAt: String

    // Path: users/{userId}/sessions/{sessionId}/activities/{activityId}
}
```

**Source:** Firebase Firestore documentation, existing ActivityRepository pattern from Phase 2

### Pattern 4: Component Extraction (Avoid Massive View Files)

**What:** Extract UI sections into separate view components with single responsibilities
**When to use:** When any view file exceeds ~300 lines or contains multiple distinct UI sections
**Why:** Web app PracticeSession.tsx is 1000+ lines - iOS must avoid this from start

**Example:**
```swift
// TimerDisplayView.swift - SINGLE RESPONSIBILITY: Display elapsed time
struct TimerDisplayView: View {
    let elapsedTime: TimeInterval

    private var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 80, weight: .bold, design: .monospaced))
            .foregroundColor(.primary)
            // Readable from 10 feet (music stand distance) - PROJECT.md requirement
    }
}

// SessionControlsView.swift - SINGLE RESPONSIBILITY: Pause/Resume/End buttons
struct SessionControlsView: View {
    let state: SessionState
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            if state == .active {
                Button(action: onPause) {
                    Label("Pause", systemImage: "pause.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)  // Large touch targets for holding instrument
            } else if state == .paused {
                Button(action: onResume) {
                    Label("Resume", systemImage: "play.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button(action: onEnd) {
                Label("End Session", systemImage: "stop.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

// ActiveSessionView.swift - ORCHESTRATOR: Composes components
struct ActiveSessionView: View {
    @StateObject var viewModel: SessionViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 30) {
            // Current activity name
            Text(viewModel.currentActivityName)
                .font(.title2)

            // Large timer display
            TimerDisplayView(elapsedTime: viewModel.elapsedTime)

            // Progress indicator
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)

            // Session controls
            SessionControlsView(
                state: viewModel.sessionState,
                onPause: { Task { await viewModel.pauseTimer() } },
                onResume: { Task { await viewModel.resumeTimer() } },
                onEnd: { Task { await viewModel.endSession() } }
            )

            // Notes for current activity
            SessionNotesView(
                notes: viewModel.currentActivityNotes,
                onAddNote: { note in Task { await viewModel.addNote(note) } }
            )

            // Upcoming activities queue
            ActivityQueueView(
                activities: viewModel.upcomingActivities,
                onSkip: { Task { await viewModel.skipToNext() } },
                onRemove: { activity in Task { await viewModel.removeActivity(activity) } },
                onReorder: { indices in viewModel.reorderActivities(indices) }
            )
        }
        .padding()
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background && newPhase == .active {
                viewModel.refreshTimerIfNeeded()
            }
        }
    }
}
```

**Source:** Swift by Sundell "Avoiding massive SwiftUI views", DEV Community "SwiftUI Component Architecture Mastery" (2025)

### Pattern 5: RunLoop .common Mode for Timer.publish

**What:** Use `.common` RunLoop mode when creating Timer.publish to ensure timer fires during user interaction
**When to use:** When timer must update while user scrolls, types, or interacts with UI
**Why:** Default RunLoop mode pauses during UI interaction, causing timer display to freeze

**Example:**
```swift
// SessionViewModel.swift
func startTimer() {
    startTime = Date()
    sessionState = .active

    // CRITICAL: Use .common mode, not .default
    // .default pauses during scrolling/typing
    // .common continues firing during all user interaction
    timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.elapsedTime = self.pausedElapsedTime + Date().timeIntervalSince(start)
        }
}
```

**Source:** Hacking with Swift "The ultimate guide to Timer", Swift Forums RunLoop discussions

### Anti-Patterns to Avoid

- **Tick-based counters:** Storing elapsed seconds and incrementing on each timer fire - loses accuracy when app backgrounds
- **Background modes abuse:** Requesting audio/location/voip background modes for timer app - App Store rejection risk
- **UserDefaults for session state:** Too slow for frequent writes on pause/resume, not designed for structured data
- **Massive view files:** Combining timer display, controls, notes, and activity queue in one 800+ line file - maintenance nightmare
- **Timer without .common mode:** Using default RunLoop mode causes timer to freeze during user interaction
- **@AppStorage for session state:** Sessions are temporary per-device, @SceneStorage or Firestore more appropriate

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timer backgrounding | Custom background task scheduler, local notifications as timer | Date-based calculation with scenePhase monitoring | iOS suspends apps after 30s regardless of background tasks (except specific modes like audio/location). Date calculation is simple and reliable. |
| Session state persistence | Custom file I/O, binary serialization | Firestore with immediate writes + @SceneStorage for UI flags | Firestore handles offline queuing, conflict resolution, and cross-device sync automatically. Reinventing this is high-risk. |
| Time formatting | String manipulation for HH:MM:SS | DateComponentsFormatter or manual calculation with String(format:) | DateComponentsFormatter handles localization, edge cases (>24hr sessions), and zero-padding automatically |
| Timer accuracy tracking | Tolerance compensation algorithms | Date-based calculation | Timers have ~50-100ms tolerance. Date difference is always accurate to millisecond precision. |

**Key insight:** iOS background execution is severely limited by design (30-second suspension for non-audio/navigation apps). Fighting this with background tasks is futile - embrace date-based calculations that work WITH iOS's constraints, not against them.

## Common Pitfalls

### Pitfall 1: Timer Stops After 30 Seconds in Background

**What goes wrong:** App backgrounds, timer fires for ~30 seconds, then iOS suspends app and timer stops completely. User returns to frozen timer showing time from 30 seconds after backgrounding.

**Why it happens:** iOS aggressively suspends apps to preserve battery. Only specific background modes (audio playback, navigation, VOIP) allow continued execution. Timer apps don't qualify.

**How to avoid:**
1. Use date-based calculation: store startTime as Date, calculate `Date().timeIntervalSince(startTime)` on every timer tick
2. On scenePhase change from background → active, recalculate elapsed time from stored startTime
3. Timer publisher can be cancelled during background and restarted on foreground - date calculation remains accurate

**Warning signs:** Timer value doesn't match wall clock time after backgrounding, "background time remaining" logs in console

**Source:** Apple Developer Forums "iOS Background Execution Limits", Medium "Overcoming iOS Background Limits"

### Pitfall 2: Session State Lost on Force Quit

**What goes wrong:** User force-quits app mid-session. On restart, session is lost - no way to resume practice.

**Why it happens:** @SceneStorage and @AppStorage don't write to disk until app enters background gracefully. Force quit bypasses this save cycle.

**How to avoid:**
1. Write session state to Firestore on EVERY state change (pause, activity skip, note add)
2. On app launch, check Firestore for active session (state != "ended")
3. Present "Resume Session?" alert if active session found
4. Use optimistic UI updates for responsiveness - don't wait for Firestore confirmation

**Warning signs:** No resume option after force quit, "session not found" errors on restart

**Source:** Apple Documentation on SceneStorage, Firebase best practices

### Pitfall 3: Massive View File (Session View 800+ Lines)

**What goes wrong:** ActiveSessionView contains timer display, controls, notes UI, activity queue, progress indicator, and all business logic in one file. Becomes unmaintainable.

**Why it happens:** Natural to start with all UI in one view. SwiftUI's declarative syntax makes 800-line files "feel" organized even when they're not.

**How to avoid:**
1. Extract components EARLY - don't wait until refactor is painful
2. Single Responsibility Principle: TimerDisplayView only displays time, SessionControlsView only shows buttons
3. Use Xcode's "Extract Subview" refactoring (Cmd+click on View builder expression)
4. Set line count limit: if any view exceeds 300 lines, extract components
5. Move business logic to ViewModel - views should only render @Published properties

**Warning signs:** Difficulty finding where specific UI element is defined, merge conflicts in session view, test coverage gaps

**Source:** Swift by Sundell "Avoiding massive SwiftUI views", Clean Swift architecture articles

### Pitfall 4: Timer Display Freezes During User Interaction

**What goes wrong:** User types notes or scrolls activity queue, timer display stops updating. Resumes when user stops interacting.

**Why it happens:** Timer.publish uses `.default` RunLoop mode by default, which pauses during user interaction (scrolling, text input).

**How to avoid:**
```swift
// BAD - timer freezes during interaction
Timer.publish(every: 0.1, on: .main, in: .default)

// GOOD - timer continues during interaction
Timer.publish(every: 0.1, on: .main, in: .common)
```

**Warning signs:** Timer seconds skip when scrolling stops, timer freezes while typing notes

**Source:** Hacking with Swift "The ultimate guide to Timer", Swift Forums RunLoop discussions

### Pitfall 5: In-Between Time Tracking Forgotten

**What goes wrong:** User completes activity A, takes 2-minute break, starts activity B. The 2-minute break is not tracked or displayed in session summary.

**Why it happens:** Easy to focus on activity timing and forget about transition periods. Web app tracks this - iOS must too for data consistency.

**How to avoid:**
1. When user taps "Next Activity" or completes current activity, start in-between timer
2. Create SessionActivity with `isInBetweenTime: true` and `activityName: "Break"`
3. End in-between timer when next activity starts
4. Display in-between time as separate entries in session summary

**Warning signs:** Session summary total time doesn't match wall clock duration, missing time periods in session breakdown

**Source:** PROJECT.md requirement "App tracks 'in between' time (breaks between activities)", web app behavior mapping

## Code Examples

Verified patterns from research and existing codebase:

### Timer with Background Handling
```swift
// SessionViewModel.swift
import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class SessionViewModel: ObservableObject {
    // MARK: - Published State
    @Published var elapsedTime: TimeInterval = 0
    @Published var sessionState: SessionState = .setup
    @Published var currentActivityIndex: Int = 0
    @Published var activities: [SessionActivity] = []

    // MARK: - Dependencies
    private let repository: SessionRepositoryProtocol
    private let userId: String

    // MARK: - Timer State
    private var startTime: Date?
    private var pausedElapsedTime: TimeInterval = 0
    private var timerCancellable: AnyCancellable?

    // MARK: - Session State
    private var currentSession: Session?

    init(userId: String, repository: SessionRepositoryProtocol = SessionRepository()) {
        self.userId = userId
        self.repository = repository
    }

    // MARK: - Session Lifecycle

    func startSession(selectedActivities: [Activity]) async throws {
        // Create session document in Firestore
        let session = Session(
            id: nil,
            startTime: Date().toISO8601String(),
            endTime: nil,
            state: "active",
            pausedAt: nil,
            currentActivityIndex: 0,
            totalDuration: 0,
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String()
        )

        currentSession = try await repository.createSession(userId: userId, session: session)

        // Initialize activity queue
        activities = selectedActivities.enumerated().map { index, activity in
            SessionActivity(
                id: nil,
                activityId: activity.id,
                activityName: activity.name,
                startTime: index == 0 ? Date().toISO8601String() : "",
                endTime: nil,
                duration: 0,
                notes: nil,
                isInBetweenTime: false,
                createdAt: Date().toISO8601String(),
                updatedAt: Date().toISO8601String()
            )
        }

        // Start timer for first activity
        startTimer()
    }

    func startTimer() {
        startTime = Date()
        sessionState = .active

        // CRITICAL: Use .common RunLoop mode for timer during user interaction
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.startTime else { return }
                // Date-based calculation - survives backgrounding
                self.elapsedTime = self.pausedElapsedTime + Date().timeIntervalSince(start)
            }
    }

    func pauseTimer() async {
        timerCancellable?.cancel()
        pausedElapsedTime = elapsedTime
        startTime = nil
        sessionState = .paused

        // Persist to Firestore for crash recovery
        guard let sessionId = currentSession?.id else { return }
        let updates: [String: Any] = [
            "state": "paused",
            "pausedAt": Date().toISO8601String(),
            "updatedAt": Date().toISO8601String()
        ]
        try? await repository.updateSessionState(userId: userId, sessionId: sessionId, updates: updates)
    }

    func resumeTimer() async {
        startTimer()

        // Update Firestore
        guard let sessionId = currentSession?.id else { return }
        let updates: [String: Any] = [
            "state": "active",
            "pausedAt": NSNull(),  // Remove pausedAt field
            "updatedAt": Date().toISO8601String()
        ]
        try? await repository.updateSessionState(userId: userId, sessionId: sessionId, updates: updates)
    }

    func skipToNext() async {
        // End current activity
        var currentActivity = activities[currentActivityIndex]
        currentActivity.endTime = Date().toISO8601String()
        currentActivity.duration = Int(elapsedTime)
        activities[currentActivityIndex] = currentActivity

        // Save current activity to Firestore
        guard let sessionId = currentSession?.id else { return }
        try? await repository.addSessionActivity(
            userId: userId,
            sessionId: sessionId,
            activity: currentActivity
        )

        // Start in-between time
        pausedElapsedTime = 0
        elapsedTime = 0
        sessionState = .inBetween
        startTimer()

        // Note: User must manually start next activity (or auto-start after configurable delay)
    }

    func startNextActivity() async {
        // End in-between time
        let inBetweenActivity = SessionActivity(
            id: nil,
            activityId: nil,
            activityName: "Break",
            startTime: startTime?.toISO8601String() ?? "",
            endTime: Date().toISO8601String(),
            duration: Int(elapsedTime),
            notes: nil,
            isInBetweenTime: true,
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String()
        )

        guard let sessionId = currentSession?.id else { return }
        try? await repository.addSessionActivity(
            userId: userId,
            sessionId: sessionId,
            activity: inBetweenActivity
        )

        // Start next activity
        currentActivityIndex += 1
        pausedElapsedTime = 0
        elapsedTime = 0
        sessionState = .active

        var nextActivity = activities[currentActivityIndex]
        nextActivity.startTime = Date().toISO8601String()
        activities[currentActivityIndex] = nextActivity

        startTimer()
    }

    func endSession() async {
        timerCancellable?.cancel()

        // Calculate total duration
        let totalDuration = activities.reduce(0) { $0 + $1.duration }

        guard let sessionId = currentSession?.id else { return }
        try? await repository.endSession(
            userId: userId,
            sessionId: sessionId,
            endTime: Date().toISO8601String(),
            totalDuration: totalDuration
        )

        sessionState = .ended
    }

    // Called when app returns to foreground
    func refreshTimerIfNeeded() {
        if sessionState == .active, timerCancellable == nil {
            // Timer was cancelled during background - restart it
            // Date-based calculation ensures accuracy
            startTimer()
        }
    }

    // MARK: - Computed Properties

    var currentActivityName: String {
        guard currentActivityIndex < activities.count else { return "" }
        return activities[currentActivityIndex].activityName
    }

    var progress: Double {
        guard !activities.isEmpty else { return 0 }
        return Double(currentActivityIndex) / Double(activities.count)
    }

    var upcomingActivities: [SessionActivity] {
        guard currentActivityIndex < activities.count - 1 else { return [] }
        return Array(activities[(currentActivityIndex + 1)...])
    }
}

// SessionState.swift
enum SessionState: String {
    case setup
    case active
    case paused
    case inBetween
    case ended
}
```

### Session Repository Pattern (Mirrors ActivityRepository)
```swift
// SessionRepository.swift
import Foundation
import FirebaseFirestore

protocol SessionRepositoryProtocol {
    func createSession(userId: String, session: Session) async throws -> Session
    func updateSessionState(userId: String, sessionId: String, updates: [String: Any]) async throws
    func getActiveSession(userId: String) async throws -> Session?
    func endSession(userId: String, sessionId: String, endTime: String, totalDuration: Int) async throws
    func addSessionActivity(userId: String, sessionId: String, activity: SessionActivity) async throws
    func listenToSession(userId: String, sessionId: String, completion: @escaping (Session?) -> Void) -> ListenerRegistration
}

final class SessionRepository: SessionRepositoryProtocol {
    private let db = Firestore.firestore()

    func createSession(userId: String, session: Session) async throws -> Session {
        var newSession = session
        newSession.updatedAt = Date().toISO8601String()

        let docRef = try db.collection("users")
            .document(userId)
            .collection("sessions")
            .addDocument(from: newSession)

        newSession.id = docRef.documentID
        return newSession
    }

    func updateSessionState(userId: String, sessionId: String, updates: [String: Any]) async throws {
        var mutableUpdates = updates
        mutableUpdates["updatedAt"] = Date().toISO8601String()

        try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .updateData(mutableUpdates)
    }

    func getActiveSession(userId: String) async throws -> Session? {
        // Find session where state != "ended"
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("state", isNotEqualTo: "ended")
            .limit(to: 1)
            .getDocuments()

        return try snapshot.documents.first?.data(as: Session.self)
    }

    func endSession(userId: String, sessionId: String, endTime: String, totalDuration: Int) async throws {
        let updates: [String: Any] = [
            "state": "ended",
            "endTime": endTime,
            "totalDuration": totalDuration,
            "updatedAt": Date().toISO8601String()
        ]

        try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .updateData(updates)
    }

    func addSessionActivity(userId: String, sessionId: String, activity: SessionActivity) async throws {
        var newActivity = activity
        newActivity.updatedAt = Date().toISO8601String()

        _ = try db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .collection("activities")
            .addDocument(from: newActivity)
    }

    func listenToSession(userId: String, sessionId: String, completion: @escaping (Session?) -> Void) -> ListenerRegistration {
        return db.collection("users")
            .document(userId)
            .collection("sessions")
            .document(sessionId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("ERROR listening to session: \(error)")
                    completion(nil)
                    return
                }

                guard let snapshot = snapshot else {
                    completion(nil)
                    return
                }

                let session = try? snapshot.data(as: Session.self)
                completion(session)
            }
    }
}
```

### Component Extraction Example
```swift
// TimerDisplayView.swift - Single responsibility: Display time
struct TimerDisplayView: View {
    let elapsedTime: TimeInterval

    private var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 80, weight: .bold, design: .monospaced))
            .foregroundColor(.primary)
            .monospacedDigit()  // Prevents width changes when digits change
    }
}

// ActivityQueueView.swift - Single responsibility: Show/manage upcoming activities
struct ActivityQueueView: View {
    let activities: [SessionActivity]
    let onSkip: () -> Void
    let onRemove: (SessionActivity) -> Void
    let onReorder: (IndexSet, Int) -> Void

    @State private var editMode = EditMode.inactive

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Upcoming Activities")
                    .font(.headline)
                Spacer()
                EditButton()
                    .environment(\.editMode, $editMode)
            }

            List {
                ForEach(activities) { activity in
                    HStack {
                        Text(activity.activityName)
                        Spacer()
                        if editMode == .inactive {
                            Button(action: { onRemove(activity) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .onMove(perform: onReorder)
            }
            .environment(\.editMode, $editMode)
        }
    }
}

// SessionNotesView.swift - Single responsibility: Notes input/display
struct SessionNotesView: View {
    let notes: String?
    let onAddNote: (String) -> Void

    @State private var noteText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.headline)

            if let existingNotes = notes, !existingNotes.isEmpty {
                Text(existingNotes)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            HStack {
                TextField("Add note...", text: $noteText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)

                Button(action: {
                    onAddNote(noteText)
                    noteText = ""
                    isFocused = false
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(noteText.isEmpty)
            }
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Background tasks for timer | Date-based calculation with scenePhase | iOS 13+ (2019) | Apps can no longer rely on background execution. Must embrace iOS constraints. |
| @State for session persistence | Firestore + @SceneStorage hybrid | SwiftUI 2.0 (2020) | @SceneStorage added for UI state, but Firestore needed for durable session data |
| Timer.scheduledTimer | Timer.publish with Combine | iOS 13+ (2019) | Combine provides better cancellation, memory management, and SwiftUI integration |
| Manual RunLoop.add | Timer.publish in: parameter | iOS 13+ (2019) | Cleaner API, explicitly specify RunLoop mode |

**Deprecated/outdated:**
- **Background fetch for timer updates:** No longer viable - iOS suspends apps regardless
- **UIApplicationDelegate background tasks:** SwiftUI uses scenePhase instead
- **@EnvironmentObject for timer state:** @StateObject provides clearer ownership
- **Notification-based time tracking:** Date calculation is simpler and more reliable

## Open Questions

1. **Resume Session UX Flow**
   - What we know: Need to detect active session on app launch, present resume option
   - What's unclear: Should resume be automatic or require user confirmation? Show preview of session state (current activity, elapsed time)?
   - Recommendation: Show alert with session preview (activity name, elapsed time) and "Resume" / "End Session" buttons. Auto-resume could be surprising if user doesn't remember they had active session.

2. **In-Between Time Auto-Start**
   - What we know: Must track time between activities when user takes breaks
   - What's unclear: Should in-between time start automatically on "Next Activity" tap, or require explicit "Start Break" action?
   - Recommendation: Auto-start in-between time when current activity ends, require explicit "Start Next Activity" button to end break. Provides flexibility for variable break lengths.

3. **Timer Update Frequency**
   - What we know: More frequent updates provide smoother display but increase CPU/battery usage
   - What's unclear: Optimal balance between smoothness (0.1s) and efficiency (1.0s)?
   - Recommendation: 0.1s (10Hz) for active session display (smooth seconds transitions), 1.0s (1Hz) when app is backgrounded or timer paused (saves battery). Use scenePhase to adjust frequency.

4. **Session Activity Ordering Storage**
   - What we know: Need to support reordering activities during session
   - What's unclear: Store order as array index or explicit `order: Int` field in SessionActivity?
   - Recommendation: Explicit `order` field - array index is fragile during concurrent modifications from real-time sync. Order field allows deterministic sorting.

## Validation Architecture

> Validation section included because workflow.nyquist_validation is not explicitly false in config.json

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (iOS 16+) |
| Config file | None - standard Xcode test target |
| Quick run command | `xcodebuild test -scheme "Hone" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Practice_TimerTests/SessionViewModelTests` |
| Full suite command | `xcodebuild test -scheme "Hone" -destination 'platform=iOS Simulator,name=iPhone 15'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETUP-01 | View list of activities to select | Integration | N/A - UI interaction | N/A |
| SETUP-02 | Select multiple activities | Integration | N/A - UI selection state | N/A |
| SETUP-04 | Start session with selected activities | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testStartSession` | ❌ Wave 0 |
| SETUP-05 | Reorder activities before start | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testReorderActivities` | ❌ Wave 0 |
| EXEC-01 | Start timed practice session | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testStartTimer` | ❌ Wave 0 |
| EXEC-02 | Large clear time display | Manual | Visual inspection from 10 feet | Manual only |
| EXEC-03 | Pause practice session | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testPauseTimer` | ❌ Wave 0 |
| EXEC-04 | Resume paused session | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testResumeTimer` | ❌ Wave 0 |
| EXEC-05 | Add notes during practice | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testAddNote` | ❌ Wave 0 |
| EXEC-06 | View notes added | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testNotesDisplay` | ❌ Wave 0 |
| EXEC-07 | Skip to next activity | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testSkipToNext` | ❌ Wave 0 |
| EXEC-08 | Remove upcoming activity | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testRemoveActivity` | ❌ Wave 0 |
| EXEC-09 | Reorder activities during session | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testReorderDuringSession` | ❌ Wave 0 |
| EXEC-10 | Visual progress indicator | Integration | N/A - UI rendering | N/A |
| EXEC-11 | Track in-between time | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testInBetweenTime` | ❌ Wave 0 |
| EXEC-12 | End practice session | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testEndSession` | ❌ Wave 0 |
| EXEC-13 | Timer survives backgrounding | Unit | `xcodebuild test -only-testing:SessionViewModelTests/testBackgroundAccuracy` | ❌ Wave 0 |
| EXEC-14 | Simple obvious controls | Manual | Usability testing with musician | Manual only |
| EXEC-15 | Session state persists on crash | Integration | `xcodebuild test -only-testing:SessionRepositoryTests/testSessionPersistence` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -only-testing:SessionViewModelTests` (< 10 seconds)
- **Per wave merge:** `xcodebuild test -scheme "Hone"` (full suite, ~30 seconds)
- **Phase gate:** Full suite green + manual UI verification (timer display readability, control sizes) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Hone Tests/SessionViewModelTests.swift` — covers EXEC-01, EXEC-03, EXEC-04, EXEC-05, EXEC-07, EXEC-08, EXEC-11, EXEC-12, EXEC-13
- [ ] `Hone Tests/SessionRepositoryTests.swift` — covers EXEC-15 (persistence)
- [ ] `Hone Tests/MockSessionRepository.swift` — test double for SessionViewModel tests
- [ ] Test infrastructure exists (ActivityRepositoryTests pattern), no framework install needed

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation - scenePhase, Timer.publish, background execution limits
- Existing codebase - ActivityRepository pattern (Phase 2), Session model structure (Phase 1), test infrastructure (ActivityRepositoryTests)
- Firebase Firestore Documentation - offline persistence, real-time listeners, subcollections

### Secondary (MEDIUM confidence)
- Hacking with Swift "The ultimate guide to Timer" - RunLoop .common mode usage
- Hacking with Swift Forums "How to make timer continue working in background" - Date-based calculation approach, scenePhase handling
- Swift by Sundell "Avoiding massive SwiftUI views" - Component extraction patterns, @Binding usage
- Apple Developer Forums "iOS Background Execution Limits" - 30-second suspension limit, background modes restrictions
- Medium "Overcoming iOS Background Limits: A Time Tracker App in Swift UI" (Feb 2024) - Date-based timer implementation (403 error on fetch, but WebSearch provided summary)

### Tertiary (LOW confidence)
- DEV Community "SwiftUI Component Architecture Mastery" (2025) - Generic component patterns (overview only from WebSearch)
- WebSearch results on @AppStorage vs @SceneStorage - Requires official docs verification for production use

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All frameworks already integrated or native to iOS 16+
- Architecture: HIGH - Date-based timer is established pattern, component extraction is industry standard, existing codebase provides SessionRepository pattern
- Pitfalls: HIGH - Background suspension is well-documented iOS limitation, massive view files are documented anti-pattern, RunLoop .common mode is verified solution

**Research date:** 2026-03-03
**Valid until:** 2026-04-03 (30 days - stable patterns, iOS 16 feature set unchanging)
