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

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  deleteDoc,
  Timestamp,
  setLogLevel,
} from 'firebase/firestore';

setLogLevel('error'); // silence the verbose Firestore SDK chatter

const OWNER = 'owner-uid';
const TUTOR = 'tutor-uid';
const STRANGER = 'stranger-uid';
const PROFILE = '5';
const COMPLETIONS = `users/${OWNER}/learner_profiles/${PROFILE}/completions`;
const GOALS = `users/${OWNER}/learner_profiles/${PROFILE}/goals`;
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
  });
});

const owner = () => env.authenticatedContext(OWNER).firestore();
const tutor = () => env.authenticatedContext(TUTOR).firestore();
const stranger = () => env.authenticatedContext(STRANGER).firestore();
const anon = () => env.unauthenticatedContext().firestore();

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
});

describe('goals — owner write with key whitelist, tutor read-only', () => {
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
});

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
