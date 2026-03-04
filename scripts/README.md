# Practice Timer Scripts

Utility scripts for development and testing.

## copy-user-data.js

Copies all session data (sessions + activities) from one user to another. Useful for populating test accounts with real data.

### Setup

1. **Install dependencies:**
   ```bash
   cd scripts
   npm install
   ```

2. **Set up Firebase Admin authentication** (choose one):

   **Option A: Service Account Key (Recommended)**
   ```bash
   # Download service account key from Firebase Console:
   # Project Settings > Service Accounts > Generate New Private Key
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
   ```

   **Option B: Application Default Credentials**
   ```bash
   gcloud auth application-default login
   ```

### Usage

**Copy from zack.huber@gmail.com to a test user:**
```bash
cd scripts
node copy-user-data.js test@example.com
```

**Copy from any user to another:**
```bash
node copy-user-data.js source@email.com target@email.com
```

### What it does

1. ✅ Deletes all existing sessions and activities for target user
2. ✅ Copies all sessions from source user
3. ✅ Copies all activities subcollections for each session
4. ✅ Copies activities collection (user's activity list)

### Safety

- ⚠️ **WARNING:** All existing data for the target user will be deleted first
- ✅ Source user data is never modified (read-only)
- ✅ Works with production Firestore (not emulator)

### Example Output

```
🔄 Copying data from zack.huber@gmail.com to test@example.com

1️⃣  Deleting existing target user data...
   ✅ Target user data deleted

2️⃣  Fetching source user sessions...
   Found 47 sessions

3️⃣  Copying sessions and activities...
   Copied 47/47 sessions (183 activities)...
   ✅ Copied 47 sessions and 183 activities

4️⃣  Checking for activities collection...
   Found 8 activities, copying...
   ✅ Copied 8 activities

✨ Data copy complete!

🎉 Done!
```

### Troubleshooting

**"Error initializing Firebase Admin"**
- Make sure GOOGLE_APPLICATION_CREDENTIALS is set
- Or run `gcloud auth application-default login`

**"Permission denied"**
- Service account needs Firestore read/write permissions
- Check Firebase Console > IAM & Admin

**"No sessions found"**
- Source user ID might be incorrect
- Check Firestore console to verify user ID format

---

## migrate-web-to-ios-format.js

Transforms session data from web app format (embedded activities arrays) to iOS format (activities subcollections). Used for cross-platform data model alignment.

### What it does

Converts session storage from:
```javascript
// Web app format (embedded)
users/{userId}/sessions/{sessionId}
{
  activities: [{...}, {...}],      // ← Embedded array
  activityTimes: {0: 120, 1: 180},
  activityNotes: {0: "note1", 1: "note2"},
  completed: true,
  completedAt: "2026-03-04...",
  totalTime: 300
}
```

To:
```swift
// iOS format (subcollection)
users/{userId}/sessions/{sessionId}
{
  state: "ended",
  startTime: "2026-03-04...",
  endTime: "2026-03-04...",
  totalDuration: 300
}

users/{userId}/sessions/{sessionId}/activities/{actId}
{
  activityId: "abc123",
  activityName: "Scales",
  duration: 120,
  notes: "note1",
  ...
}
```

### Safety Features

- ✅ **Whitelist protection**: Only migrates users in `ALLOWED_TEST_USERS` array
- ✅ **Production blocked**: zack.huber@gmail.com rejected by default
- ✅ **Dry-run mode**: Test migration without making changes
- ✅ **Progress logging**: Shows what's happening step-by-step

### Usage

**Dry run (recommended first):**
```bash
cd scripts
node migrate-web-to-ios-format.js zackspromos@gmail.com --dry-run
```

**Actual migration:**
```bash
node migrate-web-to-ios-format.js zackspromos@gmail.com
```

### Migration Process

1. **Session Transformation:**
   - `completed: true` → `state: "ended"`
   - `createdAt` → `startTime`
   - `completedAt` → `endTime`
   - `totalTime` → `totalDuration`

2. **Activities Subcollection:**
   - Each item in `activities[]` becomes a subcollection document
   - `activityTimes[i]` → `duration`
   - `activityNotes[i]` → `notes`
   - Start/end times calculated from cumulative durations

3. **Cleanup:**
   - Embedded `activities` array removed from session
   - `activityTimes` and `activityNotes` maps removed

### Example Output

```
🔗 Connected to Firebase project: practice-timer-e5efb

🔍 Looking up user ID...

   📧 zackspromos@gmail.com → UID: abc123xyz


🔄 Migrating sessions from web format to iOS format

User ID: abc123xyz
Dry Run: NO

1️⃣  Fetching sessions...
   Found 12 sessions

2️⃣  Transforming sessions...
   Transformed 12/12 sessions (47 activities total)...
   ✅ Transformed 12 sessions

3️⃣  Creating activities subcollections...
   ✅ Created 47 activity documents

✅ Migration complete!

Summary:
  User: zackspromos@gmail.com
  Sessions migrated: 12
  Activities created: 47
  Total duration: 14520s
```

### Before/After Comparison

**Before (web format):**
- Session: 1 document with embedded array
- Reads: 1 (entire session including all activities)
- Writes: 1 (update entire document)

**After (iOS format):**
- Session: 1 document + N subcollection documents
- Reads: 1 (session) + on-demand (activities)
- Writes: 1 (session) + N (activities, independent)

**Benefits:**
- Scales to large sessions (no 1MB document limit)
- Lazy-load activities (don't fetch unless needed)
- Update individual activities without rewriting session
- Better real-time update performance

### Adding More Test Users

To allow migration for additional test users:

1. Edit `migrate-web-to-ios-format.js`
2. Add email to `ALLOWED_TEST_USERS` array:
   ```javascript
   const ALLOWED_TEST_USERS = [
     'zackspromos@gmail.com',
     'test2@example.com'  // Add new test user
   ];
   ```

### Troubleshooting

**"User not authorized for migration"**
- User not in `ALLOWED_TEST_USERS` whitelist
- Edit script to add user (or verify you want to migrate production)

**"No sessions found"**
- User has no web app sessions
- Verify user email/UID is correct

**"Migration failed"**
- Check Firebase permissions
- Verify authentication is set up correctly
- Run with `--dry-run` first to test
