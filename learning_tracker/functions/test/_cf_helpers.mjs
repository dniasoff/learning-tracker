// Shared harness for the Cloud Functions tests (L5).
//
// Each `cf_*.test.mjs` file imports these helpers and runs the REAL function
// handlers (functions/lib, built by tsc) against the Firestore emulator via
// firebase-functions-test `.wrap()`. `firebase emulators:exec` sets
// GCLOUD_PROJECT + FIRESTORE_EMULATOR_HOST, so the Admin SDK inside the imported
// functions talks to the emulator; fft.wrap() invokes the handler directly with
// the supplied {data, auth}, bypassing the App Check / auth middleware.
//
// Run all CF suites:  make test-functions
//   (firebase emulators:exec ... "node --test --test-concurrency=1 functions/test/cf_*.test.mjs")
// --test-concurrency=1 serialises the files so each can clearFirestore() freely.

import assert from 'node:assert/strict';
import admin from 'firebase-admin';
import functionsTestInit from 'firebase-functions-test';

export const PROJECT = process.env.GCLOUD_PROJECT || 'demo-cf';
export const fft = functionsTestInit(); // offline mode — no real project

// Import AFTER the emulator env is in place (index.js calls
// admin.initializeApp() at import time). One init per node:test child process.
export const fns = await import('../lib/index.js');

export const db = admin.firestore();

// ── Canonical fixture identities ──────────────────────────────────────────────
export const TUTOR = 'tutor-uid';
export const PARENT = 'parent-uid';
export const STRANGER = 'stranger-uid';
export const PROFILE = 5;
export const GRANT = 'grant-1';

export const tutorAuth = { uid: TUTOR, token: {} };
export const parentAuth = { uid: PARENT, token: {} };
export const strangerAuth = { uid: STRANGER, token: {} };

/** Root collections every CF touches. Cleared (incl. subcollections) per test. */
const ROOT_COLLECTIONS = ['tutor_grants', 'users', 'tutor_active_access'];

/**
 * Wipe all emulator data (call in beforeEach). Uses the Admin SDK's awaited
 * recursiveDelete — deterministic and synchronous-to-await, unlike the
 * emulator REST clear endpoint (which returned before nested subcollections
 * like tutor_grants/{id}/audit_log were actually purged, leaving stale grants
 * and accumulating audit entries across tests).
 */
export async function clearFirestore() {
  await Promise.all(
    ROOT_COLLECTIONS.map((c) => db.recursiveDelete(db.collection(c))),
  );
}

/**
 * Seed an active tutor grant. [permissions] is the per-action permission bag
 * (e.g. { can_reset_completion: true }); [overrides] tweaks any grant field
 * (e.g. { state: 'pending' }, { tutor_uid: 'someone-else' }).
 */
export async function seedActiveGrant(permissions = {}, overrides = {}) {
  await db
    .collection('tutor_grants')
    .doc(GRANT)
    .set({
      tutor_uid: TUTOR,
      parent_uid: PARENT,
      child_profile_id: PROFILE,
      state: 'active',
      permissions,
      tutor_name_snapshot: 'Mr Tutor',
      ...overrides,
    });
}

/** Reference to a learner-profile doc under users/{uid}/learner_profiles/{id}. */
export function profileRef(uid = PARENT, profileId = PROFILE) {
  return db
    .collection('users')
    .doc(uid)
    .collection('learner_profiles')
    .doc(String(profileId));
}

/** Invoke a wrapped callable. Pass auth=null for an unauthenticated call. */
export function call(fn, data, auth = tutorAuth) {
  const wrapped = fft.wrap(fn);
  return auth === null ? wrapped({ data }) : wrapped({ data, auth });
}

/** Assert a callable rejects with the given HttpsError canonical code. */
export async function expectHttpsError(promise, code) {
  await assert.rejects(promise, (err) => {
    const actual = err.code ?? err.httpErrorCode?.canonicalName;
    assert.equal(
      actual,
      code,
      `expected HttpsError "${code}", got "${actual}" (${err.message})`,
    );
    return true;
  });
}

// ── Auth-emulator user seeding (AUD-firebase-01) ───────────────────────────────
//
// acceptTutorInvite / declineTutorInvite call the REAL admin.auth().getUser()
// against the Auth emulator (make test-functions starts `--only firestore,auth`),
// so exercising their email-match / emailVerified gates requires a real Auth
// user to exist — fft.wrap()'s `{uid, token}` auth context only fakes the
// CALLABLE's request.auth; it does not create an Auth-emulator user record.
//
// Idempotent (create-or-update) so repeated calls across tests/files sharing
// one emulator instance never collide on `auth/uid-already-exists`.
export async function seedAuthUser({ uid, email, emailVerified = true, displayName }) {
  const props = {
    email,
    emailVerified,
    ...(displayName !== undefined ? { displayName } : {}),
  };
  try {
    await admin.auth().createUser({ uid, ...props });
  } catch (err) {
    if (err.code === 'auth/uid-already-exists' || err.code === 'auth/email-already-exists') {
      await admin.auth().updateUser(uid, props);
    } else {
      throw err;
    }
  }
}
