#!/usr/bin/env node

/**
 * Update activity categories to match iOS app conventions
 *
 * Maps old category names to new ones:
 * - "songs" → "Piece"
 * - "technical" → "Technique"
 * - "warmup" → "Warm-up"
 *
 * Usage:
 *   node update-activity-categories.js <userEmail> [--live]
 *
 * Example:
 *   node update-activity-categories.js zackspromos@gmail.com --live
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Category mapping: old → new
const CATEGORY_MAP = {
  'songs': 'Piece',
  'technical': 'Technique',
  'warmup': 'Warm-up',
  // Add any other mappings here
};

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

async function updateActivityCategories(userEmail, isLive = false) {
  console.log(`\n🔍 ${isLive ? 'UPDATING' : 'DRY RUN - Checking'} activity categories for: ${userEmail}\n`);

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

  // Get all activities
  const activitiesSnapshot = await db.collection('users')
    .doc(userId)
    .collection('activities')
    .get();

  console.log(`📊 Total activities: ${activitiesSnapshot.size}\n`);

  let updatedCount = 0;
  let unchangedCount = 0;
  const updates = [];

  for (const activityDoc of activitiesSnapshot.docs) {
    const activityData = activityDoc.data();
    const oldCategory = activityData.category;
    const newCategory = CATEGORY_MAP[oldCategory] || oldCategory;

    if (oldCategory !== newCategory) {
      updates.push({
        id: activityDoc.id,
        name: activityData.name,
        oldCategory,
        newCategory
      });
      updatedCount++;
    } else {
      unchangedCount++;
    }
  }

  // Display updates
  if (updates.length > 0) {
    console.log('📝 Category updates:\n');
    updates.forEach((update, index) => {
      console.log(`${index + 1}. "${update.name}"`);
      console.log(`   ${update.oldCategory} → ${update.newCategory}`);
      console.log();
    });
  }

  console.log('📈 Summary:');
  console.log(`   Activities to update: ${updatedCount}`);
  console.log(`   Activities unchanged: ${unchangedCount}`);
  console.log();

  if (!isLive) {
    console.log('⚠️  DRY RUN - No changes made');
    console.log('   Run with --live to apply changes\n');
    process.exit(0);
  }

  // Live mode - apply updates
  console.log('🔄 Applying updates...\n');

  const batch = db.batch();
  let batchCount = 0;

  for (const update of updates) {
    const activityRef = db.collection('users')
      .doc(userId)
      .collection('activities')
      .doc(update.id);

    batch.update(activityRef, {
      category: update.newCategory,
      updatedAt: new Date().toISOString()
    });

    batchCount++;

    // Firestore batch limit is 500, commit and start new batch if needed
    if (batchCount >= 500) {
      await batch.commit();
      console.log(`   ✅ Committed batch of ${batchCount} updates`);
      batchCount = 0;
    }
  }

  // Commit remaining updates
  if (batchCount > 0) {
    await batch.commit();
    console.log(`   ✅ Committed final batch of ${batchCount} updates`);
  }

  console.log(`\n🎉 Successfully updated ${updatedCount} activities!\n`);
  process.exit(0);
}

// Parse command line arguments
const userEmail = process.argv[2];
const isLive = process.argv.includes('--live');

if (!userEmail) {
  console.error('Usage: node update-activity-categories.js <userEmail> [--live]');
  console.error('Example: node update-activity-categories.js zackspromos@gmail.com --live');
  process.exit(1);
}

updateActivityCategories(userEmail, isLive).catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
