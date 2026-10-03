// CF tests — Change history undo on the server path (Story 4.6 / DNI-514).
//
// AC-8: an undo over 10 governed docs goes online through the owner-only
// ownerOversizedGovernedWrite (writeWithChangeLog) and its change_log entry
// keeps reverts_action_id, exactly like the owner batch path.
// AC-10: an undo racing a tutor write on the same field is decided by
// server commit order; both immutable actions stay in the history.
//
// AC-1: an undo is a parent action, so writeWithChangeLog refuses a
// revertsActionId from a child (or tutor) actor. Otherwise the Story
// 1.8 / 1.10 contract already carries revertsActionId. See _cf_helpers.mjs
// for the harness.

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
  expectHttpsError,
  fns,
  parentAuth,
  profileRef,
  seedLearningGrant,
  seedProfile,
  tutorAuth,
  ulid,
} from './_cf_helpers.mjs';

const C = 'mishnah';
const GOAL = `${C}_deadline`;
const order = () => profileRef().collection('track_learning_order');
const goals = () => profileRef().collection('goals');
const orderId = (i) => `${C}_masechet_${i}`;

/** An owner undo action of one entity, for ownerOversizedGovernedWrite. */
function ownerUndo(id, reverts, entity, entityId, docs) {
  return {
    profileId: PROFILE,
    revertsActionId: reverts,
    entries: [{ id, entity, entityId, docs }],
  };
}

beforeEach(async () => {
  await clearFirestore();
  await seedProfile();
});

describe('AC-8: an oversized undo goes through ownerOversizedGovernedWrite', () => {
  beforeEach(async () => {
    const batch = db.batch();
    for (let i = 0; i < 11; i++) {
      batch.set(order().doc(orderId(i)), {
        curriculum_id: C, level: 'masechet', ref: `Tractate ${i}`,
        user_sort_order: i, last_change_id: ulid(1),
      });
    }
    await batch.commit();
  });

  const restore = () => Array.from({ length: 11 }, (_, i) => ({
    collection: 'track_learning_order', docId: orderId(i), fields: { user_sort_order: i + 100 },
  }));

  test('restores all 11 docs in one entry carrying reverts_action_id', async () => {
    const res = await call(fns.ownerOversizedGovernedWrite,
      ownerUndo(ulid(2), ulid(1), 'mainTrackOrder', C, restore()), parentAuth);
    assert.deepEqual(res.change_ids, [ulid(2)]);
    const [entry] = await changeLog();
    assert.equal(entry.id, ulid(2));
    assert.equal(entry.action_id, ulid(2));
    assert.equal(entry.reverts_action_id, ulid(1));
    assert.equal(entry.actor.role, 'parent');
    assert.equal(Object.keys(entry.after).length, 11);
    for (const d of (await order().get()).docs) {
      const i = Number(d.id.split('_').pop());
      assert.equal(d.get('user_sort_order'), i + 100);
      assert.equal(d.get('last_change_id'), ulid(2));
    }
  });

  test('a retry of the same undo is a replay: one entry, still reverting', async () => {
    const req = ownerUndo(ulid(2), ulid(1), 'mainTrackOrder', C, restore());
    await call(fns.ownerOversizedGovernedWrite, req, parentAuth);
    const again = await call(fns.ownerOversizedGovernedWrite, req, parentAuth);
    assert.equal(again.replayed, true);
    const entries = await changeLog();
    assert.equal(entries.length, 1);
    assert.equal(entries[0].reverts_action_id, ulid(1));
  });

  test('a malformed reverts id is rejected and writes nothing', async () => {
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite,
        ownerUndo(ulid(2), 'not-a-ulid', 'mainTrackOrder', C, restore()), parentAuth),
      'invalid-argument',
    );
    assert.deepEqual(await changeLog(), []);
    assert.equal((await order().doc(orderId(0)).get()).get('user_sort_order'), 0);
  });

  test('a child session cannot send an undo: permission-denied, nothing written', async () => {
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite,
        { ...ownerUndo(ulid(2), ulid(1), 'mainTrackOrder', C, restore()), actorRole: 'child' },
        parentAuth),
      'permission-denied',
    );
    assert.deepEqual(await changeLog(), []);
    assert.equal((await order().doc(orderId(0)).get()).get('user_sort_order'), 0);
  });

  test('a child session may still send an oversized change that is not an undo', async () => {
    const res = await call(fns.ownerOversizedGovernedWrite,
      {
        profileId: PROFILE,
        actorRole: 'child',
        entries: [{ id: ulid(2), entity: 'mainTrackOrder', entityId: C, docs: restore() }],
      },
      parentAuth);
    assert.deepEqual(res.change_ids, [ulid(2)]);
    const [entry] = await changeLog();
    assert.equal(entry.actor.role, 'child');
    assert.equal(entry.reverts_action_id, undefined);
  });

  test('a tutor cannot send an owner undo', async () => {
    await seedLearningGrant();
    await expectHttpsError(
      call(fns.ownerOversizedGovernedWrite,
        { ...ownerUndo(ulid(2), ulid(1), 'mainTrackOrder', C, restore()), ownerUid: PARENT, grantId: GRANT },
        tutorAuth),
      'permission-denied',
    );
    assert.deepEqual(await changeLog(), []);
  });
});

describe('AC-10: an undo racing a tutor write on the same field', () => {
  const base = { grantId: GRANT, ownerUid: PARENT, profileId: PROFILE };
  const tutorDeadline = (actionId, date) => call(fns.tutorUpsertGoal, {
    ...base, goalId: GOAL, actionId,
    goalData: { goal_type: 'deadline', target_date: date, curriculum_id: C },
  });
  const parentRestore = (id) => call(fns.ownerOversizedGovernedWrite, ownerUndo(id, ulid(1), 'goal', GOAL, [
    { collection: 'goals', docId: GOAL, fields: { target_date: '2027-07-01' } },
  ]), parentAuth);

  beforeEach(async () => {
    await seedLearningGrant();
    await goals().doc(GOAL).set({
      goal_type: 'deadline', target_date: '2027-07-01', curriculum_id: C, last_change_id: ulid(0),
    });
    await tutorDeadline(ulid(1), '2027-06-01'); // the action the parent undoes
  });

  test('the tutor commits last: the tutor value stands and both actions stay', async () => {
    await parentRestore(ulid(2));
    await tutorDeadline(ulid(3), '2027-06-15');
    const goal = (await goals().doc(GOAL).get()).data();
    assert.equal(goal.target_date, '2027-06-15');
    assert.equal(goal.last_change_id, ulid(3));
    const entries = await changeLog();
    assert.deepEqual(entries.map((e) => e.id), [ulid(1), ulid(2), ulid(3)]);
    assert.equal(entries[1].reverts_action_id, ulid(1));
    assert.equal(entries[2].reverts_action_id, undefined);
  });

  test('the undo commits last: the restored value stands, the tutor entry '
    + 'is kept and the field now reads as changed by the parent', async () => {
    await tutorDeadline(ulid(2), '2027-06-15');
    await parentRestore(ulid(3));
    const goal = (await goals().doc(GOAL).get()).data();
    assert.equal(goal.target_date, '2027-07-01');
    assert.equal(goal.last_change_id, ulid(3));
    const entries = await changeLog();
    assert.deepEqual(entries.map((e) => e.id), [ulid(1), ulid(2), ulid(3)]);
    assert.equal(entries[1].actor.role, 'tutor');
    assert.equal(entries[1].after[`goals/${GOAL}.target_date`], '2027-06-15');
    assert.equal(entries[2].reverts_action_id, ulid(1));
    assert.equal(entries[2].before[`goals/${GOAL}.target_date`], '2027-06-15');
    assert.equal(entries[2].actor.role, 'parent');
  });
});
