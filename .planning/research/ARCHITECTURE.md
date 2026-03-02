# Architecture Research

**Domain:** iOS Native Apps with SwiftUI + Firebase
**Researched:** 2026-03-01
**Confidence:** HIGH

## Standard Architecture

### System Overview

iOS SwiftUI apps with Firebase typically use MVVM (Model-View-ViewModel) architecture with a repository pattern for data access. The modern approach separates concerns into clear layers with unidirectional data flow.

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │  View   │  │  View   │  │  View   │  │  View   │        │
│  │ (Timer) │  │(Session)│  │ (Auth)  │  │(History)│        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       │            │            │            │              │
│       └────────────┴────────────┴────────────┘              │
│                         │                                   │
│                         ├───> @EnvironmentObject            │
│                         ├───> @StateObject                  │
│                         └───> @ObservedObject               │
├─────────────────────────────────────────────────────────────┤
│                    BUSINESS LOGIC LAYER                      │
├─────────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ ViewModel  │  │ ViewModel  │  │ ViewModel  │            │
│  │ (Timer)    │  │ (Session)  │  │  (Auth)    │            │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘            │
│        │ObservableObject│              │                    │
│        │@Published props│              │                    │
│        └────────────────┴──────────────┘                    │
│                         │                                   │
├─────────────────────────┴───────────────────────────────────┤
│                      DATA ACCESS LAYER                       │
├─────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │  Repository    │  │  Repository    │  │   Service    │  │
│  │  (Activities)  │  │  (Sessions)    │  │   (Auth)     │  │
│  └────────┬───────┘  └────────┬───────┘  └──────┬───────┘  │
│           │                   │                 │           │
├───────────┴───────────────────┴─────────────────┴───────────┤
│                    FIREBASE SERVICES                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────────┐   │
│  │  Firestore   │  │ Firebase    │  │  Firebase Auth   │   │
│  │  (Database)  │  │  Storage    │  │                  │   │
│  └──────────────┘  └─────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **View** | Display data, handle user interaction | SwiftUI Views with @State, @Binding, @ObservedObject |
| **ViewModel** | Provide data to views, handle UI logic, coordinate repositories | ObservableObject classes with @Published properties |
| **Repository** | Abstract data access, handle CRUD operations | Protocol-based classes managing Firestore queries/writes |
| **Service** | Handle cross-cutting concerns (auth, analytics) | Singleton or injected services for Firebase SDK operations |
| **Model** | Data structures | Codable structs conforming to Identifiable |
| **AppState** | Global application state (optional) | @EnvironmentObject for shared state like user session |

## Recommended Project Structure

```
PracticeTimer/
├── App/
│   ├── PracticeTimerApp.swift       # App entry point, Firebase init
│   └── AppDelegate.swift             # Firebase configuration
├── Core/
│   ├── Models/                       # Domain models
│   │   ├── User.swift
│   │   ├── Activity.swift
│   │   ├── Session.swift
│   │   └── SessionActivity.swift
│   ├── Services/                     # Cross-cutting services
│   │   ├── AuthService.swift        # Firebase Auth wrapper
│   │   └── FirebaseManager.swift    # Firebase singleton
│   ├── Repositories/                 # Data access layer
│   │   ├── ActivityRepository.swift
│   │   ├── SessionRepository.swift
│   │   └── UserRepository.swift
│   └── Utilities/                    # Helpers and extensions
│       ├── Extensions/
│       │   ├── Date+Extensions.swift
│       │   └── TimeInterval+Extensions.swift
│       └── Constants.swift
├── Features/                         # Feature-based organization
│   ├── Authentication/
│   │   ├── Views/
│   │   │   ├── LoginView.swift
│   │   │   ├── SignUpView.swift
│   │   │   └── SignInWithAppleButton.swift
│   │   └── ViewModels/
│   │       └── AuthViewModel.swift
│   ├── Activities/
│   │   ├── Views/
│   │   │   ├── ActivityListView.swift
│   │   │   ├── ActivityDetailView.swift
│   │   │   └── ActivityFormView.swift
│   │   └── ViewModels/
│   │       └── ActivityViewModel.swift
│   ├── Timer/
│   │   ├── Views/
│   │   │   ├── TimerView.swift
│   │   │   ├── SessionSetupView.swift
│   │   │   └── SessionSummaryView.swift
│   │   └── ViewModels/
│   │       ├── TimerViewModel.swift
│   │       └── SessionSetupViewModel.swift
│   └── History/
│       ├── Views/
│       │   ├── HistoryListView.swift
│       │   └── SessionDetailView.swift
│       └── ViewModels/
│           └── HistoryViewModel.swift
├── Resources/
│   ├── Assets.xcassets/
│   ├── GoogleService-Info.plist     # Firebase config
│   └── Info.plist
└── Supporting Files/
    └── PracticeTimer.entitlements   # For Sign in with Apple
```

### Structure Rationale

- **Feature-based organization**: Groups related views and view models together, making features easier to find and modify
- **Core layer separation**: Shared models, services, and repositories prevent duplication and establish clear contracts
- **Flat view/viewmodel structure**: For smaller features, keeping views and viewmodels in the same folder improves discoverability
- **Protocol-based repositories**: Enables dependency injection and makes testing easier

## Architectural Patterns

### Pattern 1: MVVM with ObservableObject

**What:** Views observe ViewModels that publish state changes. ViewModels coordinate with repositories for data operations.

**When to use:** Standard pattern for all SwiftUI + Firebase apps. Works well for apps of any size.

**Trade-offs:**
- **Pros**: Natural fit for SwiftUI's reactive model, clear separation of concerns, easy to test ViewModels
- **Cons**: Can lead to "fat" ViewModels if business logic isn't extracted into separate services/interactors

**Example:**
```swift
// ViewModel
class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: ActivityRepository
    private var listener: ListenerRegistration?

    init(repository: ActivityRepository = ActivityRepository()) {
        self.repository = repository
    }

    func fetchActivities(for userId: String) {
        isLoading = true
        listener = repository.observeActivities(for: userId) { [weak self] result in
            self?.isLoading = false
            switch result {
            case .success(let activities):
                self?.activities = activities
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    deinit {
        listener?.remove()
    }
}

// View
struct ActivityListView: View {
    @StateObject private var viewModel = ActivityViewModel()
    @EnvironmentObject var authService: AuthService

    var body: some View {
        List(viewModel.activities) { activity in
            ActivityRow(activity: activity)
        }
        .onAppear {
            viewModel.fetchActivities(for: authService.currentUserId)
        }
    }
}
```

### Pattern 2: Repository Pattern for Data Access

**What:** Abstract data access behind protocol-based repositories. ViewModels interact with repositories, not Firebase directly.

**When to use:** Always. Separates Firebase implementation details from business logic.

**Trade-offs:**
- **Pros**: Easy to swap data sources (Firestore → local DB), testable via mocks, clear data access contracts
- **Cons**: Adds abstraction layer, slightly more code upfront

**Example:**
```swift
// Protocol
protocol ActivityRepositoryProtocol {
    func observeActivities(for userId: String, completion: @escaping (Result<[Activity], Error>) -> Void) -> ListenerRegistration
    func create(_ activity: Activity) async throws -> String
    func update(_ activity: Activity) async throws
    func delete(id: String) async throws
}

// Implementation
class ActivityRepository: ActivityRepositoryProtocol {
    private let db = Firestore.firestore()

    func observeActivities(for userId: String, completion: @escaping (Result<[Activity], Error>) -> Void) -> ListenerRegistration {
        return db.collection("activities")
            .whereField("userId", isEqualTo: userId)
            .whereField("archived", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let activities = documents.compactMap { try? $0.data(as: Activity.self) }
                completion(.success(activities))
            }
    }

    func create(_ activity: Activity) async throws -> String {
        let docRef = try db.collection("activities").addDocument(from: activity)
        return docRef.documentID
    }
}
```

### Pattern 3: Dependency Injection via @EnvironmentObject

**What:** Share services/state across view hierarchy using SwiftUI's Environment system.

**When to use:** For app-wide state (auth, settings) or services used by multiple features.

**Trade-offs:**
- **Pros**: No need to pass dependencies through every view layer, SwiftUI-native approach
- **Cons**: Runtime crash if not provided (use @Environment with custom keys for default values), harder to track what views depend on

**Example:**
```swift
// Service
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false

    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthListener()
    }

    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user?.uid != nil ? User(id: user!.uid) : nil
            self?.isAuthenticated = user != nil
        }
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
}

// App entry point
@main
struct PracticeTimerApp: App {
    @StateObject private var authService = AuthService()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}

// Deep view can access it
struct SomeDeepView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Text("User: \(authService.currentUser?.id ?? "None")")
    }
}
```

### Pattern 4: Timer Background State Management

**What:** iOS suspends timers after ~30 seconds in background. Use timestamps + foreground/background lifecycle events instead of continuous Timer execution.

**When to use:** Any timer-based feature that needs to survive backgrounding.

**Trade-offs:**
- **Pros**: Works reliably across background/foreground transitions, battery efficient
- **Cons**: More complex than simple Timer, requires careful state management

**Example:**
```swift
class TimerViewModel: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning = false

    private var startTime: Date?
    private var pausedElapsedTime: TimeInterval = 0
    private var timer: Timer?

    // Use ScenePhase to detect background/foreground
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            invalidateTimer()
        case .active:
            if isRunning {
                restartTimer()
            }
        default:
            break
        }
    }

    func start() {
        startTime = Date()
        isRunning = true
        restartTimer()
    }

    func pause() {
        pausedElapsedTime = currentElapsedTime()
        isRunning = false
        invalidateTimer()
    }

    private func currentElapsedTime() -> TimeInterval {
        guard let startTime = startTime else { return pausedElapsedTime }
        return pausedElapsedTime + Date().timeIntervalSince(startTime)
    }

    private func restartTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.elapsedTime = self?.currentElapsedTime() ?? 0
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// In View
struct TimerView: View {
    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Text(timeString(from: viewModel.elapsedTime))
            .onChange(of: scenePhase) { newPhase in
                viewModel.handleScenePhase(newPhase)
            }
    }
}
```

### Pattern 5: Firestore Real-Time Listeners with ObservableObject

**What:** Use snapshot listeners to automatically update UI when Firestore data changes.

**When to use:** For any data that needs real-time sync (activities, sessions, user profile).

**Trade-offs:**
- **Pros**: Automatic UI updates, works offline, syncs seamlessly when online
- **Cons**: Must remember to remove listeners (memory leaks), counts against read quota

**Example:**
```swift
class SessionViewModel: ObservableObject {
    @Published var sessions: [Session] = []

    private let repository: SessionRepository
    private var listener: ListenerRegistration?

    init(repository: SessionRepository = SessionRepository()) {
        self.repository = repository
    }

    func startListening(for userId: String) {
        // Repository returns listener registration
        listener = repository.observeSessions(for: userId) { [weak self] result in
            if case .success(let sessions) = result {
                self?.sessions = sessions
            }
        }
    }

    deinit {
        // CRITICAL: Remove listener to prevent memory leaks
        listener?.remove()
    }
}
```

## Data Flow

### Request Flow (Write Operation)

```
User Action (tap "Save Activity")
    ↓
View calls ViewModel method
    ↓
ViewModel validates input
    ↓
ViewModel calls Repository
    ↓
Repository encodes model to Firestore document
    ↓
Firestore writes to local cache (offline-first)
    ↓
Firestore syncs to server when online
    ↓
Server write triggers snapshot listener
    ↓
Listener updates ViewModel @Published property
    ↓
SwiftUI automatically re-renders View
```

### State Management (Read Operation)

```
View appears
    ↓
View calls ViewModel.fetch() in .onAppear
    ↓
ViewModel calls Repository.observe()
    ↓
Repository registers Firestore snapshot listener
    ↓
Firestore reads from cache (instant if offline-enabled)
    ↓
Firestore also fetches from server (when online)
    ↓
Snapshot listener receives documents
    ↓
Repository decodes documents to models
    ↓
Repository calls completion handler
    ↓
ViewModel updates @Published property
    ↓
SwiftUI re-renders subscribed Views
```

### Authentication Flow

```
User enters credentials
    ↓
View calls AuthService.signIn()
    ↓
AuthService calls Firebase Auth SDK
    ↓
Firebase Auth validates credentials
    ↓
Auth state change triggers listener
    ↓
AuthService updates @Published isAuthenticated
    ↓
App-level View observes change
    ↓
SwiftUI shows authenticated content
```

### Offline Sync Flow

```
User makes change while offline
    ↓
Repository writes to Firestore (queued locally)
    ↓
Snapshot listener immediately reflects local change
    ↓
UI updates (appears instant)
    ↓
...later, when connection restored...
    ↓
Firestore auto-syncs queued writes to server
    ↓
Server processes writes (applies conflict resolution)
    ↓
Server sends updated documents back
    ↓
Snapshot listener receives updates
    ↓
UI reconciles if needed (usually no visible change due to optimistic updates)
```

### Key Data Flows

1. **User authentication state**: Auth.auth().addStateDidChangeListener → AuthService @Published properties → @EnvironmentObject across app → views react to auth state
2. **Real-time activity updates**: Firestore snapshot listener → Repository → ViewModel @Published → View auto-updates
3. **Timer state across lifecycle**: ScenePhase changes → ViewModel handles background/foreground → recalculates elapsed time from Date timestamps → @Published property updates → View shows current time

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-1k users | Standard MVVM + Repository pattern is sufficient. Single Firebase project. All features in monolithic app. Use @EnvironmentObject for shared state. |
| 1k-100k users | Optimize Firestore queries (add indexes, limit listener scope). Consider lazy loading for large lists. Move heavy processing off main thread. Add caching layer in repositories if needed. Monitor Firebase quota usage. |
| 100k+ users | Implement pagination for large collections. Consider feature-based Swift Package modules for better compile times. Use Firebase Performance Monitoring. May need backend Cloud Functions for complex business logic. Consider data sharding strategies for hot collections. |

### Scaling Priorities

1. **First bottleneck: Firestore read quota** - Snapshot listeners can consume reads quickly. Mitigation: Use `getDocuments()` for infrequent data, scope listeners narrowly, implement local caching, paginate large lists.

2. **Second bottleneck: App size and compile times** - As features grow, Xcode compile times suffer. Mitigation: Extract features into Swift Package modules, use dependency injection to break circular dependencies, lazy-load feature modules.

3. **Third bottleneck: Offline data conflicts** - As users create more data offline, conflicts increase. Mitigation: Implement custom conflict resolution using server timestamps and version fields, educate users about sync status, provide manual conflict resolution UI for critical data.

## Anti-Patterns

### Anti-Pattern 1: Massive ViewModels

**What people do:** Put all business logic, validation, formatting, and data access directly in ViewModels. ViewModels become 500+ line "god objects."

**Why it's wrong:** Hard to test, hard to reuse logic, difficult to maintain, violates single responsibility principle.

**Do this instead:**
- Extract business logic into separate service classes or interactors
- Move formatting logic into model extensions or utility functions
- Keep ViewModels focused on coordinating between views and repositories
- Use composition: ViewModels can depend on multiple focused services

**Example:**
```swift
// BAD: Everything in ViewModel
class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []

    func formatDuration(_ seconds: TimeInterval) -> String {
        // Complex formatting logic here
    }

    func validateActivity(_ activity: Activity) -> Bool {
        // Validation logic here
    }

    func calculateStatistics() -> Stats {
        // Complex calculation logic here
    }

    // ...plus Firestore access, error handling, etc.
}

// GOOD: Separated concerns
class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []

    private let repository: ActivityRepository
    private let validator: ActivityValidator
    private let statsCalculator: StatisticsService

    init(repository: ActivityRepository,
         validator: ActivityValidator,
         statsCalculator: StatisticsService) {
        self.repository = repository
        self.validator = validator
        self.statsCalculator = statsCalculator
    }
}

extension TimeInterval {
    func formatted() -> String {
        // Formatting logic on the type it formats
    }
}
```

### Anti-Pattern 2: Direct Firebase SDK Calls in Views

**What people do:** Call `Firestore.firestore().collection("activities").addDocument()` directly in SwiftUI views.

**Why it's wrong:** Tight coupling to Firebase, impossible to test, can't switch data sources, duplicates data access logic across views.

**Do this instead:** Always use Repository pattern. Views → ViewModels → Repositories → Firebase.

**Example:**
```swift
// BAD: Firebase in View
struct ActivityListView: View {
    @State private var activities: [Activity] = []

    var body: some View {
        List(activities) { activity in
            Text(activity.name)
        }
        .onAppear {
            Firestore.firestore()
                .collection("activities")
                .getDocuments { snapshot, error in
                    // Handle result
                }
        }
    }
}

// GOOD: Repository abstraction
struct ActivityListView: View {
    @StateObject private var viewModel = ActivityViewModel()

    var body: some View {
        List(viewModel.activities) { activity in
            Text(activity.name)
        }
        .onAppear {
            viewModel.fetchActivities()
        }
    }
}
```

### Anti-Pattern 3: Forgetting to Remove Firestore Listeners

**What people do:** Register snapshot listeners but never call `.remove()`, especially in ViewModels that get recreated.

**Why it's wrong:** Memory leaks, unexpected behavior, unnecessary Firestore reads consuming quota, app performance degrades over time.

**Do this instead:** Always store `ListenerRegistration` and remove in `deinit`. Consider creating a helper to manage listener lifecycle.

**Example:**
```swift
// BAD: Listener never removed
class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []

    func fetchActivities() {
        Firestore.firestore()
            .collection("activities")
            .addSnapshotListener { snapshot, error in
                // Updates activities
            }
        // Listener lives forever!
    }
}

// GOOD: Proper cleanup
class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    private var listener: ListenerRegistration?

    func startListening() {
        listener = Firestore.firestore()
            .collection("activities")
            .addSnapshotListener { [weak self] snapshot, error in
                // Updates activities
            }
    }

    deinit {
        listener?.remove()
    }
}
```

### Anti-Pattern 4: Using Timer for Long-Running Timers

**What people do:** Use `Timer.scheduledTimer` for practice session timing, expecting it to work in background.

**Why it's wrong:** iOS suspends timers after ~30 seconds in background. Timer stops, elapsed time is wrong, user sees incorrect values.

**Do this instead:** Store start timestamp as `Date`, calculate elapsed time on-demand by comparing to current time. Timer only for UI updates.

**Example:**
```swift
// BAD: Relies on Timer ticking
class TimerViewModel: ObservableObject {
    @Published var seconds = 0
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.seconds += 1 // Stops working in background!
        }
    }
}

// GOOD: Timestamp-based
class TimerViewModel: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0

    private var startDate: Date?
    private var pausedElapsed: TimeInterval = 0
    private var displayTimer: Timer?

    func start() {
        startDate = Date()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
    }

    private func updateDisplay() {
        guard let startDate = startDate else { return }
        elapsedTime = pausedElapsed + Date().timeIntervalSince(startDate)
    }

    // Works correctly even after backgrounding
}
```

### Anti-Pattern 5: Not Enabling Offline Persistence

**What people do:** Forget to enable Firestore offline persistence, or assume it's automatic.

**Why it's wrong:** App requires internet connection, poor UX in low connectivity, no offline support.

**Do this instead:** Enable persistence at app startup. Design assuming offline-first.

**Example:**
```swift
// Configure in AppDelegate or App init
@main
struct PracticeTimerApp: App {
    init() {
        FirebaseApp.configure()

        // Enable offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Firebase Authentication | Wrap in AuthService as @EnvironmentObject | Listen to auth state changes with `addStateDidChangeListener`. Provide user session globally. |
| Firestore | Access via Repository pattern | Enable offline persistence. Use snapshot listeners for real-time sync. Remove listeners in deinit. |
| Firebase Storage | Wrap in StorageService (if needed) | For profile images or file uploads. Not needed for Practice Timer v1. |
| Sign in with Apple | Native AuthenticationServices framework + Firebase | Required by App Store if offering Google OAuth. Link to Firebase with OAuthProvider. |
| Google Sign-In | GoogleSignIn SDK + Firebase | Follow Firebase documentation for iOS setup. Configure OAuth client ID. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| View ↔ ViewModel | @StateObject, @ObservedObject | View creates or receives ViewModel. ViewModel publishes state changes. View is stateless except for local UI state. |
| ViewModel ↔ Repository | Protocol-based dependency injection | ViewModel calls async repository methods or registers listeners. Repository returns data via completion handlers or listener callbacks. |
| Repository ↔ Firebase | Direct SDK calls, wrapped in error handling | Repository encapsulates all Firebase-specific code. Uses Codable for serialization. Handles online/offline transparently. |
| App ↔ Services (Auth, etc.) | @EnvironmentObject | App creates singleton services, injects via `.environmentObject()`. Deep views access via `@EnvironmentObject`. |
| ViewModels ↔ ViewModels | Avoid direct communication | Use shared @EnvironmentObject state (e.g., AuthService) or Combine publishers if needed. Prefer parent view coordinating child ViewModels. |

## Build Order Recommendations

Based on architecture dependencies, recommended build order for Practice Timer:

### Phase 1: Foundation Layer
1. **Firebase setup** - Configure Firebase, enable offline persistence
2. **Core models** - Define Activity, Session, User structs
3. **AuthService + Repository** - Authentication state management
4. **Authentication UI** - Login, sign up, Sign in with Apple, Google OAuth

**Rationale:** Auth is a hard dependency for all features. Must be done first. Models define data contracts used everywhere.

### Phase 2: Data Access Layer
1. **ActivityRepository** - CRUD operations for activities
2. **SessionRepository** - CRUD operations for sessions
3. **Test repositories with offline/online scenarios**

**Rationale:** Repositories abstract Firebase complexity. Building them early validates data model design and offline sync behavior.

### Phase 3: Core Features
1. **Activity management** - Create, edit, delete, archive activities
2. **Session setup** - Select activities, plan session
3. **Timer functionality** - Start, pause, resume, background handling

**Rationale:** Activity management is prerequisite for session setup. Timer is complex and needs thorough testing.

### Phase 4: Session Execution
1. **Active session UI** - Large timer display, activity navigation
2. **Session notes** - Add notes per activity
3. **Session completion** - Save session to Firestore

**Rationale:** Builds on timer foundation. Most complex feature interaction-wise.

### Phase 5: History & Polish
1. **Session history** - View past sessions
2. **Activity statistics** - Time totals, trends
3. **Offline sync indicators** - Show sync status in UI
4. **Error handling** - User-friendly error messages

**Rationale:** History requires completed sessions. Polish improves UX but isn't blocking.

### Dependencies Between Components

```
AuthService
    ↓ (required by all repositories)
Models
    ↓ (required by all features)
Repositories
    ↓ (required by ViewModels)
ViewModels
    ↓ (required by Views)
Views
```

**Critical path:** AuthService → Models → Repositories → ViewModels → Views

**Parallel tracks possible:**
- ActivityRepository + SessionRepository (independent)
- Activity management UI + History UI (independent, both use ActivityRepository)

## Sources

**HIGH CONFIDENCE:**
- Firebase iOS Documentation (https://firebase.google.com/docs/ios/setup) - Official setup guide, updated Feb 2026
- Firebase Firestore Offline Documentation (https://firebase.google.com/docs/firestore/manage-data/enable-offline) - Official offline persistence guide
- Peter Friese - Firebase Developer Advocate (https://peterfriese.dev/posts/swiftui-firebase-fetch-data, https://peterfriese.dev/posts/replicating-reminder-swiftui-firebase-part2) - Authoritative SwiftUI + Firebase architecture tutorials
- Alexey Naumov - Clean Architecture for SwiftUI (https://nalexn.github.io/clean-architecture-swiftui/) - Comprehensive architecture guide with unidirectional data flow

**MEDIUM CONFIDENCE:**
- DEV Community - "How to Structure a SwiftUI Project in 2026" (https://dev.to/__be2942592/how-to-structure-a-swiftui-project-in-2026-41m8) - Community best practices, recent
- Medium - Modern MVVM + Repository Pattern (https://medium.com/@gauravios/modern-mvvm-repository-pattern-in-swiftui-eca4f78fc2f5) - Oct 2025, practical examples
- Medium - iOS Background Timer (https://medium.com/deuk/overcoming-ios-background-limits-a-time-tracker-app-in-swift-ui-5d157a58df68) - Timer app case study, directly relevant
- 7Span - "Modern iOS App Architecture in 2026" (https://7span.com/blog/mvvm-vs-clean-architecture-vs-tca) - Architecture comparison, 2026 perspective

**LOW CONFIDENCE (Training Data):**
- @Observable macro availability (iOS 17+) - mentioned in search results but not verified with official docs for this use case
- Specific Firestore conflict resolution details beyond last-write-wins - referenced but not comprehensively documented

---
*Architecture research for: iOS Native Apps with SwiftUI + Firebase*
*Researched: 2026-03-01*
