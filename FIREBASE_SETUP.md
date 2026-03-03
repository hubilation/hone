# Firebase Setup Guide

This document explains how to set up and deploy Firebase resources for Practice Timer.

## Prerequisites

1. **Firebase CLI installed:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Firebase project access:**
   - Project ID: `practice-timer-e5efb`
   - You need admin access to deploy security rules and indexes

3. **Authenticate with Firebase:**
   ```bash
   firebase login
   ```

## Project Structure

```
Practice Timer/
├── firebase.json              # Firebase configuration (references rules and indexes)
├── .firebaserc               # Firebase project configuration
├── firestore.rules           # Firestore security rules
├── firestore.indexes.json    # Firestore composite indexes
└── GoogleService-Info.plist  # iOS Firebase configuration
```

## Firestore Composite Indexes

### Why Indexes Are Required

Firestore requires **composite indexes** for queries that:
1. Combine a WHERE filter with ORDER BY on different fields
2. Use multiple ORDER BY clauses
3. Use range filters (>, <, >=, <=) on different fields

Without the required indexes, queries will fail at runtime with:
```
The query requires an index. You can create it here: [Firebase Console URL]
```

### Practice Timer Index Requirements

The app requires two composite indexes for the activities collection:

#### 1. Active Activities Query
- **Query:** `whereField("archived", isEqualTo: false).order(by: "name")`
- **Collection:** `users/{userId}/activities`
- **Fields:**
  - `archived` (ascending)
  - `name` (ascending)
- **Used by:** `ActivityRepository.listenToActiveActivities()`
- **Purpose:** Display active activities sorted alphabetically

#### 2. Archived Activities Query
- **Query:** `whereField("archived", isEqualTo: true).order(by: "updatedAt", descending: true)`
- **Collection:** `users/{userId}/activities`
- **Fields:**
  - `archived` (ascending)
  - `updatedAt` (descending)
- **Used by:** `ActivityRepository.listenToArchivedActivities()`
- **Purpose:** Display archived activities sorted by most recently updated

### Deploying Indexes

**Deploy indexes to production:**
```bash
firebase deploy --only firestore:indexes
```

**Verify indexes in Firebase Console:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `practice-timer-e5efb`
3. Navigate to Firestore Database → Indexes
4. Verify both indexes are listed with status "Enabled"

**Index deployment takes time:**
- Simple indexes: ~5 minutes
- Large collections: up to 30 minutes
- Status shows "Building" until complete

## Firestore Security Rules

Security rules are defined in `firestore.rules` and control read/write access to Firestore collections.

**Deploy security rules:**
```bash
firebase deploy --only firestore:rules
```

**Test rules locally:**
```bash
firebase emulators:start
```
- Firestore Emulator: http://localhost:8080
- Emulator UI: http://localhost:4000

## Deploy Everything

**Deploy all Firestore resources:**
```bash
firebase deploy --only firestore
```
This deploys both security rules and indexes.

**Deploy all Firebase resources:**
```bash
firebase deploy
```

## Testing Index Requirements

### Problem: Emulator Auto-Creates Indexes

The Firestore emulator automatically creates missing indexes, which means **you won't catch missing index errors during local development**.

### Solution: Test Against Production

**Before releasing a new version:**

1. **Deploy indexes to production:**
   ```bash
   firebase deploy --only firestore:indexes
   ```

2. **Configure app to use production Firestore:**
   - In Xcode, ensure `GoogleService-Info.plist` points to production project
   - Remove any Firestore emulator configuration from app delegate

3. **Create a test account** (don't use your personal account)

4. **Run through all query scenarios:**
   - Create activities
   - View active activities list (tests: archived=false + order by name)
   - Archive activities
   - View archived activities list (tests: archived=true + order by updatedAt desc)
   - Check Xcode console for "requires an index" errors

5. **If you see "requires an index" error:**
   - Update `firestore.indexes.json` with new index definition
   - Deploy: `firebase deploy --only firestore:indexes`
   - Wait for index to build (check Firebase Console)
   - Re-test queries

### CI/CD Best Practices

1. **Include index deployment in CI/CD pipeline:**
   ```bash
   firebase deploy --only firestore:indexes
   ```

2. **Run before deploying new app versions:**
   - Deploy indexes first
   - Wait for "Enabled" status
   - Then deploy app to App Store

3. **Version control indexes:**
   - Always commit `firestore.indexes.json` changes
   - Review index changes in pull requests
   - Document why each index is needed

## Common Issues

### Issue: Query fails with "requires an index"

**Symptoms:**
- App displays empty list or error state
- Xcode console shows: "The query requires an index..."

**Solution:**
1. Copy the Firebase Console URL from error message
2. Click URL to create index in console, OR
3. Add index definition to `firestore.indexes.json`
4. Deploy: `firebase deploy --only firestore:indexes`
5. Wait for index to build

### Issue: Index deployment fails

**Symptoms:**
- `firebase deploy --only firestore:indexes` returns error
- Console shows "Invalid index configuration"

**Solution:**
1. Validate JSON syntax in `firestore.indexes.json`
2. Check field names match Firestore document fields exactly
3. Verify `collectionGroup` name is correct (use collection name, not full path)
4. For subcollections, use collection name only (e.g., "activities", not "users/{userId}/activities")

### Issue: Index stuck in "Building" status

**Symptoms:**
- Index shows "Building" for more than 30 minutes
- Queries still fail with "requires an index"

**Solution:**
1. Check collection size (large collections take longer)
2. Wait longer (can take hours for millions of documents)
3. Check Firebase Console for error messages
4. If stuck for >24 hours, delete and recreate index

## Additional Resources

- [Firestore Index Documentation](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)

## Index Documentation in Code

For detailed information about which indexes are required and why, see inline documentation in:
```
Practice Timer/Core/Repositories/ActivityRepository.swift
```

The repository class header includes:
- Complete list of required indexes
- Explanation of why each query needs an index
- Testing strategies
- Deployment instructions
