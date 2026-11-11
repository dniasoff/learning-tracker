#!/usr/bin/env node

// Operations-only grant for school verification and moderation callables.
// This script must run with audited Application Default Credentials; app
// clients cannot set the claim. Never grant the claim from a callable.
import admin from 'firebase-admin';

const args = process.argv.slice(2);
const uidAt = args.indexOf('--uid');
const uid = uidAt >= 0 ? args[uidAt + 1] : null;
const revoke = args.includes('--revoke');
if (!uid || args.some((arg, index) => arg === '--uid' && index !== uidAt) ||
    args.some((arg) => !['--uid', uid, '--revoke'].includes(arg))) {
  console.error('usage: set_app_owner_claim.mjs --uid <uid> [--revoke]');
  process.exit(2);
}

admin.initializeApp();
const auth = admin.auth();
const user = await auth.getUser(uid);
const claims = { ...(user.customClaims ?? {}) };
if (revoke) delete claims.app_owner;
else claims.app_owner = true;
await auth.setCustomUserClaims(uid, claims);
console.log(`${uid}: app_owner=${claims.app_owner === true}`);
