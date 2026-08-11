// CF tests — owner self-service delete functions:
//   deleteLearnerProfile, deleteCurriculumTrack, deleteBulkMarkedCompletions,
//   deleteAccountData
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

  // AD-24: a learner profile is addressed by a ULID STRING doc-id, so a
  // non-empty string is the VALID shape. This test previously asserted the
  // opposite — that `profileId: '5'` must be rejected — which contradicted
  // deletes.ts's own already-migrated `typeof profileId !== "string"` guard.
  // It was stale, and it was the only assertion still pinning the pre-ULID
  // contract in this suite.
  test('profileId is a number → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteLearnerProfile, { profileId: 5 }, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is an empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteLearnerProfile, { profileId: '' }, parentAuth),
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

  // ── CLIENT CONTRACT ────────────────────────────────────────────────────
  // Pins the exact argument shape the Dart client sends from
  // FirestoreCurriculumTrackRepositoryAdapter.deleteTrackPermanently:
  //     { profileId: <profile ULID string>, curriculumId: <storageKey string> }
  //
  // This seam has broken TWICE — e2ab5aeb (CF wanted a ULID, Dart sent an int)
  // and P3-17 (14 CF guards still demanded a number). Both times each side was
  // internally consistent, so neither `dart analyze` nor these tests could see
  // the disagreement: the fixture supplied whatever shape the bug expected.
  // This fails if the client is ever changed to send an enum or a numeric id.
  test('CLIENT CONTRACT: the exact shape the Dart adapter sends is accepted', async () => {
    const trackRef = db
      .collection('users')
      .doc(PARENT)
      .collection('learner_profiles')
      .doc(String(PROFILE))
      .collection('curriculum_tracks')
      .doc('genesis');
    await trackRef.set({ curriculumId: 'genesis', enabled: true });

    const res = await call(
      fns.deleteCurriculumTrack,
      { profileId: String(PROFILE), curriculumId: 'genesis' },
      parentAuth,
    );

    assert.equal(res.success, true);
    assert.equal((await trackRef.get()).exists, false);
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

// ── deleteBulkMarkedCompletions ───────────────────────────────────────────────
//
// Owner decision (docs/firestore-rewrite-map.md, 2026-08-02): a `source ==
// 'bulkInTrack'` completion may be deleted, which also retracts its
// `learning_ledger` "learnt" status. A `source == 'live'` completion is
// PERMANENT — the single most important property this suite verifies. A
// `source == 'lifetimeOnly'` ledger entry (a standalone historical import,
// never tied to a bulk-marked track) must also never be touched. A document
// with no `source` field at all (legacy / not yet written by the new
// FirestoreCompletionRepository) must be left alone — absence means
// "don't touch", never "assume bulk".
describe('deleteBulkMarkedCompletions', () => {
  const CURRICULUM = 'genesis';
  const OTHER_CURRICULUM = 'exodus';
  const OTHER_PROFILE = PROFILE + 1;
  const REF_A = 'Genesis 1:1';
  const REF_B = 'Genesis 1:2';
  const REF_UNTOUCHED = 'Genesis 1:3';
  const UNIT_A = 'Genesis'; // the masechta/seder REF_A and REF_B belong to
  const UNIT_B = 'Exodus'; // a different unit — must never be touched by goodArgs
  const goodArgs = {
    profileId: PROFILE,
    curriculumId: CURRICULUM,
    sefariaRefs: [REF_A, REF_B],
    unitIdentifiers: [UNIT_A],
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  function pRefFor(uid, profileId) {
    return db.collection('users').doc(uid).collection('learner_profiles').doc(String(profileId));
  }

  // ── argument validation ─────────────────────────────────────────────────────

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, goodArgs, null),
      'unauthenticated',
    );
  });

  test('profileId missing → invalid-argument', async () => {
    await expectHttpsError(
      call(
        fns.deleteBulkMarkedCompletions,
        { curriculumId: CURRICULUM, sefariaRefs: [REF_A] },
        parentAuth,
      ),
      'invalid-argument',
    );
  });

  test('profileId is a float → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, profileId: 2.5 }, parentAuth),
      'invalid-argument',
    );
  });

  test('profileId is zero → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, profileId: 0 }, parentAuth),
      'invalid-argument',
    );
  });

  test('curriculumId missing → invalid-argument', async () => {
    await expectHttpsError(
      call(
        fns.deleteBulkMarkedCompletions,
        { profileId: PROFILE, sefariaRefs: [REF_A] },
        parentAuth,
      ),
      'invalid-argument',
    );
  });

  test('curriculumId empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, curriculumId: '' }, parentAuth),
      'invalid-argument',
    );
  });

  test('sefariaRefs missing → invalid-argument', async () => {
    await expectHttpsError(
      call(
        fns.deleteBulkMarkedCompletions,
        { profileId: PROFILE, curriculumId: CURRICULUM },
        parentAuth,
      ),
      'invalid-argument',
    );
  });

  test('sefariaRefs is an empty array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, sefariaRefs: [] }, parentAuth),
      'invalid-argument',
    );
  });

  test('sefariaRefs is not an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, sefariaRefs: REF_A }, parentAuth),
      'invalid-argument',
    );
  });

  test('sefariaRefs contains a non-string element → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, sefariaRefs: [REF_A, 42] }, parentAuth),
      'invalid-argument',
    );
  });

  test('sefariaRefs contains an empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, sefariaRefs: [''] }, parentAuth),
      'invalid-argument',
    );
  });

  // unitIdentifiers is REQUIRED — see the class doc comment's "Ledger sweep"
  // section. A missing/empty value must fail loudly and delete NOTHING,
  // never silently fall back to "every bulkInTrack ledger entry for the
  // curriculum" (the exact over-deletion bug this parameter fixes).
  test('unitIdentifiers missing → invalid-argument, and nothing is deleted', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('completions').doc('a-stage1').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 1, source: 'bulkInTrack',
    });
    await pRef.collection('learning_ledger').doc('ledger-1').set({
      ulid: 'ledger-1', curriculum_id: CURRICULUM, unit_identifier: UNIT_A, source: 'bulkInTrack',
    });
    const { unitIdentifiers: _omit, ...argsWithoutUnitIdentifiers } = goodArgs;

    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, argsWithoutUnitIdentifiers, parentAuth),
      'invalid-argument',
    );

    assert.equal(
      (await pRef.collection('completions').doc('a-stage1').get()).exists,
      true,
      'a missing unitIdentifiers must not delete any completion',
    );
    assert.equal(
      (await pRef.collection('learning_ledger').doc('ledger-1').get()).exists,
      true,
      'a missing unitIdentifiers must not delete any ledger entry',
    );
  });

  test('unitIdentifiers is an empty array → invalid-argument, and nothing is deleted', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('completions').doc('a-stage1').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 1, source: 'bulkInTrack',
    });
    await pRef.collection('learning_ledger').doc('ledger-1').set({
      ulid: 'ledger-1', curriculum_id: CURRICULUM, unit_identifier: UNIT_A, source: 'bulkInTrack',
    });

    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, unitIdentifiers: [] }, parentAuth),
      'invalid-argument',
    );

    assert.equal((await pRef.collection('completions').doc('a-stage1').get()).exists, true);
    assert.equal((await pRef.collection('learning_ledger').doc('ledger-1').get()).exists, true);
  });

  test('unitIdentifiers is not an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, unitIdentifiers: UNIT_A }, parentAuth),
      'invalid-argument',
    );
  });

  test('unitIdentifiers contains a non-string element → invalid-argument', async () => {
    await expectHttpsError(
      call(
        fns.deleteBulkMarkedCompletions,
        { ...goodArgs, unitIdentifiers: [UNIT_A, 42] },
        parentAuth,
      ),
      'invalid-argument',
    );
  });

  test('unitIdentifiers contains an empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.deleteBulkMarkedCompletions, { ...goodArgs, unitIdentifiers: [''] }, parentAuth),
      'invalid-argument',
    );
  });

  // ── completions sweep ────────────────────────────────────────────────────────

  test('deletes bulkInTrack completions for the named sefariaRefs, both stages', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    // Bulk-mark-prior writes one completion per (item x stage) — seed two
    // stages for REF_A to prove the whole item, not just one stage, is swept.
    await pRef.collection('completions').doc('a-stage1').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 1, source: 'bulkInTrack',
    });
    await pRef.collection('completions').doc('a-stage2').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 2, source: 'bulkInTrack',
    });
    await pRef.collection('completions').doc('b-stage1').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_B, stage_id: 1, source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(res.deleted.completions, 3);
    assert.equal((await pRef.collection('completions').doc('a-stage1').get()).exists, false);
    assert.equal((await pRef.collection('completions').doc('a-stage2').get()).exists, false);
    assert.equal((await pRef.collection('completions').doc('b-stage1').get()).exists, false);
  });

  test('a bulkInTrack completion for an UNNAMED sefariaRef in the same curriculum survives', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('completions').doc('untouched').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_UNTOUCHED, stage_id: 1, source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(res.deleted.completions, 0);
    assert.equal(
      (await pRef.collection('completions').doc('untouched').get()).exists,
      true,
      'a completion outside the requested sefariaRefs must survive',
    );
  });

  test('THE MOST IMPORTANT TEST — a live completion for a named sefariaRef is NEVER deleted', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('completions').doc('live-a').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 1, source: 'live',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(res.deleted.completions, 0);
    const snap = await pRef.collection('completions').doc('live-a').get();
    assert.equal(snap.exists, true, 'a live completion must survive — permanent, no undo');
    assert.equal(snap.data().source, 'live');
  });

  test('a completion with no source field at all survives (legacy row — absence means leave alone)', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('completions').doc('legacy-a').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 1,
      // no `source` field
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(res.deleted.completions, 0);
    assert.equal(
      (await pRef.collection('completions').doc('legacy-a').get()).exists,
      true,
      'a completion with no source field must survive',
    );
  });

  test('a bulkInTrack completion for a named sefariaRef but a DIFFERENT curriculum survives', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('completions').doc('other-curriculum').set({
      curriculum_id: OTHER_CURRICULUM, sefaria_ref: REF_A, stage_id: 1, source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(
      (await pRef.collection('completions').doc('other-curriculum').get()).exists,
      true,
    );
  });

  test('a bulkInTrack completion under a different profile survives', async () => {
    const targetRef = pRefFor(PARENT, PROFILE);
    const otherRef = pRefFor(PARENT, OTHER_PROFILE);
    await otherRef.collection('completions').doc('other-profile').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 1, source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal((await otherRef.collection('completions').doc('other-profile').get()).exists, true);
    assert.equal((await targetRef.collection('completions').doc('other-profile').get()).exists, false);
  });

  test('a bulkInTrack completion under a different user survives', async () => {
    const strangerRef = pRefFor(STRANGER, PROFILE);
    await strangerRef.collection('completions').doc('stranger').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 1, source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal((await strangerRef.collection('completions').doc('stranger').get()).exists, true);
  });

  // ── learning_ledger sweep ────────────────────────────────────────────────────

  test('deletes bulkInTrack ledger entries for the target curriculum', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('learning_ledger').doc('ledger-1').set({
      ulid: 'ledger-1', curriculum_id: CURRICULUM, unit_identifier: 'Genesis', source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(res.deleted.learning_ledger, 1);
    assert.equal((await pRef.collection('learning_ledger').doc('ledger-1').get()).exists, false);
  });

  // Regression test for the over-deletion bug: an earlier version of this
  // function matched learning_ledger by curriculum_id + source alone, with
  // no per-unit narrowing. A user who bulk-marked all of Shas (~63 masechtos
  // = ~63 bulkInTrack ledger entries under ONE curriculum_id) un-ticking a
  // single daf of Berachos would have wiped every one of those 63 lifetime
  // records instead of just Berachos's. unitIdentifiers exists to prevent
  // exactly this: the ledger sweep must only ever touch units the caller
  // actually named.
  test('un-ticking a ref in unit A deletes only unit A\'s ledger entry — unit B is untouched', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('learning_ledger').doc('ledger-unit-a').set({
      ulid: 'ledger-unit-a', curriculum_id: CURRICULUM, unit_identifier: UNIT_A, source: 'bulkInTrack',
    });
    // Same curriculum, same profile, same source — differs ONLY by unit.
    // A third and fourth masechta stand in for the other ~61 of a bulk-marked
    // Shas that must never be touched by an un-tick scoped to UNIT_A alone.
    await pRef.collection('learning_ledger').doc('ledger-unit-b').set({
      ulid: 'ledger-unit-b', curriculum_id: CURRICULUM, unit_identifier: UNIT_B, source: 'bulkInTrack',
    });
    await pRef.collection('learning_ledger').doc('ledger-unit-c').set({
      ulid: 'ledger-unit-c', curriculum_id: CURRICULUM, unit_identifier: 'Leviticus', source: 'bulkInTrack',
    });

    // goodArgs.unitIdentifiers is [UNIT_A] only — the caller is un-ticking
    // one item of unit A, not touching units B or C.
    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(res.deleted.learning_ledger, 1, 'exactly one ledger entry (unit A) should be deleted');
    assert.equal(
      (await pRef.collection('learning_ledger').doc('ledger-unit-a').get()).exists,
      false,
      'unit A ledger entry should be deleted',
    );
    assert.equal(
      (await pRef.collection('learning_ledger').doc('ledger-unit-b').get()).exists,
      true,
      'unit B ledger entry must survive — the caller never named it',
    );
    assert.equal(
      (await pRef.collection('learning_ledger').doc('ledger-unit-c').get()).exists,
      true,
      'unit C ledger entry must survive — the caller never named it',
    );
  });

  test('a live-sourced ledger entry for the same curriculum survives', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('learning_ledger').doc('ledger-live').set({
      ulid: 'ledger-live', curriculum_id: CURRICULUM, unit_identifier: 'Genesis', source: 'live',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    const snap = await pRef.collection('learning_ledger').doc('ledger-live').get();
    assert.equal(snap.exists, true, 'a live ledger entry must survive');
    assert.equal(snap.data().source, 'live');
  });

  test('a lifetimeOnly ledger entry for the same curriculum survives (standalone import, never track-bound)', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('learning_ledger').doc('ledger-lifetime').set({
      ulid: 'ledger-lifetime', curriculum_id: CURRICULUM, unit_identifier: 'Genesis', source: 'lifetimeOnly',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    const snap = await pRef.collection('learning_ledger').doc('ledger-lifetime').get();
    assert.equal(snap.exists, true, 'a lifetimeOnly ledger entry must never be deleted by this function');
    assert.equal(snap.data().source, 'lifetimeOnly');
  });

  test('a ledger entry with no source field at all survives (legacy — absence means leave alone)', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('learning_ledger').doc('ledger-legacy').set({
      ulid: 'ledger-legacy', curriculum_id: CURRICULUM, unit_identifier: 'Genesis',
      // no `source` field
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(
      (await pRef.collection('learning_ledger').doc('ledger-legacy').get()).exists,
      true,
    );
  });

  test('a bulkInTrack ledger entry for a DIFFERENT curriculum survives', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('learning_ledger').doc('ledger-other-curriculum').set({
      ulid: 'ledger-other-curriculum', curriculum_id: OTHER_CURRICULUM,
      unit_identifier: 'Exodus', source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(
      (await pRef.collection('learning_ledger').doc('ledger-other-curriculum').get()).exists,
      true,
      'a ledger entry for a different curriculum must survive',
    );
  });

  test('a bulkInTrack ledger entry under a different profile survives', async () => {
    const otherRef = pRefFor(PARENT, OTHER_PROFILE);
    await otherRef.collection('learning_ledger').doc('ledger-other-profile').set({
      ulid: 'ledger-other-profile', curriculum_id: CURRICULUM, unit_identifier: 'Genesis', source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal(
      (await otherRef.collection('learning_ledger').doc('ledger-other-profile').get()).exists,
      true,
    );
  });

  test('a bulkInTrack ledger entry under a different user survives', async () => {
    const strangerRef = pRefFor(STRANGER, PROFILE);
    await strangerRef.collection('learning_ledger').doc('ledger-stranger').set({
      ulid: 'ledger-stranger', curriculum_id: CURRICULUM, unit_identifier: 'Genesis', source: 'bulkInTrack',
    });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal((await strangerRef.collection('learning_ledger').doc('ledger-stranger').get()).exists, true);
  });

  // ── sibling append-only collections must never be touched ────────────────────

  test('streak_events and points_ledger are untouched', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('streak_events').doc('keep').set({ profile_id: String(PROFILE) });
    await pRef.collection('points_ledger').doc('keep').set({ profile_id: String(PROFILE), delta: 10 });

    const res = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.equal((await pRef.collection('streak_events').doc('keep').get()).exists, true);
    assert.equal((await pRef.collection('points_ledger').doc('keep').get()).exists, true);
  });

  // ── idempotency and scale ─────────────────────────────────────────────────────

  test('idempotent — running twice is safe and does not error or double-report', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    await pRef.collection('completions').doc('a-stage1').set({
      curriculum_id: CURRICULUM, sefaria_ref: REF_A, stage_id: 1, source: 'bulkInTrack',
    });
    await pRef.collection('learning_ledger').doc('ledger-1').set({
      ulid: 'ledger-1', curriculum_id: CURRICULUM, unit_identifier: 'Genesis', source: 'bulkInTrack',
    });

    const first = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);
    assert.equal(first.success, true);
    assert.equal(first.deleted.completions, 1);
    assert.equal(first.deleted.learning_ledger, 1);

    const second = await call(fns.deleteBulkMarkedCompletions, goodArgs, parentAuth);
    assert.equal(second.success, true, 'rerun on already-deleted data must not error');
    assert.equal(second.deleted.completions, 0);
    assert.equal(second.deleted.learning_ledger, 0);
  });

  test('sweeps more than 500 bulkInTrack completions in one call (bulkWriter, not batch-capped)', async () => {
    const pRef = pRefFor(PARENT, PROFILE);
    const N = 550;
    const refs = [];
    const chunks = [];
    let batch = db.batch();
    let opsInBatch = 0;
    for (let i = 0; i < N; i++) {
      const ref = `Genesis 1:${i}`;
      refs.push(ref);
      batch.set(pRef.collection('completions').doc(`c${i}`), {
        curriculum_id: CURRICULUM, sefaria_ref: ref, stage_id: 1, source: 'bulkInTrack',
      });
      opsInBatch++;
      if (opsInBatch === 450) {
        chunks.push(batch.commit());
        batch = db.batch();
        opsInBatch = 0;
      }
    }
    if (opsInBatch > 0) chunks.push(batch.commit());
    await Promise.all(chunks);

    const res = await call(
      fns.deleteBulkMarkedCompletions,
      { profileId: PROFILE, curriculumId: CURRICULUM, sefariaRefs: refs, unitIdentifiers: [UNIT_A] },
      parentAuth,
    );

    assert.equal(res.success, true);
    assert.equal(res.deleted.completions, N);
    const remaining = await pRef.collection('completions').where('curriculum_id', '==', CURRICULUM).get();
    assert.equal(remaining.size, 0, 'all 550 completions should be deleted');
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
