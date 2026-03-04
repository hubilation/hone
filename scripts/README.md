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
