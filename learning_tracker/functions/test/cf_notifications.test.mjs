// CF tests — onChangeLogCreated: parent push when a tutor changes the goal or
// the main track (Story 4.7 / DNI-515; AD-39, AD-54, prd-deviations #9).
//
// The trigger is invoked through firebase-functions-test's v2 wrap with a real
// emulator snapshot (the emulator run loads no functions, so nothing fires on
// its own). FCM is replaced by a recording fake through the module's test
// seam; everything else — siblings query, receipt, account tokens, pruning —
// runs against the Firestore emulator. See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { afterEach, beforeEach, describe, test } from 'node:test';
import admin from 'firebase-admin';
import {
  GRANT,
  PARENT,
  PARENT_NAME,
  PROFILE,
  TUTOR,
  call,
  captureLogs,
  changeLog,
  clearFirestore,
  db,
  fft,
  fns,
  profileRef,
  seedLearningGrant,
  seedProfile,
  ulid,
} from './_cf_helpers.mjs';

const notifications = await import('../lib/notifications.js');

const TUTOR_NAME = 'Rav Cohen';
const LEARNER_NAME = 'Yehuda';
const C = 'mishnah';
const TUTOR_ACTOR = { uid: TUTOR, role: 'tutor', display_name: TUTOR_NAME };
const PARENT_ACTOR = { uid: PARENT, role: 'parent', display_name: PARENT_NAME };
const CHILD_ACTOR = { uid: PARENT, role: 'child', display_name: LEARNER_NAME };

const wrapped = fft.wrap(fns.onChangeLogCreated);

/** Recording FCM fake; [script] maps a token to an error code (else success). */
function fakeMessaging(script = {}) {
  const calls = [];
  return {
    calls,
    get messages() { return calls.flat(); },
    async sendEach(messages) {
      calls.push(messages);
      const responses = messages.map((m) => (script[m.token]
        ? { success: false, error: { code: script[m.token] } }
        : { success: true, messageId: `m-${m.token}` }));
      const successCount = responses.filter((r) => r.success).length;
      return { responses, successCount, failureCount: responses.length - successCount };
    },
  };
}

let fcm;

async function seedTokens(uid, tokens) {
  const map = {};
  for (const [installId, token] of Object.entries(tokens)) {
    map[installId] = { token, updated_at: admin.firestore.Timestamp.now() };
  }
  await db.collection('users').doc(uid).set({ fcm_tokens: map }, { merge: true });
}

async function tokensOf(uid) {
  const snap = await db.collection('users').doc(uid).get();
  const map = snap.get('fcm_tokens') ?? {};
  return Object.fromEntries(Object.entries(map).map(([k, v]) => [k, v.token]));
}

/** Writes a change_log entry exactly as writeWithChangeLog stores it. */
async function seedEntry(id, { entity, entityId = C, actionId, actor = TUTOR_ACTOR, after = {} }) {
  await profileRef().collection('change_log').doc(id).set({
    entity,
    entity_id: entityId,
    action_id: actionId ?? id,
    before: null,
    after,
    at: admin.firestore.Timestamp.now(),
    actor,
  });
}

/** Fires the deployed binding for an existing entry (path params from the doc path). */
async function fire(id, owner = PARENT, profileId = PROFILE) {
  const ref = db.collection('users').doc(owner).collection('learner_profiles')
    .doc(profileId).collection('change_log').doc(id);
  const snap = await ref.get();
  return wrapped({ data: snap, params: { ownerUid: owner, profileId, entryId: id } });
}

/** The handler's outcome, for assertions on why nothing was sent. */
async function outcome(id) {
  const snap = await profileRef().collection('change_log').doc(id).get();
  return notifications.handleChangeLogCreated({
    ownerUid: PARENT, profileId: PROFILE, entryId: id, entry: snap.data(),
  });
}

beforeEach(async () => {
  await clearFirestore();
  await seedProfile({ display_name: LEARNER_NAME });
  fcm = fakeMessaging();
  notifications.setPushMessagingForTests(fcm);
});

afterEach(() => notifications.setPushMessagingForTests(null));

describe('AC-1: an eligible tutor entry pushes to every owner install', () => {
  test('one data-only message per token, naming tutor, learner and change kind', async () => {
    await seedTokens(PARENT, { installA: 'tok-a', installB: 'tok-b' });
    await seedEntry(ulid(1), {
      entity: 'goal', entityId: `${C}_deadline`,
      after: { goal_type: 'deadline', target_date: '2027-06-01' },
    });

    await fire(ulid(1));

    assert.equal(fcm.calls.length, 1);
    assert.deepEqual(fcm.messages.map((m) => m.token).sort(), ['tok-a', 'tok-b']);
    for (const m of fcm.messages) {
      assert.equal(m.notification, undefined, 'data-only: the OS must not render it (AC-5)');
      assert.deepEqual(m.data, {
        type: 'tutor_change',
        owner_uid: PARENT,
        profile_id: PROFILE,
        action_id: ulid(1),
        entry_id: ulid(1),
        kind: 'deadline',
        tutor_name: TUTOR_NAME,
        learner_name: LEARNER_NAME,
      });
      assert.equal(m.android.priority, 'high');
    }
  });

  test('the change kind follows the entity (pace goal and every main-track entity)', async () => {
    await seedTokens(PARENT, { installA: 'tok-a' });
    const cases = [
      ['goal', `${C}_pace`, { goal_type: 'pace', pace_value: 2 }, 'pace'],
      ['goal', `${C}_pace`, null, 'pace'],
      ['goal', `${C}_deadline`, null, 'deadline'],
      ['mainTrack', C, { state: 'active' }, 'mainTrack'],
      ['mainTrackOrder', `${C}_masechet_1`, {}, 'mainTrackOrder'],
      ['mainTrackProgram', C, {}, 'mainTrackProgram'],
      ['mainTrackStudyDays', `${C}_1`, {}, 'mainTrackStudyDays'],
    ];
    let n = 10;
    for (const [entity, entityId, after, kind] of cases) {
      n += 1;
      await seedEntry(ulid(n), { entity, entityId, after });
      await fire(ulid(n));
      assert.equal(fcm.messages.at(-1).data.kind, kind, `${entity} ${entityId}`);
    }
    assert.equal(fcm.calls.length, cases.length);
  });

  test('zero registered installs sends nothing and still records the delivery', async () => {
    await seedEntry(ulid(1), { entity: 'mainTrack' });
    await fire(ulid(1));
    assert.equal(fcm.calls.length, 0);
    const receipt = await profileRef().collection('push_receipts').doc(ulid(1)).get();
    assert.equal(receipt.get('state'), 'sent');
    assert.equal(receipt.get('token_count'), 0);
  });

  test('a real tutorUpsertGoal entry is delivered end to end', async () => {
    await seedLearningGrant({ tutor_name_snapshot: TUTOR_NAME });
    await seedTokens(PARENT, { installA: 'tok-a' });
    await call(fns.tutorUpsertGoal, {
      grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, goalId: `${C}_deadline`,
      goalData: { goal_type: 'deadline', target_date: '2027-06-01', curriculum_id: C },
      actionId: ulid(5),
    });
    const [entry] = await changeLog();
    await fire(entry.id);
    assert.equal(fcm.messages.length, 1);
    assert.equal(fcm.messages[0].data.tutor_name, TUTOR_NAME);
    assert.equal(fcm.messages[0].data.kind, 'deadline');
  });
});

describe('AC-2: one push per action, idempotent on retry', () => {
  test('only the smallest-id eligible entry of an action sends', async () => {
    await seedTokens(PARENT, { installA: 'tok-a' });
    const action = ulid(100);
    // A non-eligible entry with the smallest id must not steal the slot.
    await seedEntry(ulid(1), { entity: 'mainTrackStages', actionId: action });
    await seedEntry(ulid(2), { entity: 'mainTrackOrder', actionId: action });
    await seedEntry(ulid(3), { entity: 'mainTrack', actionId: action });

    assert.equal(await outcome(ulid(3)), 'not_first_in_action');
    for (const id of [ulid(3), ulid(1), ulid(2)]) await fire(id);

    assert.equal(fcm.calls.length, 1);
    assert.equal(fcm.messages[0].data.entry_id, ulid(2));
    assert.equal(fcm.messages[0].data.action_id, action);
    assert.equal(fcm.messages[0].data.kind, 'mainTrackOrder');
  });

  test('a repeated delivery of the same event sends once', async () => {
    await seedTokens(PARENT, { installA: 'tok-a' });
    await seedEntry(ulid(1), { entity: 'goal', entityId: `${C}_deadline` });
    await fire(ulid(1));
    await fire(ulid(1));
    assert.equal(await outcome(ulid(1)), 'already_delivered');
    assert.equal(fcm.calls.length, 1);
  });

  test('concurrent deliveries of the same event send once', async () => {
    await seedTokens(PARENT, { installA: 'tok-a' });
    await seedEntry(ulid(1), { entity: 'goal', entityId: `${C}_deadline` });
    await Promise.all([fire(ulid(1)), fire(ulid(1)), fire(ulid(1))]);
    assert.equal(fcm.calls.length, 1);
  });

  test('a retry after a crashed attempt (expired claim) delivers', async () => {
    await seedTokens(PARENT, { installA: 'tok-a' });
    await seedEntry(ulid(1), { entity: 'goal', entityId: `${C}_deadline` });
    await profileRef().collection('push_receipts').doc(ulid(1)).set({
      entry_id: ulid(1), entity: 'goal', state: 'claimed',
      claimed_at: admin.firestore.Timestamp.fromMillis(
        Date.now() - notifications.DELIVERY_LEASE_MS - 1000),
    });
    await fire(ulid(1));
    assert.equal(fcm.calls.length, 1);
  });
});

describe('AC-3: parent, child and excluded tutor entities never push', () => {
  const silent = [
    ['parent goal', { entity: 'goal', actor: PARENT_ACTOR }],
    ['child goal', { entity: 'goal', actor: CHILD_ACTOR }],
    ['parent mainTrack', { entity: 'mainTrack', actor: PARENT_ACTOR }],
    ['tutor subTrack', { entity: 'subTrack' }],
    ['tutor mainTrackStages', { entity: 'mainTrackStages' }],
    ['tutor mainTrackScope', { entity: 'mainTrackScope' }],
    ['tutor learnerSettings', { entity: 'learnerSettings', entityId: PROFILE }],
  ];
  for (const [name, entry] of silent) {
    test(`${name}: no send, history entry untouched`, async () => {
      await seedTokens(PARENT, { installA: 'tok-a' });
      await seedEntry(ulid(1), entry);
      const before = await changeLog();
      await fire(ulid(1));
      assert.equal(await outcome(ulid(1)), 'ineligible');
      assert.equal(fcm.calls.length, 0);
      assert.deepEqual(await changeLog(), before);
      const receipts = await profileRef().collection('push_receipts').get();
      assert.equal(receipts.size, 0);
    });
  }
});

describe('AC-7: dead tokens are pruned, transient failures keep tokens', () => {
  test('only unregistered / invalid installs are removed; logs carry no learner data', async () => {
    await seedTokens(PARENT, {
      deadA: 'tok-unregistered', deadB: 'tok-invalid', flaky: 'tok-flaky', good: 'tok-good',
    });
    notifications.setPushMessagingForTests(fcm = fakeMessaging({
      'tok-unregistered': 'messaging/registration-token-not-registered',
      'tok-invalid': 'messaging/invalid-registration-token',
      'tok-flaky': 'messaging/internal-error',
    }));
    await seedEntry(ulid(1), { entity: 'goal', entityId: `${C}_deadline` });

    const { error, logs } = await captureLogs(() => fire(ulid(1)));

    assert.equal(error, undefined);
    assert.deepEqual(await tokensOf(PARENT), { flaky: 'tok-flaky', good: 'tok-good' });
    const pruned = logs.filter((l) => l.entry.message === 'parent_push_token_pruned');
    assert.deepEqual(pruned.map((l) => l.entry.code).sort(), [
      'messaging/invalid-registration-token',
      'messaging/registration-token-not-registered',
    ]);
    const failed = logs.filter((l) => l.entry.message === 'parent_push_send_failed');
    assert.deepEqual(failed.map((l) => l.entry.code), ['messaging/internal-error']);
    for (const l of [...pruned, ...failed]) {
      assert.deepEqual(Object.keys(l.entry).sort(), ['code', 'entity', 'message', 'severity']);
      assert.equal(l.entry.entity, 'goal');
    }
    const allText = logs.map((l) => l.raw).join('\n');
    for (const secret of [PARENT, TUTOR, PROFILE, TUTOR_NAME, LEARNER_NAME, 'tok-', 'deadA']) {
      assert.ok(!allText.includes(secret), `log output leaked: ${secret}`);
    }
  });

  test('an install that re-registered a new token during the send is kept', async () => {
    await seedTokens(PARENT, { installA: 'tok-old' });
    notifications.setPushMessagingForTests({
      async sendEach(messages) {
        // The device replaces its token while FCM reports the old one dead.
        await seedTokens(PARENT, { installA: 'tok-new' });
        return {
          responses: messages.map(() => ({
            success: false, error: { code: 'messaging/registration-token-not-registered' },
          })),
          successCount: 0,
          failureCount: messages.length,
        };
      },
    });
    await seedEntry(ulid(1), { entity: 'mainTrack' });
    await fire(ulid(1));
    assert.deepEqual(await tokensOf(PARENT), { installA: 'tok-new' });
  });
});

describe('AC-8: recipients are the owning account, never the tutor', () => {
  test("a tutor who also owns a family account gets nothing on their own tokens", async () => {
    await seedTokens(PARENT, { parentPhone: 'tok-parent' });
    await seedTokens(TUTOR, { tutorPhone: 'tok-tutor' });
    await seedEntry(ulid(1), { entity: 'goal', entityId: `${C}_deadline` });
    await fire(ulid(1));
    assert.deepEqual(fcm.messages.map((m) => m.token), ['tok-parent']);
    assert.equal(fcm.messages[0].data.owner_uid, PARENT);
  });
});

// AC-9 / ruling B5: the gated backend deploy (DNI-490's release job,
// `firebase deploy --only firestore:rules,firestore:indexes,functions`)
// deploys every export of index.ts, so exporting the trigger is what puts it
// in that deploy; the deploy runs only after the rules and functions suites
// that CI runs here. No second workflow is added.
describe('AC-9: the trigger ships through the gated backend deploy', () => {
  test('index.ts exports onChangeLogCreated bound to the profile change_log', () => {
    assert.equal(typeof fns.onChangeLogCreated, 'function');
    const endpoint = fns.onChangeLogCreated.__endpoint;
    assert.equal(endpoint.eventTrigger.eventType, 'google.cloud.firestore.document.v1.created');
    assert.equal(
      endpoint.eventTrigger.eventFilterPathPatterns.document,
      'users/{ownerUid}/learner_profiles/{profileId}/change_log/{entryId}',
    );
  });

  test('CI runs the rules and functions suites that gate the deploy', () => {
    const ci = readFileSync(new URL('../../../.github/workflows/ci.yml', import.meta.url), 'utf8');
    assert.match(ci, /node --test functions\/test\/firestore_rules\.test\.mjs/);
    assert.match(ci, /make test-functions/);
  });
});
