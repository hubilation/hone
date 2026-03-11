#!/usr/bin/env node
import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Safety: Only allow migration for test users
const ALLOWED_TEST_USERS = ['zackspromos@gmail.com', 'zack.huber@gmail.com'];

// Read project ID from .firebaserc
let projectId;
try {
  const firebaserc = JSON.parse(
    readFileSync(join(__dirname, '..', '.firebaserc'), 'utf8')
  );
  projectId = firebaserc.projects.default;
} catch (error) {
  console.error('Error reading .firebaserc:', error.message);
  process.exit(1);
}

// Initialize Firebase Admin
try {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: projectId
  });
  console.log(`🔗 Connected to Firebase project: ${projectId}\n`);
} catch (error) {
  console.error('Error initializing Firebase Admin:', error.message);
  console.error('\nPlease set up authentication:');
  console.error('1. Download service account key from Firebase Console');
  console.error('2. Set GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json');
  console.error('   OR');
  console.error('3. Run: gcloud auth application-default login');
  process.exit(1);
}

const db = admin.firestore();
const auth = admin.auth();

/**
 * Convert email to UID if needed
 */
async function getUserId(emailOrUid) {
  // If it looks like an email, lookup the UID
  if (emailOrUid.includes('@')) {
    try {
      const userRecord = await auth.getUserByEmail(emailOrUid);
      console.log(`   📧 ${emailOrUid} → UID: ${userRecord.uid}`);
      return userRecord.uid;
    } catch (error) {
      console.error(`   ❌ User not found: ${emailOrUid}`);
      throw error;
    }
  }
  // Otherwise assume it's already a UID
  return emailOrUid;
}

/**
 * Check if user is allowed for migration
 */
function checkUserAllowed(emailOrUid) {
  const isAllowed = ALLOWED_TEST_USERS.some(testUser =>
    emailOrUid.includes(testUser) || emailOrUid === testUser
  );

  if (!isAllowed) {
    console.error(`\n❌ ERROR: User not in allowed test users list`);
    console.error(`   User: ${emailOrUid}`);
    console.error(`   Allowed: ${ALLOWED_TEST_USERS.join(', ')}`);
    console.error(`\n⚠️  This safety check prevents accidental production data migration.`);
    console.error(`   To migrate production users, edit ALLOWED_TEST_USERS in the script.\n`);
    throw new Error('User not authorized for migration');
  }
}

/**
 * Transform web app session to iOS format
 */
function transformSession(webSession) {
  const iosSession = {
    state: webSession.completed ? 'ended' : 'setup',
    startTime: webSession.createdAt,
    endTime: webSession.completedAt || null,
    totalDuration: webSession.totalTime || 0,
    createdAt: webSession.createdAt,
    updatedAt: webSession.updatedAt || webSession.createdAt
  };

  // Set currentActivityIndex to last activity index
  if (webSession.activities && webSession.activities.length > 0) {
    iosSession.currentActivityIndex = webSession.activities.length - 1;
  } else {
    iosSession.currentActivityIndex = 0;
  }

  return iosSession;
}

/**
 * Main migration function
 */
export async function migrateUserSessions(userEmailOrUid, isDryRun = false) {
  console.log('🔍 Looking up user ID...\n');

  // Check authorization first (before UID lookup)
  checkUserAllowed(userEmailOrUid);

  // Convert email to UID
  const userId = await getUserId(userEmailOrUid);

  console.log('\n🔄 Migrating sessions from web format to iOS format\n');
  console.log(`User ID: ${userId}`);
  console.log(`Dry Run: ${isDryRun ? 'YES (no changes will be made)' : 'NO'}\n`);

  // Get all sessions for user
  console.log('1️⃣  Fetching sessions...');
  const sessionsRef = db.collection('users').doc(userId).collection('sessions');
  const sessionsSnapshot = await sessionsRef.get();

  if (sessionsSnapshot.empty) {
    console.log('   No sessions found for user\n');
    return {
      userId,
      sessionCount: 0,
      activityCount: 0,
      totalDuration: 0
    };
  }

  console.log(`   Found ${sessionsSnapshot.size} sessions\n`);

  let sessionCount = 0;
  let activityCount = 0;
  let totalDuration = 0;

  // Transform each session
  console.log('2️⃣  Transforming sessions...');

  for (const sessionDoc of sessionsSnapshot.docs) {
    const webSession = sessionDoc.data();
    const sessionId = sessionDoc.id;

    // Transform to iOS format
    const iosSession = transformSession(webSession);

    // Count activities
    const activityArray = webSession.activities || [];
    activityCount += activityArray.length;
    totalDuration += (webSession.totalTime || 0);

    if (!isDryRun) {
      // Write transformed session (overwrite existing)
      await sessionDoc.ref.set(iosSession);
    }

    sessionCount++;
    process.stdout.write(`   Transformed ${sessionCount}/${sessionsSnapshot.size} sessions (${activityCount} activities total)...\r`);
  }

  console.log(`\n   ✅ Transformed ${sessionCount} sessions\n`);

  // Create activities subcollections
  console.log('3️⃣  Creating activities subcollections...');

  let activitiesCreated = 0;

  for (const sessionDoc of sessionsSnapshot.docs) {
    const webSession = sessionDoc.data();
    const sessionId = sessionDoc.id;
    const activityArray = webSession.activities || [];

    if (activityArray.length === 0) {
      continue;
    }

    const activityTimes = webSession.activityTimes || {};
    const activityNotes = webSession.activityNotes || {};
    const sessionStartTime = webSession.createdAt;

    // Calculate start time for each activity
    let cumulativeOffset = 0;

    for (let index = 0; index < activityArray.length; index++) {
      const activity = activityArray[index];
      const duration = activityTimes[index] || 0;
      const notes = activityNotes[index] || null;

      // Calculate activity start and end times
      const startTime = new Date(new Date(sessionStartTime).getTime() + cumulativeOffset * 1000);
      const endTime = new Date(startTime.getTime() + duration * 1000);

      // Create SessionActivity document
      const sessionActivity = {
        activityId: activity.id || null,
        activityName: activity.name,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
        duration: duration,
        notes: notes,
        isInBetweenTime: false,
        createdAt: sessionStartTime,
        updatedAt: webSession.updatedAt || sessionStartTime
      };

      if (!isDryRun) {
        // Create document in activities subcollection
        const activitiesRef = db.collection('users')
          .doc(userId)
          .collection('sessions')
          .doc(sessionId)
          .collection('activities');

        await activitiesRef.add(sessionActivity);
      }

      activitiesCreated++;
      cumulativeOffset += duration;
    }

    if (isDryRun) {
      console.log(`   [DRY RUN] Would create ${activityArray.length} activities for session ${sessionId}`);
    }
  }

  console.log(`   ✅ Created ${activitiesCreated} activity documents\n`);

  return {
    userId,
    sessionCount,
    activityCount: activitiesCreated,
    totalDuration
  };
}

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length === 0) {
  console.log('\n📋 Usage:');
  console.log('  node migrate-web-to-ios-format.js <userEmail> [--dry-run]');
  console.log('\nExample:');
  console.log('  node migrate-web-to-ios-format.js zackspromos@gmail.com --dry-run');
  console.log('  node migrate-web-to-ios-format.js zackspromos@gmail.com');
  console.log('\nAllowed test users:');
  ALLOWED_TEST_USERS.forEach(user => console.log(`  - ${user}`));
  console.log('\n⚠️  Production users (zack.huber@gmail.com) are blocked for safety.\n');
  process.exit(0);
}

const userEmail = args[0];
const isDryRun = args.includes('--dry-run');

// Run migration
migrateUserSessions(userEmail, isDryRun)
  .then((result) => {
    console.log('✅ Migration complete!');
    console.log(`\nSummary:`);
    console.log(`  User: ${userEmail}`);
    console.log(`  Sessions migrated: ${result.sessionCount}`);
    console.log(`  Activities created: ${result.activityCount}`);
    console.log(`  Total duration: ${result.totalDuration}s\n`);
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Migration failed:', error.message);
    process.exit(1);
  });
