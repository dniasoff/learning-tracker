#!/usr/bin/env node

// List account uids whose rules-validated client build meets the threshold.
// Run: node functions/scripts/report_accounts_on_build.mjs <build>
// Application Default Credentials (or GOOGLE_APPLICATION_CREDENTIALS) required.
import admin from 'firebase-admin';

const [rawBuild] = process.argv.slice(2);
const build = Number(rawBuild);
if (!/^\d+$/.test(rawBuild ?? '') || !Number.isSafeInteger(build) || build < 1 || build > 2147483647) {
  console.error('usage: report_accounts_on_build.mjs <positive-build-number>');
  process.exit(2);
}

admin.initializeApp();
const snapshot = await admin.firestore()
  .collection('users')
  .where('last_seen_app_build', '>=', build)
  .orderBy('last_seen_app_build')
  .get();

console.log(`Accounts with last_seen_app_build >= ${build}: ${snapshot.size}`);
for (const account of snapshot.docs) console.log(account.id);
