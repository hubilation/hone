#!/usr/bin/env node

/**
 * Fix conflicting activity states
 *
 * Sets active=false for any activity that has completed=true or archived=true
 *
 * Usage:
 *   node fix-activity-states.js <userEmail> [--live]
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const firebaserc = JSON.parse(
  readFileSync(join(__dirname, '..', '.firebaserc'), 'utf8')
);
const projectId = firebaserc.projects.default;

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: projectId
});

const db = admin.firestore();

async function fixActivityStates(userEmail, isLive = false) {
  console.log(`\n🔍 ${isLive ? 'FIXING' : 'DRY RUN - Checking'} activity states for: ${userEmail}\n`);

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

  const activitiesSnapshot = await db.collection('users')
    .doc(userId)
    .collection('activities')
    .get();

  console.log(`📊 Total activities: ${activitiesSnapshot.size}\n`);

  const toFix = [];

  activitiesSnapshot.docs.forEach(doc => {
    const data = doc.data();
    const active = data.active;
    const completed = data.completed || false;
    const archived = data.archived || false;

    // If active but should be archived (completed or archived=true)
    if (active && (completed || archived)) {
      toFix.push({
        id: doc.id,
        name: data.name,
        active,
        completed,
        archived
      });
    }
  });

  if (toFix.length > 0) {
    console.log('⚠️  Activities with conflicting states:\n');
    toFix.forEach((activity, index) => {
      console.log(`${index + 1}. "${activity.name}"`);
      console.log(`   active: ${activity.active}, completed: ${activity.completed}, archived: ${activity.archived}`);
      console.log(`   → Will set active: false`);
      console.log();
    });
  } else {
    console.log('✅ No conflicting states found!\n');
    process.exit(0);
  }

  console.log(`📈 Summary: ${toFix.length} activities to fix\n`);

  if (!isLive) {
    console.log('⚠️  DRY RUN - No changes made');
    console.log('   Run with --live to apply fixes\n');
    process.exit(0);
  }

  console.log('🔄 Applying fixes...\n');

  const batch = db.batch();

  for (const activity of toFix) {
    const activityRef = db.collection('users')
      .doc(userId)
      .collection('activities')
      .doc(activity.id);

    batch.update(activityRef, {
      active: false,
      archived: true,
      updatedAt: new Date().toISOString()
    });
  }

  await batch.commit();

  console.log(`🎉 Successfully fixed ${toFix.length} activities!\n`);
  process.exit(0);
}

const userEmail = process.argv[2];
const isLive = process.argv.includes('--live');

if (!userEmail) {
  console.error('Usage: node fix-activity-states.js <userEmail> [--live]');
  process.exit(1);
}

fixActivityStates(userEmail, isLive).catch(console.error);
