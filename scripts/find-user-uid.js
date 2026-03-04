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
try {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: projectId
  });
} catch (error) {
  console.error('Error initializing Firebase Admin:', error.message);
  process.exit(1);
}

const auth = admin.auth();

/**
 * Find user UID by email
 */
async function findUserByEmail(email) {
  try {
    const userRecord = await auth.getUserByEmail(email);
    console.log('\n✅ User found!\n');
    console.log(`Email: ${userRecord.email}`);
    console.log(`UID:   ${userRecord.uid}`);
    console.log(`Name:  ${userRecord.displayName || '(not set)'}`);
    console.log(`Created: ${userRecord.metadata.creationTime}\n`);
    console.log('Use this UID for the copy script:');
    console.log(`node copy-user-data.js ${userRecord.uid} <targetUID>\n`);
    return userRecord.uid;
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.error(`\n❌ No user found with email: ${email}\n`);
    } else {
      console.error(`\n❌ Error: ${error.message}\n`);
    }
    process.exit(1);
  }
}

// Parse command line arguments
const email = process.argv[2];

if (!email) {
  console.log('\n📋 Usage:');
  console.log('  node find-user-uid.js <email>\n');
  console.log('Example:');
  console.log('  node find-user-uid.js zack.huber@gmail.com\n');
  process.exit(0);
}

findUserByEmail(email)
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
