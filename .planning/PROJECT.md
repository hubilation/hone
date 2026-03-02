# Practice Timer iOS

## What This Is

A native iOS app for Practice Timer - a practice session tracker for musicians. Users can manage their practice activities (instruments, pieces, techniques), plan timed practice sessions, and track their progress over time. This iOS app provides full feature parity with the existing web application while delivering an iOS-native experience optimized for iPhone and iPad.

## Core Value

Musicians can reliably track their practice sessions with accurate timing, notes, and history that syncs seamlessly between web and iOS platforms. If the timer works, notes save, and data syncs, everything else is secondary.

## Requirements

### Validated

- ✓ Web app functional - existing React/Firebase web application with full practice tracking features
- ✓ Firebase infrastructure - Firestore database, Authentication, and Hosting already operational
- ✓ Codebase mapping - complete understanding of web app architecture and data models

### Active

- [ ] User can authenticate with email/password on iOS
- [ ] User can authenticate with Google OAuth on iOS
- [ ] User can authenticate with Sign in with Apple
- [ ] User session persists across app restarts
- [ ] User can create, edit, and delete practice activities
- [ ] User can categorize activities (instrument, piece, technique, etc.)
- [ ] User can archive and restore activities
- [ ] User can plan a practice session by selecting activities
- [ ] User can start a timed practice session
- [ ] User can see large, clear time display during practice (visible from distance)
- [ ] User can pause and resume practice sessions
- [ ] User can add notes during practice for each activity
- [ ] User can track "in between" time (breaks between activities)
- [ ] User can skip or remove activities during active session
- [ ] User can reorder activities during session
- [ ] User can view practice session summary after completion
- [ ] User can view session history (past practice sessions)
- [ ] User can view activity statistics (total time per activity)
- [ ] User can access admin panel features (if applicable from web app)
- [ ] App works fully offline with local data persistence
- [ ] Data syncs in real-time when online
- [ ] Offline changes sync automatically when connection restored
- [ ] Session setup is simplified with smart activity suggestions based on practice history
- [ ] Session setup requires fewer steps than web app
- [ ] Timer UI has simpler, more obvious controls
- [ ] Timer UI shows visual progress indicator for session
- [ ] App supports iPhone (all sizes)
- [ ] App supports iPad with adaptive layouts
- [ ] App ready for App Store submission and approval

### Out of Scope

- iOS widgets - defer to v2, focus on core app experience first
- Apple Watch companion app - defer to v2, add once core iOS app proven
- Push notifications - defer to v2, not essential for practice tracking
- Voice notes - defer to v2, keep note-taking consistent with web app for v1
- Quick note presets - defer to v2, standard text input sufficient for v1
- Session templates - defer to v2, smart suggestions provide similar value
- iOS 15 support - targeting iOS 16+ for better SwiftUI features
- Android version - iOS-only for initial release

## Context

**Existing Web Application:**
The Practice Timer web app is a fully functional React-based SPA with Firebase backend. It has been mapped extensively and includes:
- Authentication (email/password, Google OAuth)
- Real-time data sync via Firestore
- Activity management with categories and archiving
- Complex practice session flow with timer, pause/resume, notes, and dynamic activity management
- Session history and statistics
- Admin panel

**Web App Architecture:**
- Frontend: React 19, React Router, Vite build tool
- Backend: Firebase (Auth, Firestore, Hosting)
- State: Context API for session state, custom hooks for Firestore operations
- Data model: Users → Profile, Activities, Sessions with timestamps and activity tracking

**Known Web App Issues Being Addressed:**
- Session setup has too many steps - iOS will streamline with smart suggestions
- Timer UI is cluttered - iOS will simplify controls and improve visual hierarchy
- PracticeSession component is 1000+ lines - iOS architecture will be more modular from start

**Target Users:**
Musicians (self and others) who practice regularly and want to track their progress. Primary use case is during active practice with instrument in hand, so UI must be operable with minimal interaction.

**iOS-Specific Considerations:**
- Users may use app while holding instrument, so controls must be large and obvious
- Timer display must be readable from distance (e.g., on music stand)
- Offline support essential since practice spaces may have poor connectivity
- iOS-native patterns preferred over web design translation
- App Store guidelines must be followed for approval

## Constraints

- **Platform**: iOS 16+ minimum to balance feature availability with user base reach
- **Devices**: Universal app supporting iPhone and iPad with adaptive layouts
- **Backend**: Must use existing Firebase project and data models for cross-platform data sharing
- **Authentication**: Must support Firebase Auth with Google OAuth + add Sign in with Apple (App Store requirement for apps offering third-party sign-in)
- **Data Sync**: Firestore with offline persistence enabled - hybrid real-time sync when online, queue operations when offline
- **Technology**: Native SwiftUI (not React Native, Capacitor, or Flutter) for best iOS experience
- **Design Language**: iOS-native patterns, SF Symbols, native controls - not a port of web design
- **Distribution**: Public App Store release (not TestFlight-only)
- **App Store Requirements**: Privacy policy, terms of service, app icons, screenshots, and compliance with App Store guidelines required before submission
- **Timeline**: No rush - prioritize quality over speed, iterate as needed

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native SwiftUI vs React Native | Best iOS experience, access to latest iOS features, better performance for timer-critical app | — Pending |
| Shared Firebase backend | Users expect data to sync between web and iOS, single source of truth simplifies architecture | — Pending |
| iOS 16+ minimum | Good balance of modern SwiftUI features and user reach, iOS 16 shipped Sept 2022 | — Pending |
| Hybrid sync (real-time + offline) | Matches web app behavior when online, essential offline support for practice spaces with poor connectivity | — Pending |
| Sign in with Apple required | App Store guidelines require it when offering third-party OAuth (Google) | — Pending |
| iOS-native design over web port | iOS users expect iOS patterns, timer must be optimized for glanceable use during practice | — Pending |
| Defer iOS-specific features (widgets, watch, notifications) | Focus v1 on feature parity and core improvements, validate product before platform-specific features | — Pending |
| Smart suggestions over templates | Simpler UX for session setup, leverages existing practice history data | — Pending |

---
*Last updated: 2026-03-01 after initialization*
