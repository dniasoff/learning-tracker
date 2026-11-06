#!/usr/bin/env node

// Operations-only rollout tool. Run it after the minimum app version gate is
// live, one user at a time or from a separately audited batch driver:
//
//   node functions/scripts/set_parent_session_claim.mjs <uid> [on|off]
//
// Application clients cannot invoke this operation. Application Default
// Credentials (or GOOGLE_APPLICATION_CREDENTIALS) must be configured for the
// operator running it.
import admin from 'firebase-admin';

const [uid, requested] = process.argv.slice(2);
if (!uid || (requested !== undefined && requested !== 'on' && requested !== 'off')) {
  console.error('usage: set_parent_session_claim.mjs <uid> [on|off]');
  process.exit(2);
}

admin.initializeApp();
const auth = admin.auth();
const user = await auth.getUser(uid);
const claims = { ...(user.customClaims ?? {}) };
if ((requested ?? 'on') === 'on') {
  claims.parent_session_enforced = true;
} else {
  delete claims.parent_session_enforced;
}
await auth.setCustomUserClaims(uid, claims);
console.log(`${uid}: parent_session_enforced=${claims.parent_session_enforced === true}`);
