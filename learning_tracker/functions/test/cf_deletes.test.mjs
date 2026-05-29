// CF tests — owner self-service delete functions:
//   deleteLearnerProfile, deleteCurriculumTrack, deleteAccountData
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  PARENT,
  PROFILE,
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
