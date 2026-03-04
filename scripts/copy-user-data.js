#!/usr/bin/env node
import admin from 'firebase-admin';
import { readFileSync } from 'fs';

// Initialize Firebase Admin
// Expects GOOGLE_APPLICATION_CREDENTIALS env var or service account key file
try {
  admin.initializeApp({
    credential: admin.credential.applicationDefault()
  });
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

// Run the copy
copyUserData(sourceUser, targetUser)
  .then(() => {
    console.log('🎉 Done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });
