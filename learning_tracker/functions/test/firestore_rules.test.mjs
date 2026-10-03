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
  deleteField,
  collection,
  query,
  limit,
  Timestamp,
  setLogLevel,
  writeBatch,
  where,
} from 'firebase/firestore';
import { retiredKeysOf } from './_retired_inventory.mjs';

// The retired R16 keys of the goal and curriculum-track codecs, read from the
// AD-49 inventory (DNI-489) so no test spells a retired name.
const GOAL_REPOSITORY = 'lib/data/repositories/firestore_goal_repository.dart';
const TRACK_REPOSITORY = 'lib/data/repositories/firestore_curriculum_track_repository.dart';

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

// ── DNI-471: AD-38 governed-write fixtures (shared by the legacy governed
// collection blocks below and the sub-tracks feature blocks at the end) ──────
//
// Deterministic Crockford-base32 ULIDs (26 chars, the shape lib/core/time/
// ulid.dart mints and firestore.rules' isUlid() accepts).
let _ulidSeq = 0;
function nextUlid() {
  _ulidSeq += 1;
  return `01J9ZZ${String(_ulidSeq).padStart(20, '0')}`;
}

// The client-asserted actor every owner write carries (AD-46).
const OWNER_ACTOR = { uid: OWNER, role: 'parent', display_name: 'Abba' };

// A canonical AD-52 change_log entry for one governed entity.
function changeEntry(entity, entityId, changeId, overrides = {}) {
  return {
    entity,
    entity_id: entityId,
    action_id: changeId,
    before: {},
    after: {},
    at: pastTs,
    actor: OWNER_ACTOR,
    ...overrides,
  };
}

// The AD-38 owner write: one field-level merge of the governed doc stamped
// with a fresh `last_change_id`, plus that id's change_log entry, in ONE
// batch. Options let negative tests break exactly one branch of the rule.
function governedWrite(db, path, data, entity, entityId, {
  changeId = nextUlid(),
  entry = {},
  withEntry = true,
} = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, path), { ...data, last_change_id: changeId }, { merge: true });
  if (withEntry) {
    batch.set(
      doc(db, `${LP}/change_log/${changeId}`),
      changeEntry(entity, entityId, changeId, entry),
    );
  }
  return batch.commit();
}

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
  // DNI-471: `{ entity, entityId }` for an AD-38 governed collection — the
  // owner write then goes through governedWrite() (doc + change_log entry in
  // one batch), the only owner write path the rules accept for it.
  governed = null,
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
  if (governed) {
    await assertSucceeds(
      governedWrite(db_owner, path, validDoc, governed.entity, governed.entityId),
    );
    // A governed doc never accepts a plain (change-log-less) value change.
    await assertFails(setDoc(doc(db_owner, path), { ...validDoc, last_change_id: nextUlid() }));
  } else {
    await assertSucceeds(setDoc(doc(db_owner, path), validDoc));
  }

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
// DNI-471: governed entity `mainTrackStages` (AD-38) — owner writes carry a
// same-batch change_log entry whose entity_id is the doc's curriculum_id.
describe('stage_definitions — owner write with key whitelist, tutor read, delete denied', () => {
  const GOV = { entity: 'mainTrackStages', entityId: 'c1' };
  // Sourced from PAYLOADS.stage_definitions (the codec-derived single source
  // of truth — see C-EXTRA) with only the whitelist-only legacy fields the
  // current codec no longer emits (profile_id/delay_days/days_of_week/
  // rolling_window_size) layered on top (R16, DNI-484: synced_at is retired). Keeps this matrix literal
  // from silently diverging from PAYLOADS the way `track_id` once did
  // (string 't1' here vs. numeric 1 in the fixture — see AUD-firebase-13).
  const validStage = {
    ...PAYLOADS.stage_definitions,
    profile_id: PROFILE,
    delay_days: 0,
    days_of_week: [1, 2, 3],
    rolling_window_size: 7,
  };

  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/stage_definitions/t1_1`, validStage, {
      governed: GOV,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      governedWrite(owner(), `${LP}/stage_definitions/t1_1`, {
        ...validStage,
        hacker_field: true,
      }, GOV.entity, GOV.entityId),
    );
  });
  test('tutor cannot write stage_definitions', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/stage_definitions/t1_1`), validStage));
  });
});

// ── Path 14: curriculum_tracks (with hasOnly whitelist) ──────────────────────
// DNI-471: governed entity `mainTrack` (AD-38).
describe('curriculum_tracks — owner write with key whitelist, tutor read, delete denied', () => {
  const GOV = { entity: 'mainTrack', entityId: 'c1' };
  const validTrack = {
    profile_id: PROFILE,
    track_id: 't1',
    curriculum_id: 'c1',
    state: 'active',
    activated_at: pastTs,
  };

  test('owner-write + tutor-read + stranger-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/curriculum_tracks/t1`, validTrack, {
      governed: GOV,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      governedWrite(owner(), `${LP}/curriculum_tracks/t1`, {
        ...validTrack,
        extra_field: 'bad',
      }, GOV.entity, GOV.entityId),
    );
  });
  test('tutor cannot write curriculum_tracks', async () => {
    await assertFails(setDoc(doc(tutor(), `${LP}/curriculum_tracks/t1`), validTrack));
  });
  // R16 (DNI-484): the old reorder-amnesty baseline is
  // retired with the other legacy track fields — see the DNI-484 block.
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
// DNI-471: governed entity `mainTrackOrder` (AD-38).
describe('track_learning_order — owner write with key whitelist, tutor read, delete denied, SR-4 cap', () => {
  const GOV = { entity: 'mainTrackOrder', entityId: 'c1' };
  const validTrackOrder = {
    curriculum_id: 'c1',
    sefaria_ref: 'Berakhot.2a',
    user_sort_order: 1,
  };

  test('owner-write + tutor-read + stranger-deny + unauthenticated-deny matrix', async () => {
    await expectOwnerWriteTutorRead(`${LP}/track_learning_order/o1`, validTrackOrder, {
      governed: GOV,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      governedWrite(owner(), `${LP}/track_learning_order/o1`, {
        ...validTrackOrder,
        bad_field: 99,
      }, GOV.entity, GOV.entityId),
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
      governedWrite(db, `${LP}/track_learning_order/independence_check`, validTrackOrder,
        GOV.entity, GOV.entityId),
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
// DNI-471: governed entity `goal` (AD-38) — entity_id is the doc id; owner
// delete is now DENIED (removal is an `ended_at` tombstone, AD-38).
describe('goals — owner write with key whitelist (AD-38 governed), tutor read-only, delete denied', () => {
  test('owner writes goal with whitelisted keys', async () => {
    await assertSucceeds(
      governedWrite(owner(), `${GOALS}/g`, {
        goal_id: 'g', profile_id: PROFILE, goal_type: 'deadline',
      }, 'goal', 'g'),
    );
  });
  test('owner write with an unknown key is denied', async () => {
    await assertFails(
      governedWrite(owner(), `${GOALS}/g2`, { goal_id: 'g2', hacker_field: true }, 'goal', 'g2'),
    );
  });
  test('tutor can read goals but not write them', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `${GOALS}/seed`), { goal_id: 'seed' });
    });
    await assertSucceeds(getDoc(doc(tutor(), `${GOALS}/seed`)));
    await assertFails(setDoc(doc(tutor(), `${GOALS}/seed`), { goal_id: 'seed' }));
  });

  // Goal deletion: AD-38 denies every client delete of a governed doc —
  // removal is an `ended_at` tombstone co-written with its change_log entry
  // (the earlier owner-delete allowance is superseded). Tutor removal is
  // server-side via writeWithChangeLog (story 1.10).
  describe('client delete (denied for everyone, AD-38)', () => {
    const validGoal = { goal_id: 'g_del', profile_id: PROFILE, goal_type: 'deadline' };

    test('owner CANNOT delete their own goal; tombstoning via the owner rule works', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `${GOALS}/g_del`), validGoal);
      });
      await assertFails(deleteDoc(doc(owner(), `${GOALS}/g_del`)));
      await assertSucceeds(
        governedWrite(owner(), `${GOALS}/g_del`, { ended_at: pastTs }, 'goal', 'g_del'),
      );
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
// DNI-471: governed entity `mainTrackProgram` (AD-38); owner delete denied.
describe('profile_programs — owner write with key whitelist (AD-38 governed), tutor read, delete denied', () => {
  const GOV = { entity: 'mainTrackProgram', entityId: 'c1' };
  const validProgram = {
    profile_id: PROFILE,
    curriculum_id: 'c1',
    program_id: 'p1',
    tracking_start_date: '2024-01-01',
    tracking_start_ref: 'Berakhot.2a',
  };

  test('owner-write + tutor-read + stranger-deny matrix (owner delete denied)', async () => {
    await expectOwnerWriteTutorRead(`${LP}/profile_programs/c1`, validProgram, {
      governed: GOV,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      governedWrite(owner(), `${LP}/profile_programs/c1`, {
        ...validProgram,
        extra: 'bad',
      }, GOV.entity, GOV.entityId),
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
// DNI-471: governed entity `mainTrackScope` (AD-38); owner delete denied.
describe('curriculum_scopes — owner write (no whitelist, AD-38 governed), tutor read, delete denied', () => {
  const validScope = {
    curriculum_id: 'c1',
    scope_data: 'some-value',
  };

  test('owner-write + tutor-read + stranger-deny matrix (owner delete denied)', async () => {
    await expectOwnerWriteTutorRead(`${LP}/curriculum_scopes/sc1`, validScope, {
      governed: { entity: 'mainTrackScope', entityId: 'c1' },
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
// DNI-471: governed entity `mainTrackStudyDays` (AD-38); owner delete denied.
describe('study_day_configs — owner write with key whitelist (AD-38 governed), tutor read, delete denied', () => {
  const GOV = { entity: 'mainTrackStudyDays', entityId: 'c1' };
  // Sourced from PAYLOADS.study_day_configs (see C-EXTRA). Keeps this matrix
  // literal from silently diverging from PAYLOADS the way `day_type` once did
  // ('learning' here vs. 'study' in the fixture — see AUD-firebase-13).
  // R16 (DNI-484): the governed synced_at is retired.
  const validConfig = {
    ...PAYLOADS.study_day_configs,
  };

  test('owner-write + tutor-read + stranger-deny matrix (owner delete denied)', async () => {
    await expectOwnerWriteTutorRead(`${LP}/study_day_configs/cfg1`, validConfig, {
      governed: GOV,
    });
  });
  test('owner write with unknown field is rejected (whitelist)', async () => {
    await assertFails(
      governedWrite(owner(), `${LP}/study_day_configs/cfg1`, {
        ...validConfig,
        bad_field: 'x',
      }, GOV.entity, GOV.entityId),
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
    // 5–8, 10, 15: AD-38 governed collections (DNI-471) — the legitimate
    // owner write is the doc + its change_log entry in one batch.
    // 5. curriculum_tracks — whitelist allows profile_id, track_id, curriculum_id, state, ...
    await assertSucceeds(governedWrite(db, `${LP}/curriculum_tracks/c1`, PAYLOADS.curriculum_tracks, 'mainTrack', 'c1'));
    // 6. stage_definitions — whitelist allows curriculum_id, track_id, stage_order, ...
    await assertSucceeds(governedWrite(db, `${LP}/stage_definitions/t1_1`, PAYLOADS.stage_definitions, 'mainTrackStages', 'c1'));
    // 7. study_day_configs — whitelist allows profile_id, curriculum_id, track_id, day_of_week, day_type, updated_at
    await assertSucceeds(governedWrite(db, `${LP}/study_day_configs/c1_1_1`, PAYLOADS.study_day_configs, 'mainTrackStudyDays', 'c1'));
    // 8. goals — wide hasOnly whitelist (camelCase + snake_case)
    await assertSucceeds(governedWrite(db, `${GOALS}/g1`, PAYLOADS.goals, 'goal', 'g1'));
    // 9. learning_order — whitelist allows curriculum_id, sefaria_ref, user_sort_order, updated_at
    await assertSucceeds(setDoc(doc(db, `${LP}/learning_order/c1_ref`), PAYLOADS.learning_order));
    // 10. profile_programs — whitelist allows profile_id, curriculum_id, program_id, tracking_start_date, tracking_start_ref
    await assertSucceeds(governedWrite(db, `${LP}/profile_programs/c1`, PAYLOADS.profile_programs, 'mainTrackProgram', 'c1'));
    // 11. learning_ledger — no hasOnly; open write (append-only by ULID doc-id)
    await assertSucceeds(setDoc(doc(db, `${LP}/learning_ledger/ULID001`), PAYLOADS.learning_ledger));
    // 12. streak_events — no hasOnly; append-only
    await assertSucceeds(setDoc(doc(db, `${LP}/streak_events/ULID002`), PAYLOADS.streak_events));
    // 13. preferences — no hasOnly; open bag
    await assertSucceeds(setDoc(doc(db, `${LP}/preferences/notification_settings`), { enabled: true }));
    // 14. import_metadata — whitelist allows profile_id, curriculum_id, item_count, imported_at
    await assertSucceeds(setDoc(doc(db, `${LP}/import_metadata/c1`), PAYLOADS.import_metadata));
    // 15. curriculum_scopes — open bag, AD-38 governed
    await assertSucceeds(governedWrite(db, `${LP}/curriculum_scopes/sc1`, { curriculum_id: 'c1' }, 'mainTrackScope', 'c1'));
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
    // curriculum_tracks hasOnly also denies unknown keys (even on a
    // otherwise-legitimate AD-38 governed write)
    await assertFails(governedWrite(db, `${LP}/curriculum_tracks/canary`, {
      ...PAYLOADS.curriculum_tracks,
      canary_unknown_field: true,
    }, 'mainTrack', 'c1'));
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
      governed: { entity: 'mainTrack', entityId: 'c1' },
      path: `${LP}/curriculum_tracks/c1_e`,
      payload: { ...PAYLOADS.curriculum_tracks },
      assertField: 'state',
      assertValue: 'active',
    },
    {
      name: 'stage_definitions',
      governed: { entity: 'mainTrackStages', entityId: 'c1' },
      path: `${LP}/stage_definitions/t1_1_e`,
      payload: { ...PAYLOADS.stage_definitions },
      assertField: 'stage_order',
      assertValue: 1,
    },
    {
      name: 'study_day_configs',
      governed: { entity: 'mainTrackStudyDays', entityId: 'c1' },
      path: `${LP}/study_day_configs/c1_1_1_e`,
      payload: { ...PAYLOADS.study_day_configs },
      assertField: 'day_type',
      assertValue: 'study',
    },
    {
      name: 'goals',
      governed: { entity: 'goal', entityId: 'goal_e' },
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
      governed: { entity: 'mainTrackProgram', entityId: 'c1' },
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
      await assertSucceeds(
        tc.governed
          ? governedWrite(device1, tc.path, tc.payload, tc.governed.entity, tc.governed.entityId)
          : setDoc(doc(device1, tc.path), tc.payload),
      );
      const snap = await assertSucceeds(getDoc(doc(device2, tc.path)));
      assert.strictEqual(snap.data()[tc.assertField], tc.assertValue);
    });
  }
});

// ════════════════════════════════════════════════════════════════════════════
// DNI-471 (story 1.9) — sub-tracks feature rules: learning_events,
// change_log, sub_tracks, AD-38 owner rule, pts_ binding, AD-54 skew and
// access-call budget. Later stories add their own describe blocks below.
// ════════════════════════════════════════════════════════════════════════════

const EVENTS = `${LP}/learning_events`;
const CHANGE_LOG = `${LP}/change_log`;
const SUB_TRACKS = `${LP}/sub_tracks`;
const POINTS = `${LP}/points_ledger`;
const TEN_MIN_MS = 10 * 60 * 1000;

// Canonical AD-52 payloads.
function learnEvent(overrides = {}) {
  return {
    kind: 'learn',
    curriculum_id: 'c1',
    ref: 'Berakhot.2a',
    source: 'main',
    date_state: 'dated',
    learned_on: '2019-12-31',
    stage: 1,
    recorded_at: pastTs,
    actor: OWNER_ACTOR,
    ...overrides,
  };
}

function voidEvent(targetId, overrides = {}) {
  return {
    kind: 'void',
    target_id: targetId,
    recorded_at: pastTs,
    actor: OWNER_ACTOR,
    ...overrides,
  };
}

function subTrack(overrides = {}) {
  return {
    curriculum_id: 'c1',
    name: 'Shiur Gemara',
    type: 'school_year',
    academic_year: 2026,
    window_start: '2026-09-01',
    window_end: '2027-06-30',
    rate_per_week: 4,
    weeks_per_year: 36,
    learns_on_shabbos: false,
    ground: [{ level: 'masechta', ref: 'Berakhot' }],
    ...overrides,
  };
}

function withoutKey(obj, key) {
  const { [key]: _omitted, ...rest } = obj;
  return rest;
}

// Writes a sub-track through the AD-38 owner rule; returns the change id.
async function writeSubTrack(db, id, data = subTrack(), opts = {}) {
  const changeId = opts.changeId ?? nextUlid();
  await governedWrite(db, `${SUB_TRACKS}/${id}`, data, 'subTrack', id, { ...opts, changeId });
  return changeId;
}

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

// ── AC-1: learning_events ─────────────────────────────────────────────────
describe('DNI-471 AC-1 — learning_events are append-only owner events', () => {
  test('owner creates each valid learn shape and a void; identical replay succeeds', async () => {
    const db = owner();
    const learnId = nextUlid();
    await assertSucceeds(setDoc(doc(db, `${EVENTS}/${learnId}`), learnEvent()));
    await assertSucceeds(setDoc(doc(db, `${EVENTS}/${nextUlid()}`), learnEvent({
      date_state: 'catch_up', source: nextUlid(), stage: null,
    })));
    await assertSucceeds(setDoc(doc(db, `${EVENTS}/${nextUlid()}`), learnEvent({
      date_state: 'before_tracking', learned_on: '2019-05-01', ref: 'Berakhot',
      level: 'masechta', stage: null, original_recorded_at: pastTs,
    })));
    await assertSucceeds(setDoc(doc(db, `${EVENTS}/${nextUlid()}`), learnEvent({
      date_state: 'before_tracking', learned_on: null, ref: 'Shabbat',
      level: 'masechta', stage: 0,
    })));
    await assertSucceeds(setDoc(doc(db, `${EVENTS}/${nextUlid()}`), voidEvent(learnId, {
      reverts_action_id: learnId,
    })));
    await assertSucceeds(setDoc(doc(db, `${EVENTS}/${nextUlid()}`), voidEvent(learnId, {
      original_recorded_at: pastTs,
    })));
    // SR-1 identical replay (outbox retry of a committed-but-unacked write).
    await assertSucceeds(setDoc(doc(db, `${EVENTS}/${learnId}`), learnEvent()));
  });

  test('altered replay, update and delete are denied', async () => {
    const id = nextUlid();
    await seed(`${EVENTS}/${id}`, learnEvent());
    await assertFails(setDoc(doc(owner(), `${EVENTS}/${id}`), learnEvent({ ref: 'Berakhot.2b' })));
    await assertFails(setDoc(doc(owner(), `${EVENTS}/${id}`), { ref: 'Berakhot.9a' }, { merge: true }));
    await assertFails(deleteDoc(doc(owner(), `${EVENTS}/${id}`)));
  });

  test('anonymous, stranger and tutor clients cannot create; tutor-role and foreign actors are denied', async () => {
    const path = `${EVENTS}/${nextUlid()}`;
    await assertFails(setDoc(doc(anon(), path), learnEvent()));
    await assertFails(setDoc(doc(stranger(), path), learnEvent({
      actor: { uid: STRANGER, role: 'parent' },
    })));
    await assertFails(setDoc(doc(tutor(), path), learnEvent({
      actor: { uid: TUTOR, role: 'tutor', display_name: 'Rebbe' },
    })));
    // The owner cannot assert the tutor role (Admin-SDK-only).
    await assertFails(setDoc(doc(owner(), path), learnEvent({
      actor: { ...OWNER_ACTOR, role: 'tutor' },
    })));
    // The owner cannot attribute an event to someone else.
    await assertFails(setDoc(doc(owner(), path), learnEvent({
      actor: { ...OWNER_ACTOR, uid: STRANGER },
    })));
    // Malformed actor maps.
    await assertFails(setDoc(doc(owner(), path), learnEvent({ actor: 'owner-uid' })));
    await assertFails(setDoc(doc(owner(), path), learnEvent({
      actor: { ...OWNER_ACTOR, extra: true },
    })));
    await assertFails(setDoc(doc(owner(), path), learnEvent({ actor: { uid: OWNER } })));
    // A child-role owner actor is accepted.
    await assertSucceeds(setDoc(doc(owner(), path), learnEvent({
      actor: { uid: OWNER, role: 'child', display_name: 'Moishy' },
    })));
  });

  test('malformed and extra fields, invalid enums, dates and void targets are denied', async () => {
    const db = owner();
    const bad = async (data, id = nextUlid()) =>
      assertFails(setDoc(doc(db, `${EVENTS}/${id}`), data));
    await bad(learnEvent({ hacker_field: true }));
    await bad(learnEvent(), 'not-a-ulid');
    await bad(learnEvent(), `01j9zz${'0'.repeat(20)}`); // lower-case is not a ULID
    await bad(learnEvent({ kind: 'unlearn' }));
    await bad(learnEvent({ date_state: 'someday' }));
    await bad(learnEvent({ learned_on: '2019-5-1' }));
    await bad(learnEvent({ learned_on: 20190501 }));
    await bad(learnEvent({ source: 'sub-track-1' }));
    await bad(learnEvent({ stage: 2, source: nextUlid() })); // stage is main-only
    await bad(learnEvent({ stage: '2' }));
    await bad(learnEvent({ ref: '' }));
    await bad(learnEvent({ level: [] }));
    await bad(learnEvent({ date_state: 'before_tracking', level: 3 })); // level is a string
    await bad(learnEvent({ level: 'masechta' })); // level only on before_tracking
    await bad(learnEvent({ learned_on: null })); // null only on before_tracking
    await bad(learnEvent({ learned_on: null, date_state: 'catch_up' }));
    await bad(learnEvent({ stage: -1 }));
    await bad(learnEvent({ reverts_action_id: 'nope' }));
    await bad(learnEvent({ reverts_action_id: nextUlid() })); // void-only
    await bad(learnEvent({ original_recorded_at: '2020-01-01' }));
    await bad(withoutKey(learnEvent(), 'curriculum_id'));
    await bad(withoutKey(learnEvent(), 'learned_on')); // required on learn (null allowed)
    await bad(withoutKey(learnEvent(), 'recorded_at'));
    await bad(withoutKey(learnEvent(), 'actor'));
    // target_id present iff kind == void.
    await bad(learnEvent({ target_id: nextUlid() }));
    await bad(withoutKey(voidEvent(nextUlid()), 'target_id'));
    await bad(voidEvent('not-a-ulid'));
    await bad(voidEvent(nextUlid(), { reverts_action_id: 'nope' }));
    await bad(withoutKey(voidEvent(nextUlid()), 'recorded_at'));
    // A void carries no learn-only key, valid or not (AD-52 / codec parity):
    // the server must never accept a void the client decoder rejects.
    await bad(voidEvent(nextUlid(), { date_state: 'someday' }));
    await bad(voidEvent(nextUlid(), { date_state: 'dated' }));
    await bad(voidEvent(nextUlid(), { curriculum_id: 42 }));
    await bad(voidEvent(nextUlid(), { curriculum_id: 'c1' }));
    await bad(voidEvent(nextUlid(), { ref: 'Berakhot.2a' }));
    await bad(voidEvent(nextUlid(), { level: 'masechta' }));
    await bad(voidEvent(nextUlid(), { source: 'xx' }));
    await bad(voidEvent(nextUlid(), { learned_on: null }));
    await bad(voidEvent(nextUlid(), { stage: 's' }));
    await bad(voidEvent(nextUlid(), {
      date_state: 'garbage', curriculum_id: 42, source: 'xx', stage: 's',
    }));
  });

  test('tutor with active access can read; list is capped at 500', async () => {
    const id = nextUlid();
    await seed(`${EVENTS}/${id}`, learnEvent());
    await assertSucceeds(getDoc(doc(tutor(), `${EVENTS}/${id}`)));
    await assertFails(getDoc(doc(stranger(), `${EVENTS}/${id}`)));
    await expectSR4ListLimitCap(EVENTS);
    await assertSucceeds(getDocs(query(collection(tutor(), EVENTS), limit(500))));
    await assertFails(getDocs(collection(tutor(), EVENTS)));
  });
});

// ── AC-1: change_log ──────────────────────────────────────────────────────
describe('DNI-471 AC-1 — change_log entries are append-only owner events', () => {
  test('owner creates an entry for every AD-38 entity; identical replay succeeds', async () => {
    const db = owner();
    for (const entity of [
      'subTrack', 'goal', 'mainTrack', 'mainTrackOrder', 'mainTrackProgram',
      'mainTrackStudyDays', 'mainTrackStages', 'mainTrackScope', 'learnerSettings',
    ]) {
      const id = nextUlid();
      await assertSucceeds(setDoc(doc(db, `${CHANGE_LOG}/${id}`), changeEntry(entity, 'x', id)));
    }
    const id = nextUlid();
    const entry = changeEntry('goal', 'c1_pace', id, {
      reverts_action_id: nextUlid(),
      original_at: pastTs,
      before: { 'goals/c1_pace.pace_value': 2 },
      after: { 'goals/c1_pace.pace_value': 3 },
    });
    await assertSucceeds(setDoc(doc(db, `${CHANGE_LOG}/${id}`), entry));
    await assertSucceeds(setDoc(doc(db, `${CHANGE_LOG}/${id}`), entry));
  });

  test('altered replay, update and delete are denied', async () => {
    const id = nextUlid();
    await seed(`${CHANGE_LOG}/${id}`, changeEntry('goal', 'g', id));
    await assertFails(setDoc(doc(owner(), `${CHANGE_LOG}/${id}`), changeEntry('goal', 'other', id)));
    await assertFails(deleteDoc(doc(owner(), `${CHANGE_LOG}/${id}`)));
  });

  test('anonymous, stranger, tutor client and tutor-role entries are denied', async () => {
    const id = nextUlid();
    const path = `${CHANGE_LOG}/${id}`;
    await assertFails(setDoc(doc(anon(), path), changeEntry('goal', 'g', id)));
    await assertFails(setDoc(doc(stranger(), path), changeEntry('goal', 'g', id, {
      actor: { uid: STRANGER, role: 'parent' },
    })));
    await assertFails(setDoc(doc(tutor(), path), changeEntry('goal', 'g', id, {
      actor: { uid: TUTOR, role: 'tutor' },
    })));
    await assertFails(setDoc(doc(owner(), path), changeEntry('goal', 'g', id, {
      actor: { ...OWNER_ACTOR, role: 'tutor' },
    })));
  });

  test('malformed and extra fields and invalid entities are denied', async () => {
    const db = owner();
    const bad = async (data, id = nextUlid()) =>
      assertFails(setDoc(doc(db, `${CHANGE_LOG}/${id}`), data));
    const id = nextUlid();
    await bad(changeEntry('goal', 'g', id, { hacker_field: 1 }));
    await bad(changeEntry('goal', 'g', id), 'not-a-ulid');
    await bad(changeEntry('bookmark', 'g', id));
    await bad(changeEntry('goal', '', id));
    await bad(changeEntry('goal', 'g', 'not-a-ulid'));
    await bad(changeEntry('goal', 'g', id, { reverts_action_id: 'nope' }));
    await bad(changeEntry('goal', 'g', id, { before: 'x' }));
    await bad(changeEntry('goal', 'g', id, { after: [] }));
    await bad(changeEntry('goal', 'g', id, { original_at: '2020-01-01' }));
    await bad(withoutKey(changeEntry('goal', 'g', id), 'before'));
    await bad(withoutKey(changeEntry('goal', 'g', id), 'at'));
  });

  test('tutor with active access can read; list is capped at 500', async () => {
    const id = nextUlid();
    await seed(`${CHANGE_LOG}/${id}`, changeEntry('goal', 'g', id));
    await assertSucceeds(getDoc(doc(tutor(), `${CHANGE_LOG}/${id}`)));
    await assertFails(getDoc(doc(stranger(), `${CHANGE_LOG}/${id}`)));
    await expectSR4ListLimitCap(CHANGE_LOG);
  });

  test('no document-access calls: the event, change_log and points validators are access-call free', () => {
    // AD-54 budget arithmetic assumes these cost zero; the full-budget batch
    // in AC-5 proves it at runtime, this pins it at source level.
    const rules = readFileSync('firestore.rules', 'utf8');
    for (const fn of [
      'isValidLearningEvent', 'isValidVoidEvent', 'isValidLearnEvent',
      'isValidChangeLogEntry', 'isValidPointsEntry', 'isOwnerActor',
      'isClientTime', 'isUlid', 'isIdenticalReplay', 'isValidSubTrack',
    ]) {
      const start = rules.indexOf(`function ${fn}(`);
      assert.ok(start >= 0, `${fn} must exist in firestore.rules`);
      const body = rules.slice(start, rules.indexOf('\n    }\n', start));
      assert.ok(
        // `.get(` is the map accessor, not a document read.
        !/(?<![.\w])(get|getAfter|exists|existsAfter)\s*\(/.test(body),
        `${fn} must not make a document-access call (AD-54)`,
      );
    }
  });
});

// ── AC-2: sub_tracks + the AD-38 owner-rule branch matrix ──────────────────
describe('DNI-471 AC-2/AC-5 — governed writes require their same-batch change log', () => {
  test('create: a new sub-track with its change_log entry succeeds', async () => {
    const id = nextUlid();
    await assertSucceeds(writeSubTrack(owner(), id));
    const snap = await getDoc(doc(owner(), `${SUB_TRACKS}/${id}`));
    assert.strictEqual(snap.data().name, 'Shiur Gemara');
    // An ongoing sub-track (no academic_year, open window) is also valid.
    await assertSucceeds(writeSubTrack(owner(), nextUlid(), subTrack({
      type: 'ongoing', academic_year: null, window_end: null,
    })));
  });

  test('replay: an identical re-push succeeds without a new entry', async () => {
    const id = nextUlid();
    const changeId = await writeSubTrack(owner(), id);
    await assertSucceeds(setDoc(
      doc(owner(), `${SUB_TRACKS}/${id}`),
      { ...subTrack(), last_change_id: changeId },
    ));
    // ...and the entry itself replays identically too.
    await assertSucceeds(setDoc(
      doc(owner(), `${CHANGE_LOG}/${changeId}`),
      changeEntry('subTrack', id, changeId),
    ));
  });

  test('update: a field-level change with a fresh last_change_id + entry succeeds', async () => {
    const id = nextUlid();
    await writeSubTrack(owner(), id);
    await assertSucceeds(writeSubTrack(owner(), id, { rate_per_week: 5 }));
  });

  test('stale last_change_id (equal to the stored one) is denied', async () => {
    const id = nextUlid();
    const changeId = await writeSubTrack(owner(), id);
    // Even with a brand-new entry at that id the stored id must change.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), `${CHANGE_LOG}/${changeId}`));
    });
    await assertFails(writeSubTrack(owner(), id, { rate_per_week: 6 }, { changeId }));
  });

  test('missing entry (no change_log write in the batch) is denied', async () => {
    await assertFails(writeSubTrack(owner(), nextUlid(), subTrack(), { withEntry: false }));
    // A plain setDoc with no last_change_id at all is also denied.
    await assertFails(setDoc(doc(owner(), `${SUB_TRACKS}/${nextUlid()}`), subTrack()));
  });

  test('pre-existing entry id (entry not created in THIS batch) is denied', async () => {
    const id = nextUlid();
    const changeId = nextUlid();
    await seed(`${CHANGE_LOG}/${changeId}`, changeEntry('subTrack', id, changeId));
    // The batch "re-creates" the entry as an identical replay, which the
    // change_log rule allows — the owner rule's !exists() must still deny.
    await assertFails(writeSubTrack(owner(), id, subTrack(), { changeId }));
  });

  test('malformed last_change_id is denied', async () => {
    await assertFails(writeSubTrack(owner(), nextUlid(), subTrack(), { changeId: 'not-a-ulid-change-id-00000' }));
  });

  test('wrong entity and wrong entity_id are denied', async () => {
    const id = nextUlid();
    await assertFails(governedWrite(owner(), `${SUB_TRACKS}/${id}`, subTrack(), 'goal', id));
    await assertFails(governedWrite(owner(), `${SUB_TRACKS}/${id}`, subTrack(), 'subTrack', nextUlid()));
  });

  test('tutor role is denied (tutor client, and a tutor-role entry from the owner)', async () => {
    const id = nextUlid();
    await assertFails(governedWrite(tutor(), `${SUB_TRACKS}/${id}`, subTrack(), 'subTrack', id, {
      entry: { actor: { uid: TUTOR, role: 'tutor' } },
    }));
    await assertFails(writeSubTrack(owner(), id, subTrack(), {
      entry: { actor: { ...OWNER_ACTOR, role: 'tutor' } },
    }));
    await assertFails(writeSubTrack(stranger(), id, subTrack(), {
      entry: { actor: { uid: STRANGER, role: 'parent' } },
    }));
  });

  test('delete is denied for everyone (removal is an ended_at tombstone)', async () => {
    const id = nextUlid();
    await writeSubTrack(owner(), id);
    await assertFails(deleteDoc(doc(owner(), `${SUB_TRACKS}/${id}`)));
    await assertFails(deleteDoc(doc(tutor(), `${SUB_TRACKS}/${id}`)));
    await assertSucceeds(writeSubTrack(owner(), id, { ended_at: pastTs, end_reason: 'deleted' }));
  });

  test('tutor with active access can read sub_tracks; stranger cannot', async () => {
    const id = nextUlid();
    await writeSubTrack(owner(), id);
    await assertSucceeds(getDoc(doc(tutor(), `${SUB_TRACKS}/${id}`)));
    await assertFails(getDoc(doc(stranger(), `${SUB_TRACKS}/${id}`)));
  });
});

describe('DNI-471 AC-2 — sub_tracks permits only its exact AD-52 schema', () => {
  test('a sub_tracks write with an extra field is denied', async () => {
    await assertFails(writeSubTrack(owner(), nextUlid(), subTrack({ updated_at: pastTs })));
    await assertFails(writeSubTrack(owner(), nextUlid(), subTrack({ color: 'blue' })));
  });

  test('every AD-52 field is accepted together', async () => {
    await assertSucceeds(writeSubTrack(owner(), nextUlid(), subTrack({
      ended_at: pastTs, end_reason: 'ended',
    })));
  });

  test('type checks and required fields are enforced', async () => {
    const bad = (data) => assertFails(writeSubTrack(owner(), nextUlid(), data));
    await bad(subTrack({ type: 'summer' }));
    await bad(subTrack({ end_reason: 'bored' }));
    await bad(subTrack({ academic_year: '2026' }));
    await bad(withoutKey(subTrack(), 'academic_year')); // required for school_year
    await bad(subTrack({ type: 'ongoing', academic_year: 2026 })); // school_year only
    await bad(subTrack({ window_start: '1 Sept 2026' }));
    await bad(subTrack({ window_end: 20270630 }));
    await bad(subTrack({ rate_per_week: '4' }));
    await bad(subTrack({ rate_per_week: -1 }));
    await bad(subTrack({ weeks_per_year: null }));
    await bad(subTrack({ learns_on_shabbos: 'no' }));
    await bad(subTrack({ ground: { level: 'masechta' } }));
    await bad(subTrack({ name: '' }));
    await bad(subTrack({ curriculum_id: 7 }));
    for (const key of [
      'curriculum_id', 'name', 'type', 'window_start', 'rate_per_week',
      'weeks_per_year', 'learns_on_shabbos', 'ground',
    ]) {
      await bad(withoutKey(subTrack(), key));
    }
    for (const reason of ['ended', 'deleted', 'undo', 'track_deleted']) {
      await assertSucceeds(writeSubTrack(owner(), nextUlid(), subTrack({
        ended_at: pastTs, end_reason: reason,
      })));
    }
  });

  test('curriculum_id is immutable on update', async () => {
    const id = nextUlid();
    await writeSubTrack(owner(), id);
    await assertFails(writeSubTrack(owner(), id, { curriculum_id: 'c2' }));
  });
});

describe('DNI-471 AC-2 — each governed collection maps to its AD-38 entity', () => {
  // [collection, docId, payload, entity, entity_id]
  const CASES = [
    ['goals', 'c1_pace', { goal_type: 'pace', pace_value: 2, pace_unit: 'daf', curriculum_id: 'c1' }, 'goal', 'c1_pace'],
    ['curriculum_tracks', 'c1', { curriculum_id: 'c1', state: 'active' }, 'mainTrack', 'c1'],
    ['track_learning_order', 'c1_daf_Berakhot.2a', { curriculum_id: 'c1', level: 'daf', ref: 'Berakhot.2a', user_sort_order: 3 }, 'mainTrackOrder', 'c1'],
    ['profile_programs', 'c1', { curriculum_id: 'c1', program_id: 'p1', tracking_start_date: '2026-01-01' }, 'mainTrackProgram', 'c1'],
    ['study_day_configs', 'c1_1_1', { curriculum_id: 'c1', day_of_week: 1, day_type: 'study' }, 'mainTrackStudyDays', 'c1'],
    ['stage_definitions', 'c1_1', { curriculum_id: 'c1', stage_order: 1, stage_name: 'Stage 1' }, 'mainTrackStages', 'c1'],
    ['curriculum_scopes', 'c1', { curriculum_id: 'c1', scope: 'Berakhot' }, 'mainTrackScope', 'c1'],
  ];

  for (const [coll, docId, payload, entity, entityId] of CASES) {
    test(`${coll} ↔ ${entity} (entity_id = ${entityId === docId ? 'doc id' : 'curriculum_id'})`, async () => {
      const path = `${LP}/${coll}/${docId}`;
      await assertSucceeds(governedWrite(owner(), path, payload, entity, entityId));
      // Wrong entity for this collection.
      await assertFails(governedWrite(owner(), path, payload, entity === 'goal' ? 'mainTrack' : 'goal', entityId));
      // Wrong entity_id.
      await assertFails(governedWrite(owner(), path, payload, entity, 'c9'));
      // Missing entry.
      await assertFails(governedWrite(owner(), path, payload, entity, entityId, { withEntry: false }));
      // Client delete.
      await assertFails(deleteDoc(doc(owner(), path)));
      // Tombstone through the owner rule.
      await assertSucceeds(governedWrite(owner(), path, { ended_at: pastTs }, entity, entityId));
    });
  }

  test('mainTrack* docs require an immutable curriculum_id', async () => {
    const path = `${LP}/curriculum_tracks/c1`;
    await assertFails(governedWrite(owner(), path, { state: 'active' }, 'mainTrack', 'c1'));
    await assertSucceeds(governedWrite(owner(), path, { curriculum_id: 'c1', state: 'active' }, 'mainTrack', 'c1'));
    await assertFails(governedWrite(owner(), path, { curriculum_id: 'c2' }, 'mainTrack', 'c2'));
  });

  test('a governed doc with a non-timestamp ended_at is denied', async () => {
    await assertFails(governedWrite(owner(), `${GOALS}/c1_deadline`, {
      curriculum_id: 'c1', ended_at: '2020-01-01',
    }, 'goal', 'c1_deadline'));
  });
});

describe('DNI-471 AC-2 — learner_profiles settings keys take the AD-38 branch', () => {
  const PROFILE_PATH = `users/${OWNER}/learner_profiles/${PROFILE}`;
  const SETTINGS = { latitude: 31.77, longitude: 35.21, time_zone: 'Asia/Jerusalem', in_israel: true };

  test('non-settings profile fields keep their plain owner field-level write', async () => {
    await assertSucceeds(setDoc(doc(owner(), PROFILE_PATH), { display_name: 'Moishy' }, { merge: true }));
    await assertFails(setDoc(doc(tutor(), PROFILE_PATH), { display_name: 'x' }, { merge: true }));
  });

  test('a settings write without its change_log entry is denied', async () => {
    await assertFails(setDoc(doc(owner(), PROFILE_PATH), SETTINGS, { merge: true }));
    await assertFails(setDoc(doc(owner(), PROFILE_PATH), { in_israel: false }, { merge: true }));
    // last_change_id alone also routes through the owner rule.
    await assertFails(setDoc(doc(owner(), PROFILE_PATH), { last_change_id: nextUlid() }, { merge: true }));
  });

  test('a settings write with a learnerSettings entry (entity_id = profileId) succeeds', async () => {
    await assertSucceeds(governedWrite(owner(), PROFILE_PATH, SETTINGS, 'learnerSettings', PROFILE));
    // Field-level change of one setting.
    await assertSucceeds(governedWrite(owner(), PROFILE_PATH, { in_israel: false }, 'learnerSettings', PROFILE));
    // Ordinary fields still write plainly afterwards.
    await assertSucceeds(setDoc(doc(owner(), PROFILE_PATH), { display_name: 'Moishy' }, { merge: true }));
  });

  test('profile creation with seed settings + seed entry succeeds (AD-37)', async () => {
    const path = `users/${OWNER}/learner_profiles/new_profile`;
    const changeId = nextUlid();
    const db = owner();
    const batch = writeBatch(db);
    batch.set(doc(db, path), { name: 'New', ...SETTINGS, last_change_id: changeId });
    batch.set(
      doc(db, `users/${OWNER}/learner_profiles/new_profile/change_log/${changeId}`),
      changeEntry('learnerSettings', 'new_profile', changeId),
    );
    await assertSucceeds(batch.commit());
  });

  test('wrong entity / entity_id, tutor role and invalid settings types are denied', async () => {
    await assertFails(governedWrite(owner(), PROFILE_PATH, SETTINGS, 'goal', PROFILE));
    await assertFails(governedWrite(owner(), PROFILE_PATH, SETTINGS, 'learnerSettings', 'other'));
    await assertFails(governedWrite(owner(), PROFILE_PATH, SETTINGS, 'learnerSettings', PROFILE, {
      entry: { actor: { ...OWNER_ACTOR, role: 'tutor' } },
    }));
    const bad = (data) => assertFails(governedWrite(owner(), PROFILE_PATH, data, 'learnerSettings', PROFILE));
    await bad({ latitude: 31.77, longitude: 35.21, in_israel: true }); // time_zone required
    await bad({ ...SETTINGS, time_zone: 12 });
    await bad({ ...SETTINGS, latitude: 91 });
    await bad({ ...SETTINGS, longitude: '35.21' });
    await bad({ ...SETTINGS, in_israel: 'yes' });
    // A null location (no location → fail-closed fallback, AD-36) is valid.
    await assertSucceeds(governedWrite(owner(), PROFILE_PATH, {
      ...SETTINGS, latitude: null, longitude: null,
    }, 'learnerSettings', PROFILE));
  });
});

// ── AC-3: points_ledger pts_ binding ──────────────────────────────────────
describe('DNI-471 AC-3 — points ledger id derives from event id', () => {
  test('pts_{event_id} create succeeds, co-written with its learning event', async () => {
    const eventId = nextUlid();
    const db = owner();
    const batch = writeBatch(db);
    batch.set(doc(db, `${EVENTS}/${eventId}`), learnEvent());
    batch.set(doc(db, `${POINTS}/pts_${eventId}`), {
      event_id: eventId, points: 10, created_at: pastTs,
    });
    await assertSucceeds(batch.commit());
  });

  test('mismatched or malformed ids are denied', async () => {
    const eventId = nextUlid();
    await assertFails(setDoc(doc(owner(), `${POINTS}/pts_${nextUlid()}`), { event_id: eventId, points: 10 }));
    await assertFails(setDoc(doc(owner(), `${POINTS}/${eventId}`), { event_id: eventId, points: 10 }));
    await assertFails(setDoc(doc(owner(), `${POINTS}/pts_${eventId}`), { points: 10 }));
    await assertFails(setDoc(doc(owner(), `${POINTS}/pts_abc`), { event_id: 'abc', points: 10 }));
  });

  test('non-event entries (spends, adjustments) keep their ULID ids', async () => {
    await assertSucceeds(setDoc(doc(owner(), `${POINTS}/${nextUlid()}`), { delta: -50, created_at: pastTs }));
    // created_at stays optional, but a present null is still denied (pre-AD-54 behaviour).
    await assertSucceeds(setDoc(doc(owner(), `${POINTS}/${nextUlid()}`), { delta: -5 }));
    await assertFails(setDoc(doc(owner(), `${POINTS}/${nextUlid()}`), { delta: -5, created_at: null }));
  });

  test('tutor cannot write a pts_ entry; replay is identical-only', async () => {
    const eventId = nextUlid();
    const entry = { event_id: eventId, points: 10, created_at: pastTs };
    await assertFails(setDoc(doc(tutor(), `${POINTS}/pts_${eventId}`), entry));
    await assertSucceeds(setDoc(doc(owner(), `${POINTS}/pts_${eventId}`), entry));
    await assertSucceeds(setDoc(doc(owner(), `${POINTS}/pts_${eventId}`), entry));
    await assertFails(setDoc(doc(owner(), `${POINTS}/pts_${eventId}`), { ...entry, points: 100 }));
  });
});

// ── AC-4: AD-54 clock-skew boundary ───────────────────────────────────────
describe('DNI-471 AC-4 — timestamp skew boundary for event and governed writes', () => {
  // request.time is stamped after the client computes Date.now(), so
  // now + 10 min (minus a 1 s margin) is always inside the bound and
  // now + 10 min + 30 s is always outside it.
  const atBoundary = () => Timestamp.fromMillis(Date.now() + TEN_MIN_MS - 1000);
  const beyond = () => Timestamp.fromMillis(Date.now() + TEN_MIN_MS + 30 * 1000);
  const notATimestamp = () => new Date(Date.now()).toISOString();

  const WRITERS = {
    'learning_events.recorded_at': (ts) =>
      setDoc(doc(owner(), `${EVENTS}/${nextUlid()}`), learnEvent({ recorded_at: ts })),
    'change_log.at': (ts) => {
      const id = nextUlid();
      return setDoc(doc(owner(), `${CHANGE_LOG}/${id}`), changeEntry('goal', 'g', id, { at: ts }));
    },
    'sub_tracks.ended_at': (ts) =>
      writeSubTrack(owner(), nextUlid(), subTrack({ ended_at: ts, end_reason: 'ended' })),
    'goals.ended_at': (ts) => {
      const goalId = `c1_pace_${nextUlid()}`;
      return governedWrite(owner(), `${GOALS}/${goalId}`, { curriculum_id: 'c1', ended_at: ts }, 'goal', goalId);
    },
    'points_ledger.created_at': (ts) => {
      const eventId = nextUlid();
      return setDoc(doc(owner(), `${POINTS}/pts_${eventId}`), { event_id: eventId, points: 5, created_at: ts });
    },
  };

  for (const [field, write] of Object.entries(WRITERS)) {
    test(`${field}: ≤ request.time + 10 min allowed; beyond and non-timestamp denied`, async () => {
      await assertSucceeds(write(atBoundary()));
      await assertFails(write(beyond()));
      await assertFails(write(notATimestamp()));
    });
  }
});

// ── AC-5: AD-54 access-call budget ────────────────────────────────────────
//
// AD-54 prices a governed doc at 2 document-access calls (`exists` +
// `getAfter` on its change_log entry), events / change_log / `pts_` entries
// at 0, and caps a batch at 20 calls, so an owner batch carries ≤ 10
// governed docs and the 11th is over budget.
//
// What this block PROVES on the emulator: the rules evaluate exactly 2
// document-access calls per governed doc (counted from the emulator's
// per-expression evaluation report, `:ruleCoverage`, the same data the TQ-9
// gate reads), events / change_log / `pts_` entries evaluate 0, and a batch
// of exactly 10 governed docs (20 calls) commits.
//
// What it does NOT prove: that the platform DENIES an 11th governed doc.
// The emulator's own limit enforcement under-counts — it does not count
// `getAfter()` on a document written in the same batch, so it admits 20
// governed docs and first denies the 21st (pinned below as supplemental
// evidence) — and Firebase does not document whether production counts that
// call. AC-5's 11th-doc platform denial is therefore DEFERRED to DNI-490
// (1.28 cutover) release verification, the first point where production
// rules evaluation can be observed (no production access in this story,
// AD-54 single production project). Recorded default pending the
// architect/PO ruling on bead learning-tracker-fyh.72: this story's AC-5
// evidence is the 2-call-per-doc accounting, the exactly-20-call 10-doc
// commit and the 22-call 11-doc over-budget count below. Release
// verification must confirm in production that a 10-doc owner batch
// commits and record whether an 11-doc batch is denied, amending AD-54's
// numbers if production counting differs. The batch size is a platform
// budget, not an authorization boundary: every governed doc in any batch is
// authorized individually by the AD-38 owner rule.
// The rules keep AD-38's exact 2-call shape and never add an artificial
// third call (that would break legitimate 10-doc batches if production
// counts getAfter). Shipped clients never send an 11th governed doc: the
// owner command path splits at 10 and routes larger writes online through
// writeWithChangeLog (DNI-470 / story 1.10).
const AD54_BATCH_CALL_LIMIT = 20;
const ACCESS_CALL_RE = /(?<![.\w])(get|getAfter|exists|existsAfter)\s*\(/g;

// Every document-access call site in a rules source, 1-based line/column
// (comments stripped), as the coverage report positions expressions.
function accessCallSites(rulesSource) {
  const sites = [];
  rulesSource.split('\n').forEach((text, idx) => {
    const code = text.replace(/\/\/.*$/, '');
    for (const m of code.matchAll(ACCESS_CALL_RE)) {
      sites.push({ line: idx + 1, column: m.index + 1, fn: m[1] });
    }
  });
  return sites;
}

async function fetchRuleCoverage() {
  const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
  const res = await fetch(`http://${host}/emulator/v1/projects/demo-rules:ruleCoverage`);
  assert.equal(res.status, 200, 'rule coverage report must be available');
  return res.json();
}

// Total evaluated document-access calls recorded so far: for each call
// site, the innermost report node starting there (the call expression
// itself), summing every evaluation that produced a value (an `undefined`
// value means the expression was not reached in that evaluation).
function evaluatedAccessCalls(coverage) {
  const rulesSource = coverage.rules.files[0].content;
  const sites = accessCallSites(rulesSource);
  const innermost = new Map();
  const walk = (nodes) => {
    for (const n of nodes ?? []) {
      const p = n.sourcePosition;
      if (p) {
        const key = `${p.line}:${p.column}`;
        const span = p.endOffset - p.currentOffset;
        const prev = innermost.get(key);
        if (!prev || span < prev.span) innermost.set(key, { span, node: n });
      }
      walk(n.children);
    }
  };
  walk(coverage.report);
  let total = 0;
  for (const s of sites) {
    const hit = innermost.get(`${s.line}:${s.column}`);
    for (const v of hit?.node.values ?? []) {
      if (!('undefined' in (v.value ?? {}))) total += v.count;
    }
  }
  return total;
}

describe('DNI-471 AC-5 — AD-38 access-call budget (10 governed docs per owner batch)', () => {
  function governedBatch(db, n, { extraEvents = 0 } = {}) {
    const batch = writeBatch(db);
    for (let i = 0; i < n; i++) {
      const id = nextUlid();
      const changeId = nextUlid();
      batch.set(doc(db, `${SUB_TRACKS}/${id}`), { ...subTrack(), last_change_id: changeId }, { merge: true });
      batch.set(doc(db, `${CHANGE_LOG}/${changeId}`), changeEntry('subTrack', id, changeId));
    }
    // Zero-cost members: learning events and their pts_ entries.
    for (let i = 0; i < extraEvents; i++) {
      const eventId = nextUlid();
      batch.set(doc(db, `${EVENTS}/${eventId}`), learnEvent());
      batch.set(doc(db, `${POINTS}/pts_${eventId}`), { event_id: eventId, points: 10, created_at: pastTs });
    }
    return batch.commit();
  }

  // Commits `n` governed docs (+ zero-cost members) and returns the access
  // calls the rules evaluated for that batch alone.
  async function accountedBatch(n, opts) {
    const before = evaluatedAccessCalls(await fetchRuleCoverage());
    await governedBatch(owner(), n, opts);
    return evaluatedAccessCalls(await fetchRuleCoverage()) - before;
  }

  test('the AD-38 owner rule holds exactly the AD-54 access calls: one exists + one getAfter', () => {
    const rules = readFileSync('firestore.rules', 'utf8');
    const start = rules.indexOf('function changeLogCoWritten(');
    const body = rules.slice(start, rules.indexOf('\n    }\n', start));
    const calls = [...body.replace(/\/\/.*$/gm, '').matchAll(ACCESS_CALL_RE)].map((m) => m[1]).sort();
    assert.deepEqual(calls, ['exists', 'getAfter']);
    for (const fn of [
      'isGovernedOwnerWrite', 'isMainTrackOwnerWrite', 'hasImmutableCurriculumId',
      'hasValidEndedAt', 'touchesLearnerSettings', 'isValidLearnerSettings',
      'isLearnerProfileOwnerWrite',
    ]) {
      const s = rules.indexOf(`function ${fn}(`);
      assert.ok(s >= 0, `${fn} must exist in firestore.rules`);
      const b = rules.slice(s, rules.indexOf('\n    }\n', s)).replace(/\/\/.*$/gm, '');
      assert.equal([...b.matchAll(ACCESS_CALL_RE)].length, 0, `${fn} must not make a direct access call`);
    }
  });

  test('a batch of exactly 10 governed docs plus their change_log entries costs 20 calls and commits', async () => {
    const before = evaluatedAccessCalls(await fetchRuleCoverage());
    await assertSucceeds(governedBatch(owner(), 10));
    const calls = evaluatedAccessCalls(await fetchRuleCoverage()) - before;
    assert.equal(calls, 20, 'each governed doc costs exactly 2 access calls (AD-54)');
    assert.ok(calls <= AD54_BATCH_CALL_LIMIT, '10 governed docs fit the 20-call batch budget');
  });

  // NOT a denial proof. The emulator COMMITS this batch (it does not count
  // same-batch getAfter calls; see block comment), and production counting
  // is undocumented, so AC-5's "11th doc is denied" is deferred to DNI-490
  // release verification (bead learning-tracker-fyh.72). The
  // ≤ 10 guarantee in shipped code is the owner command path's own batch
  // split (DNI-470: 11+ governed docs go online through writeWithChangeLog).
  // This test pins only the arithmetic the budget rests on: the rules
  // evaluate 2 access calls per governed doc, so 11 docs need 22 > 20.
  test('accounting only (11th-doc platform denial deferred to DNI-490 release verification, fyh.72): 11 governed docs evaluate 22 access calls, over the 20-call budget', async () => {
    const calls = await accountedBatch(11);
    assert.equal(calls, 22, 'each governed doc costs exactly 2 access calls (AD-54)');
    assert.ok(calls > AD54_BATCH_CALL_LIMIT, '11 governed docs exceed the AD-54 batch budget');
  });

  test('learning events, change_log and pts_ entries cost zero: the full 10-doc batch still commits with 20 of them added', async () => {
    const before = evaluatedAccessCalls(await fetchRuleCoverage());
    await assertSucceeds(governedBatch(owner(), 10, { extraEvents: 10 }));
    assert.equal(evaluatedAccessCalls(await fetchRuleCoverage()) - before, 20);
  });

  test('a large access-call-free capture batch (events + pts_) costs zero and commits', async () => {
    const before = evaluatedAccessCalls(await fetchRuleCoverage());
    await assertSucceeds(governedBatch(owner(), 0, { extraEvents: 100 }));
    assert.equal(evaluatedAccessCalls(await fetchRuleCoverage()) - before, 0);
  });

  test('supplemental: the emulator platform budget denies a batch past its counted limit', async () => {
    // The emulator counts only the pre-state `exists()` per governed doc
    // (see block comment), so its own enforcement admits 20 docs and denies
    // the 21st. If an extra access call is ever added to the owner rule the
    // 20-doc assertion fails — re-derive AD-54's batch numbers first.
    await assertSucceeds(governedBatch(owner(), 20));
    await assertFails(governedBatch(owner(), 21));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// DNI-492 (story 2.1) — the owner sub-track lifecycle batches exactly as
// SubTrackCommands writes them (ruling B6: an owner create is an ordinary
// doc + entry batch admitted by the `resource == null` branch; it never
// claims the create). No rules change in this story.
// ════════════════════════════════════════════════════════════════════════════

describe('DNI-492 — owner sub-track lifecycle batches', () => {
  // The create payload SubTrackCommands sends: absent optionals are omitted.
  const createFields = () => withoutKey(withoutKey(subTrack({ type: 'ongoing' }), 'academic_year'), 'window_end');
  const keyed = (id, fields, value) =>
    Object.fromEntries(Object.keys(fields).map((f) => [`sub_tracks/${id}.${f}`, value(f)]));

  test('create: new doc + entry with null before per field succeeds (2 writes)', async () => {
    const id = nextUlid();
    const fields = createFields();
    await assertSucceeds(writeSubTrack(owner(), id, fields, {
      entry: { before: keyed(id, fields, () => null), after: keyed(id, fields, (f) => fields[f]) },
    }));
    const snap = await getDoc(doc(owner(), `${SUB_TRACKS}/${id}`));
    assert.strictEqual(snap.data().window_end, undefined);
  });

  test('create without its entry, or with another entity id, is denied', async () => {
    const id = nextUlid();
    await assertFails(writeSubTrack(owner(), id, createFields(), { withEntry: false }));
    await assertFails(governedWrite(owner(), `${SUB_TRACKS}/${id}`, createFields(), 'subTrack', nextUlid()));
  });

  test('edit replacing ground whole, then end and delete tombstones succeed', async () => {
    const id = nextUlid();
    await writeSubTrack(owner(), id, createFields());
    await assertSucceeds(writeSubTrack(owner(), id, {
      ground: [{ level: 'masechta', ref: 'Shabbat' }, { level: 'masechta', ref: 'Berakhot' }],
    }));
    await assertSucceeds(writeSubTrack(owner(), id, { ended_at: pastTs, end_reason: 'ended' }));
    const other = nextUlid();
    await writeSubTrack(owner(), other, createFields());
    await assertSucceeds(writeSubTrack(owner(), other, { ended_at: pastTs, end_reason: 'deleted' }));
    await assertFails(deleteDoc(doc(owner(), `${SUB_TRACKS}/${other}`)));
  });

  test('an extra field on the create is denied (hasOnly whitelist)', async () => {
    await assertFails(writeSubTrack(owner(), nextUlid(), { ...createFields(), progress: 3 }));
  });
});

// ── DNI-523 (Story 4.2a) — tutor-device read path for N talmidim ──────────
//
// The tutor roster reads several learners from DIFFERENT parents at once
// through `learnerStateForScopeProvider(LearnerScope)`: the tutor's own
// handle, the owner's path, gated client-side on a live `tutor_grants`
// query and server-side on hasActiveTutorAccess(). These pin both halves:
// an active tutor can list another owner's learning_events, sub_tracks,
// change_log, goals and curriculum_tracks for every granted scope; a
// revoked scope is denied while the others stay readable; and the grant
// query the client listens to is permitted for the tutor only.
describe('DNI-523 — grant-scoped tutor reads across owners (3 scopes, 2 parents)', () => {
  const OWNER_B = 'owner-b-uid';
  const P1 = '01J9ZZ0000000000000000P1AA';
  const P2 = '01J9ZZ0000000000000000P2AA';
  const P3 = '01J9ZZ0000000000000000P3AA';
  const SCOPES = [
    { owner: OWNER, profile: P1, grant: 'g-p1' },
    { owner: OWNER, profile: P2, grant: 'g-p2' },
    { owner: OWNER_B, profile: P3, grant: 'g-p3' },
  ];
  const COLLECTIONS = ['learning_events', 'sub_tracks', 'change_log', 'goals', 'curriculum_tracks'];
  const lp = ({ owner: o, profile }) => `users/${o}/learner_profiles/${profile}`;
  const accessId = ({ owner: o, profile }) => `${TUTOR}_${o}_${profile}`;
  const listAll = (db, scope, name) => getDocs(query(collection(db, `${lp(scope)}/${name}`), limit(500)));
  const grantQuery = (db, scope, { tutorUid = TUTOR } = {}) => getDocs(query(
    collection(db, 'tutor_grants'),
    where('tutor_uid', '==', tutorUid),
    where('parent_uid', '==', scope.owner),
    where('child_profile_id', '==', scope.profile),
  ));

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const scope of SCOPES) {
        await setDoc(doc(db, `tutor_active_access/${accessId(scope)}`), {
          tutor_uid: TUTOR,
          parent_uid: scope.owner,
          owner_uid: scope.owner,
          child_profile_id: scope.profile,
        });
        await setDoc(doc(db, `tutor_grants/${scope.grant}`), {
          tutor_uid: TUTOR,
          parent_uid: scope.owner,
          child_profile_id: scope.profile,
          state: 'active',
          tutor_email: 'tutor@test.com',
        });
        await setDoc(doc(db, lp(scope)), { name: scope.profile });
        for (const name of COLLECTIONS) {
          await setDoc(doc(db, `${lp(scope)}/${name}/${nextUlid()}`), { seeded: true });
        }
      }
    });
  });

  async function revoke(scope) {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await deleteDoc(doc(db, `tutor_active_access/${accessId(scope)}`));
      await setDoc(doc(db, `tutor_grants/${scope.grant}`), { state: 'revoked_by_parent' }, { merge: true });
    });
  }

  test('an active tutor lists every learner-state collection of every granted scope', async () => {
    for (const scope of SCOPES) {
      for (const name of COLLECTIONS) {
        const snap = await assertSucceeds(listAll(tutor(), scope, name));
        assert.equal(snap.size, 1, `${scope.owner}/${scope.profile}/${name}`);
      }
    }
  });

  test('revoking one scope denies only that scope; the other owners stay readable', async () => {
    const [p1, p2, p3] = SCOPES;
    await revoke(p3);
    for (const name of COLLECTIONS) {
      await assertFails(listAll(tutor(), p3, name));
      await assertSucceeds(listAll(tutor(), p1, name));
      await assertSucceeds(listAll(tutor(), p2, name));
    }
    await revoke(p1);
    for (const name of COLLECTIONS) {
      await assertFails(listAll(tutor(), p1, name));
      await assertSucceeds(listAll(tutor(), p2, name));
    }
  });

  test('a stranger with no grant cannot list any scope', async () => {
    for (const scope of SCOPES) {
      for (const name of COLLECTIONS) {
        await assertFails(listAll(stranger(), scope, name));
      }
    }
  });

  test('the client grant query is readable by the tutor, before and after a revoke', async () => {
    const p3 = SCOPES[2];
    const before = await assertSucceeds(grantQuery(tutor(), p3));
    assert.equal(before.size, 1);
    assert.equal(before.docs[0].data().state, 'active');
    await revoke(p3);
    // The tutor must still SEE the revoked grant, so the client flips the
    // row to denied rather than erroring.
    const after = await assertSucceeds(grantQuery(tutor(), p3));
    assert.equal(after.docs[0].data().state, 'revoked_by_parent');
  });

  test('the grant query is denied to anyone but the named tutor', async () => {
    const p3 = SCOPES[2];
    // A stranger cannot read another tutor's grants by naming that tutor.
    await assertFails(grantQuery(stranger(), p3));
    // The tutor cannot drop the tutor_uid pin and read the owner's grants.
    await assertFails(getDocs(query(
      collection(tutor(), 'tutor_grants'),
      where('parent_uid', '==', p3.owner),
      where('child_profile_id', '==', p3.profile),
    )));
  });
});
// ── DNI-476 (Story 1.14) — the owner governed writers' doc shapes ─────────────
// The owner repositories now write through LearningCommands.applyGovernedChange:
// the AD-52 `track_learning_order/{c}_{level}_{ref}` order doc, reset and
// "Remove track" as `ended_at` tombstones, "Re-add" clearing it, and goals at
// the AD-43 fixed ids. No rules change: these pin that the shapes the
// client writes pass the existing AD-38 owner rule, and its denials hold.
describe('DNI-476 — owner governed order docs, tombstones and fixed goal ids', () => {
  const ORDER = `${LP}/track_learning_order/c1_masechta_Berakhot`;
  const orderDoc = {
    curriculum_id: 'c1',
    level: 'masechta',
    ref: 'Berakhot',
    user_sort_order: 0,
  };
  const TRACK = `${LP}/curriculum_tracks/c1`;
  const trackDoc = {
    curriculum_id: 'c1',
    state: 'active',
    activated_at: '2026-09-01T00:00:00.000Z',
  };

  test('a reorder doc with its matching mainTrackOrder entry is accepted', async () => {
    await assertSucceeds(
      governedWrite(owner(), ORDER, orderDoc, 'mainTrackOrder', 'c1'),
    );
  });

  test('reset: an ended_at tombstone with a fresh entry is accepted and the doc remains', async () => {
    await governedWrite(owner(), ORDER, orderDoc, 'mainTrackOrder', 'c1');
    await assertSucceeds(
      governedWrite(owner(), ORDER, { ended_at: Timestamp.now() }, 'mainTrackOrder', 'c1'),
    );
    const snap = await getDoc(doc(owner(), ORDER));
    assert.ok(snap.exists());
    assert.ok(snap.data().ended_at);
  });

  test('a missing or mismatched entry is denied', async () => {
    await assertFails(
      governedWrite(owner(), ORDER, orderDoc, 'mainTrackOrder', 'c1', { withEntry: false }),
    );
    await assertFails(
      governedWrite(owner(), ORDER, orderDoc, 'mainTrackStages', 'c1'),
    );
    await assertFails(
      governedWrite(owner(), ORDER, orderDoc, 'mainTrackOrder', 'c2'),
    );
  });

  test('a client hard delete of an order doc is denied', async () => {
    await seed(ORDER, { ...orderDoc, last_change_id: nextUlid() });
    await assertFails(deleteDoc(doc(owner(), ORDER)));
  });

  test('remove track sets ended_at with a mainTrack entry; re-add clears it', async () => {
    await governedWrite(owner(), TRACK, trackDoc, 'mainTrack', 'c1');
    await assertSucceeds(
      governedWrite(owner(), TRACK, { ended_at: Timestamp.now() }, 'mainTrack', 'c1'),
    );
    await assertSucceeds(
      governedWrite(owner(), TRACK, { ended_at: null }, 'mainTrack', 'c1'),
    );
    await assertFails(deleteDoc(doc(owner(), TRACK)));
  });

  test('an AD-43 deadline goal at its fixed id with a goal entry is accepted; delete denied', async () => {
    const GOAL = `${LP}/goals/c1_deadline`;
    await assertSucceeds(
      governedWrite(owner(), GOAL, {
        curriculum_id: 'c1',
        goal_type: 'deadline',
        target_date: '2027-06-01',
        description: 'Siyum',
        date_type: 'gregorian',
        created_at: '2026-09-01T00:00:00.000Z',
      }, 'goal', 'c1_deadline'),
    );
    await assertFails(
      governedWrite(owner(), GOAL, { description: 'x' }, 'goal', 'c1_pace'),
    );
    await assertFails(deleteDoc(doc(owner(), GOAL)));
  });
});

describe('DNI-514 AC-1 — an undo (reverts_action_id) is a parent action', () => {
  const GOAL = `${GOALS}/g`;
  const GOAL_DOC = { goal_id: 'g', profile_id: PROFILE, goal_type: 'deadline', target_date: '2027-06-01' };
  const CHILD_ACTOR = { uid: OWNER, role: 'child', display_name: 'Child' };

  test('a parent undo entry and its governed restore are accepted', async () => {
    await assertSucceeds(
      governedWrite(owner(), GOAL, GOAL_DOC, 'goal', 'g', {
        entry: { reverts_action_id: nextUlid() },
      }),
    );
  });

  test('a child entry carrying reverts_action_id is denied, alone or in a governed batch', async () => {
    const id = nextUlid();
    await assertFails(setDoc(doc(owner(), `${CHANGE_LOG}/${id}`), changeEntry('goal', 'g', id, {
      reverts_action_id: nextUlid(),
      actor: CHILD_ACTOR,
    })));
    await assertFails(
      governedWrite(owner(), GOAL, GOAL_DOC, 'goal', 'g', {
        entry: { reverts_action_id: nextUlid(), actor: CHILD_ACTOR },
      }),
    );
  });

  test('a child entry without reverts_action_id is still accepted', async () => {
    await assertSucceeds(
      governedWrite(owner(), GOAL, GOAL_DOC, 'goal', 'g', {
        entry: { actor: CHILD_ACTOR },
      }),
    );
  });
});

// ════════════════════════════════════════════════════════════════════════════
// DNI-484 (story 1.22, R16) — retired fields are gone from the governed
// whitelists. Each retired key (and the camelCase aliases) is denied on its
// governed collection even inside an otherwise valid AD-38 write; the live
// schema still passes; same-named timestamps on non-governed collections keep
// their existing rules.
// ════════════════════════════════════════════════════════════════════════════
describe('DNI-484 — R16 retired fields are denied on governed docs', () => {
  // The retired keys come from the AD-49 inventory (DNI-489), scoped to the
  // goal and curriculum-track codecs, so a key retired later is covered too.
  const TRACK_RETIRED = retiredKeysOf(TRACK_REPOSITORY);
  const GOAL_RETIRED = [...retiredKeysOf(GOAL_REPOSITORY, { aliases: true }), 'updatedAt'];
  const goalValue = (key) => (/percent/i.test(key) ? 80 : pastTs);
  const liveTrack = { curriculum_id: 'c1', state: 'active', activated_at: pastTs };
  const liveDeadline = {
    curriculum_id: 'c1', goal_type: 'deadline', target_date: '2027-06-01',
  };
  const livePace = {
    curriculum_id: 'c1', goal_type: 'pace', pace_value: 2,
    pace_unit: 'per_day', pace_granularity: 'daf',
  };

  test('the live curriculum_tracks schema (state + display-only activated_at) passes', async () => {
    await assertSucceeds(
      governedWrite(owner(), `${LP}/curriculum_tracks/c1`, liveTrack, 'mainTrack', 'c1'),
    );
    await assertSucceeds(
      governedWrite(owner(), `${LP}/curriculum_tracks/c1`, { state: 'retired' }, 'mainTrack', 'c1'),
    );
  });

  for (const key of TRACK_RETIRED) {
    test(`curriculum_tracks: retired ${key} is denied`, async () => {
      await assertFails(
        governedWrite(owner(), `${LP}/curriculum_tracks/c1`, {
          ...liveTrack, [key]: pastTs,
        }, 'mainTrack', 'c1'),
      );
    });
  }

  test('the live goal schemas (deadline and pace at their AD-43 ids) pass', async () => {
    await assertSucceeds(
      governedWrite(owner(), `${GOALS}/c1_deadline`, liveDeadline, 'goal', 'c1_deadline'),
    );
    await assertSucceeds(
      governedWrite(owner(), `${GOALS}/c1_pace`, livePace, 'goal', 'c1_pace'),
    );
  });

  for (const key of GOAL_RETIRED) {
    test(`goals: retired ${key} is denied`, async () => {
      await assertFails(
        governedWrite(owner(), `${GOALS}/c1_deadline`, {
          ...liveDeadline, [key]: goalValue(key),
        }, 'goal', 'c1_deadline'),
      );
    });
  }

  const OTHER_GOVERNED = [
    ['stage_definitions', 'c1_1', { ...PAYLOADS.stage_definitions }, 'mainTrackStages'],
    ['study_day_configs', 'c1_1', { ...PAYLOADS.study_day_configs }, 'mainTrackStudyDays'],
    ['profile_programs', 'c1', { ...PAYLOADS.profile_programs }, 'mainTrackProgram'],
    ['track_learning_order', 'c1_masechta_Berakhot',
      { curriculum_id: 'c1', level: 'masechta', ref: 'Berakhot', user_sort_order: 0 },
      'mainTrackOrder'],
  ];
  for (const [col, id, live, entity] of OTHER_GOVERNED) {
    test(`${col}: the live schema passes; governed updated_at / synced_at are denied`, async () => {
      await assertSucceeds(governedWrite(owner(), `${LP}/${col}/${id}`, live, entity, 'c1'));
      for (const key of ['updated_at', 'synced_at']) {
        await assertFails(
          governedWrite(owner(), `${LP}/${col}/${id}`, { ...live, [key]: pastTs }, entity, 'c1'),
        );
      }
    });
  }

  // A governed doc written before R16 may still hold retired keys (the codecs
  // ignore them and AD-13 forbids a data migration). Field-level merges keep
  // those keys in the post-write doc, so the whitelist only constrains the
  // keys a write adds or changes: the owner can still update and tombstone
  // the doc, may drop a retired key, but can never (re)write one.
  const LEGACY_TRACK = Object.fromEntries(TRACK_RETIRED.map((k) => [k, pastTs]));
  const LEGACY_DOCS = [
    ['curriculum_tracks', 'c1', { profile_id: PROFILE, track_id: 1, ...liveTrack, ...LEGACY_TRACK },
      'mainTrack', 'c1', { state: 'paused' }, TRACK_RETIRED[0]],
    ['goals', 'c1_deadline', {
      ...liveDeadline, ...Object.fromEntries(GOAL_RETIRED.map((k) => [k, goalValue(k)])),
    }, 'goal', 'c1_deadline', { target_date: '2027-09-01' }, GOAL_RETIRED[0]],
    ...OTHER_GOVERNED.map(([col, id, live, entity]) => [
      col, id, { ...live, updated_at: pastTs, synced_at: pastTs }, entity, 'c1',
      col === 'track_learning_order' ? { user_sort_order: 1 } : { profile_id: PROFILE },
      'updated_at',
    ]),
  ];
  for (const [col, id, legacy, entity, entityId, patch, retiredKey] of LEGACY_DOCS) {
    const path = col === 'goals' ? `${GOALS}/${id}` : `${LP}/${col}/${id}`;
    const seedLegacy = () => env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), path), legacy);
    });

    test(`${col}: a pre-R16 doc holding retired keys can still be updated and tombstoned`, async () => {
      await seedLegacy();
      await assertSucceeds(governedWrite(owner(), path, patch, entity, entityId));
      await assertSucceeds(
        governedWrite(owner(), path, { ended_at: pastTs }, entity, entityId),
      );
      // The retired keys are untouched, not cleaned up by the rules.
      let stored;
      await env.withSecurityRulesDisabled(async (ctx) => {
        stored = (await getDoc(doc(ctx.firestore(), path))).data();
      });
      assert.ok(retiredKey in stored);
    });

    test(`${col}: a pre-R16 doc may drop a retired key but never rewrite one`, async () => {
      await seedLegacy();
      const changed = typeof legacy[retiredKey] === 'number' ? 90 : futureTs;
      await assertFails(
        governedWrite(owner(), path, { [retiredKey]: changed }, entity, entityId),
      );
      await assertSucceeds(
        governedWrite(owner(), path, { [retiredKey]: deleteField() }, entity, entityId),
      );
    });
  }

  test('non-governed collections keep their legitimate updated_at / synced_at', async () => {
    await assertSucceeds(setDoc(doc(owner(), `${LP}/point_configs/c1_1`), {
      curriculum_id: 'c1', stage_order: 1, points: 10, updated_at: pastTs, synced_at: pastTs,
    }));
    await assertSucceeds(setDoc(doc(owner(), `${LP}/import_metadata/c1`), {
      profile_id: PROFILE, curriculum_id: 'c1', item_count: 1, imported_at: pastTs, synced_at: pastTs,
    }));
  });
});
