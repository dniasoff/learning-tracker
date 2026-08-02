// CF tests — owner self-service delete functions:
//   deleteLearnerProfile, deleteCurriculumTrack, deleteAccountData
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  PARENT,
  PROFILE,
  STRANGER,
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  parentAuth,
} from './_cf_helpers.mjs';

// ── deleteLearnerProfile ──────────────────────────────────────────────────────
describe('deleteLearnerProfile', () => {
  const goodArgs = { profileId: PROFILE };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.deleteLearnerProfile, goodArgs, null),
      'unauthenticated',
    );
  });

  test('profileId missing → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteLearnerProfile, {}, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is a string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteLearnerProfile, { profileId: '5' }, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is a float → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteLearnerProfile, { profileId: 1.5 }, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is zero → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteLearnerProfile, { profileId: 0 }, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is negative → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteLearnerProfile, { profileId: -1 }, parentAuth),
      'invalid-argument',
    );
  });

  test('happy path → returns success and profile doc is gone', async () => {
    const pRef = db
      .collection('users')
      .doc(PARENT)
      .collection('learner_profiles')
      .doc(String(PROFILE));
    await pRef.set({ name: 'Test Learner' });

    const res = await call(fns.deleteLearnerProfile, goodArgs, parentAuth);

    assert.equal(res.success, true);
    const snap = await pRef.get();
    assert.equal(snap.exists, false, 'profile doc should be deleted');
  });

  test('happy path → subcollection docs are also deleted (recursiveDelete)', async () => {
    const pRef = db
      .collection('users')
      .doc(PARENT)
      .collection('learner_profiles')
      .doc(String(PROFILE));
    await pRef.set({ name: 'Test Learner' });
    const trackRef = pRef.collection('curriculum_tracks').doc('genesis');
    await trackRef.set({ curriculumId: 'genesis' });

    const res = await call(fns.deleteLearnerProfile, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal((await pRef.get()).exists, false, 'profile doc deleted');
    assert.equal((await trackRef.get()).exists, false, 'nested track doc deleted');
  });
});

// ── deleteCurriculumTrack ─────────────────────────────────────────────────────
describe('deleteCurriculumTrack', () => {
  const goodArgs = { profileId: PROFILE, curriculumId: 'genesis' };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, goodArgs, null),
      'unauthenticated',
    );
  });

  test('profileId missing → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, { curriculumId: 'genesis' }, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is a float → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, { ...goodArgs, profileId: 2.5 }, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is zero → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, { ...goodArgs, profileId: 0 }, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is negative → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, { ...goodArgs, profileId: -3 }, parentAuth),
      'invalid-argument',
    );
  });

  test('curriculumId missing → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, { profileId: PROFILE }, parentAuth),
      'invalid-argument',
    );
  });

  test('curriculumId empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, { profileId: PROFILE, curriculumId: '' }, parentAuth),
      'invalid-argument',
    );
  });

  test('curriculumId is a number → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, { profileId: PROFILE, curriculumId: 42 }, parentAuth),
      'invalid-argument',
    );
  });

  test('happy path → returns success and track doc is gone', async () => {
    const trackRef = db
      .collection('users')
      .doc(PARENT)
      .collection('learner_profiles')
      .doc(String(PROFILE))
      .collection('curriculum_tracks')
      .doc('genesis');
    await trackRef.set({ curriculumId: 'genesis', enabled: true });

    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);

    assert.equal(res.success, true);
    const snap = await trackRef.get();
    assert.equal(snap.exists, false, 'track doc should be deleted');
  });

  test('deleting non-existent track doc → still returns success (Firestore delete is idempotent)', async () => {
    // Firestore .delete() on a non-existent doc does NOT throw; verify that.
    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);
    assert.equal(res.success, true);
  });

  test('recursiveDelete → a nested track subcollection doc is also purged', async () => {
    const trackRef = db
      .collection('users')
      .doc(PARENT)
      .collection('learner_profiles')
      .doc(String(PROFILE))
      .collection('curriculum_tracks')
      .doc('genesis');
    await trackRef.set({ curriculumId: 'genesis' });
    const nestedRef = trackRef.collection('history').doc('h1');
    await nestedRef.set({ note: 'should not orphan' });

    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal((await trackRef.get()).exists, false, 'track doc deleted');
    assert.equal(
      (await nestedRef.get()).exists,
      false,
      'nested subcollection doc must also be purged (recursiveDelete, not shallow)',
    );
  });
});

// ── deleteCurriculumTrack — sibling collection sweep ──────────────────────────
//
// curriculum_tracks/{curriculumId} itself is a doc-id-scoped recursiveDelete,
// but track-scoped config lives in SIBLING collections under the *profile*
// (not nested under the track doc), keyed by a `curriculum_id` field —
// recursiveDelete(trackRef) never reaches them. profile_programs is the one
// exception: its doc-id IS the curriculumId (a direct doc delete, not a
// query). These tests prove every listed collection is actually swept, and —
// the test that matters most — that a sweep never crosses a curriculum,
// profile, or user boundary, and never touches append-only history.
describe('deleteCurriculumTrack — sibling collection sweep', () => {
  const CURRICULUM = 'genesis';
  const OTHER_CURRICULUM = 'exodus';
  const OTHER_PROFILE = PROFILE + 1;
  const goodArgs = { profileId: PROFILE, curriculumId: CURRICULUM };

  // Collections queried by a `curriculum_id` field (verified against
  // firestore.rules .hasOnly() whitelists / firestore_rules.test.mjs fixtures
  // — see the header comment on TRACK_SCOPED_QUERIED_COLLECTIONS in deletes.ts).
  const QUERIED_COLLECTIONS = [
    'goals',
    'stage_definitions',
    'study_day_configs',
    'curriculum_scopes',
    'learning_order',
  ];

  beforeEach(async () => {
    await clearFirestore();
  });

  function pRefFor(uid, profileId) {
    return db.collection('users').doc(uid).collection('learner_profiles').doc(String(profileId));
  }

  /** Seed one doc per queried collection under the given profile, keyed to `curriculumId`. */
  async function seedQueriedDocs(uid, profileId, curriculumId, suffix) {
    const pRef = pRefFor(uid, profileId);
    const batch = db.batch();
    for (const collectionName of QUERIED_COLLECTIONS) {
      batch.set(pRef.collection(collectionName).doc(`doc_${suffix}`), {
        curriculum_id: curriculumId,
        marker: suffix,
      });
    }
    await batch.commit();
  }

  test('sweeps every listed sibling collection for the target curriculum', async () => {
    await seedQueriedDocs(PARENT, PROFILE, CURRICULUM, 'target');
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('profile_programs').doc(CURRICULUM)
      .set({ curriculum_id: CURRICULUM, program_id: 1 });
    await pRef.collection('curriculum_tracks').doc(CURRICULUM)
      .set({ curriculum_id: CURRICULUM, state: 'active' });

    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);

    assert.equal(res.success, true);
    for (const collectionName of QUERIED_COLLECTIONS) {
      assert.equal(res.deleted[collectionName], 1, `${collectionName} deleted count`);
      const snap = await pRef.collection(collectionName).doc('doc_target').get();
      assert.equal(snap.exists, false, `${collectionName} doc should be gone`);
    }
    assert.equal(res.deleted.profile_programs, 1);
    assert.equal((await pRef.collection('profile_programs').doc(CURRICULUM).get()).exists, false);
    assert.equal(res.deleted.curriculum_tracks, 1);
    assert.equal((await pRef.collection('curriculum_tracks').doc(CURRICULUM).get()).exists, false);
  });

  test('documents belonging to a different curriculum are untouched', async () => {
    await seedQueriedDocs(PARENT, PROFILE, CURRICULUM, 'target');
    await seedQueriedDocs(PARENT, PROFILE, OTHER_CURRICULUM, 'other');
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('profile_programs').doc(CURRICULUM).set({ curriculum_id: CURRICULUM });
    await pRef.collection('profile_programs').doc(OTHER_CURRICULUM)
      .set({ curriculum_id: OTHER_CURRICULUM });

    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);

    assert.equal(res.success, true);
    for (const collectionName of QUERIED_COLLECTIONS) {
      // Target curriculum's doc is really gone...
      assert.equal(
        (await pRef.collection(collectionName).doc('doc_target').get()).exists,
        false,
        `${collectionName} target-curriculum doc should be deleted`,
      );
      // ...but the other curriculum's doc survives.
      const snap = await pRef.collection(collectionName).doc('doc_other').get();
      assert.equal(snap.exists, true, `${collectionName} doc for other curriculum must survive`);
      assert.equal(snap.data().curriculum_id, OTHER_CURRICULUM);
    }
    assert.equal((await pRef.collection('profile_programs').doc(CURRICULUM).get()).exists, false);
    assert.equal((await pRef.collection('profile_programs').doc(OTHER_CURRICULUM).get()).exists, true);
  });

  test('documents belonging to a different profile are untouched', async () => {
    await seedQueriedDocs(PARENT, PROFILE, CURRICULUM, 'target');
    await seedQueriedDocs(PARENT, OTHER_PROFILE, CURRICULUM, 'other-profile');

    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);

    assert.equal(res.success, true);
    const targetPRef = pRefFor(PARENT, PROFILE);
    const otherPRef = pRefFor(PARENT, OTHER_PROFILE);
    for (const collectionName of QUERIED_COLLECTIONS) {
      assert.equal(
        (await targetPRef.collection(collectionName).doc('doc_target').get()).exists,
        false,
        `${collectionName} doc under target profile should be deleted`,
      );
      const snap = await otherPRef.collection(collectionName).doc('doc_other-profile').get();
      assert.equal(snap.exists, true, `${collectionName} doc under other profile must survive`);
    }
  });

  test('documents belonging to a different user are untouched', async () => {
    await seedQueriedDocs(PARENT, PROFILE, CURRICULUM, 'target');
    await seedQueriedDocs(STRANGER, PROFILE, CURRICULUM, 'other-user');

    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);

    assert.equal(res.success, true);
    const targetPRef = pRefFor(PARENT, PROFILE);
    const strangerPRef = pRefFor(STRANGER, PROFILE);
    for (const collectionName of QUERIED_COLLECTIONS) {
      assert.equal(
        (await targetPRef.collection(collectionName).doc('doc_target').get()).exists,
        false,
        `${collectionName} doc under target user should be deleted`,
      );
      const snap = await strangerPRef.collection(collectionName).doc('doc_other-user').get();
      assert.equal(snap.exists, true, `${collectionName} doc under other user must survive`);
    }
  });

  test('append-only history is never touched, even when it matches the target curriculum', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    // out of scope per the task spec: completions, learning_ledger,
    // streak_events, points_ledger — a track delete must never touch the
    // owner's lifetime learning record.
    const appendOnly = {
      completions: { profile_id: PROFILE, curriculum_id: CURRICULUM, points: 10 },
      learning_ledger: { ulid: 'ULID0001', profile_id: String(PROFILE), curriculum_id: CURRICULUM },
      streak_events: { ulid: 'ULID0002', profile_id: String(PROFILE) },
      points_ledger: { ulid: 'ULID0003', profile_id: String(PROFILE), delta: -50 },
    };
    for (const [collectionName, payload] of Object.entries(appendOnly)) {
      await pRef.collection(collectionName).doc('keep').set(payload);
    }

    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);

    assert.equal(res.success, true);
    for (const collectionName of Object.keys(appendOnly)) {
      const snap = await pRef.collection(collectionName).doc('keep').get();
      assert.equal(snap.exists, true, `${collectionName} must survive a track delete (append-only)`);
    }
  });

  test('idempotent — running twice is safe and does not error or double-report', async () => {
    await seedQueriedDocs(PARENT, PROFILE, CURRICULUM, 'target');
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('profile_programs').doc(CURRICULUM).set({ curriculum_id: CURRICULUM });
    await pRef.collection('curriculum_tracks').doc(CURRICULUM).set({ curriculum_id: CURRICULUM });

    const first = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);
    assert.equal(first.success, true);
    assert.equal(first.deleted.goals, 1);
    assert.equal(first.deleted.profile_programs, 1);
    assert.equal(first.deleted.curriculum_tracks, 1);

    const second = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);
    assert.equal(second.success, true, 'rerun on already-deleted data must not error');
    for (const collectionName of QUERIED_COLLECTIONS) {
      assert.equal(second.deleted[collectionName], 0, `${collectionName} should already be empty on rerun`);
    }
    assert.equal(second.deleted.profile_programs, 0);
    assert.equal(second.deleted.curriculum_tracks, 0);
  });

  test('sweeps more than 500 documents in one collection (bulkWriter, not batch-capped)', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    const N = 550;
    // Seed via chunked WriteBatches (500-op cap) — this is test setup, not the
    // code under test, which must itself handle N > 500 via bulkWriter.
    const chunks = [];
    let batch = db.batch();
    let opsInBatch = 0;
    for (let i = 0; i < N; i++) {
      batch.set(pRef.collection('goals').doc(`g${i}`), { curriculum_id: CURRICULUM, i });
      opsInBatch++;
      if (opsInBatch === 450) {
        chunks.push(batch.commit());
        batch = db.batch();
        opsInBatch = 0;
      }
    }
    if (opsInBatch > 0) chunks.push(batch.commit());
    await Promise.all(chunks);

    const res = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(res.deleted.goals, N);
    const remaining = await pRef.collection('goals').where('curriculum_id', '==', CURRICULUM).get();
    assert.equal(remaining.size, 0, 'all 550 goals docs should be deleted');
  });
});

// ── deleteAccountData ─────────────────────────────────────────────────────────
describe('deleteAccountData', () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.deleteAccountData, {}, null),
      'unauthenticated',
    );
  });

  test('happy path → returns success and user doc is gone', async () => {
    const userRef = db.collection('users').doc(PARENT);
    await userRef.set({ email: 'test@example.com' });

    const res = await call(fns.deleteAccountData, {}, parentAuth);

    assert.equal(res.success, true);
    const snap = await userRef.get();
    assert.equal(snap.exists, false, 'users/{uid} doc should be deleted');
  });

  test('happy path → subcollections under users/{uid} are also deleted', async () => {
    const userRef = db.collection('users').doc(PARENT);
    await userRef.set({ email: 'test@example.com' });
    const profileRef = userRef.collection('learner_profiles').doc(String(PROFILE));
    await profileRef.set({ name: 'Child' });
    const trackRef = profileRef.collection('curriculum_tracks').doc('genesis');
    await trackRef.set({ curriculumId: 'genesis' });

    const res = await call(fns.deleteAccountData, {}, parentAuth);

    assert.equal(res.success, true);
    assert.equal((await userRef.get()).exists, false, 'user doc deleted');
    assert.equal((await profileRef.get()).exists, false, 'profile doc deleted');
    assert.equal((await trackRef.get()).exists, false, 'track doc deleted');
  });

  test('calling with extra args is silently ignored → still returns success', async () => {
    // deleteAccountData ignores request.data entirely; extra fields must not cause errors.
    const userRef = db.collection('users').doc(PARENT);
    await userRef.set({ email: 'test@example.com' });
    const res = await call(fns.deleteAccountData, { unexpected: 'field' }, parentAuth);
    assert.equal(res.success, true);
  });
});
