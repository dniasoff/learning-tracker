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
    ['retired target_percent', { ...DEADLINE, target_percent: 50 }],
    ['camelCase drift', { goalType: 'deadline', targetDate: '2027-06-01' }],
    ['malformed date', { ...DEADLINE, target_date: 'next summer' }],
    ['impossible date', { ...DEADLINE, target_date: '2027-02-30' }],
    ['goal_type not matching the fixed id', { ...DEADLINE, goal_type: 'pace' }],
    ['deadline goal without a target_date', { goal_type: 'deadline', curriculum_id: C }],
    ['curriculum_id not matching the fixed id', { ...DEADLINE, curriculum_id: 'tanach' }],
    ['client-written last_change_id', { ...DEADLINE, last_change_id: ulid(9) }],
    ['ended_at as a client timestamp', { ...DEADLINE, ended_at: '2026-01-01T00:00:00Z' }],
  ];
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
    id, fields: { kind: 'learn', curriculum_id: C, ref: 'Berakhot 1:1', source: 'main', date_state: 'dated' },
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

  test('an event id replayed by the same actor is a no-op; by another actor → already-exists', async () => {
    await helper.writeWithChangeLog(tutorAuth, tutorReq([learn(ulid(1))]));
    const replay = await helper.writeWithChangeLog(tutorAuth, tutorReq([learn(ulid(1))]));
    assert.deepEqual(replay.event_ids, []);
    await expectHttpsError(
      helper.writeWithChangeLog(parentAuth, { ownerUid: PARENT, profileId: PROFILE, events: [learn(ulid(1))] }),
      'already-exists',
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
    assert.equal(goal.updated_at, undefined);
    assert.equal(goal.synced_at, undefined);
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
