# Technology Stack

**Project:** Practice Timer iOS
**Researched:** 2026-03-01
**Confidence:** HIGH

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI | iOS 16+ | Declarative UI framework | Native iOS UI, excellent for timer interfaces, automatic state binding, full-featured as of 2025 |
| Swift | 6.x | Primary language | Latest concurrency features, improved safety, required for Xcode 16+ |
| Xcode | 16.2+ | IDE and build system | Required for App Store submissions as of April 2025, includes iOS 18 SDK |

### Backend & Sync
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Firebase iOS SDK | 12.10.0+ | Backend services | Matches existing web app, proven real-time sync, comprehensive auth/database/storage |
| FirebaseAuth | 12.10.0+ | User authentication | Email/password, Google OAuth, Sign in with Apple support |
| FirebaseFirestore | 12.10.0+ | Cloud database | Real-time sync, offline persistence enabled by default on iOS, matches web app data model |
| FirebaseStorage | 12.10.0+ | File storage (if needed) | Future-proof for audio/video features |

### Local Persistence
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Firestore Offline | Built-in | Offline-first data | Enabled by default, automatic sync queue, matches web app behavior |
| UserDefaults | iOS 16+ | App preferences | Simple key-value storage for settings |

**Do NOT use SwiftData or Core Data** - Firestore's built-in offline persistence already provides local caching and sync. Adding another persistence layer creates unnecessary complexity and sync conflicts.

### Dependency Management
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift Package Manager | Built-in | Dependency management | Apple's official solution, best Xcode integration, Firebase's recommended approach as of 2025 |

### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| SwiftLint | Code linting | Enforce Swift style guide, catch logic errors (force unwraps, etc.) |
| SwiftFormat | Code formatting | Auto-format on save, consistent style across team |
| Mint | Tool version management | Lock SwiftLint/SwiftFormat versions for CI consistency |

### Testing
| Framework | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| XCTest | Built-in | Unit & UI testing | Primary testing framework, mature and stable |
| Swift Testing | iOS 16+ | Modern Swift testing | Gradually adopt for new tests, parallel execution by default, Swift-native syntax |

**Testing Strategy:** Start with XCTest (proven, comprehensive), gradually migrate to Swift Testing for new test cases. Focus testing on ViewModels and business logic, not SwiftUI layout.

## Installation

### Firebase Setup via Swift Package Manager

**In Xcode:**
1. File > Add Package Dependencies
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: 12.10.0 or later
4. Add these products:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage (optional, for future features)

**App Initialization:**
```swift
import SwiftUI
import FirebaseCore

@main
struct PracticeTimerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Enable offline persistence (default, but explicit is clear)
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings

        return true
    }
}
```

### Development Tools Setup

```bash
# Install Mint (tool version manager)
brew install mint

# Install SwiftLint & SwiftFormat via Mint (version-locked)
mint install realm/SwiftLint@0.55.1
mint install nicklockwood/SwiftFormat@0.54.3

# Run linting
mint run SwiftLint lint

# Auto-format code
mint run SwiftFormat .
```

### SwiftLint Configuration

Create `.swiftlint.yml` in project root:
```yaml
disabled_rules:
  - trailing_whitespace
opt_in_rules:
  - force_unwrapping
  - implicitly_unwrapped_optional
excluded:
  - Pods
  - .build
```

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| UI Framework | SwiftUI | UIKit | SwiftUI is mature in iOS 16+, declarative approach better for reactive timer UI, matches modern development |
| Backend | Firebase | Custom REST API | Firebase already operational for web app, real-time sync built-in, offline support proven |
| Local Persistence | Firestore Offline | SwiftData/Core Data | Firestore's offline mode already caches data locally, dual persistence creates sync conflicts |
| Dependency Mgmt | SPM | CocoaPods | SPM is Apple's official tool, better Xcode integration, Firebase recommends SPM as of 2025 |
| Language | Swift 6 | Objective-C | Modern concurrency features essential for Firebase async operations, full SwiftUI support |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| SwiftData for sync | Creates dual persistence layer, sync conflicts with Firestore | Firestore's built-in offline persistence |
| Core Data for sync | Same issue, adds complexity without benefit | Firestore offline mode |
| NavigationView | Deprecated in iOS 16+ | NavigationStack (type-safe, modern) |
| React Native/Flutter | Loses iOS-native benefits, larger app size, worse performance | Native SwiftUI |
| iOS 15 support | Firebase SDK requires iOS 15+ anyway, iOS 16 fixes critical SwiftUI bugs | iOS 16+ minimum |
| @ObservableObject | Legacy observation pattern | @Observable macro (iOS 17+) or keep at iOS 16 minimum |

## Stack Patterns by Variant

### If targeting iOS 16 minimum:
- Use NavigationStack (not NavigationView)
- Use @StateObject/@ObservedObject for observation
- Stick with XCTest for testing
- All Firebase features available
- **Confidence: HIGH** - Widest device support (93.8% coverage), mature SwiftUI

### If targeting iOS 17 minimum:
- Use @Observable macro instead of ObservableObject
- Adopt Swift Testing for new tests
- SwiftData becomes option (but still not needed with Firestore)
- Better sheet/navigation bug fixes
- **Confidence: MEDIUM** - Fewer devices (89.6%), but cleaner modern API

**Recommendation: iOS 16 minimum** - Best balance of features and reach. iOS 17's @Observable is nice but not essential when ViewModels work well in iOS 16.

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Firebase iOS SDK 12.10.0 | iOS 15+ | Xcode 16.2+ required for latest versions |
| SwiftUI | iOS 16+ | NavigationStack, improved reliability |
| Swift 6.x | iOS 15+ | Xcode 16+ required, strict concurrency available |
| FirebaseAuth | FirebaseCore 12.x | Sign in with Apple requires iOS 13+ |

## Architecture Notes

### Recommended Pattern: MVVM with Observable State

```swift
// ViewModel approach (works iOS 16+)
class SessionViewModel: ObservableObject {
    @Published var currentActivity: Activity?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning = false

    private let firestore = Firestore.firestore()

    func startSession() async throws {
        // Firebase operations use async/await
        try await firestore.collection("sessions").addDocument(data: [...])
    }
}

// View (minimal, delegates to ViewModel)
struct SessionView: View {
    @StateObject private var viewModel = SessionViewModel()

    var body: some View {
        // UI only, no business logic
    }
}
```

### Concurrency Strategy

- **Firebase operations:** Use async/await (supported since SDK 10.0+)
- **UI updates:** Mark with @MainActor to guarantee main thread
- **Timer:** Use AsyncStream or Timer.publish() with Combine
- **Background work:** Use Task with proper cancellation handling

## Firebase-Specific Configuration

### Firestore Security Rules
Match existing web app rules. Test with Firebase Emulator Suite during development.

### Offline Behavior
```swift
// Offline persistence enabled by default, but configure cache size if needed
let settings = FirestoreSettings()
settings.cacheSizeBytes = FirestoreCacheSizeUnlimited // or specific byte limit
Firestore.firestore().settings = settings
```

### Sign in with Apple (Required for App Store)
When offering Google OAuth, Sign in with Apple is mandatory per App Store guidelines.

```swift
// Configure in Firebase Console Auth > Sign-in method > Apple
// Add capability in Xcode: Signing & Capabilities > + > Sign in with Apple
```

## App Store Requirements Checklist

- [ ] Privacy Policy URL in App Store Connect
- [ ] Privacy Nutrition Labels configured (data collection disclosure)
- [ ] Account deletion flow (if user accounts exist)
- [ ] Privacy manifest file (for API usage disclosure)
- [ ] Sign in with Apple enabled (when offering third-party OAuth)
- [ ] App Tracking Transparency prompt (if using analytics/ads)
- [ ] Built with Xcode 16+ and iOS 18 SDK (required April 2025+)

## CI/CD Considerations

### GitHub Actions Example
```yaml
- name: Lint
  run: mint run SwiftLint lint --strict

- name: Format Check
  run: mint run SwiftFormat --lint .

- name: Test
  run: xcodebuild test -scheme PracticeTimer -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Sources

- **Firebase iOS SDK** — Official GitHub repository, version 12.10.0 release notes (February 25, 2026)
  - https://github.com/firebase/firebase-ios-sdk/releases
  - https://firebase.google.com/support/release-notes/ios
  - https://firebase.google.com/docs/ios/setup

- **Apple Developer Documentation** — Official iOS development guidelines
  - https://developer.apple.com/documentation/swiftui/navigationstack
  - https://developer.apple.com/sf-symbols/
  - https://developer.apple.com/support/xcode/

- **SwiftUI Best Practices** — Multiple 2025 sources on SwiftUI architecture and testing
  - Medium articles on MVVM in SwiftUI (2025)
  - "The Ultimate Guide to Modern iOS Architecture in 2025"
  - SwiftUI testing guides with XCTest and Swift Testing

- **Firebase Integration** — SwiftUI + Firebase patterns
  - "Syncing SwiftData with Firebase in Swift 6" (2025)
  - Firebase Auth documentation for Apple platforms
  - Firestore offline persistence documentation

- **App Store Requirements** — Apple's official guidelines
  - App Store Review Guidelines
  - Privacy requirements for 2025
  - SDK requirements (April 2025 mandate for iOS 18 SDK)

**Confidence Assessment:**
- **Core Stack (SwiftUI, Firebase, SPM):** HIGH - Official documentation, current versions verified
- **Development Tools (SwiftLint, etc.):** HIGH - Community standard, well-documented
- **Architecture Patterns (MVVM, async/await):** HIGH - Industry consensus for SwiftUI + Firebase
- **Version Requirements:** HIGH - Verified from Apple's official developer announcements

---
*Stack research for: Native iOS app with SwiftUI and Firebase*
*Researched: 2026-03-01*
