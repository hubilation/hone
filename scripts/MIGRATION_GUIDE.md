# iOS Data Migration Guide

## Overview

This guide explains how to migrate Practice Timer data from the web app format (embedded arrays) to the iOS app format (subcollections).

## Data Model Changes

### Web App Format (Old)
```javascript
users/{userId}/sessions/{sessionId}
{
  activities: [         // Embedded array
    { name, time, ... },
    { name, time, ... }
  ],
  activityTimes: [...],
  activityNotes: [...],
  ...
}
```

### iOS App Format (New)
```javascript
users/{userId}/sessions/{sessionId}
{
  state: "ended",
  startTime: "2026-03-04T...",
  totalDuration: 3600,
  ...
}

users/{userId}/sessions/{sessionId}/activities/{activityId}
{
  activityId: "abc123",
  activityName: "Scales",
  startTime: "2026-03-04T...",
  endTime: "2026-03-04T...",
  duration: 1200,
  notes: "Good progress",
  ...
}
```

## Why Subcollections?

1. **Firestore Best Practice**: Subcollections scale better than large embedded arrays
2. **Efficient Queries**: Can query activities independently without loading entire session
3. **Real-time Updates**: Can listen to activities subcollection for live updates
4. **1MB Document Limit**: Embedded arrays can hit Firestore's document size limit

## Migration Scripts

### 1. migrate-web-to-ios-format.js

**Purpose**: Transforms web app sessions to iOS format

**Features**:
- Dry-run mode (default) - shows what will change without modifying data
- Live mode (`--live`) - actually migrates data
- Safety checks - only allows migration for whitelisted test users
- Preserves all data - creates subcollections while keeping original arrays

**Usage**:
```bash
# Dry run (safe, read-only)
node scripts/migrate-web-to-ios-format.js zackspromos@gmail.com

# Live migration (modifies data)
node scripts/migrate-web-to-ios-format.js zackspromos@gmail.com --live
```

**Safety**:
- Only works for users in `ALLOWED_TEST_USERS` array
- Must edit script to add production user email
- Dry-run by default
- Keeps original embedded arrays (backward compatible)

### 2. verify-migration.js

**Purpose**: Validates migration completed successfully

**Features**:
- Counts sessions in each format
- Identifies issues (missing fields, incomplete migrations)
- Validates activity documents have stats fields
- Provides clear pass/fail verdict

**Usage**:
```bash
node scripts/verify-migration.js zackspromos@gmail.com
```

**Output Example**:
```
🔍 Verifying migration for user: zackspromos@gmail.com

✅ Found user ID: abc123

📊 Total sessions: 162

📈 Migration Summary:
   Sessions with subcollections only: 0
   Sessions with embedded arrays only: 0
   Sessions with both formats: 162
   Total activities in subcollections: 709

✅ No issues found! All sessions are in iOS format.

🎉 Migration verification PASSED!
```

## Production Migration Workflow

### Step 1: Backup Data
```bash
# Use Firebase CLI to backup before migration
firebase firestore:export gs://your-bucket/backups/pre-ios-migration
```

### Step 2: Test Migration
```bash
# 1. Run dry-run on test user
node scripts/migrate-web-to-ios-format.js zackspromos@gmail.com

# 2. Review output carefully

# 3. Run live migration on test user
node scripts/migrate-web-to-ios-format.js zackspromos@gmail.com --live

# 4. Verify migration
node scripts/verify-migration.js zackspromos@gmail.com

# 5. Test iOS app with test user to confirm everything works
```

### Step 3: Production Migration
```bash
# 1. Edit migrate-web-to-ios-format.js
# Add production user email to ALLOWED_TEST_USERS array:
const ALLOWED_TEST_USERS = ['zackspromos@gmail.com', 'zack.huber@gmail.com'];

# 2. Run dry-run on production user
node scripts/migrate-web-to-ios-format.js zack.huber@gmail.com

# 3. Review output - verify session count matches expectations

# 4. Run live migration
node scripts/migrate-web-to-ios-format.js zack.huber@gmail.com --live

# 5. Verify migration
node scripts/verify-migration.js zack.huber@gmail.com

# 6. Test iOS app immediately to confirm success
```

### Step 4: Monitor
- Check Firestore console for new subcollections
- Monitor Firebase logs for errors
- Test all iOS app features:
  - Session history view
  - Session detail view
  - Statistics view
  - Activity total practice time

## Backward Compatibility

The migration maintains backward compatibility:

### iOS App
- ✅ Reads both `active` and `archived` fields (Activity model)
- ✅ Writes both `active` and `archived` fields (backward compatible)
- ✅ Queries use `archived` field (works with old data)
- ✅ Sessions use subcollections (new format)

### Web App
- ✅ Can continue using embedded arrays (migration keeps them)
- ✅ Will see new subcollections but doesn't need to use them
- ⚠️  Should eventually be updated to use subcollections too

## Rollback Plan

If issues are discovered:

1. **Immediate**: Disable iOS app login for affected users
2. **Investigation**: Check Firebase logs and verify-migration.js output
3. **Restore**: Use Firebase backup to restore pre-migration state
4. **Fix**: Correct migration script issues
5. **Retry**: Re-run migration after fixes

## Data Validation

After migration, verify:

- [ ] Session count matches pre-migration count
- [ ] All sessions have `state`, `startTime`, `totalDuration` fields
- [ ] All sessions have activities subcollection
- [ ] Activity count in subcollections matches embedded array count
- [ ] iOS app can load session history
- [ ] iOS app can view session details
- [ ] Statistics show correct data
- [ ] No Firebase errors in console

## Common Issues

### Issue: "User not found"
**Solution**: Verify user email is correct (case-sensitive)

### Issue: "User not in whitelist"
**Solution**: Add user email to `ALLOWED_TEST_USERS` in migration script

### Issue: Sessions still have embedded arrays
**Solution**: This is expected! Migration keeps arrays for backward compatibility.
The iOS app uses subcollections, web app can still use arrays.

### Issue: Activity stats not updating
**Solution**: Verify SessionViewModel calls `updateActivityStats()` when activities complete.
Check that ActivityRepository has the new `updateActivityStats` method.

## Next Steps

After successful migration:

1. Deploy iOS app to production
2. Monitor user feedback
3. Update web app to use subcollections (future work)
4. Consider cleanup script to remove embedded arrays (after web app updated)
