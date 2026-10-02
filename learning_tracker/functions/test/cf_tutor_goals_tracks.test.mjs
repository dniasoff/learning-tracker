// CF tests — tutor goal and main-track callables, rerouted through
// writeWithChangeLog (sub-tracks AD-38 / AD-53, Story 1.10 / DNI-472, AC-3/AC-6):
//   tutorUpsertGoal, tutorDeleteGoal, tutorUpsertTrack, tutorDeleteTrack
// The shared rejection matrix lives in _governed_contract.mjs; this file adds
// the owner-shaped entries, tombstones and the remove-track action.
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  GRANT,
  PARENT,
  PROFILE,
  call,
  changeLog,
  clearFirestore,
  db,
  fns,
  parentAuth,
  profileRef,
  seedLearningGrant,
  seedProfile,
  ulid,
} from './_cf_helpers.mjs';
import { describeGovernedContract } from './_governed_contract.mjs';

const C = 'mishnah';
const base = { grantId: GRANT, ownerUid: PARENT, profileId: PROFILE };
const DEADLINE = { goal_type: 'deadline', target_date: '2027-06-01', curriculum_id: C };
const goals = () => profileRef().collection('goals');
const tracks = () => profileRef().collection('curriculum_tracks');
const subTracks = () => profileRef().collection('sub_tracks');

/** Strips the per-call parts of an entry so owner/tutor shapes can be compared. */
const shapeOf = ({ entity, entity_id, before, after }) => ({ entity, entity_id, before, after });

describeGovernedContract('tutorUpsertGoal', {
  goodArgs: { ...base, goalId: `${C}_deadline`, goalData: DEADLINE },
  idParam: 'goalId', dataParam: 'goalData', entity: 'goal',
});

describeGovernedContract('tutorDeleteGoal', {
  goodArgs: { ...base, goalId: `${C}_deadline` },
  idParam: 'goalId', entity: 'goal',
  seed: () => goals().doc(`${C}_deadline`).set(DEADLINE),
});

describeGovernedContract('tutorUpsertTrack', {
  goodArgs: { ...base, trackId: C, trackData: { state: 'active' } },
  idParam: 'trackId', dataParam: 'trackData', entity: 'mainTrack',
});

describeGovernedContract('tutorDeleteTrack', {
  goodArgs: { ...base, trackId: C },
  idParam: 'trackId', entity: 'mainTrack',
  seed: () => tracks().doc(C).set({ state: 'active', curriculum_id: C }),
});

describe('tutor goal / track callables — AC-3 behaviour', () => {
  beforeEach(async () => {
    await clearFirestore();
    await seedProfile();
    await seedLearningGrant();
  });

  test('tutorUpsertGoal produces an entry identical in shape to the owner path', async () => {
    await call(fns.tutorUpsertGoal, { ...base, goalId: `${C}_deadline`, goalData: DEADLINE, actionId: ulid(1) });
    const [tutorEntry] = await changeLog();
    assert.deepEqual(Object.keys(tutorEntry).sort(),
      ['action_id', 'actor', 'after', 'at', 'before', 'entity', 'entity_id', 'id']);

    await clearFirestore();
    await seedProfile();
    await call(fns.ownerOversizedGovernedWrite, {
      profileId: PROFILE,
      entries: [{ id: ulid(2), entity: 'goal', entityId: `${C}_deadline`,
        docs: [{ collection: 'goals', docId: `${C}_deadline`, fields: DEADLINE }] }],
    }, parentAuth);
    const [ownerEntry] = await changeLog();
    assert.deepEqual(shapeOf(tutorEntry), shapeOf(ownerEntry));
    assert.deepEqual(Object.keys(ownerEntry).sort(), Object.keys(tutorEntry).sort());
  });

  test('tutorUpsertGoal drops legacy bookkeeping keys and normalises an ISO target_date', async () => {
    const res = await call(fns.tutorUpsertGoal, {
      ...base, goalId: `${C}_deadline`,
      goalData: { ...DEADLINE, target_date: '2027-06-01T00:00:00.000Z', profile_id: PROFILE },
    });
    assert.equal(res.success, true);
    const goal = (await goals().doc(`${C}_deadline`).get()).data();
    assert.equal(goal.target_date, '2027-06-01');
    assert.equal(goal.profile_id, undefined);
  });

  // DNI-484 (R16): every retired goal key — target_percent, its camelCase
  // alias and the governed timestamps (both spellings) — is rejected, never
  // silently dropped, and nothing is written.
  test('tutorUpsertGoal rejects each R16 retired goal field, aliases included', async () => {
    for (const [key, value] of [
      ['target_percent', 80], ['targetPercent', 80],
      ['updated_at', '2026-01-01T00:00:00Z'], ['updatedAt', '2026-01-01T00:00:00Z'],
      ['synced_at', '2026-01-01T00:00:00Z'], ['syncedAt', '2026-01-01T00:00:00Z'],
    ]) {
      await assert.rejects(
        call(fns.tutorUpsertGoal, { ...base, goalId: `${C}_deadline`, goalData: { ...DEADLINE, [key]: value } }),
        (e) => e.code === 'invalid-argument', key);
    }
    assert.deepEqual(await changeLog(), []);
    assert.equal((await goals().doc(`${C}_deadline`).get()).exists, false);
  });

  test('tutorUpsertGoal still accepts the live deadline and pace fields', async () => {
    await call(fns.tutorUpsertGoal, { ...base, goalId: `${C}_deadline`, goalData: DEADLINE });
    await call(fns.tutorUpsertGoal, {
      ...base, goalId: `${C}_pace`,
      goalData: { goal_type: 'pace', pace_value: 2, pace_unit: 'per_day', pace_granularity: 'daf', curriculum_id: C },
    });
    const pace = (await goals().doc(`${C}_pace`).get()).data();
    assert.equal(pace.pace_value, 2);
    assert.equal(pace.pace_unit, 'per_day');
    assert.equal(pace.pace_granularity, 'daf');
    assert.equal((await changeLog()).length, 2);
  });

  test('tutorDeleteGoal tombstones (ended_at) instead of deleting, and logs it', async () => {
    await goals().doc(`${C}_deadline`).set({ ...DEADLINE, last_change_id: ulid(0) });
    const res = await call(fns.tutorDeleteGoal, { ...base, goalId: `${C}_deadline`, actionId: ulid(1) });
    const goal = await goals().doc(`${C}_deadline`).get();
    assert.equal(goal.exists, true, 'a governed doc is never hard-deleted');
    assert.ok(goal.get('ended_at') instanceof Object && goal.get('ended_at').toDate);
    assert.equal(goal.get('last_change_id'), ulid(1));
    assert.equal(goal.get('target_date'), '2027-06-01', 'the tombstone keeps the config');
    const [entry] = await changeLog();
    const key = `goals/${C}_deadline.ended_at`;
    assert.deepEqual(entry.before, { [key]: null });
    assert.equal(entry.after[key].toMillis(), goal.get('ended_at').toMillis());
    assert.equal(res.at, entry.at.toDate().toISOString());
  });

  test('tutorDeleteGoal of an already-ended or absent goal is a no-op success', async () => {
    const absent = await call(fns.tutorDeleteGoal, { ...base, goalId: `${C}_pace` });
    assert.equal(absent.noop, true);
    await goals().doc(`${C}_deadline`).set({ ...DEADLINE, ended_at: new Date('2026-01-01') });
    const ended = await call(fns.tutorDeleteGoal, { ...base, goalId: `${C}_deadline` });
    assert.equal(ended.noop, true);
    assert.deepEqual(await changeLog(), []);
  });

  test('tutorDeleteGoal can tombstone a legacy (pre-AD-43 id) goal', async () => {
    await goals().doc('goal-1').set({ curriculum_id: C, description: 'legacy' });
    const res = await call(fns.tutorDeleteGoal, { ...base, goalId: 'goal-1' });
    assert.equal(res.change_ids.length, 1);
    assert.ok((await goals().doc('goal-1').get()).get('ended_at'));
  });

  test('tutorUpsertTrack writes a mainTrack entry keyed by the curriculum id', async () => {
    await call(fns.tutorUpsertTrack, { ...base, trackId: C, trackData: { state: 'active' }, actionId: ulid(1) });
    const [entry] = await changeLog();
    assert.equal(entry.entity, 'mainTrack');
    assert.equal(entry.entity_id, C);
    assert.deepEqual(entry.after, {
      [`curriculum_tracks/${C}.state`]: 'active',
      [`curriculum_tracks/${C}.curriculum_id`]: C,
    });
    const track = (await tracks().doc(C).get()).data();
    assert.equal(track.curriculum_id, C, 'the server derives the required curriculum_id');
    assert.equal(track.last_change_id, ulid(1));
  });

  test('tutorUpsertTrack rejects retired track fields and invalid states', async () => {
    for (const trackData of [{ purged: true }, { state: 'deleted' }, { progress_model: 'x' }]) {
      await assert.rejects(call(fns.tutorUpsertTrack, { ...base, trackId: C, trackData }),
        (e) => e.code === 'invalid-argument');
    }
    assert.deepEqual(await changeLog(), []);
  });

  // DNI-484 (R16): every retired curriculum_tracks key and the camelCase
  // aliases are rejected; state and the display-only activated_at still pass.
  test('tutorUpsertTrack rejects each R16 retired track field, aliases included', async () => {
    const stamp = '2026-01-01T00:00:00.000Z';
    for (const [key, value] of [
      ['state_changed_at', stamp], ['stateChangedAt', stamp],
      ['purged', true], ['purged_at', stamp],
      ['pace_reset_date', stamp], ['paceResetDate', stamp],
      ['last_reorder_at', stamp], ['lastReorderAt', stamp],
      ['progress_schema_version', 1], ['progress_computed_at', stamp],
      ['progress_model', 'x'], ['program_progress', {}], ['self_paced_progress', {}],
      ['updated_at', stamp], ['updatedAt', stamp], ['synced_at', stamp], ['syncedAt', stamp],
    ]) {
      await assert.rejects(
        call(fns.tutorUpsertTrack, { ...base, trackId: C, trackData: { state: 'active', [key]: value } }),
        (e) => e.code === 'invalid-argument', key);
    }
    assert.deepEqual(await changeLog(), []);
    assert.equal((await tracks().doc(C).get()).exists, false);
  });

  test('tutorUpsertTrack accepts state with the display-only activated_at', async () => {
    const res = await call(fns.tutorUpsertTrack, {
      ...base, trackId: C, trackData: { state: 'active', activated_at: '2026-01-01T00:00:00.000Z' },
    });
    assert.equal(res.success, true);
    const track = (await tracks().doc(C).get()).data();
    assert.equal(track.state, 'active');
    assert.equal(track.activated_at, '2026-01-01T00:00:00.000Z');
  });

  test('tutorDeleteTrack performs the remove-track action, sharing one action_id', async () => {
    await tracks().doc(C).set({ state: 'active', curriculum_id: C, last_change_id: ulid(0) });
    const liveA = '01JSBTRACK0000000000000AAA';
    const liveB = '01JSBTRACK0000000000000BBB';
    const ended = '01JSBTRACK0000000000000CCC';
    const other = '01JSBTRACK0000000000000DDD';
    await subTracks().doc(liveA).set({ curriculum_id: C, name: 'A' });
    await subTracks().doc(liveB).set({ curriculum_id: C, name: 'B', ended_at: null });
    await subTracks().doc(ended).set({ curriculum_id: C, name: 'C', ended_at: new Date('2026-01-01'), end_reason: 'ended' });
    await subTracks().doc(other).set({ curriculum_id: 'tanach', name: 'D' });
    await goals().doc(`${C}_deadline`).set(DEADLINE);

    const res = await call(fns.tutorDeleteTrack, { ...base, trackId: C, actionId: ulid(1) });
    assert.equal(res.action_id, ulid(1));
    assert.equal(res.change_ids.length, 3);

    const entries = await changeLog();
    assert.equal(entries.length, 3);
    assert.ok(entries.every((e) => e.action_id === ulid(1)));
    const main = entries.find((e) => e.entity === 'mainTrack');
    assert.equal(main.id, ulid(1));
    assert.deepEqual(Object.keys(main.after), [`curriculum_tracks/${C}.ended_at`]);
    const subs = entries.filter((e) => e.entity === 'subTrack').map((e) => e.entity_id).sort();
    assert.deepEqual(subs, [liveA, liveB]);
    for (const e of entries.filter((x) => x.entity === 'subTrack')) {
      assert.equal(e.after[`sub_tracks/${e.entity_id}.end_reason`], 'track_deleted');
    }

    const track = (await tracks().doc(C).get()).data();
    assert.ok(track.ended_at, 'the track is tombstoned, not deleted');
    assert.equal(track.state, 'active');
    assert.equal((await subTracks().doc(liveA).get()).get('end_reason'), 'track_deleted');
    assert.equal((await subTracks().doc(ended).get()).get('end_reason'), 'ended', 'no second tombstone');
    assert.equal((await subTracks().doc(other).get()).get('ended_at'), undefined);
    const goal = (await goals().doc(`${C}_deadline`).get()).data();
    assert.deepEqual(goal, DEADLINE, 'other governed docs are left alone');

    // Replaying the same action returns the stored result.
    const replay = await call(fns.tutorDeleteTrack, { ...base, trackId: C, actionId: ulid(1) });
    assert.equal(replay.replayed, true);
    assert.deepEqual(replay.change_ids, res.change_ids);
  });

  test('tutorDeleteTrack on an absent or already-ended track is a no-op', async () => {
    const absent = await call(fns.tutorDeleteTrack, { ...base, trackId: C });
    assert.equal(absent.noop, true);
    await tracks().doc(C).set({ state: 'active', curriculum_id: C, ended_at: new Date('2026-01-01') });
    const ended = await call(fns.tutorDeleteTrack, { ...base, trackId: C });
    assert.equal(ended.noop, true);
    assert.deepEqual(await changeLog(), []);
  });

  test('a tutor re-add (clearing ended_at via tutorUpsertTrack) is a logged change', async () => {
    await tracks().doc(C).set({ state: 'active', curriculum_id: C, ended_at: new Date('2026-01-01') });
    await call(fns.tutorUpsertTrack, { ...base, trackId: C, trackData: { ended_at: null }, actionId: ulid(1) });
    const track = (await tracks().doc(C).get()).data();
    assert.equal(track.ended_at, undefined);
    const [entry] = await changeLog();
    assert.equal(entry.after[`curriculum_tracks/${C}.ended_at`], null);
    assert.ok(entry.before[`curriculum_tracks/${C}.ended_at`]);
  });

  test('no governed hard delete: learning history collections are untouched by remove-track', async () => {
    await tracks().doc(C).set({ state: 'active', curriculum_id: C });
    await profileRef().collection('learning_events').doc(ulid(9)).set({ kind: 'learn', curriculum_id: C });
    await profileRef().collection('points_ledger').doc('pts_x').set({ curriculum_id: C });
    await call(fns.tutorDeleteTrack, { ...base, trackId: C });
    assert.equal((await profileRef().collection('learning_events').doc(ulid(9)).get()).exists, true);
    assert.equal((await profileRef().collection('points_ledger').doc('pts_x').get()).exists, true);
    assert.equal((await db.collection('tutor_grants').doc(GRANT).collection('audit_log').get()).size, 1);
  });
});
