# Phase 1: Foundation & Authentication - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Set up Firebase backend integration and implement all authentication methods (email/password, Google OAuth, Sign in with Apple) with proper session persistence and security rules. Establish the foundational architecture patterns (MVVM, repositories) and data models that the entire app will build upon.

</domain>

<decisions>
## Implementation Decisions

### Auth Flow & Navigation
- Sign in first, link to signup: Show signin form with "Don't have account? Sign up" link at bottom
- OAuth buttons on every auth screen: Show Google and Apple signin buttons on both signin and signup screens
- Main app immediately after auth: No onboarding for v1 - straight to home screen with activities after successful signin/signup
- Password reset: Claude's discretion - use standard Firebase password reset pattern

### Data Model Structure
- Match web app exactly: Use same Firestore collection structure as existing web app for seamless sync
  - `users/{userId}` - user profile document
  - `users/{userId}/activities/{activityId}` - activities subcollection
  - `users/{userId}/sessions/{sessionId}` - sessions subcollection
- Field names: Exact match with web app (camelCase) - use createdAt, practiceNotes, etc. as-is
- Timestamps: ISO strings (match web) - use `new Date().toISOString()` like web app for easy sync
- Model types: Codable structs - Swift structs conforming to Codable for type-safe encoding/decoding

### Session Persistence
- Always persist (Firebase default): User stays logged in until explicit logout - most convenient
- No biometrics in v1: Skip Face ID/Touch ID for now - standard Firebase session is enough
- Session expiry handling: Claude's discretion - handle standard Firebase token refresh patterns
- Multi-device: Allow concurrent sessions - user can be logged in on web and iOS simultaneously (matches current web behavior)

### Sign in with Apple
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

</decisions>

<specifics>
## Specific Ideas

- Web app uses `users/{userId}` with `activities` and `sessions` as subcollections - must match exactly for sync
- Web app stores timestamps as ISO strings (`.toISOString()`) - keep same format
- Web app uses camelCase field names - maintain consistency
- Firebase Auth handles Google OAuth and Sign in with Apple natively - leverage built-in flows
- Research warned: data model hard to change after users exist - get it right in Phase 1

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None yet - fresh Xcode project with default template only (Practice_TimerApp.swift, ContentView.swift)
- Web app reference available at `/Users/zackhuber/Documents/Hone/` for data model understanding

### Established Patterns
- None yet - Phase 1 establishes the patterns:
  - MVVM architecture (from research recommendations)
  - Repository pattern for Firebase access (from research)
  - ObservableObject/@Published for state management (iOS 16+ compatible)

### Integration Points
- Firebase SDK needs to be added via Swift Package Manager (research: use Firebase iOS SDK 12.10.0+)
- App entry point: Practice_TimerApp.swift will need Firebase initialization
- Root view: ContentView.swift will become auth state router (show auth screens vs main app)
- Security rules: Firestore security rules must be created/updated to prevent unauthorized access

### Web App Data Model Reference
From web app codebase scan:
```javascript
// Profile: doc(db, 'users', userId)
// Activities: collection(db, 'users', userId, 'activities')
// Sessions: collection(db, 'users', userId, 'sessions')
// Fields: camelCase (createdAt, practiceNotes, etc.)
// Timestamps: new Date().toISOString()
```

</code_context>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---

*Phase: 01-foundation-authentication*
*Context gathered: 2026-03-01*
