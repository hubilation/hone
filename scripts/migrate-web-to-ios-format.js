#!/usr/bin/env node
import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Safety: Only allow migration for test users
const ALLOWED_TEST_USERS = ['zackspromos@gmail.com'];

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

  // Placeholder for migration logic (Tasks 2-3)
  console.log('Migration logic will be implemented in next tasks...\n');

  return {
    userId,
    sessionCount: 0,
    activityCount: 0,
    totalDuration: 0
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
