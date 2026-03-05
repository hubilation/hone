#!/usr/bin/env node

/**
 * Verify iOS session migration
 *
 * Validates that sessions and activities subcollections are properly structured
 * for iOS app compatibility.
 *
 * Usage:
 *   node verify-migration.js <userEmail>
 *
 * Example:
 *   node verify-migration.js zackspromos@gmail.com
 */

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
try {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: projectId
  });
} catch (error) {
  console.error('Error initializing Firebase Admin:', error.message);
  console.error('\nMake sure you have authenticated with:');
  console.error('  firebase login');
  console.error('  gcloud auth application-default login');
  process.exit(1);
}

const db = admin.firestore();

async function verifyMigration(userEmail) {
  console.log(`\n🔍 Verifying migration for user: ${userEmail}\n`);

  // Get user document
  const userSnapshot = await db.collection('users')
    .where('email', '==', userEmail)
    .limit(1)
    .get();

  if (userSnapshot.empty) {
    console.error(`❌ User not found: ${userEmail}`);
    process.exit(1);
  }

  const userId = userSnapshot.docs[0].id;
  console.log(`✅ Found user ID: ${userId}\n`);

  // Get all sessions
  const sessionsSnapshot = await db.collection('users')
    .doc(userId)
    .collection('sessions')
    .get();

  console.log(`📊 Total sessions: ${sessionsSnapshot.size}\n`);

  let totalActivities = 0;
  let sessionsWithEmbeddedArrays = 0;
  let sessionsWithSubcollections = 0;
  let sessionsWithBoth = 0;
  const issues = [];

  for (const sessionDoc of sessionsSnapshot.docs) {
    const sessionData = sessionDoc.data();

    // Check for embedded activities array (old format)
    const hasEmbeddedActivities = sessionData.activities && Array.isArray(sessionData.activities);

    // Check for activities subcollection (new format)
    const activitiesSnapshot = await db.collection('users')
      .doc(userId)
      .collection('sessions')
      .doc(sessionDoc.id)
      .collection('activities')
      .get();

    const hasSubcollection = activitiesSnapshot.size > 0;

    if (hasEmbeddedActivities && hasSubcollection) {
      sessionsWithBoth++;
    } else if (hasEmbeddedActivities) {
      sessionsWithEmbeddedArrays++;
      issues.push({
        sessionId: sessionDoc.id,
        startTime: sessionData.startTime,
        issue: 'Has embedded activities array but no subcollection'
      });
    } else if (hasSubcollection) {
      sessionsWithSubcollections++;
    }

    totalActivities += activitiesSnapshot.size;

    // Validate session fields (iOS format)
    const requiredFields = ['state', 'startTime', 'totalDuration', 'createdAt', 'updatedAt'];
    const missingFields = requiredFields.filter(field => !(field in sessionData));

    if (missingFields.length > 0) {
      issues.push({
        sessionId: sessionDoc.id,
        startTime: sessionData.startTime,
        issue: `Missing required fields: ${missingFields.join(', ')}`
      });
    }
  }

  // Print summary
  console.log('📈 Migration Summary:');
  console.log(`   Sessions with subcollections only: ${sessionsWithSubcollections}`);
  console.log(`   Sessions with embedded arrays only: ${sessionsWithEmbeddedArrays}`);
  console.log(`   Sessions with both formats: ${sessionsWithBoth}`);
  console.log(`   Total activities in subcollections: ${totalActivities}`);
  console.log();

  // Print issues
  if (issues.length > 0) {
    console.log(`⚠️  Found ${issues.length} issue(s):\n`);
    issues.forEach((issue, index) => {
      console.log(`${index + 1}. Session ${issue.sessionId}`);
      console.log(`   Start Time: ${issue.startTime}`);
      console.log(`   Issue: ${issue.issue}\n`);
    });
  } else {
    console.log('✅ No issues found! All sessions are in iOS format.\n');
  }

  // Verify activities structure
  console.log('🔍 Verifying activity documents...\n');

  const activitiesSnapshot = await db.collection('users')
    .doc(userId)
    .collection('activities')
    .get();

  console.log(`📊 Total activities: ${activitiesSnapshot.size}`);

  let activitiesWithStats = 0;
  let activitiesWithoutStats = 0;

  for (const activityDoc of activitiesSnapshot.docs) {
    const activityData = activityDoc.data();

    if ('totalPracticeTime' in activityData || 'lastUsed' in activityData) {
      activitiesWithStats++;
    } else {
      activitiesWithoutStats++;
    }
  }

  console.log(`   Activities with stats (totalPracticeTime/lastUsed): ${activitiesWithStats}`);
  console.log(`   Activities without stats: ${activitiesWithoutStats}\n`);

  // Final verdict
  if (issues.length === 0 && sessionsWithEmbeddedArrays === 0) {
    console.log('🎉 Migration verification PASSED!\n');
    console.log('All sessions are in iOS subcollection format.');
    console.log('Ready for production iOS app usage.\n');
  } else if (sessionsWithEmbeddedArrays > 0) {
    console.log('⚠️  Migration verification INCOMPLETE!\n');
    console.log(`Found ${sessionsWithEmbeddedArrays} sessions with embedded arrays.`);
    console.log('Run migrate-web-to-ios-format.js to complete migration.\n');
  } else {
    console.log('⚠️  Migration verification found issues!\n');
    console.log('Review the issues above and fix before deploying iOS app.\n');
  }

  process.exit(0);
}

// Parse command line arguments
const userEmail = process.argv[2];

if (!userEmail) {
  console.error('Usage: node verify-migration.js <userEmail>');
  console.error('Example: node verify-migration.js zackspromos@gmail.com');
  process.exit(1);
}

verifyMigration(userEmail).catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
