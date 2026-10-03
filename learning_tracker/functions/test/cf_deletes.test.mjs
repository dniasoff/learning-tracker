// CF tests — owner self-service delete functions:
//   deleteLearnerProfile, deleteCurriculumTrack (now the AD-38 remove-track
//   action — tombstones, no deletes), deleteAccountData
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  PARENT,
  PARENT_NAME,
  PROFILE,
  STRANGER,
  assertPrivacySafeRejectionLog,
  call,
  captureLogs,
  changeLog,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  parentAuth,
  seedProfile,
  ulid,
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

// ── deleteCurriculumTrack — the AD-38 remove-track action ─────────────────────
// Sub-tracks Story 1.10 / DNI-472 AC-3 / AC-6: rerouted through
// writeWithChangeLog. No governed doc is hard-deleted any more: one mainTrack
// entry sets `ended_at` on the track, one subTrack tombstone entry per live
// sub-track, all under one action_id.

describe('deleteCurriculumTrack', () => {
  const C = 'genesis';
  const goodArgs = { profileId: PROFILE, curriculumId: C };
  const lp = (uid = PARENT, profileId = PROFILE) =>
    db.collection('users').doc(uid).collection('learner_profiles').doc(String(profileId));
  const trackRef = (uid, profileId) => lp(uid, profileId).collection('curriculum_tracks').doc(C);

  beforeEach(async () => {
    await clearFirestore();
    await seedProfile();
  });

  test('unauthenticated caller → unauthenticated, logged as {entity, code} only', async () => {
    const { error, logs } = await captureLogs(() => call(fns.deleteCurriculumTrack, goodArgs, null));
    await expectHttpsError(Promise.reject(error), 'unauthenticated');
    assertPrivacySafeRejectionLog(logs, { entity: 'mainTrack', code: 'unauthenticated', secrets: [C] });
  });

  for (const [label, args] of [
    ['profileId missing', { curriculumId: C }],
    ['profileId is a number', { profileId: 5, curriculumId: C }],
    ['profileId is empty', { profileId: '', curriculumId: C }],
    ['curriculumId missing', { profileId: PROFILE }],
    ['curriculumId empty', { profileId: PROFILE, curriculumId: '' }],
    ['curriculumId is a number', { profileId: PROFILE, curriculumId: 7 }],
    ['curriculumId contains a path separator', { profileId: PROFILE, curriculumId: 'a/b' }],
    ['malformed actionId', { ...goodArgs, actionId: 'nope' }],
    ['actorRole tutor asserted by an owner', { ...goodArgs, actorRole: 'tutor' }],
  ]) {
    test(`${label} → invalid-argument`, async () => {
      await trackRef().set({ state: 'active', curriculum_id: C });
      await expectHttpsError(call(fns.deleteCurriculumTrack, args, parentAuth), 'invalid-argument');
      assert.equal((await trackRef().get()).get('ended_at'), undefined);
    });
  }

  // CLIENT CONTRACT — curriculum_track_repository_impl.dart's
  // deleteTrackPermanently sends exactly
  //     { profileId: <profile ULID string>, curriculumId: <storageKey string> }
  // This seam has broken TWICE (e2ab5aeb, P3-17); this fails if the client is
  // ever changed to send an enum or a numeric id.
  test('CLIENT CONTRACT: the exact shape the Dart adapter sends is accepted', async () => {
    await trackRef().set({ state: 'active', curriculum_id: C });
    const res = await call(
      fns.deleteCurriculumTrack,
      { profileId: String(PROFILE), curriculumId: C },
      parentAuth,
    );
    assert.equal(res.success, true);
    assert.equal(res.change_ids.length, 1);
    assert.ok(!Number.isNaN(Date.parse(res.at)), 'returns the server-stamped at');
  });

  test('remove-track: tombstones the track and every live sub-track under one action_id', async () => {
    await trackRef().set({ state: 'active', curriculum_id: C, last_change_id: ulid(0) });
    const subs = lp().collection('sub_tracks');
    const live1 = '01JSBTRACK0000000000000001';
    const live2 = '01JSBTRACK0000000000000002';
    const done = '01JSBTRACK0000000000000003';
    await subs.doc(live1).set({ curriculum_id: C, name: 'one' });
    await subs.doc(live2).set({ curriculum_id: C, name: 'two' });
    await subs.doc(done).set({ curriculum_id: C, name: 'three', ended_at: new Date('2026-01-01'), end_reason: 'deleted' });

    const res = await call(fns.deleteCurriculumTrack, { ...goodArgs, actionId: ulid(1) }, parentAuth);
    assert.equal(res.action_id, ulid(1));

    const entries = await changeLog();
    assert.deepEqual(entries.map((e) => e.entity).sort(), ['mainTrack', 'subTrack', 'subTrack']);
    assert.ok(entries.every((e) => e.action_id === ulid(1)));
    assert.deepEqual(entries.find((e) => e.entity === 'mainTrack').actor,
      { uid: PARENT, role: 'parent', display_name: PARENT_NAME });
    assert.deepEqual(entries.filter((e) => e.entity === 'subTrack').map((e) => e.entity_id).sort(), [live1, live2]);

    const track = await trackRef().get();
    assert.equal(track.exists, true, 'the track doc is tombstoned, never deleted');
    assert.ok(track.get('ended_at'));
    assert.equal(track.get('last_change_id'), ulid(1));
    for (const id of [live1, live2]) {
      const d = await subs.doc(id).get();
      assert.ok(d.get('ended_at'));
      assert.equal(d.get('end_reason'), 'track_deleted');
    }
    assert.equal((await subs.doc(done).get()).get('end_reason'), 'deleted', 'ended sub-tracks keep their tombstone');
  });

  test('no governed or history doc is hard-deleted; other governed docs are left as-is', async () => {
    await trackRef().set({ state: 'active', curriculum_id: C });
    const seeds = {
      goals: [`${C}_deadline`, { goal_type: 'deadline', target_date: '2027-01-01', curriculum_id: C }],
      stage_definitions: [`${C}_1`, { curriculum_id: C, stage_order: 1 }],
      study_day_configs: [`${C}_5`, { curriculum_id: C, day_of_week: 5 }],
      curriculum_scopes: [`${C}_1_x`, { curriculum_id: C }],
      track_learning_order: [`${C}_perek_1`, { curriculum_id: C, user_sort_order: 0 }],
      profile_programs: [C, { curriculum_id: C, program_id: null }],
      learning_events: [ulid(7), { kind: 'learn', curriculum_id: C }],
      points_ledger: ['pts_x', { curriculum_id: C }],
      completions: ['c1', { curriculum_id: C }],
      streak_events: ['s1', { curriculum_id: C }],
    };
    for (const [collection, [id, data]] of Object.entries(seeds)) {
      await lp().collection(collection).doc(id).set(data);
    }
    await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);
    for (const [collection, [id, data]] of Object.entries(seeds)) {
      const snap = await lp().collection(collection).doc(id).get();
      assert.equal(snap.exists, true, `${collection}/${id} must survive`);
      assert.deepEqual(snap.data(), data, `${collection}/${id} must be untouched`);
    }
  });

  test('other curricula, profiles and users are untouched', async () => {
    await trackRef().set({ state: 'active', curriculum_id: C });
    await lp().collection('curriculum_tracks').doc('exodus').set({ state: 'active', curriculum_id: 'exodus' });
    await lp(PARENT, '01JOTHERPR0F11E00000000000').collection('curriculum_tracks').doc(C)
      .set({ state: 'active', curriculum_id: C });
    await lp(STRANGER).collection('curriculum_tracks').doc(C).set({ state: 'active', curriculum_id: C });
    await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);
    assert.equal((await lp().collection('curriculum_tracks').doc('exodus').get()).get('ended_at'), undefined);
    assert.equal((await trackRef(PARENT, '01JOTHERPR0F11E00000000000').get()).get('ended_at'), undefined);
    assert.equal((await trackRef(STRANGER).get()).get('ended_at'), undefined);
  });

  test('owner-only: a caller can only remove a track on their own profile path', async () => {
    await trackRef().set({ state: 'active', curriculum_id: C });
    // The stranger's own path has no such profile → not-found; PARENT's track is untouched.
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, goodArgs, { uid: STRANGER, token: {} }),
      'not-found',
    );
    assert.equal((await trackRef().get()).get('ended_at'), undefined);
  });

  test('idempotent: an absent or already-removed track is a no-op; a same-ULID retry replays', async () => {
    const absent = await call(fns.deleteCurriculumTrack, goodArgs, parentAuth);
    assert.equal(absent.noop, true);
    await trackRef().set({ state: 'active', curriculum_id: C });
    const first = await call(fns.deleteCurriculumTrack, { ...goodArgs, actionId: ulid(1) }, parentAuth);
    const replay = await call(fns.deleteCurriculumTrack, { ...goodArgs, actionId: ulid(1) }, parentAuth);
    assert.equal(replay.replayed, true);
    assert.deepEqual(replay.change_ids, first.change_ids);
    const again = await call(fns.deleteCurriculumTrack, { ...goodArgs, actionId: ulid(2) }, parentAuth);
    assert.equal(again.noop, true, 'an already-ended track is not tombstoned twice');
    assert.equal((await changeLog()).length, 1);
  });

  // Repair round 2 (codex HIGH): a no-op action leaves a durable receipt, so
  // a retry after the state changed replays it instead of running anew.
  test('a no-op remove is durable: a same-ULID retry after the track is recreated does not remove it', async () => {
    const first = await call(fns.deleteCurriculumTrack, { ...goodArgs, actionId: ulid(1) }, parentAuth);
    assert.equal(first.noop, true);
    assert.equal(first.replayed, false);
    await trackRef().set({ state: 'active', curriculum_id: C });
    const retry = await call(fns.deleteCurriculumTrack, { ...goodArgs, actionId: ulid(1) }, parentAuth);
    assert.equal(retry.replayed, true);
    assert.equal(retry.noop, true, 'the stored no-op result is returned');
    assert.deepEqual(retry.change_ids, []);
    assert.equal((await trackRef().get()).get('ended_at'), undefined, 'the recreated track is untouched');
    assert.deepEqual(await changeLog(), []);
  });

  test('a ULID already used for a different track → already-exists', async () => {
    await trackRef().set({ state: 'active', curriculum_id: C });
    await lp().collection('curriculum_tracks').doc('exodus').set({ state: 'active', curriculum_id: 'exodus' });
    await call(fns.deleteCurriculumTrack, { ...goodArgs, actionId: ulid(1) }, parentAuth);
    await expectHttpsError(
      call(fns.deleteCurriculumTrack, { profileId: PROFILE, curriculumId: 'exodus', actionId: ulid(1) }, parentAuth),
      'already-exists',
    );
    assert.equal((await lp().collection('curriculum_tracks').doc('exodus').get()).get('ended_at'), undefined);
  });

  test('a child owner may assert role child', async () => {
    await trackRef().set({ state: 'active', curriculum_id: C });
    await call(fns.deleteCurriculumTrack, { ...goodArgs, actorRole: 'child' }, parentAuth);
    assert.equal((await changeLog())[0].actor.role, 'child');
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
