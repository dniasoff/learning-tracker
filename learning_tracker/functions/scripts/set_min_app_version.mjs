#!/usr/bin/env node

// Operations-only control for the client-side minimum build gate.
// Run: node functions/scripts/set_min_app_version.mjs <build>
// Application Default Credentials (or GOOGLE_APPLICATION_CREDENTIALS) required.
import admin from 'firebase-admin';

const [rawBuild] = process.argv.slice(2);
const build = Number(rawBuild);
if (!/^\d+$/.test(rawBuild ?? '') || !Number.isSafeInteger(build) || build < 1 || build > 2147483647) {
  console.error('usage: set_min_app_version.mjs <positive-build-number>');
  process.exit(2);
}

admin.initializeApp();
await admin.firestore().doc('app_config/min_version').set({
  minimum_build_number: build,
  updated_at: admin.firestore.FieldValue.serverTimestamp(),
});
console.log(`Minimum app build set to ${build}`);
