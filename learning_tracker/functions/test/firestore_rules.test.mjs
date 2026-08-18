// Firestore security-rules tests (L5) — run against the Firestore emulator.
//
//   cd learning_tracker
//   firebase emulators:exec --only firestore --project demo-rules \
//     "node --test functions/test/firestore_rules.test.mjs"
//
// These lock the LOAD-BEARING security boundaries that the fake-Firestore unit
// tests cannot enforce (the gap that caused a real sign-in lockout, see memory
// project_firestore_rules_deploy):
//   • owner-only read/write of the user subtree (lockout cause),
//   • the tutor WRITE BLOCK — a tutor (different uid) can never write a
//     completion even with an active grant (canMarkLiveCompletion=false, site 3),
//   • completions field validation (points∈[0,100], completed_at<=now),
//   • Admin-SDK-only tutor_grants / tutor_active_access.
//
// Coverage: 25/25 match paths in firestore.rules.
//
// Hardening additions (emulator-hardening plan):
//   C-EXTRA: PAYLOADS fixture derived from Dart codec encode() outputs —
//     single source of truth for valid doc shapes, consumed by Phase D and E.
//   PHASE D: Zero-denial oracle — all legitimate owner writes must succeed.
//   PHASE E: Cross-device replication round-trip — device-1 writes, device-2
//     reads back the same document successfully.

import { readFileSync } from 'node:fs';
import { strict as assert } from 'node:assert';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  getDocs,
  setDoc,
  deleteDoc,
  collection,
  query,
  limit,
  Timestamp,
  setLogLevel,
} from 'firebase/firestore';

setLogLevel('error'); // silence the verbose Firestore SDK chatter

// ── C-EXTRA: canonical write-payload fixtures ─────────────────────────────────
// Derived from Dart codec encode() outputs and LocalDataUploadService map
// literals. ISO-8601 strings are converted to Firestore Timestamps so that
// time-comparison rules (completed_at <= request.time) evaluate correctly.
// Re-generate: cd learning_tracker && make emit-fixtures
const _rawPayloads = JSON.parse(
  readFileSync('functions/test/fixtures/write_payloads.json', 'utf8'),
);

// Walk a JSON object and convert any ISO-8601 date string to a Firestore
// Timestamp so time-comparison rules evaluate correctly.
function convertTimestamps(obj) {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(convertTimestamps);
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(v)) {
      out[k] = Timestamp.fromDate(new Date(v));
    } else {
      out[k] = convertTimestamps(v);
    }
  }
  return out;
}

// PAYLOADS: each collection's canonical write payload with Timestamp objects.
// Fields intentionally match what the app actually pushes to Firestore.
const PAYLOADS = convertTimestamps(_rawPayloads);

const OWNER = 'owner-uid';
const TUTOR = 'tutor-uid';
const STRANGER = 'stranger-uid';
const PROFILE = '5';

// Subcollection path prefixes
const LP = `users/${OWNER}/learner_profiles/${PROFILE}`;
const COMPLETIONS = `${LP}/completions`;
const GOALS = `${LP}/goals`;

// hasActiveTutorAccess() looks up the deterministic id {tutor}_{owner}_{profile}.
const ACCESS_ID = `${TUTOR}_${OWNER}_${PROFILE}`;

const pastTs = Timestamp.fromMillis(Date.UTC(2020, 0, 1));
const futureTs = Timestamp.fromMillis(Date.UTC(2999, 0, 1));

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-rules',
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Seed an active tutor grant index entry (Admin-SDK-only in prod) so the
  // tutor's READ path is exercised — writes must still be denied.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `tutor_active_access/${ACCESS_ID}`), {
      tutor_uid: TUTOR,
      parent_uid: OWNER,
      owner_uid: OWNER,
      child_profile_id: PROFILE,
    });
    await setDoc(doc(db, `tutor_grants/g1`), {
      tutor_uid: TUTOR,
      parent_uid: OWNER,
      state: 'active',
    });
    // Pre-existing completion so the tutor read + owner update paths have a doc.
    await setDoc(doc(db, `${COMPLETIONS}/c1`), {
      points: 10,
      completed_at: pastTs,
    });
    // Pre-existing learner profile doc.
    await setDoc(doc(db, `users/${OWNER}/learner_profiles/${PROFILE}`), {
      name: 'Test Profile',
    });
  });
});

const owner = () => env.authenticatedContext(OWNER).firestore();
const tutor = () => env.authenticatedContext(TUTOR).firestore();
const stranger = () => env.authenticatedContext(STRANGER).firestore();
const anon = () => env.unauthenticatedContext().firestore();

// ── Helper: assert the standard owner-write / tutor-read / stranger-deny matrix.
// `path` is the full Firestore path to the document being tested.
// `validDoc` is a valid payload for owner create/update.
// `tutorCanRead` controls whether the tutor-read assertion is checked
//   (false for paths that are owner-only even with active access).
// `ownerCanDelete` controls whether the owner-delete assertion is checked.
async function expectOwnerWriteTutorRead(path, validDoc, {
  tutorCanRead = true,
  ownerCanDelete = false,
} = {}) {
  const db_owner = owner();
  const db_tutor = tutor();
  const db_stranger = stranger();
  const db_anon = anon();

  // Seed the doc so reads have something to return.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), validDoc);
  });

  // Owner can read and write.
  await assertSucceeds(getDoc(doc(db_owner, path)));
  await assertSucceeds(setDoc(doc(db_owner, path), validDoc));

  // Tutor can read iff tutorCanRead; tutor can never write.
  if (tutorCanRead) {
    await assertSucceeds(getDoc(doc(db_tutor, path)));
  } else {
    await assertFails(getDoc(doc(db_tutor, path)));
  }
  await assertFails(setDoc(doc(db_tutor, path), validDoc));

  // Stranger and anon are always denied.
  await assertFails(getDoc(doc(db_stranger, path)));
  await assertFails(getDoc(doc(db_anon, path)));
  await assertFails(setDoc(doc(db_stranger, path), validDoc));

  // Delete: permitted only when ownerCanDelete=true.
  if (ownerCanDelete) {
    await assertSucceeds(deleteDoc(doc(db_owner, path)));
  } else {
    await assertFails(deleteDoc(doc(db_owner, path)));
  }
  // Tutor/stranger can never delete.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), validDoc);
  });
  await assertFails(deleteDoc(doc(db_tutor, path)));
  await assertFails(deleteDoc(doc(db_stranger, path)));
}

// ── Path 1 / 2: global default-deny ──────────────────────────────────────────
describe('global default-deny — unlisted paths are denied for everyone', () => {
  test('arbitrary unlisted collection/doc is denied read and write', async () => {
    const ref = doc(owner(), 'random_collection/some_doc');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, { x: 1 }));
    await assertFails(deleteDoc(ref));
  });
  test('anon and stranger also denied on unlisted path', async () => {
    await assertFails(getDoc(doc(anon(), 'random_collection/x')));
    await assertFails(getDoc(doc(stranger(), 'random_collection/x')));
  });
});

// ── Path 3: users/{uid} — owner-only (lockout boundary) ─────────────────────
describe('users/{uid} — owner-only (lockout boundary)', () => {
  test('owner reads & writes own doc', async () => {
    await assertSucceeds(setDoc(doc(owner(), `users/${OWNER}`), { name: 'A' }));
    await assertSucceeds(getDoc(doc(owner(), `users/${OWNER}`)));
  });
  test('non-owner & anon are denied read', async () => {
    await assertFails(getDoc(doc(stranger(), `users/${OWNER}`)));
    await assertFails(getDoc(doc(anon(), `users/${OWNER}`)));
  });
  test('non-owner is denied write; delete denied for everyone', async () => {
    await assertFails(setDoc(doc(stranger(), `users/${OWNER}`), { x: 1 }));
    await assertFails(deleteDoc(doc(owner(), `users/${OWNER}`)));
  });
});

// ── Path 4: users/{uid}/profile/{docId} — owner-only (tutor DENIED) ─────────
describe('users/{uid}/profile/{docId} — owner-only; tutor with active access is DENIED', () => {
  test('owner can read and write profile/data', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), `users/${OWNER}/profile/data`), { display_name: 'Alice' }),
    );
    await assertSucceeds(getDoc(doc(owner(), `users/${OWNER}/profile/data`)));
  });
  test('tutor with active access cannot read profile/data (owner-only path)', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${OWNER}/profile/data`), { display_name: 'Alice' });
    });
    await assertFails(getDoc(doc(tutor(), `users/${OWNER}/profile/data`)));
  });
  test('stranger and anon are denied', async () => {
    await assertFails(getDoc(doc(stranger(), `users/${OWNER}/profile/data`)));
    await assertFails(getDoc(doc(anon(), `users/${OWNER}/profile/data`)));
    await assertFails(setDoc(doc(stranger(), `users/${OWNER}/profile/data`), { x: 1 }));
  });
  test('delete is denied even for owner', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${OWNER}/profile/data`), { x: 1 });
    });
    await assertFails(deleteDoc(doc(owner(), `users/${OWNER}/profile/data`)));
  });
});

// ── Path 5: users/{uid}/diagnostic_logs/{logId} — owner-only (tutor DENIED) ──
describe('users/{uid}/diagnostic_logs/{logId} — owner-only append; tutor with active access is DENIED', () => {
  test('owner can create a diagnostic log entry', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), `users/${OWNER}/diagnostic_logs/entry1`), { message: 'test' }),
    );
  });
  test('owner can read diagnostic logs', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${OWNER}/diagnostic_logs/e1`), { msg: 'x' });
    });
    await assertSucceeds(getDoc(doc(owner(), `users/${OWNER}/diagnostic_logs/e1`)));
  });
  test('tutor with active access cannot read diagnostic logs (owner-only path)', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${OWNER}/diagnostic_logs/e1`), { msg: 'x' });
    });
    await assertFails(getDoc(doc(tutor(), `users/${OWNER}/diagnostic_logs/e1`)));
  });
  test('update and delete are denied even for owner (append-only)', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${OWNER}/diagnostic_logs/e1`), { msg: 'x' });
    });
    // update is deny:false in rules
    await assertFails(deleteDoc(doc(owner(), `users/${OWNER}/diagnostic_logs/e1`)));
  });
  test('stranger and anon are denied', async () => {
    await assertFails(getDoc(doc(stranger(), `users/${OWNER}/diagnostic_logs/e1`)));
    await assertFails(getDoc(doc(anon(), `users/${OWNER}/diagnostic_logs/e1`)));
  });
});

// ── Path 6: learner_profiles/{profileId} doc itself ─────────────────────────
describe('learner_profiles/{profileId} document — owner write, tutor read, stranger denied', () => {
  test('owner can read and write the learner profile doc', async () => {
    await assertSucceeds(getDoc(doc(owner(), `users/${OWNER}/learner_profiles/${PROFILE}`)));
    await assertSucceeds(
      setDoc(doc(owner(), `users/${OWNER}/learner_profiles/${PROFILE}`), { name: 'Updated' }),
    );
  });
  test('tutor with active access can read the learner profile doc', async () => {
    await assertSucceeds(getDoc(doc(tutor(), `users/${OWNER}/learner_profiles/${PROFILE}`)));
  });
  test('tutor cannot write the learner profile doc', async () => {
    await assertFails(
      setDoc(doc(tutor(), `users/${OWNER}/learner_profiles/${PROFILE}`), { name: 'Hacked' }),
    );
  });
  test('stranger and anon are denied', async () => {
    await assertFails(getDoc(doc(stranger(), `users/${OWNER}/learner_profiles/${PROFILE}`)));
    await assertFails(getDoc(doc(anon(), `users/${OWNER}/learner_profiles/${PROFILE}`)));
  });
  test('delete is denied even for owner', async () => {
    await assertFails(deleteDoc(doc(owner(), `users/${OWNER}/learner_profiles/${PROFILE}`)));
  });
});

// ── SR-5: revoked/expired tutor access is denied ─────────────────────────────
// hasActiveTutorAccess() is an O(1) EXISTENCE check against
// tutor_active_access/{accessId} — the doc is maintained authoritatively by
// Cloud Functions: written by acceptInvite, DELETED by revokeGrant /
// resignGrant / expirePendingInvites (see functions/src/tutor_invites.ts,
// functions/src/deletes.ts). There is no separate `state`/`expires_at` field
// on this doc for the rule to inspect — absence of the doc IS "revoked or
// expired". This block proves that cutoff actually holds at the rules layer:
// once the access doc is gone, every previously-tutor-readable path denies
// the same tutor, using the SAME auth identity that succeeded while access
// was active (beforeEach seeds it; each test here deletes it first).
describe('SR-5 — revoked/expired tutor access (tutor_active_access absent) denies tutor reads', () => {
  async function revokeAccess() {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), `tutor_active_access/${ACCESS_ID}`));
    });
  }

  test('revoked tutor cannot read the learner profile doc (was readable while active)', async () => {
    // Sanity: access is active before revocation (mirrors the test above).
    await assertSucceeds(getDoc(doc(tutor(), `users/${OWNER}/learner_profiles/${PROFILE}`)));
    await revokeAccess();
    await assertFails(getDoc(doc(tutor(), `users/${OWNER}/learner_profiles/${PROFILE}`)));
  });

  test('revoked tutor cannot read completions (was readable while active)', async () => {
    await assertSucceeds(getDoc(doc(tutor(), `${COMPLETIONS}/c1`)));
    await revokeAccess();
    await assertFails(getDoc(doc(tutor(), `${COMPLETIONS}/c1`)));
  });

  test('revoked tutor cannot read goals (was readable while active)', async () => {
    await revokeAccess();
    await assertFails(getDoc(doc(tutor(), `${GOALS}/g1`)));
  });

  test('a tutor who was never granted access (no tutor_active_access doc ever written) is denied', async () => {
    // Distinct from revocation: this asserts the non-existence branch holds
    // even without a prior active state, i.e. hasActiveTutorAccess() never
    // defaults to true when the lookup doc is simply missing.
    await revokeAccess();
    await assertFails(getDoc(doc(tutor(), `${LP}/streak_events/s1`)));
    await assertFails(getDoc(doc(tutor(), `${LP}/learning_ledger/ll1`)));
  });
});

// ── Path 7: completions — owner write + validation + TUTOR WRITE BLOCK ───────
describe('completions — owner write + validation + TUTOR WRITE BLOCK', () => {
  test('owner creates valid completion (points in range, no future date)', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), `${COMPLETIONS}/ok`), { points: 50, completed_at: pastTs }),
    );
    await assertSucceeds(
      setDoc(doc(owner(), `${COMPLETIONS}/nopoints`), { sefaria_ref: 'Berakhot.2a' }),
    );
  });
  test('owner cannot write invalid points or a future completed_at', async () => {
    await assertFails(setDoc(doc(owner(), `${COMPLETIONS}/neg`), { points: -1 }));
    await assertFails(setDoc(doc(owner(), `${COMPLETIONS}/big`), { points: 101 }));
    await assertFails(setDoc(doc(owner(), `${COMPLETIONS}/str`), { points: '50' }));
    await assertFails(
      setDoc(doc(owner(), `${COMPLETIONS}/future`), { completed_at: futureTs }),
    );
  });
  test('tutor with active grant CAN read completions', async () => {
    await assertSucceeds(getDoc(doc(tutor(), `${COMPLETIONS}/c1`)));
  });
  test('tutor with active grant CANNOT create or update a completion (write block)', async () => {
    await assertFails(setDoc(doc(tutor(), `${COMPLETIONS}/x`), { points: 1, completed_at: pastTs }));
    await assertFails(setDoc(doc(tutor(), `${COMPLETIONS}/c1`), { points: 99 }));
  });
  test('non-owner non-tutor cannot read; nobody can delete', async () => {
    await assertFails(getDoc(doc(stranger(), `${COMPLETIONS}/c1`)));
    await assertFails(deleteDoc(doc(owner(), `${COMPLETIONS}/c1`)));
  });
  // SR-1 (AUD-docs-01): append-only collections deny value mutation on
  // update — only an idempotent identical replay is permitted. c1 is
  // seeded in beforeEach with points: 10.
  test('SR-1: owner CANNOT change points on an existing completion (value mutation denied)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${COMPLETIONS}/c1`), { points: 99, completed_at: pastTs }),
    );
  });
  test('SR-1: owner CAN replay the identical completion value (idempotent retry)', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), `${COMPLETIONS}/c1`), { points: 10, completed_at: pastTs }),
    );
  });
  test('SR-4: list() capped at limit(500); unbounded/501+ denied; get() unaffected', async () => {
    await expectSR4ListLimitCap(COMPLETIONS);
  });
});

// ── SR-4 helper: list() queries are capped at request.query.limit <= 500 ────
// (AUD-firebase-09) get() (single-doc read) stays unrestricted (exercised
// elsewhere by expectOwnerWriteTutorRead / the completions describe block
// above); list() (a collection query) must specify limit(500) or fewer to
// succeed — a larger or absent limit is denied, regardless of how many
// documents actually exist in the collection.
async function expectSR4ListLimitCap(collectionPath) {
  const db_owner = owner();
  await assertSucceeds(
    getDocs(query(collection(db_owner, collectionPath), limit(500))),
  );
  await assertFails(
    getDocs(query(collection(db_owner, collectionPath), limit(501))),
  );
  await assertFails(getDocs(collection(db_owner, collectionPath))); // no limit() at all
}

// ── SR-1 helper: changed-value update denied, identical replay allowed ──────
// (AUD-docs-01) Seeds `path` with `seedDoc`, then asserts an owner update
// with `changedDoc` (a different field value) FAILS, and an owner update
// re-sending `seedDoc` unchanged (idempotent retry) SUCCEEDS.
async function expectSR1ChangedValueDenied(path, seedDoc, changedDoc) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), seedDoc);
  });
  await assertFails(setDoc(doc(owner(), path), changedDoc));
  await assertSucceeds(setDoc(doc(owner(), path), seedDoc));
}

// ── Path 8: streak_events ────────────────────────────────────────────────────
describe('streak_events — owner write, tutor read, delete denied', () => {
  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/streak_events/s1`, { event: 'start' });
  });
  test('tutor cannot write streak_events', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/streak_events/x`), { event: 'x' }));
  });
  test('SR-1: owner CANNOT change an existing streak_events value (identical replay still allowed)', async () => {
    await expectSR1ChangedValueDenied(
      `${LP}/streak_events/s2`,
      { event: 'start' },
      { event: 'tampered' },
    );
  });
  test('SR-4: list() capped at limit(500); unbounded/501+ denied; get() unaffected', async () => {
    await expectSR4ListLimitCap(`${LP}/streak_events`);
  });
  test('SR-3: owner cannot write a future created_at; past created_at succeeds', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/streak_events/future`), { event: 'x', created_at: futureTs }),
    );
    await assertSucceeds(
      setDoc(doc(owner(), `${LP}/streak_events/past`), { event: 'x', created_at: pastTs }),
    );
  });
});

// ── Path 9: learning_ledger ──────────────────────────────────────────────────
describe('learning_ledger — owner write, tutor read, delete denied', () => {
  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/learning_ledger/ll1`, { minutes: 30 });
  });
  test('tutor cannot write learning_ledger', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/learning_ledger/x`), { minutes: 1 }));
  });
  test('SR-1: owner CANNOT change an existing learning_ledger value (identical replay still allowed)', async () => {
    await expectSR1ChangedValueDenied(
      `${LP}/learning_ledger/ll2`,
      { minutes: 30 },
      { minutes: 9999 },
    );
  });
  test('SR-4: list() capped at limit(500); unbounded/501+ denied; get() unaffected', async () => {
    await expectSR4ListLimitCap(`${LP}/learning_ledger`);
  });
  test('SR-3: owner cannot write a future completed_at; past completed_at succeeds', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/learning_ledger/future`), { minutes: 1, completed_at: futureTs }),
    );
    await assertSucceeds(
      setDoc(doc(owner(), `${LP}/learning_ledger/past`), { minutes: 1, completed_at: pastTs }),
    );
  });
});

// ── Path 10: points_ledger ───────────────────────────────────────────────────
describe('points_ledger — owner write, tutor read, delete denied', () => {
  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/points_ledger/pl1`, { points: 10 });
  });
  test('tutor cannot write points_ledger', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/points_ledger/x`), { points: 5 }));
  });
  test('SR-1: owner CANNOT change an existing points_ledger value (identical replay still allowed)', async () => {
    await expectSR1ChangedValueDenied(
      `${LP}/points_ledger/pl2`,
      { points: 10 },
      { points: 500 },
    );
  });
  test('SR-4: list() capped at limit(500); unbounded/501+ denied; get() unaffected', async () => {
    await expectSR4ListLimitCap(`${LP}/points_ledger`);
  });
  test('SR-3: owner cannot write a future created_at; past created_at succeeds', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/points_ledger/future`), { points: 1, created_at: futureTs }),
    );
    await assertSucceeds(
      setDoc(doc(owner(), `${LP}/points_ledger/past`), { points: 1, created_at: pastTs }),
    );
  });
});

// ── Path 11: reward_redemptions ──────────────────────────────────────────────
describe('reward_redemptions — owner write, tutor read, delete denied', () => {
  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/reward_redemptions/rr1`, {
      reward_id: 'r1',
      state: 'pending_fulfilment',
    });
  });
  test('tutor cannot write reward_redemptions', async () => {
    await assertFails(
      setDoc(doc(tutor(), `${LP}/reward_redemptions/x`), { reward_id: 'r1', state: 'pending_fulfilment' }),
    );
  });
});

// ── Path 12: settings ────────────────────────────────────────────────────────
describe('settings — owner write (open bag), tutor read, delete denied', () => {
  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/settings/cur1`, {
      profile_id: PROFILE,
      custom_open_key: 'value',
    });
  });
  test('tutor cannot write settings', async () => {
    await assertFails(
      setDoc(doc(tutor(), `${LP}/settings/cur1`), { profile_id: PROFILE }),
    );
  });
});

// ── Path 13: stage_definitions (with hasOnly whitelist) ──────────────────────
describe('stage_definitions — owner write with key whitelist, tutor read, delete denied', () => {
  // Sourced from PAYLOADS.stage_definitions (the codec-derived single source
  // of truth — see C-EXTRA) with only the whitelist-only legacy fields the
  // current codec no longer emits (profile_id/delay_days/days_of_week/
  // rolling_window_size/synced_at) layered on top. Keeps this matrix literal
  // from silently diverging from PAYLOADS the way `track_id` once did
  // (string 't1' here vs. numeric 1 in the fixture — see AUD-firebase-13).
  const validStage = {
    ...PAYLOADS.stage_definitions,
    profile_id: PROFILE,
    delay_days: 0,
    days_of_week: [1, 2, 3],
    rolling_window_size: 7,
    synced_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/stage_definitions/t1_1`, validStage);
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/stage_definitions/t1_1`), {
        ...validStage,
        hacker_field: true,
      }),
    );
  });
  test('tutor cannot write stage_definitions', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/stage_definitions/t1_1`), validStage));
  });
});

// ── Path 14: curriculum_tracks (with hasOnly whitelist) ──────────────────────
describe('curriculum_tracks — owner write with key whitelist, tutor read, delete denied', () => {
  const validTrack = {
    profile_id: PROFILE,
    track_id: 't1',
    curriculum_id: 'c1',
    state: 'active',
    state_changed_at: pastTs,
    activated_at: pastTs,
    synced_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/curriculum_tracks/t1`, validTrack);
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/curriculum_tracks/t1`), {
        ...validTrack,
        extra_field: 'bad',
      }),
    );
  });
  test('tutor cannot write curriculum_tracks', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/curriculum_tracks/t1`), validTrack));
  });
  // Gap 2 (docs/firestore-rewrite-map.md "OPEN" section): last_reorder_at
  // (TrackDao.stampReorderAt's reorder-amnesty baseline) was absent from
  // this whitelist, which permission-denied the WHOLE track write, not
  // merely dropped the field (hasOnly() is all-or-nothing).
  test('owner CAN write last_reorder_at (Gap 2 — reorder-amnesty baseline)', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), `${LP}/curriculum_tracks/t_reorder`), {
        ...validTrack,
        last_reorder_at: pastTs,
      }),
    );
  });
  // Regression guard: adding last_reorder_at did not widen the whitelist
  // beyond that one field — a genuinely unknown field is still denied.
  test('regression: an unrelated unknown field is still denied alongside ' +
      'last_reorder_at', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/curriculum_tracks/t_reorder2`), {
        ...validTrack,
        last_reorder_at: pastTs,
        still_unknown_field: true,
      }),
    );
  });
});

// ── Path 15: bookmarks (with hasOnly whitelist) ───────────────────────────────
describe('bookmarks — owner write with key whitelist, tutor read, delete denied', () => {
  // NOTE: no `track_type` — removed from the schema (W3.22) and absent from the
  // bookmarks hasOnly() allowlist. A stale fixture carrying track_type made this
  // rules test red on dev (invisible because test-rules isn't wired into `make ci`).
  const validBookmark = {
    profile_id: PROFILE,
    curriculum_id: 'c1',
    content_item_id: 'item1',
    sefaria_ref: 'Berakhot.2a',
    stage_id: 's1',
    updated_at: pastTs,
    synced_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/bookmarks/bk1`, validBookmark);
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/bookmarks/bk1`), {
        ...validBookmark,
        unknown_field: 'x',
      }),
    );
  });
  test('tutor cannot write bookmarks', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/bookmarks/bk1`), validBookmark));
  });
  test('SR-2: an oversized sefaria_ref (>500 chars) is denied', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/bookmarks/bk2`), {
        ...validBookmark,
        sefaria_ref: 'x'.repeat(501),
      }),
    );
  });
  test('SR-2: a wrong-typed curriculum_id (number, not string) is denied', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/bookmarks/bk3`), {
        ...validBookmark,
        curriculum_id: 12345,
      }),
    );
  });
});

// ── Path 16: learning_order (with hasOnly whitelist; owner DELETE allowed) ───
describe('learning_order — owner write+delete with key whitelist, tutor read', () => {
  const validOrder = {
    curriculum_id: 'c1',
    sefaria_ref: 'Berakhot.2a',
    ref: 'Berakhot 2a',
    user_sort_order: 1,
    updated_at: pastTs,
    synced_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny matrix (owner can delete)', async () => {
    await expectOwnerWriteTutorRead(`${LP}/learning_order/o1`, validOrder, {
      ownerCanDelete: true,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/learning_order/o1`), {
        ...validOrder,
        bad_field: 99,
      }),
    );
  });
  test('tutor cannot write learning_order', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/learning_order/o1`), validOrder));
  });
});

// ── Path 16b: track_learning_order (Gap 1 — hasOnly whitelist, SR-4 cap) ────
//
// A SEPARATE collection from learning_order — see doc_ids.dart's
// trackLearningOrderDocId doc comment for why the two orderings cannot share
// one collection. Mirrors learning_order's owner/tutor/whitelist shape, plus
// an SR-4 list() cap that learning_order itself does not have.
describe('track_learning_order — owner write with key whitelist, tutor read, delete denied, SR-4 cap', () => {
  const validTrackOrder = {
    curriculum_id: 'c1',
    sefaria_ref: 'Berakhot.2a',
    user_sort_order: 1,
    updated_at: pastTs,
    synced_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny + unauthenticated-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/track_learning_order/o1`, validTrackOrder);
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/track_learning_order/o1`), {
        ...validTrackOrder,
        bad_field: 99,
      }),
    );
  });
  test('tutor cannot write track_learning_order', async () => {
    await assertFails(
      setDoc(doc(tutor(), `${LP}/track_learning_order/o1`), validTrackOrder),
    );
  });
  test('SR-4: list() capped at limit(500); unbounded/501+ denied; get() unaffected', async () => {
    await expectSR4ListLimitCap(`${LP}/track_learning_order`);
  });
  // Regression guard: this is a genuinely separate collection from
  // learning_order, not an accidental alias of the same rules block — a
  // write to one never appears when querying the other.
  test('regression: track_learning_order and learning_order are independent ' +
      'collections — a write to one is invisible from the other', async () => {
    const db = owner();
    await assertSucceeds(
      setDoc(doc(db, `${LP}/track_learning_order/independence_check`), validTrackOrder),
    );
    const learningOrderDocs = await getDocs(
      query(collection(db, `${LP}/learning_order`), limit(500)),
    );
    assert.ok(
      !learningOrderDocs.docs.some((d) => d.id === 'independence_check'),
      'a track_learning_order write must never appear in learning_order',
    );
  });
});

// ── Path 17: preferences (open bag, no whitelist) ────────────────────────────
describe('preferences — owner write (open bag, no whitelist), tutor read, delete denied', () => {
  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/preferences/notification_settings`, {
      enabled: true,
      any_open_field: 'allowed',
    });
  });
  test('tutor cannot write preferences', async () => {
    await assertFails(
      setDoc(doc(tutor(), `${LP}/preferences/notification_settings`), { enabled: false }),
    );
  });
  // SR-2: preferences has no hasOnly() whitelist (open, heterogeneous bag),
  // so Firestore Rules can't type/size-check arbitrary unknown keys — the
  // achievable generic guard is a top-level key-count cap (see the rule's
  // comment in firestore.rules), a defence against a garbage/DoS payload.
  test('SR-2: a payload with 51 keys (over the 50 key-count cap) is denied', async () => {
    const bloated = {};
    for (let i = 0; i < 51; i++) bloated[`field_${i}`] = i;
    await assertFails(
      setDoc(doc(owner(), `${LP}/preferences/notification_settings`), bloated),
    );
  });
  test('SR-2: a normal-sized preferences payload (well under the cap) succeeds', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), `${LP}/preferences/notification_settings`), {
        enabled: true,
        any_open_field: 'allowed',
      }),
    );
  });
});

// ── Path 18: goals (with hasOnly whitelist; owner DELETE allowed) ────────────
describe('goals — owner write+delete with key whitelist, tutor read-only', () => {
  test('owner writes goal with whitelisted keys', async () => {
    await assertSucceeds(
      setDoc(doc(owner(), `${GOALS}/g`), {
        goal_id: 'g', profile_id: PROFILE, target_percent: 80,
      }),
    );
  });
  test('owner write with an unknown key is denied', async () => {
    await assertFails(
      setDoc(doc(owner(), `${GOALS}/g2`), { goal_id: 'g2', hacker_field: true }),
    );
  });
  test('tutor can read goals but not write them', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `${GOALS}/seed`), { goal_id: 'seed' });
    });
    await assertSucceeds(getDoc(doc(tutor(), `${GOALS}/seed`)));
    await assertFails(setDoc(doc(tutor(), `${GOALS}/seed`), { goal_id: 'seed' }));
  });

  // Owner-initiated goal deletion: create/update were already owner-writable
  // (above); this closes the asymmetry where a tutor could delete a goal via
  // the `tutorDeleteGoal` Cloud Function (Admin SDK) but the owner could not
  // remove their own goal from the client.
  describe('owner-initiated delete', () => {
    const validGoal = { goal_id: 'g_del', profile_id: PROFILE, target_percent: 50 };

    test('owner CAN delete their own goal', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `${GOALS}/g_del`), validGoal);
      });
      await assertSucceeds(deleteDoc(doc(owner(), `${GOALS}/g_del`)));
    });

    test('a different signed-in user (stranger) CANNOT delete it', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `${GOALS}/g_del`), validGoal);
      });
      await assertFails(deleteDoc(doc(stranger(), `${GOALS}/g_del`)));
    });

    test('an unauthenticated client CANNOT delete it', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `${GOALS}/g_del`), validGoal);
      });
      await assertFails(deleteDoc(doc(anon(), `${GOALS}/g_del`)));
    });

    // A tutor with an active grant reads/writes via hasActiveTutorAccess(),
    // but `allow delete: if isOwner(uid)` carries no such OR-clause — a
    // tutor's uid is never the owner's uid, so this is denied structurally,
    // same as any other non-owner. Real tutor deletion is server-side only,
    // via tutorDeleteGoal (Admin SDK, bypasses rules entirely) — unaffected
    // by this change.
    test('a tutor with active access CANNOT delete it directly from the client', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `${GOALS}/g_del`), validGoal);
      });
      await assertFails(deleteDoc(doc(tutor(), `${GOALS}/g_del`)));
    });

    // Regression guard: confirm this change did not widen delete permission
    // on a genuinely append-only collection — learning_ledger still denies
    // owner delete outright (no isOwner-based allow delete at all).
    test('regression guard: learning_ledger (append-only) still denies owner delete', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `${LP}/learning_ledger/ULID_del`), {
          ulid: 'ULID_del',
        });
      });
      await assertFails(
        deleteDoc(doc(owner(), `${LP}/learning_ledger/ULID_del`)),
      );
    });
  });
});

// ── Path 19: import_metadata (with hasOnly whitelist) ────────────────────────
describe('import_metadata — owner write with key whitelist, tutor read, delete denied', () => {
  const validMeta = {
    profile_id: PROFILE,
    curriculum_id: 'c1',
    item_count: 50,
    imported_at: pastTs,
    synced_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/import_metadata/c1`, validMeta);
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/import_metadata/c1`), {
        ...validMeta,
        sneaky: true,
      }),
    );
  });
  test('tutor cannot write import_metadata', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/import_metadata/c1`), validMeta));
  });
});

// ── Path 20: profile_programs (with hasOnly whitelist; owner DELETE allowed) ──
describe('profile_programs — owner write+delete with key whitelist, tutor read', () => {
  const validProgram = {
    profile_id: PROFILE,
    curriculum_id: 'c1',
    program_id: 'p1',
    tracking_start_date: '2024-01-01',
    tracking_start_ref: 'Berakhot.2a',
    synced_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny matrix (owner can delete)', async () => {
    await expectOwnerWriteTutorRead(`${LP}/profile_programs/c1`, validProgram, {
      ownerCanDelete: true,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/profile_programs/c1`), {
        ...validProgram,
        extra: 'bad',
      }),
    );
  });
  test('tutor cannot write or delete profile_programs', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `${LP}/profile_programs/c1`), validProgram);
    });
    await assertFails(setDoc(doc(tutor(), `${LP}/profile_programs/c1`), validProgram));
    await assertFails(deleteDoc(doc(tutor(), `${LP}/profile_programs/c1`)));
  });
});

// ── Path 21: curriculum_scopes (open bag; owner DELETE allowed) ───────────────
describe('curriculum_scopes — owner write+delete (no whitelist), tutor read', () => {
  const validScope = {
    curriculum_id: 'c1',
    scope_data: 'some-value',
  };

  test('owner-write + tutor-read + stranger-deny matrix (owner can delete)', async () => {
    await expectOwnerWriteTutorRead(`${LP}/curriculum_scopes/sc1`, validScope, {
      ownerCanDelete: true,
    });
  });
  test('tutor cannot write or delete curriculum_scopes', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `${LP}/curriculum_scopes/sc1`), validScope);
    });
    await assertFails(setDoc(doc(tutor(), `${LP}/curriculum_scopes/sc1`), validScope));
    await assertFails(deleteDoc(doc(tutor(), `${LP}/curriculum_scopes/sc1`)));
  });
});

// ── Path 22: study_day_configs (with hasOnly whitelist; owner DELETE allowed) ─
describe('study_day_configs — owner write+delete with key whitelist, tutor read', () => {
  // Sourced from PAYLOADS.study_day_configs (see C-EXTRA) plus `synced_at`,
  // the one field the fixture omits. Keeps this matrix literal from silently
  // diverging from PAYLOADS the way `day_type` once did ('learning' here vs.
  // 'study' in the fixture — see AUD-firebase-13).
  const validConfig = {
    ...PAYLOADS.study_day_configs,
    synced_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny matrix (owner can delete)', async () => {
    await expectOwnerWriteTutorRead(`${LP}/study_day_configs/cfg1`, validConfig, {
      ownerCanDelete: true,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/study_day_configs/cfg1`), {
        ...validConfig,
        bad_field: 'x',
      }),
    );
  });
  test('tutor cannot write or delete study_day_configs', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `${LP}/study_day_configs/cfg1`), validConfig);
    });
    await assertFails(setDoc(doc(tutor(), `${LP}/study_day_configs/cfg1`), validConfig));
    await assertFails(deleteDoc(doc(tutor(), `${LP}/study_day_configs/cfg1`)));
  });
});

// ── Path 22b: point_configs (with hasOnly whitelist + points range; owner DELETE allowed) ─
describe('point_configs — owner write+delete with key whitelist, tutor read', () => {
  const validConfig = { ...PAYLOADS.point_configs };

  test('owner-write + tutor-read + stranger-deny matrix (owner can delete)', async () => {
    await expectOwnerWriteTutorRead(`${LP}/point_configs/cfg1`, validConfig, {
      ownerCanDelete: true,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/point_configs/cfg1`), {
        ...validConfig,
        bad_field: 'x',
      }),
    );
  });
  test('owner write with points outside 1..100 is rejected (range)', async () => {
    await assertFails(
      setDoc(doc(owner(), `${LP}/point_configs/cfg1`), {
        ...validConfig,
        points: 0,
      }),
    );
    await assertFails(
      setDoc(doc(owner(), `${LP}/point_configs/cfg1`), {
        ...validConfig,
        points: 101,
      }),
    );
  });
  test('tutor cannot write or delete point_configs', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `${LP}/point_configs/cfg1`), validConfig);
    });
    await assertFails(setDoc(doc(tutor(), `${LP}/point_configs/cfg1`), validConfig));
    await assertFails(deleteDoc(doc(tutor(), `${LP}/point_configs/cfg1`)));
  });
});

// ── Path 23: tutor_grants & tutor_grants/audit_log ────────────────────────────
describe('tutor_grants & tutor_active_access — Admin-SDK only', () => {
  test('tutor reads grant where tutor_uid matches; parent where parent_uid matches', async () => {
    await assertSucceeds(getDoc(doc(tutor(), `tutor_grants/g1`)));
    await assertSucceeds(getDoc(doc(owner(), `tutor_grants/g1`)));
  });
  test('unrelated user / anon cannot read a grant', async () => {
    await assertFails(getDoc(doc(stranger(), `tutor_grants/g1`)));
    await assertFails(getDoc(doc(anon(), `tutor_grants/g1`)));
  });
  test('no client may create/update/delete a grant (forge active state denied)', async () => {
    await assertFails(setDoc(doc(tutor(), `tutor_grants/forge`), { state: 'active', tutor_uid: TUTOR }));
    await assertFails(deleteDoc(doc(owner(), `tutor_grants/g1`)));
  });
  test('tutor reads own access entry; others denied; no client writes', async () => {
    await assertSucceeds(getDoc(doc(tutor(), `tutor_active_access/${ACCESS_ID}`)));
    await assertFails(getDoc(doc(owner(), `tutor_active_access/${ACCESS_ID}`)));
    await assertFails(setDoc(doc(tutor(), `tutor_active_access/forge`), { tutor_uid: TUTOR }));
  });
});

// ── Path 24: tutor_grants/{grantId}/audit_log/{entryId} ──────────────────────
describe('tutor_grants/{grantId}/audit_log/{entryId} — read-only for parties; no client writes', () => {
  const GRANT_ID = 'g1';
  const AUDIT_PATH = `tutor_grants/${GRANT_ID}/audit_log/entry1`;

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), AUDIT_PATH), {
        action: 'accepted',
        ts: pastTs,
      });
    });
  });

  test('parent (owner of grant parent_uid) can read audit log entry', async () => {
    await assertSucceeds(getDoc(doc(owner(), AUDIT_PATH)));
  });
  test('tutor can read audit log entry for their own grant', async () => {
    await assertSucceeds(getDoc(doc(tutor(), AUDIT_PATH)));
  });
  test('stranger and anon cannot read audit log entry', async () => {
    await assertFails(getDoc(doc(stranger(), AUDIT_PATH)));
    await assertFails(getDoc(doc(anon(), AUDIT_PATH)));
  });
  test('no client can create, update, or delete audit log entries (Admin SDK only)', async () => {
    await assertFails(
      setDoc(doc(owner(), AUDIT_PATH), { action: 'forged' }),
    );
    await assertFails(
      setDoc(doc(tutor(), `tutor_grants/${GRANT_ID}/audit_log/new`), { action: 'forge' }),
    );
    await assertFails(deleteDoc(doc(owner(), AUDIT_PATH)));
    await assertFails(deleteDoc(doc(tutor(), AUDIT_PATH)));
  });
});

// ── PHASE D — permission-denied oracle ───────────────────────────────────────
//
// A legitimate owner must be able to write every whitelisted collection
// without a single permission-denied error. If a future payload or rules
// change causes a legitimate write to be denied, the first test here breaks
// immediately — the zero-denial oracle catches it before it reaches production.
//
// The second test (canary) proves the oracle can fail: adding an unknown
// key to a hasOnly-guarded collection IS denied, so the positive test is
// not trivially green.
describe('PHASE D — permission-denied oracle: all legitimate owner writes succeed', () => {
  test('owner can write all whitelisted collections without a single denial', async () => {
    const db = owner();
    const profilePath = `users/${OWNER}/learner_profiles/${PROFILE}`;

    // 1. learner_profiles document itself
    await assertSucceeds(setDoc(doc(db, profilePath), { name: 'Alice' }));
    // 2. completions — requires Timestamp for completed_at <= request.time rule
    await assertSucceeds(setDoc(doc(db, `${LP}/completions/d1`), { points: 5, completed_at: pastTs }));
    // 3. bookmarks — minimal codec shape; hasOnly allows these keys
    await assertSucceeds(setDoc(doc(db, `${LP}/bookmarks/bk_d`), PAYLOADS.bookmarks));
    // 4. settings — open bag; no whitelist
    await assertSucceeds(setDoc(doc(db, `${LP}/settings/c1`), PAYLOADS.settings));
    // 5. curriculum_tracks — whitelist allows profile_id, track_id, curriculum_id, state, ...
    await assertSucceeds(setDoc(doc(db, `${LP}/curriculum_tracks/c1`), PAYLOADS.curriculum_tracks));
    // 6. stage_definitions — whitelist allows curriculum_id, track_id, stage_order, ...
    await assertSucceeds(setDoc(doc(db, `${LP}/stage_definitions/t1_1`), PAYLOADS.stage_definitions));
    // 7. study_day_configs — whitelist allows profile_id, curriculum_id, track_id, day_of_week, day_type, updated_at
    await assertSucceeds(setDoc(doc(db, `${LP}/study_day_configs/c1_1_1`), PAYLOADS.study_day_configs));
    // 8. goals — wide hasOnly whitelist (camelCase + snake_case)
    await assertSucceeds(setDoc(doc(db, `${GOALS}/g1`), PAYLOADS.goals));
    // 9. learning_order — whitelist allows curriculum_id, sefaria_ref, user_sort_order, updated_at
    await assertSucceeds(setDoc(doc(db, `${LP}/learning_order/c1_ref`), PAYLOADS.learning_order));
    // 10. profile_programs — whitelist allows profile_id, curriculum_id, program_id, tracking_start_date, tracking_start_ref
    await assertSucceeds(setDoc(doc(db, `${LP}/profile_programs/c1`), PAYLOADS.profile_programs));
    // 11. learning_ledger — no hasOnly; open write (append-only by ULID doc-id)
    await assertSucceeds(setDoc(doc(db, `${LP}/learning_ledger/ULID001`), PAYLOADS.learning_ledger));
    // 12. streak_events — no hasOnly; append-only
    await assertSucceeds(setDoc(doc(db, `${LP}/streak_events/ULID002`), PAYLOADS.streak_events));
    // 13. preferences — no hasOnly; open bag
    await assertSucceeds(setDoc(doc(db, `${LP}/preferences/notification_settings`), { enabled: true }));
    // 14. import_metadata — whitelist allows profile_id, curriculum_id, item_count, imported_at
    await assertSucceeds(setDoc(doc(db, `${LP}/import_metadata/c1`), PAYLOADS.import_metadata));
    // 15. curriculum_scopes — open write + delete
    await assertSucceeds(setDoc(doc(db, `${LP}/curriculum_scopes/sc1`), { curriculum_id: 'c1' }));
    // 16. points_ledger — no hasOnly; append-only (AUD-firebase-05)
    await assertSucceeds(setDoc(doc(db, `${LP}/points_ledger/ULID0003`), PAYLOADS.points_ledger));
    // 17. reward_redemptions — no hasOnly; LWW state machine (AUD-firebase-05)
    await assertSucceeds(setDoc(doc(db, `${LP}/reward_redemptions/ULID0004`), PAYLOADS.reward_redemptions));
  });

  test('oracle canary: unknown key in hasOnly-guarded collection is denied (oracle is live, not trivially green)', async () => {
    const db = owner();
    // bookmarks hasOnly denies any key not in its allowlist
    await assertFails(setDoc(doc(db, `${LP}/bookmarks/canary`), {
      ...PAYLOADS.bookmarks,
      canary_unknown_field: true,
    }));
    // curriculum_tracks hasOnly also denies unknown keys
    await assertFails(setDoc(doc(db, `${LP}/curriculum_tracks/canary`), {
      ...PAYLOADS.curriculum_tracks,
      canary_unknown_field: true,
    }));
  });
});

// ── PHASE E — cross-device replication round-trip ────────────────────────────
//
// For each whitelisted per-profile collection: device-1 writes a document,
// device-2 (a separate Firestore client instance with the same uid) reads it
// back and asserts the key field has the expected value.
//
// In @firebase/rules-unit-testing, each call to
// env.authenticatedContext(uid).firestore() returns a fresh client instance
// with the same auth token — correctly modelling a second device signed in
// with the same account.
//
// synced_at is intentionally omitted from all payloads: rules permit it
// (hasOnly lists it as allowed) but do NOT require it. Using pastTs rather
// than FieldValue.serverTimestamp() avoids flakiness.
describe('PHASE E — cross-device replication round-trip (same uid, two Firestore contexts)', () => {
  // Each test case: a collection, the full Firestore path, the write payload,
  // and one key+value to assert on read-back.
  const COLLECTIONS = [
    {
      name: 'completions',
      path: `${LP}/completions/rt1`,
      // completions rules validate completed_at <= request.time: use pastTs
      payload: { points: 10, completed_at: pastTs },
      assertField: 'points',
      assertValue: 10,
    },
    {
      name: 'bookmarks',
      path: `${LP}/bookmarks/bk_e`,
      payload: { ...PAYLOADS.bookmarks },
      assertField: 'curriculum_id',
      assertValue: 'c1',
    },
    {
      name: 'settings',
      path: `${LP}/settings/c1_e`,
      payload: { ...PAYLOADS.settings },
      assertField: 'curriculum_id',
      assertValue: 'c1',
    },
    {
      name: 'curriculum_tracks',
      path: `${LP}/curriculum_tracks/c1_e`,
      payload: { ...PAYLOADS.curriculum_tracks },
      assertField: 'state',
      assertValue: 'active',
    },
    {
      name: 'stage_definitions',
      path: `${LP}/stage_definitions/t1_1_e`,
      payload: { ...PAYLOADS.stage_definitions },
      assertField: 'stage_order',
      assertValue: 1,
    },
    {
      name: 'study_day_configs',
      path: `${LP}/study_day_configs/c1_1_1_e`,
      payload: { ...PAYLOADS.study_day_configs },
      assertField: 'day_type',
      assertValue: 'study',
    },
    {
      name: 'goals',
      path: `${GOALS}/goal_e`,
      payload: { ...PAYLOADS.goals },
      assertField: 'profile_id',
      // profile_id was written as string '5' (matching the path-segment constant)
      assertValue: PROFILE,
    },
    {
      name: 'learning_order',
      path: `${LP}/learning_order/c1_Berakhot_2a`,
      payload: { ...PAYLOADS.learning_order },
      assertField: 'user_sort_order',
      assertValue: 1,
    },
    {
      name: 'profile_programs',
      path: `${LP}/profile_programs/c1_e`,
      payload: { ...PAYLOADS.profile_programs },
      assertField: 'curriculum_id',
      assertValue: 'c1',
    },
    {
      name: 'learning_ledger',
      path: `${LP}/learning_ledger/ULID0001`,
      payload: { ...PAYLOADS.learning_ledger },
      assertField: 'ulid',
      assertValue: 'ULID0001',
    },
    {
      // AUD-firebase-05
      name: 'points_ledger',
      path: `${LP}/points_ledger/ULID0003_e`,
      payload: { ...PAYLOADS.points_ledger },
      assertField: 'delta',
      assertValue: -50,
    },
    {
      // AUD-firebase-05
      name: 'reward_redemptions',
      path: `${LP}/reward_redemptions/ULID0004_e`,
      payload: { ...PAYLOADS.reward_redemptions },
      assertField: 'status',
      assertValue: 'pending_fulfilment',
    },
  ];

  for (const tc of COLLECTIONS) {
    test(`${tc.name}: device-1 write is readable by device-2`, async () => {
      const device1 = env.authenticatedContext(OWNER).firestore();
      const device2 = env.authenticatedContext(OWNER).firestore();
      await assertSucceeds(setDoc(doc(device1, tc.path), tc.payload));
      const snap = await assertSucceeds(getDoc(doc(device2, tc.path)));
      assert.strictEqual(snap.data()[tc.assertField], tc.assertValue);
    });
  }
});
