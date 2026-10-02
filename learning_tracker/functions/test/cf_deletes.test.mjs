// CF tests — owner self-service delete functions:
//   deleteLearnerProfile, deleteCurriculumTrack (now the AD-38 remove-track
//   action — tombstones, no deletes), deleteBulkMarkedCompletions,
//   deleteAccountData
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
