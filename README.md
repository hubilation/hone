# Hone

A native iOS app for tracking music practice sessions. Manage your practice activities, run timed sessions, take notes, and review your history — all synced in real-time with the Hone web app via Firebase.

## Features

- **Practice sessions** — start a timed session with one or more activities, pause/resume, add notes, and get a summary when done
- **Smart suggestions** — activity recommendations based on what you haven't practiced recently, plus a streak display to keep you consistent
- **Session history** — browse past sessions with activity breakdowns and total time
- **Activity management** — create, edit, archive, and categorize activities (instrument, piece, technique, etc.)
- **Statistics** — per-activity totals and weekly/daily practice charts
- **Offline-first** — full functionality without a connection; changes sync automatically when back online
- **Cross-platform sync** — shares a Firebase backend with the Hone web app; data is consistent across both

## Tech Stack

- **Language:** Swift 6, SwiftUI
- **Minimum OS:** iOS 16
- **Backend:** Firebase (Firestore, Authentication)
- **Auth:** Email/password, Google OAuth, Sign in with Apple
- **Architecture:** MVVM + Repository pattern

## Project Structure

```
Hone/
├── App/                    # App entry point and delegate
├── Core/
│   ├── Models/             # Firestore data models
│   ├── Repositories/       # Firestore read/write layer
│   ├── Services/           # NetworkMonitor, SyncStateService, SuggestionsService
│   └── Extensions/         # Date, String, TimeInterval helpers
└── Features/
    ├── Auth/               # Sign in / sign up flows
    ├── Activities/         # Activity list, form, statistics
    ├── Sessions/           # Session setup, active session, history
    └── Statistics/         # Charts and weekly summary
```

## Getting Started

1. Clone the repo
2. Open `Hone.xcodeproj` in Xcode
3. Add your `GoogleService-Info.plist` to the `Hone/` target (not included — connect your own Firebase project)
4. Build and run on a simulator or device (iOS 16+)
