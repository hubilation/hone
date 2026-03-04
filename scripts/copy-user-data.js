#!/usr/bin/env node
import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

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
// Expects GOOGLE_APPLICATION_CREDENTIALS env var or service account key file
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
 * Copy all session data from source user to target user
 * WARNING: Deletes all existing data for target user first
 */
async function copyUserData(sourceUserId, targetUserId) {
  console.log(`\n🔄 Copying data from ${sourceUserId} to ${targetUserId}\n`);

  // Step 1: Delete all existing data for target user
  console.log('1️⃣  Deleting existing target user data...');
  await deleteUserData(targetUserId);
  console.log('   ✅ Target user data deleted\n');

  // Step 2: Get all sessions from source user
  console.log('2️⃣  Fetching source user sessions...');
  const sourceSessions = await db
    .collection('users')
    .doc(sourceUserId)
    .collection('sessions')
    .get();

  console.log(`   Found ${sourceSessions.size} sessions\n`);

  if (sourceSessions.empty) {
    console.log('   ⚠️  No sessions found for source user');
    return;
  }

  // Step 3: Copy each session and its activities
  console.log('3️⃣  Copying sessions and activities...');
  let sessionCount = 0;
  let activityCount = 0;

  for (const sessionDoc of sourceSessions.docs) {
    const sessionData = sessionDoc.data();
    const sessionId = sessionDoc.id;

    // Copy session document
    await db
      .collection('users')
      .doc(targetUserId)
      .collection('sessions')
      .doc(sessionId)
      .set(sessionData);

    sessionCount++;

    // Copy activities subcollection
    const activities = await db
      .collection('users')
      .doc(sourceUserId)
      .collection('sessions')
      .doc(sessionId)
      .collection('activities')
      .get();

    for (const activityDoc of activities.docs) {
      const activityData = activityDoc.data();
      const activityId = activityDoc.id;

      await db
        .collection('users')
        .doc(targetUserId)
        .collection('sessions')
        .doc(sessionId)
        .collection('activities')
        .doc(activityId)
        .set(activityData);

      activityCount++;
    }

    process.stdout.write(`   Copied ${sessionCount}/${sourceSessions.size} sessions (${activityCount} activities)...\r`);
  }

  console.log(`\n   ✅ Copied ${sessionCount} sessions and ${activityCount} activities\n`);

  // Step 4: Copy activities collection (if exists)
  console.log('4️⃣  Checking for activities collection...');
  const sourceActivities = await db
    .collection('users')
    .doc(sourceUserId)
    .collection('activities')
    .get();

  if (!sourceActivities.empty) {
    console.log(`   Found ${sourceActivities.size} activities, copying...`);
    for (const activityDoc of sourceActivities.docs) {
      await db
        .collection('users')
        .doc(targetUserId)
        .collection('activities')
        .doc(activityDoc.id)
        .set(activityDoc.data());
    }
    console.log(`   ✅ Copied ${sourceActivities.size} activities\n`);
  } else {
    console.log('   No activities collection found\n');
  }

  console.log('✨ Data copy complete!\n');
}

/**
 * Delete all session data for a user
 */
async function deleteUserData(userId) {
  const sessions = await db
    .collection('users')
    .doc(userId)
    .collection('sessions')
    .get();

  // Delete each session and its activities subcollection
  for (const sessionDoc of sessions.docs) {
    // Delete activities subcollection
    const activities = await sessionDoc.ref.collection('activities').get();
    const batch = db.batch();
    activities.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    // Delete session
    await sessionDoc.ref.delete();
  }

  // Delete activities collection
  const activities = await db
    .collection('users')
    .doc(userId)
    .collection('activities')
    .get();

  if (!activities.empty) {
    const batch = db.batch();
    activities.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }
}

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length === 0) {
  // Default: copy from zack.huber@gmail.com to current test user
  const SOURCE_USER = 'zack.huber@gmail.com';

  console.log('\n📋 Usage:');
  console.log('  node copy-user-data.js <targetUserId>');
  console.log('  node copy-user-data.js <sourceUserId> <targetUserId>');
  console.log('\nExample:');
  console.log('  node copy-user-data.js test@example.com');
  console.log('  node copy-user-data.js zack.huber@gmail.com test@example.com');
  console.log('\nDefault source user: zack.huber@gmail.com\n');
  process.exit(0);
}

let sourceUser, targetUser;

if (args.length === 1) {
  // Single argument: target user (source defaults to zack.huber@gmail.com)
  sourceUser = 'zack.huber@gmail.com';
  targetUser = args[0];
} else if (args.length === 2) {
  // Two arguments: source and target
  sourceUser = args[0];
  targetUser = args[1];
} else {
  console.error('❌ Invalid arguments. Use 1 or 2 arguments.');
  process.exit(1);
}

// Confirm before proceeding
console.log('\n⚠️  WARNING: This will DELETE all existing data for target user!\n');
console.log(`Source: ${sourceUser}`);
console.log(`Target: ${targetUser}\n`);

console.log('🔍 Looking up user IDs...\n');

// Convert emails to UIDs if needed, then run the copy
(async () => {
  try {
    const sourceUid = await getUserId(sourceUser);
    const targetUid = await getUserId(targetUser);

    console.log('\n');
    await copyUserData(sourceUid, targetUid);
    console.log('🎉 Done!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
})();
