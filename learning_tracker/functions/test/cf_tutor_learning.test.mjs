// CF tests — tutor learning callables (sub-tracks Story 1.23 / DNI-485):
// tutorRecordLearning, tutorVoidLearning (void / replace) and tutorUnlearn.
// Acceptance tests AC-1..AC-5, run against the Firestore emulator through the
// real exported handlers (see _cf_helpers.mjs). `make test-functions` picks
// this file up through its existing `cf_*.test.mjs` glob.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { beforeEach, describe, test } from 'node:test';
import admin from 'firebase-admin';
import {
  GRANT,
  PARENT,
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
  tutorAuth,
  ulid,
} from './_cf_helpers.mjs';

const C = 'mishnah';
const LOG_ENTITY = 'learningEvent';
const TUTOR_ACTOR = { uid: TUTOR, role: 'tutor', display_name: 'Mr Tutor' };

const eventsCol = () => profileRef().collection('learning_events');
const pointsCol = () => profileRef().collection('points_ledger');
const receiptsCol = () => profileRef().collection('governed_action_receipts');

async function allEvents() {
  const snap = await eventsCol().get();
  return new Map(snap.docs.map((d) => [d.id, d.data()]));
}
async function allPoints() {
  const snap = await pointsCol().get();
  return new Map(snap.docs.map((d) => [d.id, d.data()]));
}

/** Asserts the profile holds no learning event, points entry or change_log entry. */
async function assertNothingWritten() {
  assert.equal((await eventsCol().get()).size, 0, 'no learning event written');
  assert.equal((await pointsCol().get()).size, 0, 'no points entry written');
  assert.deepEqual(await changeLog(), [], 'no change_log entry written');
}

const routing = (extra = {}) => ({ grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, ...extra });

const dated = (id, ref, extra = {}) => ({
  id,
  fields: {
    kind: 'learn', curriculum_id: C, ref, source: 'main',
    date_state: 'dated', learned_on: '2026-10-01', ...extra,
  },
});
const beforeTrackingNode = (id, ref, level, extra = {}) => ({
  id,
  fields: {
    kind: 'learn', curriculum_id: C, ref, level, source: 'main',
    date_state: 'before_tracking', learned_on: null, ...extra,
  },
});

const record = (events, extra = {}, auth = tutorAuth) =>
  call(fns.tutorRecordLearning, routing({ events, ...extra }), auth);

const BERACHOS_2 = ['Berakhot 2:1', 'Berakhot 2:2', 'Berakhot 2:3'];

beforeEach(async () => {
  await clearFirestore();
  await seedProfile();
  await seedLearningGrant();
});

// ── AC-1: exports and write paths ─────────────────────────────────────────────

describe('AC-1 — exports and three callable write paths', () => {
  test('index.ts exports all three callables', () => {
    for (const name of ['tutorRecordLearning', 'tutorVoidLearning', 'tutorUnlearn']) {
      assert.equal(typeof fns[name], 'function', `${name} is exported`);
    }
  });

  test('the module writes only through writeWithChangeLog, checks no grant itself and emits no analytics', () => {
    const src = readFileSync(new URL('../src/tutor_learning.ts', import.meta.url), 'utf8');
    const code = src.split('\n').filter((l) => !l.trim().startsWith('//')).join('\n');
    assert.match(code, /from "\.\/write_with_change_log"/);
    assert.equal((code.match(/writeWithChangeLog\(request\.auth/g) ?? []).length, 4,
      'record, void, replace and unlearn each call the helper');
    for (const forbidden of [
      /\.set\(/, /\.create\(/, /\.update\(/, /\.delete\(/, /\.batch\(/, /runTransaction/,
      /tutor_grants/, /verifyTutorGrant/, /can_edit_learning/, /permissions/,
      /analytics/i, /logEvent/,
    ]) {
      assert.doesNotMatch(code, forbidden, `tutor_learning.ts must not contain ${forbidden}`);
    }
  });

  test('source is limited to main: a sub-track source is rejected, nothing written', async () => {
    const { error, logs } = await captureLogs(() =>
      record([dated(ulid(1), 'Berakhot 2:1', { source: ulid(50) })]));
    await expectHttpsError(Promise.reject(error), 'invalid-argument');
    assertPrivacySafeRejectionLog(logs, { entity: LOG_ENTITY, code: 'invalid-argument' });
    await assertNothingWritten();
  });

  test('catch_up and void kinds are not tutor captures', async () => {
    await expectHttpsError(record([dated(ulid(1), 'Berakhot 2:1', { date_state: 'catch_up' })]), 'invalid-argument');
    await expectHttpsError(record([{ id: ulid(1), fields: { kind: 'void', target_id: ulid(2) } }]), 'invalid-argument');
    await assertNothingWritten();
  });
});

// ── AC-2: record a three-leaf range ───────────────────────────────────────────

describe('AC-2 — tutorRecordLearning for Berachos 2:1–2:3', () => {
  test('one transaction writes three dated main learn events and their pts_ entries', async () => {
    const before = Date.now();
    const res = await record(BERACHOS_2.map((ref, i) => dated(ulid(i + 1), ref)));
    const after = Date.now();

    assert.equal(res.success, true);
    assert.deepEqual(res.event_ids, [ulid(1), ulid(2), ulid(3)]);
    assert.deepEqual(res.change_ids, [], 'learning events are not change_log entities');
    assert.equal(res.action_id, ulid(1), 'the capture action id is the first event id');
    assert.equal(res.replayed, false);
    assert.ok(res.recorded_at, 'the server-stamped recorded_at is returned');
    const stampMs = Date.parse(res.recorded_at);
    assert.ok(stampMs >= before - 5000 && stampMs <= after + 5000, 'recorded_at is server time');

    const events = await allEvents();
    assert.equal(events.size, 3);
    const points = await allPoints();
    assert.equal(points.size, 3);
    BERACHOS_2.forEach((ref, i) => {
      const id = ulid(i + 1);
      const ev = events.get(id);
      assert.ok(ev, `event stored under its client ULID ${id}`);
      assert.equal(ev.kind, 'learn');
      assert.equal(ev.ref, ref);
      assert.equal(ev.source, 'main');
      assert.equal(ev.date_state, 'dated');
      assert.equal(ev.learned_on, '2026-10-01');
      assert.deepEqual(ev.actor, TUTOR_ACTOR, 'actor is derived on the server');
      assert.ok(ev.recorded_at instanceof admin.firestore.Timestamp);
      assert.equal(ev.recorded_at.toDate().toISOString(), res.recorded_at, 'one commit-time stamp');

      const pts = points.get(`pts_${id}`);
      assert.ok(pts, `pts_${id} written`);
      assert.equal(pts.event_id, id);
      assert.equal(pts.ulid, `pts_${id}`);
      assert.equal(pts.entry_kind, 'completion');
      assert.equal(pts.source, 'live');
      assert.equal(pts.delta, 10, 'default ladder, first stage (no stage_definitions) = 10');
      assert.ok(pts.created_at.isEqual(ev.recorded_at), 'created_at = event.recorded_at');
    });
    assert.deepEqual(await changeLog(), []);
  });

  test('the pts_ amount is point_configs[curriculum, stage ?? firstStageOrder]', async () => {
    const p = profileRef();
    await p.collection('stage_definitions').doc(`${C}_1`).set({ curriculum_id: C, stage_order: 1, ended_at: admin.firestore.Timestamp.now() });
    await p.collection('stage_definitions').doc(`${C}_2`).set({ curriculum_id: C, stage_order: 2 });
    await p.collection('stage_definitions').doc(`${C}_3`).set({ curriculum_id: C, stage_order: 3 });
    await p.collection('point_configs').doc(`${C}_2`).set({ curriculum_id: C, stage_order: 2, points: 7 });
    await record([
      dated(ulid(1), 'Berakhot 2:1'),
      dated(ulid(2), 'Berakhot 2:2', { stage: 3 }),
      dated(ulid(3), 'Berakhot 2:3', { stage: 2 }),
    ]);
    const points = await allPoints();
    assert.equal(points.get(`pts_${ulid(1)}`).delta, 7, 'no stage → first live stage (2) → override 7');
    assert.equal(points.get(`pts_${ulid(2)}`).delta, 3, 'stage 3, no override → ladder 3');
    assert.equal(points.get(`pts_${ulid(3)}`).delta, 7, 'stage 2 → override 7');
  });

  test('caller-supplied actor, recorded_at or original_recorded_at is rejected', async () => {
    for (const extra of [
      { actor: { uid: TUTOR, role: 'parent', display_name: 'x' } },
      { recorded_at: '2026-10-01T00:00:00Z' },
      { original_recorded_at: '2026-10-01T00:00:00Z' },
    ]) {
      await expectHttpsError(record([dated(ulid(1), 'Berakhot 2:1', extra)]), 'invalid-argument');
    }
    await assertNothingWritten();
  });

  test('a call over the AD-54 chunk size is rejected before anything is written', async () => {
    // 226 dated events + 226 pts_ entries > 450 writes per call.
    const evs = Array.from({ length: 226 }, (_, i) => dated(ulid(1000 + i), `Berakhot ${i}:1`));
    await expectHttpsError(record(evs), 'invalid-argument');
    await assertNothingWritten();
  });
});

// ── AC-3: idempotent replay ───────────────────────────────────────────────────

describe('AC-3 — replay of an identical client ULID', () => {
  test('a retry returns the stored result and writes no duplicate event, pts_ or change_log entry', async () => {
    const evs = BERACHOS_2.map((ref, i) => dated(ulid(i + 1), ref));
    const first = await record(evs);
    const receipts = (await receiptsCol().get()).size;
    const replay = await record(evs);
    assert.equal(replay.replayed, true);
    assert.deepEqual(replay.event_ids, first.event_ids);
    assert.equal(replay.recorded_at, first.recorded_at, 'the stored stamp, not a fresh one');
    assert.equal((await eventsCol().get()).size, 3);
    assert.equal((await pointsCol().get()).size, 3);
    assert.deepEqual(await changeLog(), []);
    assert.equal((await receiptsCol().get()).size, receipts, 'no second receipt');
  });

  test('the same ULID with a different event or a different actor is rejected without writes', async () => {
    await record([dated(ulid(1), 'Berakhot 2:1')]);
    const snapshot = async () => ({
      events: [...(await allEvents()).entries()].map(([k, v]) => [k, v.ref, v.learned_on]),
      points: [...(await allPoints()).keys()],
    });
    const before = await snapshot();
    // Same ULID, different entity (ref).
    await expectHttpsError(record([dated(ulid(1), 'Berakhot 2:2')]), 'already-exists');
    // Same ULID, different actor (the owner replaying the tutor's capture).
    await expectHttpsError(record([dated(ulid(1), 'Berakhot 2:1')], {}, parentAuth), 'already-exists');
    assert.deepEqual(await snapshot(), before);
    assert.deepEqual(await changeLog(), []);
  });

  test('an owner-path event under the same ULID is never replayed for the tutor', async () => {
    await eventsCol().doc(ulid(1)).set({
      ...dated(ulid(1), 'Berakhot 2:1').fields,
      recorded_at: admin.firestore.Timestamp.now(),
      actor: { uid: PARENT, role: 'parent', display_name: 'Parent Name' },
    });
    await expectHttpsError(record([dated(ulid(1), 'Berakhot 2:1')]), 'already-exists');
    assert.equal((await pointsCol().get()).size, 0);
  });
});

// ── AC-4: helper-mediated authorisation and payload rejections ────────────────

describe('AC-4 — invalid tutor access and event payloads', () => {
  const calls = {
    tutorRecordLearning: () => call(fns.tutorRecordLearning, routing({ events: [dated(ulid(1), 'Berakhot 2:1')] })),
    tutorVoidLearning: () => call(fns.tutorVoidLearning, routing({ eventId: ulid(2), targetId: ulid(9) })),
    tutorUnlearn: () => call(fns.tutorUnlearn, routing({ actionId: ulid(3), curriculumId: C, leafSet: ['Berakhot 2:1'] })),
  };

  const cases = {
    'no active grant (grant absent)': async () => {
      await db.collection('tutor_grants').doc(GRANT).delete();
    },
    'grant not active': async () => {
      await seedLearningGrant({ state: 'revoked_by_parent' });
    },
    'can_edit_learning false': async () => {
      await seedActiveGrant({ can_edit_learning: false });
    },
    'can_edit_learning absent (legacy keys only)': async () => {
      await seedActiveGrant({ can_mark_completion: true, can_reset_completion: true });
    },
    'grant for another profile': async () => {
      await seedLearningGrant({ child_profile_id: '01J8XKQ2M3N4P5R6S7T8V9ZZZZ' });
    },
  };

  for (const [caseName, arrange] of Object.entries(cases)) {
    for (const [fnName, invoke] of Object.entries(calls)) {
      test(`${fnName}: ${caseName} → permission-denied, nothing written, {entity, code} log`, async () => {
        await arrange();
        const { error, logs } = await captureLogs(invoke);
        await expectHttpsError(Promise.reject(error), 'permission-denied');
        assertPrivacySafeRejectionLog(logs, {
          entity: LOG_ENTITY, code: 'permission-denied', secrets: ['Berakhot', GRANT],
        });
        await assertNothingWritten();
        assert.equal((await receiptsCol().get()).size, 0);
      });
    }
  }

  test('unauthenticated → unauthenticated, nothing written', async () => {
    await expectHttpsError(
      call(fns.tutorRecordLearning, routing({ events: [dated(ulid(1), 'Berakhot 2:1')] }), null),
      'unauthenticated');
    await assertNothingWritten();
  });

  test('an AD-52 whitelist violation is rejected and logged privacy-safely', async () => {
    const { error, logs } = await captureLogs(() =>
      record([dated(ulid(1), 'Berakhot 2:1', { completed: true })]));
    await expectHttpsError(Promise.reject(error), 'invalid-argument');
    assertPrivacySafeRejectionLog(logs, { entity: LOG_ENTITY, code: 'invalid-argument', secrets: ['Berakhot'] });
    // A type violation the helper's AD-52 check catches (learned_on not a date).
    await expectHttpsError(record([dated(ulid(1), 'Berakhot 2:1', { learned_on: '2026-13-40' })]), 'invalid-argument');
    await assertNothingWritten();
  });

  test('a void whose target is not a learn event is rejected', async () => {
    await record([dated(ulid(1), 'Berakhot 2:1')]);
    await call(fns.tutorVoidLearning, routing({ eventId: ulid(2), targetId: ulid(1) }));
    const { error, logs } = await captureLogs(() =>
      call(fns.tutorVoidLearning, routing({ eventId: ulid(3), targetId: ulid(2) })));
    await expectHttpsError(Promise.reject(error), 'invalid-argument');
    assertPrivacySafeRejectionLog(logs, { entity: LOG_ENTITY, code: 'invalid-argument' });
    assert.equal((await eventsCol().doc(ulid(3)).get()).exists, false);
  });

  test('a void replayed by the same actor returns the stored result', async () => {
    await record([dated(ulid(1), 'Berakhot 2:1')]);
    const first = await call(fns.tutorVoidLearning, routing({ eventId: ulid(2), targetId: ulid(1) }));
    const replay = await call(fns.tutorVoidLearning, routing({ eventId: ulid(2), targetId: ulid(1) }));
    assert.equal(replay.replayed, true);
    assert.equal(replay.recorded_at, first.recorded_at);
    assert.equal((await eventsCol().get()).size, 2);
    assert.equal((await pointsCol().get()).size, 1, 'a void writes no points entry');
  });
});

// ── AC-5: lock-window capture is stored, not rejected ─────────────────────────

describe('AC-5 — a lock-stamped capture is stored', () => {
  test('the callable never evaluates the lock: the event is stored and the exact stamp returned', async () => {
    // AD-36 / deviation #2: the lock is applied by the client's CaptureGate
    // (on the returned stamp) and by derivation, never by the server. The
    // learner's lock settings are present, and the server still stores the
    // capture whatever its server time — whether or not that instant falls in
    // the learner's Shabbos/Yom Tov window (the emulator clock cannot be
    // pinned inside one, so the test proves there is no rejection path).
    await profileRef().set({
      latitude: 31.778, longitude: 35.235, time_zone: 'Asia/Jerusalem', in_israel: true,
    }, { merge: true });
    const res = await record([dated(ulid(1), 'Berakhot 2:1', { learned_on: '2026-10-03' })]);
    const stored = (await eventsCol().doc(ulid(1)).get()).data();
    assert.ok(stored, 'stored, not rejected');
    assert.equal(res.recorded_at, stored.recorded_at.toDate().toISOString(),
      'the response carries the exact server recorded_at');
    assert.ok((await pointsCol().doc(`pts_${ulid(1)}`).get()).exists,
      'pts_ is attached; the engine alone decides earning');
  });
});

// ── AC-1 / AC-2: before-tracking and replacement shapes ───────────────────────

describe('AC-1 / AC-2 — before-tracking and replacement shapes', () => {
  test('a before_tracking node event carries level and learned_on = null, and earns no pts_', async () => {
    await record([beforeTrackingNode(ulid(1), 'Berakhot 2', 'perek')]);
    const ev = (await eventsCol().doc(ulid(1)).get()).data();
    assert.equal(ev.level, 'perek');
    assert.equal(ev.learned_on, null);
    assert.equal(ev.date_state, 'before_tracking');
    assert.equal((await pointsCol().get()).size, 0);
  });

  test('a before_tracking leaf may omit learned_on (stored as null); a date or a dated level is rejected', async () => {
    await record([{ id: ulid(1), fields: {
      kind: 'learn', curriculum_id: C, ref: 'Berakhot 3:1', source: 'main', date_state: 'before_tracking',
    } }]);
    assert.equal((await eventsCol().doc(ulid(1)).get()).get('learned_on'), null);
    await expectHttpsError(
      record([beforeTrackingNode(ulid(2), 'Berakhot 2', 'perek', { learned_on: '2026-10-01' })]), 'invalid-argument');
    await expectHttpsError(record([dated(ulid(3), 'Berakhot 2:1', { level: 'mishnah' })]), 'invalid-argument');
    await expectHttpsError(record([dated(ulid(4), 'Berakhot 2:1', { learned_on: null })]), 'invalid-argument');
    assert.equal((await eventsCol().get()).size, 1);
  });

  test('replace voids the target and writes its corrected copy in one transaction', async () => {
    const original = await record([dated(ulid(1), 'Berakhot 2:1', { learned_on: '2026-09-29' })]);
    const res = await call(fns.tutorVoidLearning, routing({
      eventId: ulid(2), targetId: ulid(1), replacement: dated(ulid(3), 'Berakhot 2:1', { learned_on: '2026-09-30' }),
    }));
    assert.deepEqual(res.event_ids, [ulid(2), ulid(3)]);
    const events = await allEvents();
    const voidEv = events.get(ulid(2));
    const copy = events.get(ulid(3));
    assert.equal(voidEv.kind, 'void');
    assert.equal(voidEv.target_id, ulid(1));
    assert.equal(copy.kind, 'learn');
    assert.equal(copy.learned_on, '2026-09-30');
    assert.deepEqual(copy.actor, TUTOR_ACTOR);
    assert.ok(voidEv.recorded_at.isEqual(copy.recorded_at), 'one transaction, one stamp');
    assert.equal(copy.original_recorded_at.toDate().toISOString(), original.recorded_at,
      'the copy keeps effectiveAt(target)');
    const points = await allPoints();
    assert.ok(points.has(`pts_${ulid(3)}`), 'the dated copy earns a pts_ entry');
    assert.ok(!points.has(`pts_${ulid(2)}`), 'no points entry for a void');
    assert.equal(points.size, 2);
    // Replay of the replace is idempotent.
    const replay = await call(fns.tutorVoidLearning, routing({
      eventId: ulid(2), targetId: ulid(1), replacement: dated(ulid(3), 'Berakhot 2:1', { learned_on: '2026-09-30' }),
    }));
    assert.equal(replay.replayed, true);
    assert.equal((await eventsCol().get()).size, 3);
    assert.equal((await pointsCol().get()).size, 2);
  });

  test('replace rejects an absent, non-learn or already voided target, writing nothing', async () => {
    const replacement = dated(ulid(9), 'Berakhot 2:1');
    await expectHttpsError(call(fns.tutorVoidLearning, routing({
      eventId: ulid(2), targetId: ulid(1), replacement,
    })), 'not-found');
    await record([dated(ulid(1), 'Berakhot 2:1')]);
    await call(fns.tutorVoidLearning, routing({ eventId: ulid(2), targetId: ulid(1) }));
    await expectHttpsError(call(fns.tutorVoidLearning, routing({
      eventId: ulid(3), targetId: ulid(2), replacement,
    })), 'invalid-argument');
    await expectHttpsError(call(fns.tutorVoidLearning, routing({
      eventId: ulid(4), targetId: ulid(1), replacement,
    })), 'failed-precondition');
    assert.equal((await eventsCol().doc(ulid(9)).get()).exists, false);
  });
});

// ── DNI-486: a tutor void stays on main-track learning of one curriculum ─────

describe('DNI-486 — tutorVoidLearning targets main-track learning only', () => {
  const seedOwnerEvent = (id, fields) => eventsCol().doc(id).set({
    kind: 'learn', curriculum_id: C, ref: 'Berakhot 2:1', date_state: 'dated', learned_on: '2026-10-01',
    recorded_at: admin.firestore.Timestamp.now(),
    actor: { uid: PARENT, role: 'parent', display_name: 'Parent' },
    ...fields,
  });

  test('a void or replace of a sub-track learn event is rejected, writing nothing', async () => {
    await seedOwnerEvent(ulid(1), { source: ulid(50) });
    await expectHttpsError(call(fns.tutorVoidLearning, routing({ eventId: ulid(2), targetId: ulid(1) })),
      'invalid-argument');
    await expectHttpsError(call(fns.tutorVoidLearning, routing({
      eventId: ulid(3), targetId: ulid(1), replacement: dated(ulid(4), 'Berakhot 2:1'),
    })), 'invalid-argument');
    assert.equal((await eventsCol().get()).size, 1, 'only the seeded sub-track event');
    assert.deepEqual(await changeLog(), []);
  });

  test('a plain void of an absent target is rejected', async () => {
    await expectHttpsError(call(fns.tutorVoidLearning, routing({ eventId: ulid(2), targetId: ulid(1) })),
      'not-found');
    await assertNothingWritten();
  });

  test('a replacement on another curriculum is rejected, writing nothing', async () => {
    await record([dated(ulid(1), 'Berakhot 2:1')]);
    const before = (await eventsCol().get()).size;
    await expectHttpsError(call(fns.tutorVoidLearning, routing({
      eventId: ulid(2), targetId: ulid(1),
      replacement: dated(ulid(3), 'Berakhot 2:1', { curriculum_id: 'bavli' }),
    })), 'invalid-argument');
    assert.equal((await eventsCol().get()).size, before);
    assert.equal((await eventsCol().doc(ulid(3)).get()).exists, false);
  });
});

// ── AC-1 / AC-4: unlearn with partial node coverage ───────────────────────────

describe('AC-1 / AC-4 — tutorUnlearn(curriculum, leafSet)', () => {
  const NODE = ulid(10);

  async function seedUnlearnFixture() {
    await record([dated(ulid(1), 'Berakhot 2:1'), dated(ulid(2), 'Berakhot 2:2')]);
    await record([dated(ulid(3), 'Berakhot 2:2', { learned_on: '2026-09-01' })]);
    // Already voided learn of 2:1 — not counted, so not voided again.
    await record([dated(ulid(4), 'Berakhot 2:1', { learned_on: '2026-08-01' })]);
    await call(fns.tutorVoidLearning, routing({ eventId: ulid(5), targetId: ulid(4) }));
    // Same ref in another curriculum — untouched.
    await record([dated(ulid(6), 'Berakhot 2:1', { curriculum_id: 'talmud_bavli' })]);
    // A before_tracking node covering Berakhot 2 (2:1–2:5).
    await record([beforeTrackingNode(NODE, 'Berakhot 2', 'perek')]);
  }

  const unlearnArgs = (extra = {}) => routing({
    actionId: ulid(20),
    curriculumId: C,
    leafSet: ['Berakhot 2:1', 'Berakhot 2:2'],
    nodeReissues: [{
      targetEventId: NODE,
      reissues: [
        { eventId: ulid(21), ref: 'Berakhot 2:3', level: 'mishnah' },
        { eventId: ulid(22), ref: 'Berakhot 2:4-5', level: 'mishnah' },
      ],
    }],
    ...extra,
  });

  test('voids every counted leaf learn and the node, re-issuing its unaffected portion', async () => {
    await seedUnlearnFixture();
    const nodeRecordedAt = (await eventsCol().doc(NODE).get()).get('recorded_at');
    const pointsBefore = (await pointsCol().get()).size;

    const res = await call(fns.tutorUnlearn, unlearnArgs());
    assert.equal(res.action_id, ulid(20));

    const events = await allEvents();
    const voidTargets = [...events.values()].filter((e) => e.kind === 'void').map((e) => e.target_id).sort();
    assert.deepEqual(voidTargets, [ulid(1), ulid(2), ulid(3), ulid(4), NODE].sort(),
      'counted 2:1/2:2 learns and the node are voided; the already-voided learn keeps its one void');
    assert.ok(!voidTargets.includes(ulid(6)), 'another curriculum is untouched');

    for (const [id, ref] of [[ulid(21), 'Berakhot 2:3'], [ulid(22), 'Berakhot 2:4-5']]) {
      const r = events.get(id);
      assert.ok(r, `re-issue ${id} stored under its client ULID`);
      assert.equal(r.kind, 'learn');
      assert.equal(r.ref, ref);
      assert.equal(r.level, 'mishnah');
      assert.equal(r.date_state, 'before_tracking');
      assert.equal(r.learned_on, null);
      assert.equal(r.source, 'main');
      assert.ok(r.original_recorded_at.toMillis() === nodeRecordedAt.toMillis(),
        'original_recorded_at = effectiveAt(node)');
      assert.deepEqual(r.actor, TUTOR_ACTOR);
    }
    assert.equal((await pointsCol().get()).size, pointsBefore, 'no reversal or re-issue points');
    assert.deepEqual(await changeLog(), []);
    assert.equal(res.event_ids.length, 6, 'four new voids and two re-issues');
    assert.ok(res.event_ids.includes(ulid(21)) && res.event_ids.includes(ulid(22)));

    // Replay returns the stored result and writes nothing.
    const count = events.size;
    const replay = await call(fns.tutorUnlearn, unlearnArgs());
    assert.equal(replay.replayed, true);
    assert.deepEqual(replay.event_ids, res.event_ids);
    assert.equal((await eventsCol().get()).size, count);
  });

  test('re-issued ref in leafSet, missing level, duplicate ULIDs or a missing actionId → invalid-argument', async () => {
    await seedUnlearnFixture();
    const before = (await eventsCol().get()).size;
    const bad = [
      unlearnArgs({ nodeReissues: [{ targetEventId: NODE, reissues: [{ eventId: ulid(21), ref: 'Berakhot 2:1', level: 'mishnah' }] }] }),
      unlearnArgs({ nodeReissues: [{ targetEventId: NODE, reissues: [{ eventId: ulid(21), ref: 'Berakhot 2:3' }] }] }),
      unlearnArgs({ nodeReissues: [{ targetEventId: NODE, reissues: [
        { eventId: ulid(21), ref: 'Berakhot 2:3', level: 'mishnah' },
        { eventId: ulid(21), ref: 'Berakhot 2:4', level: 'mishnah' },
      ] }] }),
      unlearnArgs({ actionId: undefined }),
      unlearnArgs({ leafSet: [] }),
    ];
    for (const args of bad) {
      await expectHttpsError(call(fns.tutorUnlearn, args), 'invalid-argument');
    }
    assert.equal((await eventsCol().get()).size, before);
  });

  test('a target that is not a learn node event of the curriculum is rejected', async () => {
    await seedUnlearnFixture();
    const before = (await eventsCol().get()).size;
    for (const targetEventId of [ulid(5) /* a void */, ulid(3) /* a dated leaf */, ulid(6) /* other curriculum */]) {
      await expectHttpsError(call(fns.tutorUnlearn, unlearnArgs({
        nodeReissues: [{ targetEventId, reissues: [] }],
      })), 'invalid-argument');
    }
    await expectHttpsError(call(fns.tutorUnlearn, unlearnArgs({
      nodeReissues: [{ targetEventId: ulid(99), reissues: [] }],
    })), 'not-found');
    assert.equal((await eventsCol().get()).size, before);
  });

  test('DNI-486 AC-7: with leafEventIds only the named (counted) events are voided — a stored lock-window learn of the same ref stays unvoided', async () => {
    await record([dated(ulid(1), 'Berakhot 3:1')]);
    // Stored but not counted by the engine (recorded inside the lock window).
    await record([dated(ulid(2), 'Berakhot 3:1', { learned_on: '2026-09-05' })]);

    const res = await call(fns.tutorUnlearn, routing({
      actionId: ulid(40), curriculumId: C, leafSet: ['Berakhot 3:1'], leafEventIds: [ulid(1)],
    }));

    const events = await allEvents();
    const voidTargets = [...events.values()].filter((e) => e.kind === 'void').map((e) => e.target_id);
    assert.deepEqual(voidTargets, [ulid(1)]);
    assert.ok(events.has(ulid(2)), 'the lock-window event stays stored');
    assert.equal(res.event_ids.length, 1);

    const replay = await call(fns.tutorUnlearn, routing({
      actionId: ulid(40), curriculumId: C, leafSet: ['Berakhot 3:1'], leafEventIds: [ulid(1)],
    }));
    assert.equal(replay.replayed, true);
    assert.deepEqual(replay.event_ids, res.event_ids);
  });

  test('leafEventIds that are not main learn events of the curriculum with a ref in leafSet are rejected', async () => {
    await seedUnlearnFixture();
    const before = (await eventsCol().get()).size;
    for (const leafEventIds of [[ulid(5)] /* a void */, [ulid(6)] /* other curriculum */, [ulid(3)] /* ref not in leafSet */, ['x']]) {
      await expectHttpsError(call(fns.tutorUnlearn, unlearnArgs({
        leafSet: ['Berakhot 2:1'], nodeReissues: [], leafEventIds,
      })), 'invalid-argument');
    }
    await expectHttpsError(call(fns.tutorUnlearn, unlearnArgs({
      leafSet: ['Berakhot 2:1'], nodeReissues: [], leafEventIds: [ulid(98)],
    })), 'not-found');
    assert.equal((await eventsCol().get()).size, before);
  });

  test('a leaf set with nothing counted is a no-op action', async () => {
    const res = await call(fns.tutorUnlearn, routing({
      actionId: ulid(30), curriculumId: C, leafSet: ['Berakhot 9:9'],
    }));
    assert.equal(res.noop, true);
    assert.deepEqual(res.event_ids, []);
    await assertNothingWritten();
  });
});

// ── AD-50 in the shared helper: which events get a pts_ entry ─────────────────

const helper = await import('../lib/write_with_change_log.js');

describe('writeWithChangeLog — AD-50 pts_ attachment (shared helper)', () => {
  test('every new main dated or catch_up learn event gets pts_; sub-track, before_tracking and void events do not', async () => {
    await helper.writeWithChangeLog(parentAuth, {
      ownerUid: PARENT,
      profileId: PROFILE,
      events: [
        dated(ulid(1), 'Berakhot 4:1'),
        dated(ulid(2), 'Berakhot 4:2', { date_state: 'catch_up' }),
        dated(ulid(3), 'Berakhot 4:3', { source: ulid(60) }),
        beforeTrackingNode(ulid(4), 'Berakhot 5', 'perek'),
        { id: ulid(5), fields: { kind: 'void', target_id: ulid(1) } },
      ],
    });
    assert.deepEqual([...(await allPoints()).keys()].sort(), [`pts_${ulid(1)}`, `pts_${ulid(2)}`]);
  });
});
