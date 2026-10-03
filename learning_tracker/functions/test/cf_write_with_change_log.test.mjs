// CF tests — writeWithChangeLog, the shared governed write path (sub-tracks
// AD-38 callable contract, AD-53, AD-54), and ownerOversizedGovernedWrite.
// Story 1.10 / DNI-472 acceptance tests AC-1, AC-2, AC-5, AC-6.
//
// The helper is exercised through the real exported callables (tutor
// callables for grant callers, ownerOversizedGovernedWrite for owners) and,
// for learning-event voids (no callable exposes events yet — Story 1.23 adds
// them), by calling the shared helper module directly against the emulator.
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { beforeEach, describe, test } from 'node:test';
import {
  GRANT,
  PARENT,
  PARENT_NAME,
  PROFILE,
  TUTOR,
  assertPrivacySafeRejectionLog,
  call,
  captureLogs,
  changeLog,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  parentAuth,
  profileRef,
  seedActiveGrant,
  seedLearningGrant,
  seedProfile,
  strangerAuth,
  tutorAuth,
  ulid,
} from './_cf_helpers.mjs';
import { retiredKeysOf } from './_retired_inventory.mjs';

// The retired R16 goal keys, read from the AD-49 inventory (DNI-489).
const GOAL_REPOSITORY = 'lib/data/repositories/firestore_goal_repository.dart';

const helper = await import('../lib/write_with_change_log.js');

const C = 'mishnah';
const goalArgs = (goalData, extra = {}) => ({
  grantId: GRANT,
  ownerUid: PARENT,
  profileId: PROFILE,
  goalId: `${C}_deadline`,
  goalData,
  ...extra,
});
const DEADLINE = { goal_type: 'deadline', target_date: '2027-06-01', curriculum_id: C };

/** An owner action with one entry, for ownerOversizedGovernedWrite. */
function ownerAction(id, entity, entityId, docs, extra = {}) {
  return { profileId: PROFILE, entries: [{ id, entity, entityId, docs }], ...extra };
}

const goalDoc = (fields, mode) => ({
  collection: 'goals', docId: `${C}_deadline`, fields, ...(mode ? { mode } : {}),
});

beforeEach(async () => {
  await clearFirestore();
});

// ── AC-1 / AC-6: authorisation rejection matrix ───────────────────────────────

describe('writeWithChangeLog — authorisation', () => {
  beforeEach(async () => {
    await seedProfile();
  });

  test('no auth → unauthenticated, logged as {entity, code} only', async () => {
    await seedLearningGrant();
    const { error, logs } = await captureLogs(() => call(fns.tutorUpsertGoal, goalArgs(DEADLINE), null));
    await expectHttpsError(Promise.reject(error), 'unauthenticated');
    assertPrivacySafeRejectionLog(logs, { entity: 'goal', code: 'unauthenticated', secrets: ['2027-06-01'] });
    assert.deepEqual(await changeLog(), []);
  });

  test('no grant (grant doc absent) → permission-denied', async () => {
    const { error, logs } = await captureLogs(() => call(fns.tutorUpsertGoal, goalArgs(DEADLINE)));
    await expectHttpsError(Promise.reject(error), 'permission-denied');
    assertPrivacySafeRejectionLog(logs, { entity: 'goal', code: 'permission-denied' });
    assert.equal((await profileRef().collection('goals').doc(`${C}_deadline`).get()).exists, false);
  });

  for (const state of ['revoked_by_parent', 'revoked_by_tutor', 'pending', 'declined']) {
    test(`grant state ${state} → permission-denied`, async () => {
      await seedLearningGrant({ state });
      await expectHttpsError(call(fns.tutorUpsertGoal, goalArgs(DEADLINE)), 'permission-denied');
      assert.deepEqual(await changeLog(), []);
    });
  }

  test('grant with only the legacy per-feature keys (no can_edit_learning) → permission-denied', async () => {
    await seedActiveGrant({ can_edit_goals: true, can_edit_stages: true, can_edit_study_days: true });
    const { error, logs } = await captureLogs(() => call(fns.tutorUpsertGoal, goalArgs(DEADLINE)));
    await expectHttpsError(Promise.reject(error), 'permission-denied');
    assertPrivacySafeRejectionLog(logs, { entity: 'goal', code: 'permission-denied' });
  });

  test('can_edit_learning: false → permission-denied', async () => {
    await seedActiveGrant({ can_edit_learning: false });
    await expectHttpsError(call(fns.tutorUpsertGoal, goalArgs(DEADLINE)), 'permission-denied');
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedLearningGrant();
    await expectHttpsError(call(fns.tutorUpsertGoal, goalArgs(DEADLINE), strangerAuth), 'permission-denied');
  });

  test('grant for another owner or another profile → permission-denied', async () => {
    await seedLearningGrant({ parent_uid: 'someone-else' });
    await expectHttpsError(call(fns.tutorUpsertGoal, goalArgs(DEADLINE)), 'permission-denied');
    await seedLearningGrant({ child_profile_id: '01JOTHERPR0F11E00000000000' });
    await expectHttpsError(call(fns.tutorUpsertGoal, goalArgs(DEADLINE)), 'permission-denied');
  });

  test('revoking the grant between calls stops the next write before anything is written', async () => {
    await seedLearningGrant();
    await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    await db.collection('tutor_grants').doc(GRANT).update({ state: 'revoked_by_parent' });
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goalArgs({ target_date: '2028-01-01' }, { actionId: ulid(2) })),
      'permission-denied',
    );
    const goal = (await profileRef().collection('goals').doc(`${C}_deadline`).get()).data();
    assert.equal(goal.target_date, '2027-06-01');
    assert.deepEqual((await changeLog()).map((e) => e.id), [ulid(1)]);
  });

  test('a missing learner profile → not-found (nothing is conjured)', async () => {
    await seedLearningGrant();
    await profileRef().delete();
    await expectHttpsError(call(fns.tutorUpsertGoal, goalArgs(DEADLINE)), 'not-found');
    assert.equal((await profileRef().get()).exists, false);
  });
});

// ── AC-1: server-derived actor ────────────────────────────────────────────────

describe('writeWithChangeLog — actor', () => {
  beforeEach(async () => {
    await seedProfile();
  });

  test('grant caller → role tutor, display_name from the grant; client actor fields ignored', async () => {
    await seedLearningGrant();
    await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, {
      actionId: ulid(1),
      actor: { uid: PARENT, role: 'parent', display_name: 'Forged' },
    }));
    const [entry] = await changeLog();
    assert.deepEqual(entry.actor, { uid: TUTOR, role: 'tutor', display_name: 'Mr Tutor' });
  });

  test('owner caller → asserted role accepted, display_name from the account doc', async () => {
    const res = await call(
      fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(1), 'goal', `${C}_deadline`, [goalDoc(DEADLINE)], { actorRole: 'child' }),
      parentAuth,
    );
    assert.equal(res.success, true);
    const [entry] = await changeLog();
    assert.deepEqual(entry.actor, { uid: PARENT, role: 'child', display_name: PARENT_NAME });
  });

  test('owner role defaults to parent; an owner cannot assert role tutor', async () => {
    await call(fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(1), 'goal', `${C}_deadline`, [goalDoc(DEADLINE)]), parentAuth);
    assert.equal((await changeLog())[0].actor.role, 'parent');
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite,
        ownerAction(ulid(2), 'goal', `${C}_pace`, [{
          collection: 'goals', docId: `${C}_pace`,
          fields: { goal_type: 'pace', pace_value: 2, pace_unit: 'daf', pace_granularity: 'day' },
        }], { actorRole: 'tutor' }),
        parentAuth),
      'invalid-argument',
    );
  });
});

// ── AC-1 / AC-6: payload validation ───────────────────────────────────────────

describe('writeWithChangeLog — payload validation (AD-52, AD-38 mapping, AD-43)', () => {
  beforeEach(async () => {
    await seedProfile();
    await seedLearningGrant();
  });

  const badGoalPayloads = [
    ['unknown field', { ...DEADLINE, sneaky: true }],
    ...retiredKeysOf(GOAL_REPOSITORY).filter((key) => key.includes('percent'))
      .map((key) => [`retired ${key}`, { ...DEADLINE, [key]: 50 }]),
    ['camelCase drift', { goalType: 'deadline', targetDate: '2027-06-01' }],
    ['malformed date', { ...DEADLINE, target_date: 'next summer' }],
    ['impossible date', { ...DEADLINE, target_date: '2027-02-30' }],
    ['goal_type not matching the fixed id', { ...DEADLINE, goal_type: 'pace' }],
    ['deadline goal without a target_date', { goal_type: 'deadline', curriculum_id: C }],
    ['curriculum_id not matching the fixed id', { ...DEADLINE, curriculum_id: 'tanach' }],
    ['client-written last_change_id', { ...DEADLINE, last_change_id: ulid(9) }],
    ['ended_at as a client timestamp', { ...DEADLINE, ended_at: '2026-01-01T00:00:00Z' }],
  ];
  // Repair round 1 (codex HIGH): nullability is per field — null can never
  // remove required data from a live doc (AD-52).
  const nullRequiredPatches = [
    ['curriculum_tracks.state', 'tutorUpsertTrack', 'trackId', C, 'trackData', 'curriculum_tracks', C,
      { state: 'active', curriculum_id: C }, { state: null }],
    ['track_learning_order.user_sort_order', null, null, `${C}_perek_1`, null, 'track_learning_order',
      `${C}_perek_1`, { curriculum_id: C, level: 'perek', ref: '1', user_sort_order: 0 },
      { user_sort_order: null }],
    ['track_learning_order.ref', null, null, `${C}_perek_1`, null, 'track_learning_order',
      `${C}_perek_1`, { curriculum_id: C, level: 'perek', ref: '1', user_sort_order: 0 }, { ref: null }],
    ['goals.goal_type', 'tutorUpsertGoal', 'goalId', `${C}_deadline`, 'goalData', 'goals', `${C}_deadline`,
      DEADLINE, { goal_type: null }],
  ];
  for (const [name, fn, idParam, id, dataParam, collection, docId, seed, patch] of nullRequiredPatches) {
    test(`null for required field ${name} on an existing doc → invalid-argument, data kept`, async () => {
      const ref = profileRef().collection(collection).doc(docId);
      await ref.set({ ...seed, last_change_id: ulid(0) });
      const request = fn
        ? call(fns[fn], { grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, [idParam]: id, [dataParam]: patch })
        : call(fns.ownerOversizedGovernedWrite, ownerAction(ulid(1), 'mainTrackOrder', C,
          [{ collection, docId, fields: patch, mode: 'update' }]), parentAuth);
      await expectHttpsError(request, 'invalid-argument');
      assert.deepEqual((await ref.get()).data(), { ...seed, last_change_id: ulid(0) });
      assert.deepEqual(await changeLog(), []);
    });
  }

  test('a re-add of a live-required-field-less track is rejected until state is supplied', async () => {
    const ref = profileRef().collection('curriculum_tracks').doc(C);
    await ref.set({ curriculum_id: C, ended_at: new Date('2026-01-01') });
    const base = { grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, trackId: C };
    await expectHttpsError(call(fns.tutorUpsertTrack, { ...base, trackData: { ended_at: null } }), 'invalid-argument');
    await call(fns.tutorUpsertTrack, { ...base, trackData: { ended_at: null, state: 'active' } });
    assert.equal((await ref.get()).data().state, 'active');
  });

  test('null is still accepted for nullable fields (clears them)', async () => {
    const ref = profileRef().collection('profile_programs').doc(C);
    await ref.set({ curriculum_id: C, program_id: 'daf_yomi', tracking_start_date: '2026-01-01' });
    await call(fns.tutorSetProfileProgram, {
      grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, programId: C, programData: { program_id: null },
    });
    assert.equal((await ref.get()).data().program_id, undefined);
  });

  for (const [name, goalData] of badGoalPayloads) {
    test(`bad payload (${name}) → invalid-argument, nothing written`, async () => {
      const { error, logs } = await captureLogs(() => call(fns.tutorUpsertGoal, goalArgs(goalData)));
      await expectHttpsError(Promise.reject(error), 'invalid-argument');
      assertPrivacySafeRejectionLog(logs, { entity: 'goal', code: 'invalid-argument' });
      assert.deepEqual(await changeLog(), []);
      assert.equal((await profileRef().collection('goals').doc(`${C}_deadline`).get()).exists, false);
    });
  }

  test('goal id outside the AD-43 fixed ids → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, { ...goalArgs(DEADLINE), goalId: 'goal-1' }),
      'invalid-argument',
    );
  });

  test('entity ↔ collection mapping is enforced', async () => {
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite,
        ownerAction(ulid(1), 'mainTrackOrder', C, [goalDoc(DEADLINE)]), parentAuth),
      'invalid-argument',
    );
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite,
        ownerAction(ulid(2), 'mainTrackOrder', 'tanach', [{
          collection: 'track_learning_order', docId: `${C}_masechet_Berakhot`,
          fields: { curriculum_id: C, level: 'masechet', ref: 'Berakhot', user_sort_order: 0 },
        }]), parentAuth),
      'invalid-argument',
    );
    assert.deepEqual(await changeLog(), []);
  });

  test('curriculum_id is immutable on an existing mainTrack* doc', async () => {
    await profileRef().collection('study_day_configs').doc('cfg-1')
      .set({ curriculum_id: C, day_of_week: 1, day_type: 'study' });
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, {
        grantId: GRANT, ownerUid: PARENT, profileId: PROFILE,
        configId: 'cfg-1', configData: { curriculum_id: 'tanach', day_type: 'rest' },
      }),
      'invalid-argument',
    );
  });

  test('calendar-program curriculum: goal rejected (failed-precondition) using transactional program state', async () => {
    await profileRef().collection('profile_programs').doc(C).set({
      program_id: 'daf_yomi', tracking_start_date: '2026-01-01', curriculum_id: C,
    });
    const { error, logs } = await captureLogs(() => call(fns.tutorUpsertGoal, goalArgs(DEADLINE)));
    await expectHttpsError(Promise.reject(error), 'failed-precondition');
    assertPrivacySafeRejectionLog(logs, { entity: 'goal', code: 'failed-precondition' });
    assert.equal((await profileRef().collection('goals').doc(`${C}_deadline`).get()).exists, false);
    assert.deepEqual(await changeLog(), []);
  });

  test('calendar-program check also covers the pace goal, and an ended program no longer blocks', async () => {
    const program = profileRef().collection('profile_programs').doc(C);
    await program.set({ program_id: 'daf_yomi', tracking_start_date: '2026-01-01', curriculum_id: C });
    await expectHttpsError(
      call(fns.tutorUpsertGoal, {
        ...goalArgs({ goal_type: 'pace', pace_value: 1, pace_unit: 'daf', pace_granularity: 'day' }),
        goalId: `${C}_pace`,
      }),
      'failed-precondition',
    );
    await program.update({ ended_at: new Date() });
    const res = await call(fns.tutorUpsertGoal, goalArgs(DEADLINE));
    assert.equal(res.success, true);
  });

  test('a goal tombstone is still allowed on a calendar-program curriculum', async () => {
    await profileRef().collection('goals').doc(`${C}_deadline`).set(DEADLINE);
    await profileRef().collection('profile_programs').doc(C).set({
      program_id: 'daf_yomi', tracking_start_date: '2026-01-01', curriculum_id: C,
    });
    const res = await call(fns.tutorDeleteGoal, {
      grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, goalId: `${C}_deadline`,
    });
    assert.equal(res.change_ids.length, 1);
  });
});

// ── AC-1 / AC-6: AD-31 void targets (shared helper, direct) ───────────────────

describe('writeWithChangeLog — AD-31 void targets', () => {
  const events = () => profileRef().collection('learning_events');
  const tutorReq = (evs) => ({
    ownerUid: PARENT, profileId: PROFILE, grantId: GRANT, events: evs,
  });
  const learn = (id) => ({
    id,
    fields: {
      kind: 'learn', curriculum_id: C, ref: 'Berakhot 1:1', source: 'main',
      date_state: 'dated', learned_on: '2026-09-30',
    },
  });
  const voidOf = (id, target) => ({ id, fields: { kind: 'void', target_id: target } });

  beforeEach(async () => {
    await seedProfile();
    await seedLearningGrant();
  });

  test('a void targeting a learn event is written with server recorded_at and actor', async () => {
    await helper.writeWithChangeLog(tutorAuth, tutorReq([learn(ulid(1))]));
    const res = await helper.writeWithChangeLog(tutorAuth, tutorReq([voidOf(ulid(2), ulid(1))]));
    assert.deepEqual(res.event_ids, [ulid(2)]);
    assert.ok(res.recorded_at, 'server-stamped recorded_at is returned');
    const stored = (await events().doc(ulid(2)).get()).data();
    assert.equal(stored.kind, 'void');
    assert.deepEqual(stored.actor, { uid: TUTOR, role: 'tutor', display_name: 'Mr Tutor' });
  });

  test('a void targeting a void → invalid-argument, nothing written', async () => {
    await helper.writeWithChangeLog(tutorAuth, tutorReq([learn(ulid(1))]));
    await helper.writeWithChangeLog(tutorAuth, tutorReq([voidOf(ulid(2), ulid(1))]));
    await expectHttpsError(
      helper.writeWithChangeLog(tutorAuth, tutorReq([voidOf(ulid(3), ulid(2))])),
      'invalid-argument',
    );
    assert.equal((await events().doc(ulid(3)).get()).exists, false);
  });

  test('a void whose target is absent is not an error (AD-31)', async () => {
    const res = await helper.writeWithChangeLog(tutorAuth, tutorReq([voidOf(ulid(2), ulid(99))]));
    assert.deepEqual(res.event_ids, [ulid(2)]);
  });

  test('a void without target_id, or carrying learn fields → invalid-argument', async () => {
    await expectHttpsError(
      helper.writeWithChangeLog(tutorAuth, tutorReq([{ id: ulid(2), fields: { kind: 'void' } }])),
      'invalid-argument',
    );
    await expectHttpsError(
      helper.writeWithChangeLog(tutorAuth, tutorReq([{
        id: ulid(2), fields: { kind: 'void', target_id: ulid(1), ref: 'Berakhot 1:1' },
      }])),
      'invalid-argument',
    );
  });

  test('events go through the same grant check (revoked grant → permission-denied)', async () => {
    await db.collection('tutor_grants').doc(GRANT).update({ state: 'revoked_by_parent' });
    await expectHttpsError(
      helper.writeWithChangeLog(tutorAuth, tutorReq([learn(ulid(1))])),
      'permission-denied',
    );
    await expectHttpsError(helper.writeWithChangeLog(null, tutorReq([learn(ulid(1))])), 'unauthenticated');
  });

  test('an event id replayed by the same actor returns the stored result; by another actor → already-exists', async () => {
    const first = await helper.writeWithChangeLog(tutorAuth, tutorReq([learn(ulid(1))]));
    const replay = await helper.writeWithChangeLog(tutorAuth, tutorReq([learn(ulid(1))]));
    assert.equal(replay.replayed, true);
    assert.equal(replay.noop, false, 'a replay is not a false noop');
    assert.deepEqual(replay.event_ids, [ulid(1)]);
    assert.equal(replay.recorded_at, first.recorded_at);
    await expectHttpsError(
      helper.writeWithChangeLog(parentAuth, { ownerUid: PARENT, profileId: PROFILE, events: [learn(ulid(1))] }),
      'already-exists',
    );
  });
});

// ── AD-40 / AD-52: learned_on on learn events (repair round 2, codex HIGH) ─────

describe('writeWithChangeLog — learn event learned_on', () => {
  const events = () => profileRef().collection('learning_events');
  const req = (fields) => ({
    ownerUid: PARENT, profileId: PROFILE, grantId: GRANT,
    events: [{ id: ulid(1), fields: { kind: 'learn', curriculum_id: C, ref: 'Berakhot 1:1', source: 'main', ...fields } }],
  });

  beforeEach(async () => {
    await seedProfile();
    await seedLearningGrant();
  });

  for (const state of ['dated', 'catch_up']) {
    test(`${state} without learned_on → invalid-argument, nothing written`, async () => {
      await expectHttpsError(helper.writeWithChangeLog(tutorAuth, req({ date_state: state })), 'invalid-argument');
      await expectHttpsError(
        helper.writeWithChangeLog(tutorAuth, req({ date_state: state, learned_on: null })), 'invalid-argument');
      await expectHttpsError(
        helper.writeWithChangeLog(tutorAuth, req({ date_state: state, learned_on: '2026-02-30' })), 'invalid-argument');
      assert.equal((await events().doc(ulid(1)).get()).exists, false);
    });

    test(`${state} with learned_on is stored with its civil day (counts toward streak/velocity)`, async () => {
      await helper.writeWithChangeLog(tutorAuth, req({ date_state: state, learned_on: '2026-09-30' }));
      const stored = (await events().doc(ulid(1)).get()).data();
      assert.equal(stored.date_state, state);
      assert.equal(stored.learned_on, '2026-09-30');
    });
  }

  test('before_tracking may omit learned_on or carry null, and may carry a node level', async () => {
    await helper.writeWithChangeLog(tutorAuth, req({ date_state: 'before_tracking', level: 'chapter' }));
    assert.equal((await events().doc(ulid(1)).get()).get('learned_on'), undefined);
    await helper.writeWithChangeLog(tutorAuth, {
      ...req({}),
      events: [{ id: ulid(2), fields: {
        kind: 'learn', curriculum_id: C, ref: 'Berakhot 1', source: 'main', date_state: 'before_tracking', learned_on: null,
      } }],
    });
    assert.equal((await events().doc(ulid(2)).get()).get('learned_on'), null);
  });

  test('level stays before_tracking-only', async () => {
    await expectHttpsError(
      helper.writeWithChangeLog(tutorAuth, req({ date_state: 'dated', learned_on: '2026-09-30', level: 'chapter' })),
      'invalid-argument',
    );
  });
});

// ── AC-1 / AC-6: idempotency on the client ULID ───────────────────────────────

describe('writeWithChangeLog — idempotent replay', () => {
  beforeEach(async () => {
    await seedProfile();
    await seedLearningGrant();
  });

  test('same ULID + actor + entity returns the stored result and writes nothing new', async () => {
    const first = await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    assert.equal(first.replayed, false);
    const { result: second, logs } = await captureLogs(
      () => call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) })));
    assert.equal(second.replayed, true);
    assert.equal(second.action_id, first.action_id);
    assert.deepEqual(second.change_ids, first.change_ids);
    assert.equal(second.at, first.at);
    assert.equal(logs.filter((l) => l.entry.message === 'governed_write_rejected').length, 0);
    assert.equal((await changeLog()).length, 1);
    const audit = await db.collection('tutor_grants').doc(GRANT).collection('audit_log').get();
    assert.equal(audit.size, 1, 'a replay writes no second security-audit entry');
  });

  test('same ULID for a different entity → already-exists', async () => {
    await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    const { error, logs } = await captureLogs(() => call(fns.tutorUpsertGoal, {
      ...goalArgs({ goal_type: 'pace', pace_value: 1, pace_unit: 'daf', pace_granularity: 'day' }),
      goalId: `${C}_pace`,
      actionId: ulid(1),
    }));
    await expectHttpsError(Promise.reject(error), 'already-exists');
    assertPrivacySafeRejectionLog(logs, { entity: 'goal', code: 'already-exists' });
    assert.equal((await profileRef().collection('goals').doc(`${C}_pace`).get()).exists, false);
  });

  test('same ULID from a different actor → already-exists', async () => {
    await call(fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(1), 'goal', `${C}_deadline`, [goalDoc(DEADLINE)]), parentAuth);
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) })),
      'already-exists',
    );
    assert.equal((await changeLog()).length, 1);
  });

  test('same ULID + entity with a different payload → already-exists (no silent alias)', async () => {
    await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goalArgs({ ...DEADLINE, target_date: '2030-01-01' }, { actionId: ulid(1) })),
      'already-exists',
    );
    const goal = (await profileRef().collection('goals').doc(`${C}_deadline`).get()).data();
    assert.equal(goal.target_date, '2027-06-01');
  });

  // Repair round 1 (codex HIGH): the replay key is the ACTION id, not the
  // first static entry's id, so retries are recognised whichever entry ids
  // were assigned and whichever entries were no-ops.

  test('owner action whose first entry was a no-op: the retry is a replay, not a false noop', async () => {
    await profileRef().collection('curriculum_tracks').doc(C).set({ state: 'active', curriculum_id: C });
    const action = {
      profileId: PROFILE,
      entries: [
        { id: ulid(1), entity: 'mainTrack', entityId: C,
          docs: [{ collection: 'curriculum_tracks', docId: C, fields: { state: 'active' } }] },
        { id: ulid(2), entity: 'goal', entityId: `${C}_deadline`, docs: [goalDoc(DEADLINE)] },
      ],
    };
    const first = await call(fns.ownerOversizedGovernedWrite, action, parentAuth);
    assert.equal(first.action_id, ulid(1));
    assert.deepEqual(first.change_ids, [ulid(2)], 'only the goal changed');
    const retry = await call(fns.ownerOversizedGovernedWrite, action, parentAuth);
    assert.equal(retry.replayed, true);
    assert.equal(retry.noop, false);
    assert.equal(retry.action_id, first.action_id);
    assert.deepEqual(retry.change_ids, first.change_ids);
    assert.equal(retry.at, first.at);
    assert.equal((await changeLog()).length, 1);
  });

  test('owner action with a separate actionId: the retry is a replay keyed on the actionId', async () => {
    const action = ownerAction(ulid(2), 'goal', `${C}_deadline`, [goalDoc(DEADLINE)], { actionId: ulid(1) });
    const first = await call(fns.ownerOversizedGovernedWrite, action, parentAuth);
    assert.equal(first.action_id, ulid(1));
    const retry = await call(fns.ownerOversizedGovernedWrite, action, parentAuth);
    assert.equal(retry.replayed, true);
    assert.deepEqual(retry.change_ids, first.change_ids);
    assert.equal((await changeLog()).length, 1);
  });

  test('a tutor retry by actionId after the change landed is a replay with the stored result', async () => {
    const first = await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    const retry = await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    assert.equal(retry.replayed, true);
    assert.equal(retry.noop, false);
    assert.deepEqual(retry.change_ids, first.change_ids);
    assert.equal(retry.at, first.at);
  });

  test('an entry ULID already used by a different action → already-exists, not an internal error', async () => {
    await call(fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(2), 'goal', `${C}_deadline`, [goalDoc(DEADLINE)], { actionId: ulid(1) }), parentAuth);
    const { error, logs } = await captureLogs(() => call(fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(2), 'mainTrack', C,
        [{ collection: 'curriculum_tracks', docId: C, fields: { state: 'active' } }], { actionId: ulid(3) }),
      parentAuth));
    await expectHttpsError(Promise.reject(error), 'already-exists');
    assertPrivacySafeRejectionLog(logs, { entity: 'mainTrack', code: 'already-exists' });
    assert.equal((await profileRef().collection('curriculum_tracks').doc(C).get()).exists, false);
  });

  test('a tutor actionId equal to another action\'s entry id → already-exists, not an internal error', async () => {
    await call(fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(2), 'goal', `${C}_deadline`, [goalDoc(DEADLINE)], { actionId: ulid(1) }), parentAuth);
    await expectHttpsError(
      call(fns.tutorUpsertTrack, {
        grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, trackId: C,
        trackData: { state: 'active', curriculum_id: C }, actionId: ulid(2),
      }),
      'already-exists',
    );
    assert.equal((await profileRef().collection('curriculum_tracks').doc(C).get()).exists, false);
  });

  // Repair round 2 (codex HIGH): every client action — no-ops included —
  // leaves an immutable receipt holding a canonical request fingerprint.

  test('a no-op action leaves a receipt: a retry after the state changed replays, not re-runs', async () => {
    await profileRef().collection('goals').doc(`${C}_deadline`).set(DEADLINE);
    const first = await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    assert.equal(first.noop, true);
    const receipt = await profileRef().collection('governed_action_receipts').doc(ulid(1)).get();
    assert.equal(receipt.exists, true);
    assert.equal(receipt.get('noop'), true);
    assert.deepEqual(receipt.get('actor'), { uid: TUTOR, role: 'tutor' });
    assert.match(receipt.get('fingerprint'), /^[0-9a-f]{64}$/);
    // Someone else moves the date; the tutor's retry must not write it back.
    await profileRef().collection('goals').doc(`${C}_deadline`).update({ target_date: '2029-01-01' });
    const retry = await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    assert.equal(retry.replayed, true);
    assert.equal(retry.noop, true);
    assert.deepEqual(retry.change_ids, []);
    const goal = (await profileRef().collection('goals').doc(`${C}_deadline`).get()).data();
    assert.equal(goal.target_date, '2029-01-01');
    assert.deepEqual(await changeLog(), []);
  });

  test('same ULID against a different doc whose entity id is derived in the transaction → already-exists', async () => {
    const configs = profileRef().collection('study_day_configs');
    await configs.doc('cfg-a').set({ curriculum_id: C, day_of_week: 1, day_type: 'learn' });
    await configs.doc('cfg-b').set({ curriculum_id: C, day_of_week: 2, day_type: 'learn' });
    const args = (configId) => ({
      grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, configId,
      configData: { day_type: 'rest' }, actionId: ulid(1),
    });
    const first = await call(fns.tutorUpsertStudyDayConfig, args('cfg-a'));
    assert.equal(first.change_ids.length, 1);
    await expectHttpsError(call(fns.tutorUpsertStudyDayConfig, args('cfg-b')), 'already-exists');
    assert.equal((await configs.doc('cfg-b').get()).get('day_type'), 'learn', 'the second doc is not silently skipped');
  });

  test('same ULID with a different doc mode → already-exists', async () => {
    await call(fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(1), 'goal', `${C}_deadline`, [goalDoc(DEADLINE)]), parentAuth);
    await expectHttpsError(call(fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(1), 'goal', `${C}_deadline`, [goalDoc(DEADLINE, 'update')]), parentAuth), 'already-exists');
  });

  test('same ULID with an extra event or a different event payload → already-exists', async () => {
    const ev = (id, ref) => ({ id, fields: {
      kind: 'learn', curriculum_id: C, ref, source: 'main', date_state: 'dated', learned_on: '2026-09-30',
    } });
    const base = { ownerUid: PARENT, profileId: PROFILE, grantId: GRANT, actionId: ulid(9) };
    await helper.writeWithChangeLog(tutorAuth, { ...base, events: [ev(ulid(1), 'Berakhot 1:1')] });
    await expectHttpsError(helper.writeWithChangeLog(tutorAuth,
      { ...base, events: [ev(ulid(1), 'Berakhot 1:2')] }), 'already-exists');
    await expectHttpsError(helper.writeWithChangeLog(tutorAuth,
      { ...base, events: [ev(ulid(1), 'Berakhot 1:1'), ev(ulid(2), 'Berakhot 1:2')] }), 'already-exists');
    const replay = await helper.writeWithChangeLog(tutorAuth, { ...base, events: [ev(ulid(1), 'Berakhot 1:1')] });
    assert.equal(replay.replayed, true);
    assert.deepEqual(replay.event_ids, [ulid(1)]);
  });

  test('an event id reused (no action id) with a different payload → already-exists', async () => {
    const ev = (ref) => ({ id: ulid(1), fields: {
      kind: 'learn', curriculum_id: C, ref, source: 'main', date_state: 'dated', learned_on: '2026-09-30',
    } });
    const base = { ownerUid: PARENT, profileId: PROFILE, grantId: GRANT };
    await helper.writeWithChangeLog(tutorAuth, { ...base, events: [ev('Berakhot 1:1')] });
    await expectHttpsError(
      helper.writeWithChangeLog(tutorAuth, { ...base, events: [ev('Berakhot 1:2')] }), 'already-exists');
    assert.equal((await profileRef().collection('learning_events').doc(ulid(1)).get()).get('ref'), 'Berakhot 1:1');
  });

  test('an action id already carried by a change_log entry with no receipt → already-exists', async () => {
    await profileRef().collection('change_log').doc(ulid(5)).set({
      entity: 'goal', entity_id: `${C}_deadline`, action_id: ulid(1), before: {}, after: {}, actor: { uid: PARENT },
    });
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) })), 'already-exists');
    assert.equal((await profileRef().collection('goals').doc(`${C}_deadline`).get()).exists, false);
  });

  test('a malformed client ULID → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: 'not-a-ulid' })),
      'invalid-argument',
    );
  });
});

// ── AC-2: create claim, field-level merge and atomicity ───────────────────────

describe('writeWithChangeLog — create claim and field-level merge', () => {
  beforeEach(async () => {
    await seedProfile();
    await seedLearningGrant();
  });

  test('a missing target is claimed as a create: before is null per field, last_change_id stamped', async () => {
    const res = await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    assert.deepEqual(res.change_ids, [ulid(1)]);
    const [entry] = await changeLog();
    const key = (f) => `goals/${C}_deadline.${f}`;
    assert.equal(entry.entity, 'goal');
    assert.equal(entry.entity_id, `${C}_deadline`);
    assert.equal(entry.action_id, ulid(1));
    assert.deepEqual(entry.before, { [key('goal_type')]: null, [key('target_date')]: null, [key('curriculum_id')]: null });
    assert.deepEqual(entry.after, {
      [key('goal_type')]: 'deadline', [key('target_date')]: '2027-06-01', [key('curriculum_id')]: C,
    });
    assert.equal(res.at, entry.at.toDate().toISOString(), 'returns the server-stamped at');
    const goal = (await profileRef().collection('goals').doc(`${C}_deadline`).get()).data();
    assert.equal(goal.last_change_id, ulid(1));
    for (const key of retiredKeysOf(GOAL_REPOSITORY)) assert.equal(goal[key], undefined, key);
  });

  test('an existing target is an ordinary update: only changed fields logged, unrelated fields survive', async () => {
    await profileRef().collection('goals').doc(`${C}_deadline`).set({
      ...DEADLINE, last_change_id: ulid(0), legacy_note: 'keep me',
    });
    await call(fns.tutorUpsertGoal, goalArgs({ ...DEADLINE, target_date: '2028-01-01' }, { actionId: ulid(1) }));
    const [entry] = await changeLog();
    assert.deepEqual(entry.before, { [`goals/${C}_deadline.target_date`]: '2027-06-01' });
    assert.deepEqual(entry.after, { [`goals/${C}_deadline.target_date`]: '2028-01-01' });
    const goal = (await profileRef().collection('goals').doc(`${C}_deadline`).get()).data();
    assert.equal(goal.legacy_note, 'keep me');
    assert.equal(goal.target_date, '2028-01-01');
    assert.equal(goal.last_change_id, ulid(1));
  });

  test('an unchanged payload writes nothing and logs nothing (noop)', async () => {
    await profileRef().collection('goals').doc(`${C}_deadline`).set({ ...DEADLINE, last_change_id: ulid(0) });
    const res = await call(fns.tutorUpsertGoal, goalArgs(DEADLINE, { actionId: ulid(1) }));
    assert.equal(res.noop, true);
    assert.deepEqual(await changeLog(), []);
  });

  test('an explicit create of an existing doc is rejected, not overwritten', async () => {
    await profileRef().collection('goals').doc(`${C}_deadline`).set({ ...DEADLINE, last_change_id: ulid(0) });
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite,
        ownerAction(ulid(1), 'goal', `${C}_deadline`,
          [goalDoc({ ...DEADLINE, target_date: '2030-01-01' }, 'create')]),
        parentAuth),
      'already-exists',
    );
    const goal = (await profileRef().collection('goals').doc(`${C}_deadline`).get()).data();
    assert.equal(goal.target_date, '2027-06-01');
  });

  test('competing creates: exactly one claims the doc, the other cannot overwrite it; retry is idempotent', async () => {
    const a = ownerAction(ulid(1), 'goal', `${C}_deadline`, [goalDoc(DEADLINE, 'create')]);
    const b = ownerAction(ulid(2), 'goal', `${C}_deadline`,
      [goalDoc({ ...DEADLINE, target_date: '2030-01-01' }, 'create')]);
    const results = await Promise.allSettled([
      call(fns.ownerOversizedGovernedWrite, a, parentAuth),
      call(fns.ownerOversizedGovernedWrite, b, parentAuth),
    ]);
    const won = results.filter((r) => r.status === 'fulfilled');
    const lost = results.filter((r) => r.status === 'rejected');
    assert.equal(won.length, 1);
    assert.equal(lost.length, 1);
    assert.equal(lost[0].reason.code, 'already-exists');
    const winner = won[0].value.action_id;
    const goal = (await profileRef().collection('goals').doc(`${C}_deadline`).get()).data();
    assert.equal(goal.last_change_id, winner);
    assert.equal(goal.target_date, winner === ulid(1) ? '2027-06-01' : '2030-01-01');
    assert.deepEqual((await changeLog()).map((e) => e.id), [winner]);
    // The winner's retry returns its stored result.
    const retry = await call(fns.ownerOversizedGovernedWrite, winner === ulid(1) ? a : b, parentAuth);
    assert.equal(retry.replayed, true);
  });

  test('an update-mode patch of a missing doc → not-found', async () => {
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite,
        ownerAction(ulid(1), 'goal', `${C}_deadline`, [goalDoc(DEADLINE, 'update')]), parentAuth),
      'not-found',
    );
  });

  test('multi-entity action is atomic: an invalid second entity writes nothing of the first', async () => {
    await profileRef().collection('profile_programs').doc('tanach').set({
      program_id: 'nach_yomi', tracking_start_date: '2026-01-01', curriculum_id: 'tanach',
    });
    const action = {
      profileId: PROFILE,
      entries: [
        { id: ulid(1), entity: 'mainTrack', entityId: C,
          docs: [{ collection: 'curriculum_tracks', docId: C, fields: { state: 'active' } }] },
        { id: ulid(2), entity: 'goal', entityId: 'tanach_deadline',
          docs: [{ collection: 'goals', docId: 'tanach_deadline',
            fields: { goal_type: 'deadline', target_date: '2027-01-01', curriculum_id: 'tanach' } }] },
      ],
    };
    await expectHttpsError(call(fns.ownerOversizedGovernedWrite, action, parentAuth), 'failed-precondition');
    assert.equal((await profileRef().collection('curriculum_tracks').doc(C).get()).exists, false);
    assert.deepEqual(await changeLog(), []);
  });

  test('multi-entity action: one entry per entity, all sharing the action_id', async () => {
    const res = await call(fns.ownerOversizedGovernedWrite, {
      profileId: PROFILE,
      entries: [
        { id: ulid(1), entity: 'mainTrack', entityId: C,
          docs: [{ collection: 'curriculum_tracks', docId: C, fields: { state: 'active' } }] },
        { id: ulid(2), entity: 'goal', entityId: `${C}_deadline`, docs: [goalDoc(DEADLINE)] },
      ],
    }, parentAuth);
    assert.deepEqual(res.change_ids, [ulid(1), ulid(2)]);
    const entries = await changeLog();
    assert.deepEqual(entries.map((e) => [e.entity, e.action_id]), [['mainTrack', ulid(1)], ['goal', ulid(1)]]);
  });
});

// ── AC-5: ownerOversizedGovernedWrite ─────────────────────────────────────────

describe('ownerOversizedGovernedWrite', () => {
  const order = () => profileRef().collection('track_learning_order');
  const refs = Array.from({ length: 25 }, (_, i) => `Tractate ${String(i).padStart(2, '0')}`);
  const orderId = (ref) => `${C}_masechet_${ref}`;

  beforeEach(async () => {
    await seedProfile();
    const batch = db.batch();
    refs.forEach((ref, i) => batch.set(order().doc(orderId(ref)), {
      curriculum_id: C, level: 'masechet', ref, user_sort_order: i, last_change_id: ulid(0),
    }));
    await batch.commit();
  });

  test('is exported from functions/src/index.ts', () => {
    assert.equal(typeof fns.ownerOversizedGovernedWrite, 'function');
  });

  test('reorders 25 order docs online in one transaction with one mainTrackOrder entry', async () => {
    const docs = refs.map((ref, i) => ({
      collection: 'track_learning_order', docId: orderId(ref),
      fields: { user_sort_order: (i + 1) % 25 },
    }));
    const before = Date.now();
    const res = await call(fns.ownerOversizedGovernedWrite,
      ownerAction(ulid(1), 'mainTrackOrder', C, docs), parentAuth);
    assert.deepEqual(res.change_ids, [ulid(1)]);
    const entries = await changeLog();
    assert.equal(entries.length, 1);
    const [entry] = entries;
    assert.equal(entry.entity, 'mainTrackOrder');
    assert.equal(entry.entity_id, C);
    assert.equal(Object.keys(entry.after).length, 25);
    assert.equal(entry.before[`track_learning_order/${orderId(refs[0])}.user_sort_order`], 0);
    assert.equal(entry.after[`track_learning_order/${orderId(refs[0])}.user_sort_order`], 1);
    const at = Date.parse(res.at);
    assert.ok(at >= before - 60_000 && at <= Date.now() + 60_000, 'server-stamped at');
    const stored = await order().get();
    assert.equal(stored.size, 25);
    for (const d of stored.docs) {
      const i = refs.indexOf(d.get('ref'));
      assert.equal(d.get('user_sort_order'), (i + 1) % 25);
      assert.equal(d.get('last_change_id'), ulid(1));
      assert.equal(d.get('curriculum_id'), C);
    }
  });

  test('a write over the per-call ceiling is rejected and writes neither order docs nor history', async () => {
    const docs = Array.from({ length: 451 }, (_, i) => ({
      collection: 'track_learning_order', docId: `${C}_daf_${i}`,
      fields: { curriculum_id: C, level: 'daf', ref: `Daf ${i}`, user_sort_order: i },
    }));
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite, ownerAction(ulid(1), 'mainTrackOrder', C, docs), parentAuth),
      'invalid-argument',
    );
    assert.equal((await order().get()).size, 25);
    assert.deepEqual(await changeLog(), []);
  });

  test('a tutor (even with an active can_edit_learning grant) is rejected', async () => {
    await seedLearningGrant();
    const action = ownerAction(ulid(1), 'mainTrackOrder', C, [{
      collection: 'track_learning_order', docId: orderId(refs[0]), fields: { user_sort_order: 7 },
    }]);
    const { error, logs } = await captureLogs(() => call(fns.ownerOversizedGovernedWrite,
      { ...action, ownerUid: PARENT, grantId: GRANT }, tutorAuth));
    await expectHttpsError(Promise.reject(error), 'permission-denied');
    assertPrivacySafeRejectionLog(logs, { entity: 'mainTrackOrder', code: 'permission-denied' });
    // Without ownerUid the tutor can only address its own (non-existent) path.
    await expectHttpsError(call(fns.ownerOversizedGovernedWrite, action, tutorAuth), 'not-found');
    assert.equal((await order().doc(orderId(refs[0])).get()).get('user_sort_order'), 0);
    assert.deepEqual(await changeLog(), []);
  });

  test('unauthenticated → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite, ownerAction(ulid(1), 'mainTrackOrder', C, []), null),
      'unauthenticated',
    );
  });

  test('replaying the reorder with the same ULID returns the stored result', async () => {
    const docs = refs.map((ref, i) => ({
      collection: 'track_learning_order', docId: orderId(ref), fields: { user_sort_order: 24 - i },
    }));
    const first = await call(fns.ownerOversizedGovernedWrite, ownerAction(ulid(1), 'mainTrackOrder', C, docs), parentAuth);
    const again = await call(fns.ownerOversizedGovernedWrite, ownerAction(ulid(1), 'mainTrackOrder', C, docs), parentAuth);
    assert.equal(again.replayed, true);
    assert.equal(again.at, first.at);
    assert.equal((await changeLog()).length, 1);
  });
});

// ── Wire contract fixture (shared with the Dart port codec, Story 1.8) ────────

describe('ownerOversizedGovernedWrite — wire contract fixture', () => {
  const fixture = JSON.parse(readFileSync(
    new URL('../../test/fixtures/governed_write_contract/owner_governed_action.json', import.meta.url),
    'utf8',
  ));
  const bind = (req) => JSON.parse(JSON.stringify(req).replaceAll('{{PROFILE}}', PROFILE));

  beforeEach(async () => {
    await seedProfile();
  });

  for (const example of fixture.valid) {
    test(`valid: ${example.name}`, async () => {
      const res = await call(fns.ownerOversizedGovernedWrite, bind(example.request), parentAuth);
      assert.deepEqual(res.change_ids, example.expect.change_ids);
      assert.equal(res.action_id, example.expect.action_id);
    });
  }

  for (const example of fixture.invalid) {
    test(`invalid: ${example.name} → ${example.code}`, async () => {
      await expectHttpsError(call(fns.ownerOversizedGovernedWrite, bind(example.request), parentAuth), example.code);
      assert.deepEqual(await changeLog(), []);
    });
  }
});

// ── Story 2.1 / DNI-492 — sub-track create claim, replay and AD-45 ──────────
// The callable is the only path that CLAIMS a create (ruling B6); the owner
// offline path is an ordinary doc + entry batch (rules suite). Windows are
// open-ended from 2020 so the cases count on any run date.

describe('writeWithChangeLog — sub-track create claim, replay and AD-45 (DNI-492)', () => {
  const SC = 'shas';
  const track = (overrides = {}) => ({
    curriculum_id: SC, name: 'Night seder', type: 'ongoing', window_start: '2020-01-01',
    rate_per_week: 5, weeks_per_year: 40, learns_on_shabbos: false,
    ground: [{ level: 'masechta', ref: 'Berakhot' }], ...overrides,
  });
  const subTrackAction = (entryId, docId, fields, mode) =>
    ownerAction(entryId, 'subTrack', docId, [{ collection: 'sub_tracks', docId, fields, ...(mode ? { mode } : {}) }]);
  const subTracks = () => profileRef().collection('sub_tracks');
  const seedTracks = async (n, overrides = {}) => {
    for (let i = 0; i < n; i++) {
      await subTracks().doc(ulid(900 + i)).set({ ...track(overrides), last_change_id: ulid(0) });
    }
  };
  async function expectViolation(promise, code, violations) {
    await assert.rejects(promise, (err) => {
      assert.equal(err.code ?? err.httpErrorCode?.canonicalName, code, err.message);
      assert.deepEqual(err.details?.sub_track_violations, violations);
      return true;
    });
  }

  beforeEach(async () => {
    await seedProfile();
  });

  test('claims an absent sub-track: before null per field, last_change_id stamped', async () => {
    const id = ulid(500);
    const res = await call(fns.ownerOversizedGovernedWrite, subTrackAction(ulid(1), id, track(), 'create'), parentAuth);
    assert.deepEqual(res.change_ids, [ulid(1)]);
    const [entry] = await changeLog();
    assert.equal(entry.entity, 'subTrack');
    assert.equal(entry.entity_id, id);
    for (const v of Object.values(entry.before)) assert.equal(v, null);
    assert.equal(entry.after[`sub_tracks/${id}.name`], 'Night seder');
    const doc = (await subTracks().doc(id).get()).data();
    assert.equal(doc.last_change_id, ulid(1));
    assert.equal(doc.rate_per_week, 5);
  });

  test('an identical ULID replay returns the stored result and writes nothing new', async () => {
    const id = ulid(500);
    const action = subTrackAction(ulid(1), id, track(), 'create');
    const first = await call(fns.ownerOversizedGovernedWrite, action, parentAuth);
    const again = await call(fns.ownerOversizedGovernedWrite, action, parentAuth);
    assert.equal(again.replayed, true);
    assert.deepEqual(again.change_ids, first.change_ids);
    assert.equal((await changeLog()).length, 1);
  });

  test('a non-replay create of an existing sub-track is rejected, not overwritten', async () => {
    const id = ulid(500);
    await call(fns.ownerOversizedGovernedWrite, subTrackAction(ulid(1), id, track(), 'create'), parentAuth);
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite, subTrackAction(ulid(2), id, track({ name: 'Other' }), 'create'), parentAuth),
      'already-exists',
    );
    assert.equal((await subTracks().doc(id).get()).data().name, 'Night seder');
  });

  test('a sixth counting ongoing sub-track → failed-precondition ongoing_limit, nothing written', async () => {
    await seedTracks(5);
    await expectViolation(
      call(fns.ownerOversizedGovernedWrite, subTrackAction(ulid(1), ulid(500), track()), parentAuth),
      'failed-precondition', ['ongoing_limit'],
    );
    assert.equal((await subTracks().doc(ulid(500)).get()).exists, false);
    assert.deepEqual(await changeLog(), []);
  });

  test('ended and passed-window sub-tracks do not count toward the cap', async () => {
    await seedTracks(4);
    await subTracks().doc(ulid(950)).set({ ...track({ window_end: '2020-06-30' }), last_change_id: ulid(0) });
    await subTracks().doc(ulid(951)).set({
      ...track(), ended_at: new Date('2021-01-01T00:00:00Z'), end_reason: 'ended', last_change_id: ulid(0),
    });
    const res = await call(fns.ownerOversizedGovernedWrite, subTrackAction(ulid(1), ulid(500), track()), parentAuth);
    assert.deepEqual(res.change_ids, [ulid(1)]);
  });

  test('editing one of six reconciled ongoing sub-tracks (name only) is tolerated', async () => {
    await seedTracks(6);
    const res = await call(fns.ownerOversizedGovernedWrite,
      subTrackAction(ulid(1), ulid(900), { name: 'Renamed' }, 'update'), parentAuth);
    assert.deepEqual(res.change_ids, [ulid(1)]);
  });

  test('a create on a calendar-program curriculum → calendar_program_curriculum', async () => {
    await profileRef().collection('profile_programs').doc(SC).set({
      curriculum_id: SC, program_id: 'daf_yomi', tracking_start_date: '2026-01-01', last_change_id: ulid(0),
    });
    await expectViolation(
      call(fns.ownerOversizedGovernedWrite, subTrackAction(ulid(1), ulid(500), track()), parentAuth),
      'failed-precondition', ['calendar_program_curriculum'],
    );
    assert.deepEqual(await changeLog(), []);
  });

  test('setting a calendar program on a curriculum with a non-ended sub-track → calendar_program_has_sub_tracks', async () => {
    await seedTracks(1);
    await expectViolation(
      call(fns.ownerOversizedGovernedWrite, ownerAction(ulid(1), 'mainTrackProgram', SC, [{
        collection: 'profile_programs', docId: SC,
        fields: { curriculum_id: SC, program_id: 'daf_yomi', tracking_start_date: '2026-01-01' },
      }]), parentAuth),
      'failed-precondition', ['calendar_program_has_sub_tracks'],
    );
    assert.equal((await profileRef().collection('profile_programs').doc(SC).get()).exists, false);
  });

  test('a calendar program is allowed once every sub-track is ended', async () => {
    await subTracks().doc(ulid(900)).set({
      ...track(), ended_at: new Date('2021-01-01T00:00:00Z'), end_reason: 'deleted', last_change_id: ulid(0),
    });
    const res = await call(fns.ownerOversizedGovernedWrite, ownerAction(ulid(1), 'mainTrackProgram', SC, [{
      collection: 'profile_programs', docId: SC,
      fields: { curriculum_id: SC, program_id: 'daf_yomi', tracking_start_date: '2026-01-01' },
    }]), parentAuth);
    assert.deepEqual(res.change_ids, [ulid(1)]);
  });

  test('malformed intent → invalid-argument naming each rule (AC-5)', async () => {
    await expectViolation(
      call(fns.ownerOversizedGovernedWrite, subTrackAction(ulid(1), ulid(500), track({
        ground: [{ level: 'masechta', ref: 'Berakhot' }, { level: 'masechta', ref: 'Berakhot' }],
        rate_per_week: 0, window_end: '2019-01-01',
      })), parentAuth),
      'invalid-argument', ['duplicate_ground', 'non_positive_rate', 'window_reversed'],
    );
    assert.deepEqual(await changeLog(), []);
  });

  test('ending a sub-track over the cap is always allowed (tombstones skip limits)', async () => {
    await seedTracks(6);
    const res = await call(fns.ownerOversizedGovernedWrite,
      subTrackAction(ulid(1), ulid(905), { ended_at: true, end_reason: 'ended' }, 'update'), parentAuth);
    assert.deepEqual(res.change_ids, [ulid(1)]);
    assert.equal((await subTracks().doc(ulid(905)).get()).data().end_reason, 'ended');
  });

  // AD-52 lifecycle pair: ended_at and end_reason are written, cleared and
  // judged together, including on a tombstoned doc.
  describe('ended_at / end_reason are a coupled pair', () => {
    const ENDED_AT = new Date('2021-01-01T00:00:00Z');
    const seedEnded = (reason = 'ended') =>
      subTracks().doc(ulid(900)).set({ ...track(), ended_at: ENDED_AT, end_reason: reason, last_change_id: ulid(0) });
    const update = (fields) =>
      call(fns.ownerOversizedGovernedWrite, subTrackAction(ulid(1), ulid(900), fields, 'update'), parentAuth);
    async function expectRejectedUnchanged(promise, stored) {
      await expectHttpsError(promise, 'invalid-argument');
      const doc = (await subTracks().doc(ulid(900)).get()).data();
      assert.equal(doc.end_reason, stored.end_reason);
      assert.equal(doc.ended_at === undefined, stored.ended_at === undefined);
      assert.deepEqual(await changeLog(), []);
    }

    test('ended_at without end_reason → invalid-argument', async () => {
      await seedTracks(1);
      await expectRejectedUnchanged(update({ ended_at: true }), {});
    });

    test('end_reason on a live sub-track → invalid-argument', async () => {
      await seedTracks(1);
      await expectRejectedUnchanged(update({ end_reason: 'deleted' }), {});
    });

    test('clearing ended_at but leaving end_reason → invalid-argument', async () => {
      await seedEnded();
      await expectRejectedUnchanged(update({ ended_at: null }), { end_reason: 'ended', ended_at: ENDED_AT });
    });

    test('clearing end_reason but leaving ended_at → invalid-argument', async () => {
      await seedEnded();
      await expectRejectedUnchanged(update({ end_reason: null }), { end_reason: 'ended', ended_at: ENDED_AT });
    });

    test('rewriting the end_reason of an ended sub-track → invalid-argument', async () => {
      await seedEnded();
      await expectRejectedUnchanged(update({ end_reason: 'deleted' }), { end_reason: 'ended', ended_at: ENDED_AT });
    });

    test('re-add clears both → accepted, live with no end_reason', async () => {
      await seedEnded();
      const res = await update({ ended_at: null, end_reason: null });
      assert.deepEqual(res.change_ids, [ulid(1)]);
      const doc = (await subTracks().doc(ulid(900)).get()).data();
      assert.equal(doc.ended_at, undefined);
      assert.equal(doc.end_reason, undefined);
    });

    test('a repeated tombstone of an ended sub-track is a no-op that keeps its reason', async () => {
      await seedEnded('ended');
      await update({ ended_at: true, end_reason: 'deleted' });
      assert.equal((await subTracks().doc(ulid(900)).get()).data().end_reason, 'ended');
      assert.deepEqual(await changeLog(), []);
    });
  });
});

// ── DNI-512 (Story 4.4) AC-2 — a parent revoke stops every tutor callable ─────
// The grant is re-read by writeWithChangeLog on every call (AD-38 callable
// contract, AD-53), so after the parent's real `revokeTutorGrant` commits,
// the tutor's next call is `permission-denied` and writes nothing — even
// though the tutor device still holds the grant as active (it sends the same
// routing it used a moment ago, and has not seen the revocation).

describe('DNI-512 AC-2 — revoked grant is rejected on every governed callable', () => {
  const SC = 'shas';
  const SUB = ulid(500);
  const ONGOING = {
    curriculum_id: SC,
    name: 'Rebbe Gemara',
    type: 'ongoing',
    window_start: '2026-09-01',
    rate_per_week: 5,
    weeks_per_year: 40,
    learns_on_shabbos: false,
    ground: [{ level: 'masechta', ref: 'Berakhot' }],
  };
  // What the tutor device cached while the grant was active: never refreshed.
  const staleRouting = Object.freeze({ grantId: GRANT, ownerUid: PARENT, profileId: PROFILE });
  const learn = (id, ref) => ({
    id,
    fields: {
      kind: 'learn', curriculum_id: SC, ref, source: 'main',
      date_state: 'dated', learned_on: '2026-10-01',
    },
  });
  const LEARNER_COLLECTIONS = [
    'sub_tracks', 'learning_events', 'goals', 'change_log',
    'points_ledger', 'governed_action_receipts',
  ];

  async function everything() {
    const out = {};
    for (const name of LEARNER_COLLECTIONS) {
      const snap = await profileRef().collection(name).get();
      for (const d of snap.docs) out[`${name}/${d.id}`] = d.data();
    }
    const audit = await db.collection('tutor_grants').doc(GRANT).collection('audit_log').get();
    out.auditCount = audit.size;
    return out;
  }

  const calls = {
    tutorRecordLearning: () => call(fns.tutorRecordLearning, { ...staleRouting, events: [learn(ulid(510), 'Berakhot 3a')] }),
    tutorVoidLearning: () => call(fns.tutorVoidLearning, { ...staleRouting, eventId: ulid(511), targetId: ulid(501) }),
    tutorUnlearn: () => call(fns.tutorUnlearn, { ...staleRouting, actionId: ulid(512), curriculumId: SC, leafSet: ['Berakhot 2a'] }),
    'tutorUpsertSubTrack (edit)': () => call(fns.tutorUpsertSubTrack, {
      ...staleRouting, op: 'edit', subTrackId: SUB, fields: { rate_per_week: 6 }, actionId: ulid(513),
    }),
    'tutorUpsertSubTrack (create)': () => call(fns.tutorUpsertSubTrack, {
      ...staleRouting, op: 'create', subTrackId: ulid(514), fields: { ...ONGOING, name: 'Second' },
    }),
    'tutorUpsertSubTrack (end)': () => call(fns.tutorUpsertSubTrack, {
      ...staleRouting, op: 'end', subTrackId: SUB, actionId: ulid(515),
    }),
    tutorUpsertGoal: () => call(fns.tutorUpsertGoal, {
      ...staleRouting, goalId: `${SC}_deadline`,
      goalData: { goal_type: 'deadline', target_date: '2028-01-01', curriculum_id: SC },
      actionId: ulid(516),
    }),
  };

  beforeEach(async () => {
    await seedProfile();
    await seedLearningGrant();
    // While active, the tutor authors a sub-track, a learn event and a goal.
    await call(fns.tutorUpsertSubTrack, { ...staleRouting, op: 'create', subTrackId: SUB, fields: ONGOING });
    await call(fns.tutorRecordLearning, { ...staleRouting, events: [learn(ulid(501), 'Berakhot 2a')] });
    await call(fns.tutorUpsertGoal, {
      ...staleRouting, goalId: `${SC}_deadline`,
      goalData: { goal_type: 'deadline', target_date: '2027-06-01', curriculum_id: SC },
      actionId: ulid(502),
    });
  });

  for (const [name, invoke] of Object.entries(calls)) {
    test(`${name} after the parent revokes → permission-denied, nothing written`, async () => {
      await call(fns.revokeTutorGrant, { grantId: GRANT }, parentAuth);
      const before = await everything();
      const { error, logs } = await captureLogs(invoke);
      await expectHttpsError(Promise.reject(error), 'permission-denied');
      assert.ok(
        logs.some((l) => l.entry.message === 'governed_write_rejected' && l.entry.code === 'permission-denied'),
        'the rejection is the helper\'s own grant check',
      );
      assert.deepEqual(await everything(), before, 'no governed doc, event, entry or audit row is written');
    });
  }

  test('a revoke racing an in-flight edit: committed-before is kept whole, after is denied', async () => {
    const edit = (rate, id) => call(fns.tutorUpsertSubTrack, {
      ...staleRouting, op: 'edit', subTrackId: SUB, fields: { rate_per_week: rate }, actionId: id,
    });
    const [revoke, raced] = await Promise.allSettled([
      call(fns.revokeTutorGrant, { grantId: GRANT }, parentAuth),
      edit(7, ulid(520)),
    ]);
    assert.equal(revoke.status, 'fulfilled');
    const sub = (await profileRef().collection('sub_tracks').doc(SUB).get()).data();
    const entryIds = (await changeLog()).map((e) => e.id);
    if (raced.status === 'fulfilled') {
      // Committed before the revoke: the doc and its entry are both kept.
      assert.equal(sub.rate_per_week, 7);
      assert.equal(sub.last_change_id, ulid(520));
      assert.ok(entryIds.includes(ulid(520)));
    } else {
      // Evaluated after the revoke: denied, no partial write.
      await expectHttpsError(Promise.reject(raced.reason), 'permission-denied');
      assert.equal(sub.rate_per_week, ONGOING.rate_per_week);
      assert.ok(!entryIds.includes(ulid(520)));
    }
    // Every sub-track doc's last_change_id has its entry (no half write).
    assert.ok(entryIds.includes(sub.last_change_id));
    // Whatever the race outcome, the next call is denied.
    await expectHttpsError(edit(8, ulid(521)), 'permission-denied');
  });
});
