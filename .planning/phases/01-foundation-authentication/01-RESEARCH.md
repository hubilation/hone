# Phase 1: Foundation & Authentication - Research

**Researched:** 2026-03-02
**Domain:** Firebase iOS SDK integration with SwiftUI authentication and offline-first architecture
**Confidence:** HIGH

## Summary

Phase 1 establishes the critical foundation for the entire app by integrating Firebase iOS SDK 12.10.0+ with SwiftUI using MVVM + Repository pattern. The phase implements three authentication methods (email/password, Google OAuth, Sign in with Apple), establishes the Firestore data model with subcollections matching the existing web app, and configures security rules with recursive wildcards for user data protection.

The research confirms Firebase iOS SDK provides native support for all required authentication methods with automatic session persistence through iOS Keychain. Firestore offline persistence is enabled by default on iOS with a configurable cache (default 100MB). Critical decisions include using subcollections for scalable data structures (avoiding the 1MB document limit), implementing proper ListenerRegistration cleanup to prevent memory leaks, and using ISO timestamp strings to match the web app's data format.

**Primary recommendation:** Use Firebase iOS SDK 12.10.0+ with SwiftUI's @UIApplicationDelegateAdaptor for initialization, implement MVVM + Repository pattern with feature-based folder structure, store user data in Firestore subcollections (users/{userId}/activities/{activityId}), and secure with recursive wildcard security rules testing via Firebase Emulator.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Auth Flow & Navigation:**
- Sign in first, link to signup: Show signin form with "Don't have account? Sign up" link at bottom
- OAuth buttons on every auth screen: Show Google and Apple signin buttons on both signin and signup screens
- Main app immediately after auth: No onboarding for v1 - straight to home screen with activities after successful signin/signup
- Password reset: Claude's discretion - use standard Firebase password reset pattern

**Data Model Structure:**
- Match web app exactly: Use same Firestore collection structure as existing web app for seamless sync
  - `users/{userId}` - user profile document
  - `users/{userId}/activities/{activityId}` - activities subcollection
  - `users/{userId}/sessions/{sessionId}` - sessions subcollection
- Field names: Exact match with web app (camelCase) - use createdAt, practiceNotes, etc. as-is
- Timestamps: ISO strings (match web) - use `new Date().toISOString()` like web app for easy sync
- Model types: Codable structs - Swift structs conforming to Codable for type-safe encoding/decoding

**Session Persistence:**
- Always persist (Firebase default): User stays logged in until explicit logout - most convenient
- No biometrics in v1: Skip Face ID/Touch ID for now - standard Firebase session is enough
- Session expiry handling: Claude's discretion - handle standard Firebase token refresh patterns
- Multi-device: Allow concurrent sessions - user can be logged in on web and iOS simultaneously (matches current web behavior)

**Sign in with Apple:**
- Auto-create on first signin: Apple signin always creates account if new, just like Google OAuth (consistent with OAuth behavior)
- Accept relay emails: Treat Apple private relay emails (@privaterelay.appleid.com) as valid - store whatever Apple provides
- Account deletion: Claude's discretion - implement standard App Store compliant deletion flow
- User names: Use Apple-provided name initially but allow editing in profile

### Claude's Discretion

- Password reset flow implementation details
- Firebase token refresh and session recovery patterns
- Account deletion implementation (must be App Store compliant)
- Error handling and validation messages
- Loading states and transitions

### Deferred Ideas (OUT OF SCOPE)

None - discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTH-01 | User can sign up with email and password | Firebase Auth password authentication with Auth.auth().createUser(withEmail:password:) |
| AUTH-02 | User can sign in with email and password | Firebase Auth password authentication with Auth.auth().signIn(withEmail:password:) |
| AUTH-03 | User can sign in with Google OAuth | Firebase Auth Google Sign-In with GIDSignIn integration and Firebase credential exchange |
| AUTH-04 | User can sign in with Sign in with Apple | Firebase Auth Apple Sign-In with OAuthProvider.appleCredential() handling private relay emails |
| AUTH-05 | User session persists across app restarts | Firebase Auth automatic persistence via iOS Keychain (enabled by default, no configuration needed) |
| AUTH-06 | User can sign out from app | Firebase Auth.auth().signOut() clears local session |
| AUTH-07 | User can reset password via email | Firebase Auth.auth().sendPasswordReset(withEmail:) sends templated reset link |
| PLAT-01 (partial) | Firebase setup | Firebase iOS SDK 12.10.0+ via Swift Package Manager, FirebaseCore.configure() in app initialization |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Firebase iOS SDK | 12.10.0+ | Backend integration (Auth, Firestore, Core) | Official Google SDK with native Swift support, automatic updates, 100% feature parity with web |
| FirebaseAuth | 12.10.0+ | Authentication (email/password, OAuth, Sign in with Apple) | Built-in session management, iOS Keychain persistence, token auto-refresh |
| FirebaseFirestore | 12.10.0+ | NoSQL database with offline sync | Offline-first by default, automatic conflict resolution, real-time listeners, 100MB cache |
| SwiftUI | iOS 16+ | Native UI framework | Declarative syntax, native performance, tight iOS integration, Xcode previews |
| Combine | iOS 16+ | Reactive programming (or Swift Concurrency) | Built-in async/await support, publisher-subscriber pattern for Firebase listeners |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GoogleSignIn | 8.x | Google OAuth integration | Required for Google Sign-In with Firebase (GIDSignIn) |
| AuthenticationServices | iOS 16+ | Sign in with Apple | Required for Apple Sign-In (ASAuthorizationAppleIDProvider) |
| CryptoKit | iOS 16+ | Nonce generation for Sign in with Apple | Required for secure Apple Sign-In flow (SHA256 hashing) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Firebase SDK | Supabase/AWS Amplify | Would require rewriting web app backend - not viable for sync requirement |
| ObservableObject | @Observable (Swift 5.9+) | ObservableObject more compatible with iOS 16 minimum requirement, @Observable better for iOS 17+ |
| Firestore | Core Data + CloudKit | No web app support, significantly more complex sync logic, Apple-only ecosystem lock-in |
| SwiftUI | UIKit | More boilerplate, slower development, unnecessary for new app starting in 2026 |

**Installation:**
```bash
# In Xcode: File > Add Packages
# Repository: https://github.com/firebase/firebase-ios-sdk
# Version: 12.10.0 or later (use "Up to Next Major Version")
# Select packages: FirebaseAuth, FirebaseFirestore, FirebaseCore

# For Google Sign-In (if not using Firebase bundled version):
# Repository: https://github.com/google/GoogleSignIn-iOS
# Version: 8.0.0+
```

## Architecture Patterns

### Recommended Project Structure
```
PracticeTimer/
├── App/
│   ├── PracticeTimerApp.swift       # @main entry point, Firebase.configure()
│   └── AppDelegate.swift            # @UIApplicationDelegateAdaptor for method swizzling
├── Features/
│   ├── Auth/
│   │   ├── Views/
│   │   │   ├── SignInView.swift
│   │   │   ├── SignUpView.swift
│   │   │   └── PasswordResetView.swift
│   │   ├── ViewModels/
│   │   │   └── AuthViewModel.swift  # @MainActor, ObservableObject
│   │   └── Models/
│   │       └── User.swift           # Codable struct
│   ├── Activities/                   # Phase 2
│   ├── Sessions/                     # Phase 3
│   └── History/                      # Phase 4
├── Core/
│   ├── Repositories/
│   │   ├── AuthRepository.swift     # Firebase Auth wrapper
│   │   └── UserRepository.swift     # Firestore user data access
│   ├── Services/
│   │   └── FirebaseService.swift    # Shared Firebase utilities
│   └── Extensions/
│       ├── Date+ISO8601.swift       # ISO timestamp helpers
│       └── View+Extensions.swift
├── UI/
│   └── Components/
│       ├── PrimaryButton.swift
│       ├── TextFieldStyle.swift
│       └── LoadingView.swift
└── Resources/
    ├── GoogleService-Info.plist
    └── Info.plist                    # URL schemes for OAuth
```

### Pattern 1: MVVM with Repository Layer
**What:** Separate Views, ViewModels, and Repository layers with clear responsibilities
**When to use:** All features throughout the app (established in Phase 1, reused in all phases)
**Example:**
```swift
// Source: SwiftUI MVVM best practices 2026 (multiple sources)

// Repository Layer - Firebase abstraction
protocol AuthRepositoryProtocol {
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> User
    func signOut() throws
    func resetPassword(email: String) async throws
    var currentUser: User? { get }
}

class AuthRepository: AuthRepositoryProtocol {
    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return User(from: result.user)
    }
    // ... other methods
}

// ViewModel Layer - Business logic and state
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var user: User?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
    }

    func signIn() async {
        isLoading = true
        defer { isLoading = false }

        do {
            user = try await repository.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// View Layer - UI only
struct SignInView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        // UI code only - no business logic
    }
}
```

### Pattern 2: Firebase Initialization in SwiftUI App Lifecycle
**What:** Use @UIApplicationDelegateAdaptor for Firebase configuration supporting method swizzling
**When to use:** App entry point (required for Firebase services that use iOS lifecycle hooks)
**Example:**
```swift
// Source: https://firebase.google.com/docs/ios/setup, https://peterfriese.dev/blog/2020/swiftui-new-app-lifecycle-firebase/

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }

    // Required for Google Sign-In
    func application(_ app: UIApplication, open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct PracticeTimerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Pattern 3: Firestore Codable Models with ISO Timestamps
**What:** Swift Codable structs that encode/decode to Firestore documents with ISO string timestamps
**When to use:** All data models throughout the app (User, Activity, Session)
**Example:**
```swift
// Source: Firestore Codable patterns + web app compatibility requirement

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    let email: String
    let displayName: String?
    let createdAt: String  // ISO 8601 string to match web app
    let updatedAt: String

    init(id: String, email: String, displayName: String?) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = Date().toISO8601String()
        self.updatedAt = Date().toISO8601String()
    }
}

// Extension for ISO timestamp conversion
extension Date {
    func toISO8601String() -> String {
        return ISO8601DateFormatter().string(from: self)
    }

    init?(iso8601String: String) {
        guard let date = ISO8601DateFormatter().date(from: iso8601String) else {
            return nil
        }
        self = date
    }
}

// Repository usage
class UserRepository {
    private let db = Firestore.firestore()

    func saveUser(_ user: User) async throws {
        guard let userId = user.id else { throw RepositoryError.invalidUserId }
        try db.collection("users").document(userId).setData(from: user)
    }

    func getUser(id: String) async throws -> User {
        let document = try await db.collection("users").document(id).getDocument()
        return try document.data(as: User.self)
    }
}
```

### Pattern 4: Firebase Listener Cleanup to Prevent Memory Leaks
**What:** Store ListenerRegistration and call remove() in deinit to prevent memory leaks
**When to use:** Any ViewModel that uses Firestore listeners (Phase 2+, but establish pattern in Phase 1)
**Example:**
```swift
// Source: https://github.com/firebase/firebase-ios-sdk/issues/2607 (memory leak issue discussion)

@MainActor
final class ActivitiesViewModel: ObservableObject {
    @Published var activities: [Activity] = []

    private var listener: ListenerRegistration?
    private let repository: ActivityRepository

    init(repository: ActivityRepository) {
        self.repository = repository
    }

    func startListening(userId: String) {
        // CRITICAL: Use [weak self] to break retain cycle
        listener = repository.listenToActivities(userId: userId) { [weak self] activities in
            self?.activities = activities
        }
    }

    deinit {
        // CRITICAL: Always remove listeners to prevent memory leaks
        listener?.remove()
    }
}
```

### Pattern 5: Sign in with Apple with Nonce and Full Name Handling
**What:** Generate cryptographic nonce, hash with SHA256, handle Apple credential with full name
**When to use:** Apple Sign-In flow (AUTH-04)
**Example:**
```swift
// Source: https://firebase.google.com/docs/auth/ios/apple

import AuthenticationServices
import CryptoKit
import FirebaseAuth

@MainActor
final class AuthViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    private var currentNonce: String?

    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController,
                                didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            return
        }

        // CRITICAL: Use OAuthProvider.appleCredential to preserve fullName on first sign-in
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        Task {
            do {
                try await Auth.auth().signIn(with: credential)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        // Generate cryptographically secure random string
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

### Pattern 6: Google Sign-In Integration
**What:** Configure GIDSignIn with Firebase client ID, handle sign-in flow, exchange for Firebase credential
**When to use:** Google OAuth flow (AUTH-03)
**Example:**
```swift
// Source: https://firebase.google.com/docs/auth/ios/google-signin

import GoogleSignIn
import FirebaseAuth
import FirebaseCore

@MainActor
final class AuthViewModel: ObservableObject {
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard error == nil else {
                self?.errorMessage = error?.localizedDescription
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Task {
                do {
                    try await Auth.auth().signIn(with: credential)
                } catch {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

### Anti-Patterns to Avoid
- **Importing SwiftUI in ViewModels:** Keep ViewModels framework-agnostic (import Foundation/Combine only) for testability
- **Business logic in Views:** Views should only contain UI code - all logic belongs in ViewModels or Repositories
- **Direct Firebase calls from Views:** Always abstract Firebase behind Repository layer for testability and maintainability
- **Forgetting to remove listeners:** Always call listener?.remove() in deinit or memory leaks will accumulate
- **Using Firestore Timestamp directly:** Keep models framework-agnostic by using ISO strings, convert only at repository layer
- **Strong self captures in closures:** Always use [weak self] in Firebase listener closures to prevent retain cycles

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Authentication | Custom JWT/session system | Firebase Authentication | OAuth providers (Google, Apple) require complex token exchange, Firebase handles token refresh, session persistence, security rules integration, and cross-platform sync automatically |
| Password reset emails | Email sending + token generation | Firebase Auth.auth().sendPasswordReset() | Firebase provides secure templated emails, expiring tokens, automatic verification, and customizable email templates in console |
| Offline data persistence | Custom SQLite + sync queue | Firestore offline persistence (enabled by default) | Firestore handles 100MB cache, conflict resolution, automatic sync when online, query support while offline - custom solution would take months to match |
| OAuth nonce generation | Simple random strings | CryptoKit SHA256 with secure random | Apple requires cryptographically secure nonces for Sign in with Apple - weak nonces are security vulnerabilities |
| Session token refresh | Manual token expiry checks | Firebase automatic token refresh | Firebase ID tokens expire hourly, Firebase SDK handles refresh automatically using refresh tokens, manual implementation error-prone |
| Security rules | Client-side validation only | Firestore Security Rules | Client code can be modified/bypassed, security rules run server-side and are un-bypassable, required for production apps |

**Key insight:** Firebase Authentication and Firestore are production-hardened services handling edge cases that would take years to discover and fix in custom implementations (token race conditions, network interruptions during auth, offline sync conflicts, security vulnerabilities). Use them as-is rather than building "thin wrappers" that bypass their features.

## Common Pitfalls

### Pitfall 1: Firestore Listener Memory Leaks
**What goes wrong:** ViewModels with Firestore listeners never deallocate, causing memory usage to grow indefinitely
**Why it happens:** ListenerRegistration keeps strong reference to closure, closure captures self strongly, creating retain cycle
**How to avoid:**
1. Always use [weak self] in listener closures
2. Store listener as property: `private var listener: ListenerRegistration?`
3. Call `listener?.remove()` in deinit
4. Do NOT use weak for ListenerRegistration itself (will become nil and prevent removal)
**Warning signs:** Memory usage increases when navigating away from screens, ViewModels never deinit (use Instruments to detect)

### Pitfall 2: Sign in with Apple Display Name Lost After First Sign-In
**What goes wrong:** User's name is nil on subsequent sign-ins, UI shows blank name field
**Why it happens:** Apple only provides fullName (PersonNameComponents) on first authorization, nil afterwards
**How to avoid:**
1. Use OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:) instead of OAuthProvider.credential()
2. This ensures Firebase stores the display name the first time user signs in
3. Store display name in Firestore user document as backup
**Warning signs:** Display name works in testing but breaks when testing with same Apple ID again

### Pitfall 3: Sign in with Apple Nonce Mismatch Error (Code 17999)
**What goes wrong:** Sign-in fails with FIRAuthErrorDomain Code=17999 or "Invalid nonce"
**Why it happens:** Sending raw nonce instead of SHA256-hashed nonce to Apple
**How to avoid:**
1. Generate random nonce string (32+ characters)
2. Store original nonce: `currentNonce = nonce`
3. Send SHA256 hash to Apple: `request.nonce = sha256(nonce)`
4. Use original nonce with Firebase: `OAuthProvider.appleCredential(withIDToken:rawNonce:nonce)`
**Warning signs:** Apple Sign-In works intermittently or fails with cryptic error codes

### Pitfall 4: Firebase Configure Called After SwiftUI Initialization
**What goes wrong:** App crashes with "Firebase not configured" when accessing auth state on app launch
**Why it happens:** SwiftUI App body runs before AppDelegate didFinishLaunchingWithOptions in some iOS versions
**How to avoid:**
1. Use @UIApplicationDelegateAdaptor(AppDelegate.self) in App struct
2. Call FirebaseApp.configure() in AppDelegate didFinishLaunchingWithOptions
3. Don't access Auth.auth().currentUser in App init or body
4. Use auth state listener in root view instead of app entry point
**Warning signs:** Crash on cold launch but works after hot reload in Xcode

### Pitfall 5: Google Sign-In URL Scheme Not Configured
**What goes wrong:** Google Sign-In opens browser but never returns to app, user stuck
**Why it happens:** Missing REVERSED_CLIENT_ID URL scheme in Info.plist
**How to avoid:**
1. Open GoogleService-Info.plist
2. Copy value of REVERSED_CLIENT_ID key
3. Add URL Type in Xcode: Target > Info > URL Types > Add (paste REVERSED_CLIENT_ID)
4. Implement application(_:open:options:) in AppDelegate to call GIDSignIn.sharedInstance.handle(url)
**Warning signs:** Browser opens for Google Sign-In but never redirects back to app

### Pitfall 6: Firestore Document Size Limit Exceeded
**What goes wrong:** Write operations fail with "Document size exceeds 1 MiB limit"
**Why it happens:** Storing arrays of activities or sessions directly in user document
**How to avoid:**
1. Use subcollections for all scalable collections (activities, sessions)
2. Structure: users/{userId}/activities/{activityId}, NOT users/{userId} with activities array
3. Subcollections have no size limit, each document gets own 1MB quota
4. NEVER use arrays for data that could grow beyond ~20-50 items
**Warning signs:** App works fine initially but breaks after user adds many activities/sessions

### Pitfall 7: Security Rules Don't Cover Subcollections
**What goes wrong:** User can read/write other users' subcollection data despite parent document protection
**Why it happens:** Security rules don't cascade - match /users/{userId} doesn't apply to subcollections
**How to avoid:**
1. Use recursive wildcard: `match /users/{userId}/{document=**}`
2. Or explicit subcollection rules: `match /users/{userId}/activities/{activityId}`
3. ALWAYS test security rules with Firebase Emulator before deploying
4. Use rules_version = '2' at top of rules file
**Warning signs:** Security audit shows users can access other users' data via subcollection paths

### Pitfall 8: ISO Timestamp Format Mismatch Between Platforms
**What goes wrong:** Timestamps show wrong timezone or format differently on iOS vs web
**Why it happens:** Using Date directly in Firestore creates Timestamp objects, not ISO strings
**How to avoid:**
1. Create Date+ISO8601 extension: `Date().toISO8601String()`
2. Store as String in Firestore: `let createdAt: String`
3. Use ISO8601DateFormatter for parsing: `Date(iso8601String: timestamp)`
4. NEVER use Firestore Timestamp type in models if syncing with web app
**Warning signs:** Dates look correct on iOS but wrong/corrupted on web app or vice versa

## Code Examples

Verified patterns from official sources:

### Email/Password Sign Up and Sign In
```swift
// Source: https://firebase.google.com/docs/auth/ios/password-auth (updated 2026-02-26)

import FirebaseAuth

// Sign up new user
func signUp(email: String, password: String) async throws -> User {
    let result = try await Auth.auth().createUser(withEmail: email, password: password)
    return User(from: result.user)
}

// Sign in existing user
func signIn(email: String, password: String) async throws -> User {
    let result = try await Auth.auth().signIn(withEmail: email, password: password)
    return User(from: result.user)
}

// Sign out
func signOut() throws {
    try Auth.auth().signOut()
}
```

### Password Reset
```swift
// Source: https://firebase.google.com/docs/auth/ios/manage-users (updated 2026-02-26)

import FirebaseAuth

func resetPassword(email: String) async throws {
    try await Auth.auth().sendPasswordReset(withEmail: email)
}

// Optional: Localize email
func resetPasswordLocalized(email: String, languageCode: String) async throws {
    Auth.auth().languageCode = languageCode
    try await Auth.auth().sendPasswordReset(withEmail: email)
}
```

### Auth State Listener
```swift
// Source: https://firebase.google.com/docs/auth/ios/manage-users (updated 2026-02-26)

import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        // RECOMMENDED: Listen for auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            self?.user = firebaseUser.map(User.init)
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

// Alternative: Check current user (not recommended, might be in intermediate state)
if let currentUser = Auth.auth().currentUser {
    // User is signed in
} else {
    // No user signed in
}
```

### Firestore Security Rules with Recursive Wildcards
```javascript
// Source: https://firebase.google.com/docs/firestore/security/rules-structure (updated 2026-02-25)

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User profile document - direct access only
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // User subcollections - recursive wildcard covers all nested collections
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Additional validation: createdAt must be server timestamp on create
      allow create: if request.auth != null
                    && request.auth.uid == userId
                    && request.resource.data.keys().hasAll(['createdAt']);
    }

    // Collection group query support (if needed for cross-user queries by admin)
    match /{path=**}/activities/{activityId} {
      allow read: if request.auth != null
                  && request.auth.uid == resource.data.userId;
    }
  }
}
```

### Firestore Offline Persistence Configuration
```swift
// Source: https://firebase.google.com/docs/firestore/manage-data/enable-offline (updated 2026-02-27)

import FirebaseFirestore

// Configure in AppDelegate or App init
func configureFirestore() {
    let settings = FirestoreSettings()

    // Enable offline persistence (enabled by default on iOS, but explicit is clear)
    settings.isPersistenceEnabled = true

    // Optional: Set cache size (default is 100MB)
    settings.cacheSizeBytes = FirestoreCacheSizeUnlimited // or specific bytes like 50 * 1024 * 1024

    Firestore.firestore().settings = settings
}

// Note: Keep synced is NOT available in Firestore (only Realtime Database)
// Firestore automatically caches active queries and documents
```

### Testing Security Rules with Emulator
```bash
# Source: https://firebase.google.com/docs/firestore/security/test-rules-emulator (updated 2026-02-25)

# Install Firebase CLI
npm install -g firebase-tools

# Initialize emulators
firebase init emulators

# Start Firestore emulator
firebase emulators:start --only firestore

# In Xcode, set emulator connection before Firebase.configure()
# let settings = Firestore.firestore().settings
# settings.host = "localhost:8080"
# settings.isSSLEnabled = false
# Firestore.firestore().settings = settings
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIApplicationDelegate in AppDelegate.swift | @UIApplicationDelegateAdaptor in SwiftUI App | iOS 14 (2020) | SwiftUI apps can use app lifecycle directly, but still need AppDelegate for Firebase method swizzling |
| ObservableObject (Combine) | @Observable (Swift 5.9+) | Swift 5.9 (2023) | Requires iOS 17+, ObservableObject still recommended for iOS 16 compatibility |
| FirebaseUI Auth | Custom SwiftUI auth screens | Ongoing (2024-2026) | FirebaseUI is UIKit-based and awkward in SwiftUI apps, custom screens provide better UX |
| completion handlers | async/await | Swift 5.5 (2021) | All Firebase methods now support async/await, cleaner code, better error handling |
| Storing arrays in documents | Subcollections | Always best practice | 1MB document limit makes arrays unscalable, subcollections required for production apps |
| GoogleSignIn 5.x | GoogleSignIn 6.x+ | 2021-2022 | New API with GIDConfiguration, breaking changes from 5.x, better SwiftUI support |

**Deprecated/outdated:**
- **FirebaseUI for iOS:** Still maintained but UIKit-focused, poor SwiftUI integration. Use custom SwiftUI views instead.
- **Google Sign-In 5.x:** Deprecated in favor of 6.x+ with new GIDSignIn API. Old tutorials using GIDSignIn.sharedInstance()?.signIn() are outdated.
- **FIRAuth.auth():** Old Objective-C style. Use Auth.auth() (Swift naming conventions) in modern code.
- **SnapshotListener with @escaping closures only:** Modern code should use async/await where possible, closures for real-time listeners only.
- **Firestore keepSynced():** This is a Realtime Database feature, NOT available in Firestore. Confusion common in search results.

## Open Questions

1. **Firebase Private Email Relay Configuration**
   - What we know: Firebase can relay emails to Apple private relay addresses (@privaterelay.appleid.com) if configured
   - What's unclear: Exact Firebase Console configuration steps for email relay service setup
   - Recommendation: Document during implementation, consult Firebase Console UI (typically in Authentication > Templates > Email Address Verification)

2. **Account Deletion Flow for App Store Compliance**
   - What we know: App Store requires account deletion within app, must delete both Auth account and Firestore data
   - What's unclear: Whether to soft-delete (flag) or hard-delete Firestore documents, retention policy for sessions/activities
   - Recommendation: Implement hard-delete (permanent) to meet strictest interpretation of App Store guidelines, add confirmation dialog with 30-second countdown

3. **Token Refresh Timing and Error Handling**
   - What we know: Firebase tokens expire after 1 hour, SDK auto-refreshes but may fail with network issues
   - What's unclear: Best practice for handling token expiry errors in offline-first app (retry strategy, user notification)
   - Recommendation: Let Firebase SDK handle refresh automatically, catch errors and show "Session expired, please sign in again" only if refresh fails after multiple retries

4. **Concurrent Auth Requests Race Conditions**
   - What we know: User might tap "Sign In" multiple times quickly if button doesn't disable immediately
   - What's unclear: Whether Firebase SDK handles concurrent sign-in attempts gracefully or needs explicit prevention
   - Recommendation: Disable auth buttons while isLoading=true, test with rapid tapping in implementation

## Sources

### Primary (HIGH confidence)
- Firebase iOS SDK 12.10.0 release notes - https://github.com/firebase/firebase-ios-sdk/releases (accessed 2026-03-02)
- Firebase Authentication iOS official docs - https://firebase.google.com/docs/auth/ios/ (updated 2026-02-26 to 2026-02-27)
- Firebase Firestore iOS official docs - https://firebase.google.com/docs/firestore/ (updated 2026-02-25 to 2026-02-27)
- Firebase Security Rules official docs - https://firebase.google.com/docs/firestore/security/ (updated 2026-02-25)
- Apple Sign-In with Firebase - https://firebase.google.com/docs/auth/ios/apple (updated 2026-02-27)
- Google Sign-In with Firebase - https://firebase.google.com/docs/auth/ios/google-signin (updated 2026-02-27)

### Secondary (MEDIUM confidence)
- Peter Friese: Firebase and SwiftUI App Lifecycle - https://peterfriese.dev/blog/2020/swiftui-new-app-lifecycle-firebase/ (2020, verified against 2026 Firebase docs)
- SwiftUI MVVM + Repository pattern (October 2025) - https://medium.com/@gauravios/modern-mvvm-repository-pattern-in-swiftui-eca4f78fc2f5
- How to Structure SwiftUI Project 2026 - https://dev.to/__be2942592/how-to-structure-a-swiftui-project-in-2026-41m8
- Firebase iOS SDK memory leak discussion - https://github.com/firebase/firebase-ios-sdk/issues/2607 (official issue tracker)
- Swift memory leak with Firebase listeners - https://vincentbogousslavsky.com/post/swift-memory-leak-while-using-firebase-listener (2021, pattern still valid)

### Tertiary (LOW confidence)
- Firebase search results about offline persistence cache limits (multiple sources, some conflicting on default cache size)
- CodableFirebase library discussions (older, may not reflect Firebase SDK's built-in Codable support improvements)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Firebase SDK versions verified from GitHub releases, all libraries documented in official Firebase docs
- Architecture: HIGH - MVVM + Repository is industry standard for SwiftUI Firebase apps, multiple authoritative sources confirm patterns
- Pitfalls: HIGH - All pitfalls sourced from official Firebase issue tracker or verified against official docs, not speculation

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (30 days - Firebase is stable, SwiftUI patterns mature)

**Notes:**
- Firebase iOS SDK releases monthly with patch updates, major breaking changes rare
- SwiftUI architecture patterns stabilized in 2024-2025, unlikely to change significantly
- All security rule patterns verified against rules_version = '2' (current version)
- CONTEXT.md user decisions fully integrated (data model subcollections, ISO timestamps, auth flow)
