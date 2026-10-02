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
// AD-24: learner profiles are addressed by a ULID string doc-id, never a Drift
// row integer. This fixture was `5` — a NUMBER — which is exactly why the CF
// suite could not see that 14 tutor Cloud Functions still demanded
// `typeof profileId === "number"` while every Dart caller sent a ULID. A
// number here made the tests agree with the bug instead of with production.
//
// Keep this a STRING. `String(PROFILE)` and `${PROFILE}` call sites are
// unaffected; `child_profile_id: PROFILE` now stores the same shape production
// writes rather than a coincidentally-stringified integer.
export const PROFILE = "01J8XKQ2M3N4P5R6S7T8V9W0XY";
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
 * (e.g. { can_edit_learning: true }); [overrides] tweaks any grant field
 * (e.g. { state: 'pending' }, { tutor_uid: 'someone-else' }).
 */
export async function seedActiveGrant(permissions = {}, overrides = {}) {
  await db
    .collection('tutor_grants')
    .doc(GRANT)
    .set({
      tutor_uid: TUTOR,
      parent_uid: PARENT,
      // AUD-firebase-07: String(PROFILE), matching every production writer
      // (inviteTutor requires childProfileId to be a string — see
      // functions/src/index.ts). Storing PROFILE as a bare JS number here
      // made listTutorGrants' outgoing-mode Firestore '==' query (which
      // compares against a string) never match, silently returning zero
      // results and making that test path untestable for regressions.
      child_profile_id: String(PROFILE),
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

// ── Governed-write fixtures (sub-tracks AD-38 / Story 1.10) ────────────────────

/** Display name the account doc carries for the owner (actor.display_name). */
export const PARENT_NAME = 'Parent Name';

/**
 * Deterministic test ULID: a fixed Crockford prefix plus a zero-padded
 * counter, so ids sort in creation order and match the AD-38 ULID regex.
 */
export function ulid(n) {
  return `01JTEST0000000000000${String(n).padStart(6, '0')}`;
}

/**
 * Seed the learner-profile doc (writeWithChangeLog requires it to exist) and
 * the owner's account doc (source of an owner actor's display_name).
 */
export async function seedProfile(fields = {}) {
  await db.collection('users').doc(PARENT).set({ display_name: PARENT_NAME });
  await profileRef().set({
    display_name: 'Child',
    avatar: 'lion',
    mode: 'child',
    time_zone: 'Asia/Jerusalem',
    ...fields,
  });
}

/** Seed an active grant carrying the AD-53 `can_edit_learning` permission. */
export async function seedLearningGrant(overrides = {}) {
  await seedActiveGrant({ can_edit_learning: true }, overrides);
}

/** All change_log entries of the fixture profile, ordered by id. */
export async function changeLog(uid = PARENT, profileId = PROFILE) {
  const snap = await profileRef(uid, profileId).collection('change_log').get();
  return snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .sort((a, b) => a.id.localeCompare(b.id));
}

/**
 * Runs [fn] while recording every structured log line the Functions logger
 * writes (it prints one JSON object per line to stdout/stderr), and returns
 * `{ result, error, logs }`. Output still passes through to the terminal.
 */
export async function captureLogs(fn) {
  const lines = [];
  const origOut = process.stdout.write.bind(process.stdout);
  const origErr = process.stderr.write.bind(process.stderr);
  const record = (chunk) => {
    for (const line of String(chunk).split('\n')) {
      const trimmed = line.trim();
      if (!trimmed.startsWith('{')) continue;
      try { lines.push({ raw: trimmed, entry: JSON.parse(trimmed) }); } catch { /* not a log line */ }
    }
  };
  process.stdout.write = (chunk, ...rest) => { record(chunk); return origOut(chunk, ...rest); };
  process.stderr.write = (chunk, ...rest) => { record(chunk); return origErr(chunk, ...rest); };
  let result;
  let error;
  try {
    result = await fn();
  } catch (err) {
    error = err;
  } finally {
    process.stdout.write = origOut;
    process.stderr.write = origErr;
  }
  return { result, error, logs: lines };
}

/**
 * Asserts the AD-54 privacy contract for a rejected governed call: exactly
 * one `governed_write_rejected` line, carrying only `{entity, code}` (plus the
 * logger's own severity/message), and no uid, profile id or [secrets] text
 * anywhere in what was logged.
 */
export function assertPrivacySafeRejectionLog(logs, { entity, code, secrets = [] }) {
  const rejected = logs.filter((l) => l.entry.message === 'governed_write_rejected');
  assert.equal(rejected.length, 1, `expected one governed_write_rejected log, got ${rejected.length}`);
  const { entry } = rejected[0];
  assert.deepEqual(
    Object.keys(entry).sort(),
    ['code', 'entity', 'message', 'severity'],
    `rejection log must carry only {entity, code}: ${rejected[0].raw}`,
  );
  assert.equal(entry.entity, entity);
  assert.equal(entry.code, code);
  const allText = logs.map((l) => l.raw).join('\n');
  for (const secret of [PARENT, TUTOR, String(PROFILE), PARENT_NAME, ...secrets]) {
    assert.ok(!allText.includes(secret), `log output leaked learner data: ${secret}`);
  }
}
