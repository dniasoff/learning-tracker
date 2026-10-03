// CF tests — tutorUpsertSubTrack (sub-tracks Story 4.1 / DNI-509): the
// tutor's server-checked sub-track lifecycle on a talmid's profile.
// Acceptance tests AC-1, AC-3 and AC-4, run against the Firestore emulator
// through the real exported handlers (see _cf_helpers.mjs). AC-2 (a
// sub-track `source` on tutorRecordLearning) lives in
// cf_tutor_learning.test.mjs. `make test-functions` picks this file up
// through its existing `cf_*.test.mjs` glob.

import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { beforeEach, describe, mock, test } from 'node:test';
import { fileURLToPath } from 'node:url';
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

const ENTITY = 'subTrack';
const TUTOR_ACTOR = { uid: TUTOR, role: 'tutor', display_name: 'Mr Tutor' };
const C = 'shas';
const SUB = ulid(100);
const NAME = 'Rebbe Gemara';

const subTracks = () => profileRef().collection('sub_tracks');
const receipts = () => profileRef().collection('governed_action_receipts');

const ONGOING = {
  curriculum_id: C,
  name: NAME,
  type: 'ongoing',
  window_start: '2026-09-01',
  rate_per_week: 5,
  weeks_per_year: 40,
  learns_on_shabbos: false,
  ground: [{ level: 'masechta', ref: 'Berakhot' }],
};

const SCHOOL_YEAR = {
  curriculum_id: C,
  name: 'Yeshiva',
  type: 'school_year',
  academic_year: 2026,
  window_start: '2026-09-01',
  window_end: '2027-06-30',
  rate_per_week: 3,
  weeks_per_year: 36,
  learns_on_shabbos: false,
  ground: [{ level: 'masechta', ref: 'Shabbat' }],
};

/** [obj] without [field] (a key that is absent, not undefined). */
function without(obj, field) {
  const { [field]: _omitted, ...rest } = obj;
  return rest;
}

const routing = (extra = {}) => ({ grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, ...extra });

const upsert = (op, subTrackId, extra = {}, auth = tutorAuth) =>
  call(fns.tutorUpsertSubTrack, routing({ op, subTrackId, ...extra }), auth);

const create = (subTrackId = SUB, fields = ONGOING, extra = {}, auth = tutorAuth) =>
  upsert('create', subTrackId, { fields, ...extra }, auth);

const edit = (fields, actionId, subTrackId = SUB) => upsert('edit', subTrackId, { fields, actionId });

/** The parent's own field-level change of [fields] (owner path, same helper). */
const parentEdit = (fields, entryId, subTrackId = SUB) => call(fns.ownerOversizedGovernedWrite, {
  profileId: PROFILE,
  entries: [{
    id: entryId,
    entity: 'subTrack',
    entityId: subTrackId,
    docs: [{ collection: 'sub_tracks', docId: subTrackId, fields, mode: 'update' }],
  }],
}, parentAuth);

async function subTrackDoc(id = SUB) {
  const snap = await subTracks().doc(id).get();
  return snap.exists ? snap.data() : null;
}

const key = (field, id = SUB) => `sub_tracks/${id}.${field}`;

/** Asserts that no sub-track doc and no change_log entry exist. */
async function assertNothingWritten() {
  assert.equal((await subTracks().get()).size, 0, 'no sub_tracks doc written');
  assert.deepEqual(await changeLog(), [], 'no change_log entry written');
}

/** Seeds a stored sub-track doc directly (the state before the call). */
async function seedSubTrack(id, data) {
  await subTracks().doc(id).set({ ...data, last_change_id: ulid(0) });
}

beforeEach(async () => {
  await clearFirestore();
  await seedProfile();
  await seedLearningGrant();
});

// ── AC-1: the callable, its write path and the lifecycle ─────────────────────

describe('AC-1 — tutorUpsertSubTrack covers the subTrack entity', () => {
  test('is exported from functions/src/index.ts', () => {
    assert.equal(typeof fns.tutorUpsertSubTrack, 'function');
  });

  test('writes only through writeWithChangeLog and checks no grant itself (AD-53)', () => {
    const src = readFileSync(new URL('../src/tutor_learning.ts', import.meta.url), 'utf8');
    const section = src.slice(src.indexOf('// ── tutorUpsertSubTrack'));
    const code = section.split('\n')
      .filter((l) => !/^\s*(\/\/|\*|\/\*\*)/.test(l))
      .join('\n');
    assert.equal((code.match(/writeWithChangeLog\(request\.auth/g) ?? []).length, 1);
    assert.match(code, /entity: "subTrack"/);
    for (const forbidden of [
      /\.set\(/, /\.create\(/, /\.update\(/, /\.delete\(/, /\.batch\(/, /runTransaction/,
      /tutor_grants/, /verifyTutorGrant/, /can_edit_learning/, /permissions/,
      /analytics/i, /logEvent/,
    ]) {
      assert.doesNotMatch(code, forbidden, `tutorUpsertSubTrack must not contain ${forbidden}`);
    }
  });

  test('create writes the doc field-level with one change_log entry and a tutor actor', async () => {
    const res = await create();
    assert.equal(res.success, true);
    assert.equal(res.action_id, SUB, 'a create replays on its own sub-track ULID');
    assert.deepEqual(res.change_ids, [SUB]);
    assert.equal(res.replayed, false);
    assert.ok(res.at, 'server-stamped at is returned');

    const doc = await subTrackDoc();
    assert.deepEqual({ ...doc, last_change_id: undefined }, { ...ONGOING, last_change_id: undefined });
    assert.equal(doc.last_change_id, SUB);
    assert.equal(doc.ended_at, undefined);

    const [entry, ...rest] = await changeLog();
    assert.deepEqual(rest, []);
    assert.equal(entry.id, SUB);
    assert.equal(entry.entity, ENTITY);
    assert.equal(entry.entity_id, SUB);
    assert.equal(entry.action_id, SUB);
    assert.deepEqual(entry.actor, TUTOR_ACTOR, 'actor is derived server-side');
    assert.ok(entry.at instanceof admin.firestore.Timestamp);
    for (const [field, value] of Object.entries(ONGOING)) {
      assert.equal(entry.before[key(field)], null, `before.${field} is null on a create`);
      assert.deepEqual(entry.after[key(field)], value, `after.${field}`);
    }
    assert.equal(Object.keys(entry.after).length, Object.keys(ONGOING).length);

    const audit = await db.collection('tutor_grants').doc(GRANT).collection('audit_log').get();
    assert.deepEqual(audit.docs.map((d) => d.get('action')), ['sub_track_created']);
  });

  test('edit of any field writes and logs only the changed fields', async () => {
    await create();
    const res = await edit({ name: 'Rebbe — Gemara', rate_per_week: 7, window_end: '2027-06-30' }, ulid(1));
    assert.deepEqual(res.change_ids, [ulid(1)]);

    const doc = await subTrackDoc();
    assert.equal(doc.name, 'Rebbe — Gemara');
    assert.equal(doc.rate_per_week, 7);
    assert.equal(doc.window_end, '2027-06-30');
    assert.equal(doc.weeks_per_year, ONGOING.weeks_per_year, 'unchanged fields keep their value');
    assert.equal(doc.last_change_id, ulid(1));

    const entry = (await changeLog()).find((e) => e.id === ulid(1));
    assert.deepEqual(entry.before, {
      [key('name')]: NAME, [key('rate_per_week')]: 5, [key('window_end')]: null,
    });
    assert.deepEqual(entry.after, {
      [key('name')]: 'Rebbe — Gemara', [key('rate_per_week')]: 7, [key('window_end')]: '2027-06-30',
    });
  });

  test('an edit can clear a nullable field (null removes window_end)', async () => {
    await create(SUB, { ...ONGOING, window_end: '2027-06-30' });
    await edit({ window_end: null }, ulid(1));
    const doc = await subTrackDoc();
    assert.equal('window_end' in doc, false);
    const entry = (await changeLog()).find((e) => e.id === ulid(1));
    assert.deepEqual(entry.after, { [key('window_end')]: null });
  });

  test('ground add, reorder and remove each replace ground whole, one entry each', async () => {
    await create();
    const berakhot = { level: 'masechta', ref: 'Berakhot' };
    const peah = { level: 'masechta', ref: 'Peah' };
    const demai = { level: 'perek', ref: 'Demai 1' };
    const steps = [
      [ulid(1), [berakhot, peah, demai]], // add two
      [ulid(2), [demai, berakhot, peah]], // reorder
      [ulid(3), [demai, peah]], // remove one
    ];
    let previous = ONGOING.ground;
    for (const [actionId, ground] of steps) {
      await edit({ ground }, actionId);
      assert.deepEqual((await subTrackDoc()).ground, ground);
      const entry = (await changeLog()).find((e) => e.id === actionId);
      assert.deepEqual(entry.before, { [key('ground')]: previous });
      assert.deepEqual(entry.after, { [key('ground')]: ground });
      previous = ground;
    }
    assert.equal((await changeLog()).length, 4);
  });

  test('Add next year creates a new sub-track for academic_year + 1; the source is unchanged', async () => {
    await create(SUB, SCHOOL_YEAR);
    const next = ulid(101);
    const res = await create(next, {
      ...SCHOOL_YEAR, academic_year: 2027, window_start: '2027-09-01', window_end: '2028-06-30', ground: [],
    });
    assert.deepEqual(res.change_ids, [next]);
    assert.equal((await subTrackDoc(next)).academic_year, 2027);
    const source = await subTrackDoc(SUB);
    assert.equal(source.academic_year, 2026);
    assert.equal(source.last_change_id, SUB, 'the source track is not touched');
  });

  for (const [op, reason, audit] of [['end', 'ended', 'sub_track_ended'], ['delete', 'deleted', 'sub_track_deleted']]) {
    test(`${op} is an ended_at + end_reason=${reason} tombstone; the doc and its events stay`, async () => {
      await create();
      const eventId = ulid(300);
      await profileRef().collection('learning_events').doc(eventId).set({
        kind: 'learn', curriculum_id: C, ref: 'Berakhot 2a', source: SUB, date_state: 'dated',
        learned_on: '2026-10-01', recorded_at: admin.firestore.Timestamp.now(), actor: TUTOR_ACTOR,
      });

      const res = await upsert(op, SUB, { actionId: ulid(1) });
      assert.deepEqual(res.change_ids, [ulid(1)]);

      const doc = await subTrackDoc();
      assert.ok(doc, 'never hard-deleted');
      assert.ok(doc.ended_at instanceof admin.firestore.Timestamp, 'ended_at is server-stamped');
      assert.equal(doc.end_reason, reason);
      assert.equal(doc.name, NAME, 'intent fields are kept');
      assert.ok((await profileRef().collection('learning_events').doc(eventId).get()).exists);

      const entry = (await changeLog()).find((e) => e.id === ulid(1));
      assert.deepEqual(entry.before, { [key('ended_at')]: null, [key('end_reason')]: null });
      assert.equal(entry.after[key('end_reason')], reason);
      assert.ok(entry.after[key('ended_at')] instanceof admin.firestore.Timestamp);
      const auditLog = await db.collection('tutor_grants').doc(GRANT).collection('audit_log').get();
      assert.ok(auditLog.docs.some((d) => d.get('action') === audit));
    });
  }

  test('ending an already-ended sub-track is a no-op: no rewrite, no new entry', async () => {
    await create();
    await upsert('end', SUB, { actionId: ulid(1) });
    const ended = await subTrackDoc();
    const res = await upsert('delete', SUB, { actionId: ulid(2) });
    assert.deepEqual(res.change_ids, []);
    assert.equal(res.noop, true);
    const doc = await subTrackDoc();
    assert.equal(doc.end_reason, 'ended', 'the stored end_reason is never rewritten');
    assert.ok(doc.ended_at.isEqual(ended.ended_at));
    assert.equal((await changeLog()).length, 2);
  });

  test('the parent (owner) is accepted by the same callable with an owner actor', async () => {
    const res = await create(SUB, ONGOING, {}, parentAuth);
    assert.equal(res.success, true);
    const [entry] = await changeLog();
    assert.equal(entry.actor.role, 'parent');
    assert.equal(entry.actor.uid, PARENT);
  });
});

// ── AC-3: grant rejections — permission-denied, nothing written ──────────────

describe('AC-3 — grant and permission rejections', () => {
  const cases = [
    ['no grant', async () => { await db.collection('tutor_grants').doc(GRANT).delete(); }],
    ['a revoked grant', () => seedLearningGrant({ state: 'revoked' })],
    ['an inactive (pending) grant', () => seedLearningGrant({ state: 'pending' })],
    ['can_edit_learning false', () => seedActiveGrant({ can_edit_learning: false })],
    ['can_edit_learning absent', () => seedActiveGrant({})],
    ['a grant for another profile', () => seedLearningGrant({ child_profile_id: '01J8XKQ2M3N4P5R6S7T8V9W0ZZ' })],
    ['a grant held by another tutor', () => seedLearningGrant({ tutor_uid: 'someone-else' })],
    ['a grant from another parent', () => seedLearningGrant({ parent_uid: 'other-parent' })],
  ];
  for (const [name, arrange] of cases) {
    test(`${name} → permission-denied, nothing written, {entity, code} logged only`, async () => {
      await arrange();
      const { error, logs } = await captureLogs(() => create());
      await expectHttpsError(Promise.reject(error), 'permission-denied');
      assertPrivacySafeRejectionLog(logs, {
        entity: ENTITY, code: 'permission-denied', secrets: [NAME, SUB, 'Berakhot'],
      });
      await assertNothingWritten();
      assert.equal((await receipts().get()).size, 0);
    });
  }

  test('a revoked grant cannot edit or end an existing sub-track', async () => {
    await create();
    await seedLearningGrant({ state: 'revoked' });
    await expectHttpsError(edit({ name: 'x' }, ulid(1)), 'permission-denied');
    await expectHttpsError(upsert('end', SUB, { actionId: ulid(2) }), 'permission-denied');
    assert.equal((await subTrackDoc()).name, NAME);
    assert.equal((await changeLog()).length, 1);
  });

  test('an unauthenticated caller is rejected', async () => {
    await expectHttpsError(create(SUB, ONGOING, {}, null), 'unauthenticated');
    await assertNothingWritten();
  });
});

// ── AC-3: AD-52 whitelist and AD-45 limits ───────────────────────────────────

describe('AC-3 — AD-52 whitelist and AD-45 limits', () => {
  for (const [name, fields] of [
    ['an unknown field', { ...ONGOING, colour: 'blue' }],
    ['a retired governed timestamp', { ...ONGOING, updated_at: '2026-10-01T00:00:00Z' }],
    ['a caller-supplied last_change_id', { ...ONGOING, last_change_id: ulid(9) }],
    ['a caller-supplied ended_at', { ...ONGOING, ended_at: true }],
    ['a caller-supplied end_reason', { ...ONGOING, end_reason: 'ended' }],
  ]) {
    test(`${name} → invalid-argument, nothing written`, async () => {
      const { error, logs } = await captureLogs(() => create(SUB, fields));
      await expectHttpsError(Promise.reject(error), 'invalid-argument');
      assertPrivacySafeRejectionLog(logs, { entity: ENTITY, code: 'invalid-argument', secrets: [NAME] });
      await assertNothingWritten();
    });
  }

  test('an edit cannot re-add an ended sub-track through ended_at', async () => {
    await create();
    await upsert('end', SUB, { actionId: ulid(1) });
    await expectHttpsError(edit({ ended_at: null }, ulid(2)), 'invalid-argument');
    assert.equal((await subTrackDoc()).end_reason, 'ended');
  });

  test('a sixth active ongoing sub-track on the curriculum → failed-precondition (ongoing_limit)', async () => {
    for (let i = 0; i < 5; i++) await seedSubTrack(ulid(200 + i), { ...ONGOING, name: `Ongoing ${i}` });
    await assert.rejects(create(), (err) => {
      assert.equal(err.code, 'failed-precondition');
      assert.deepEqual(err.details?.sub_track_violations, ['ongoing_limit']);
      return true;
    });
    assert.equal(await subTrackDoc(), null);
    assert.deepEqual(await changeLog(), []);
  });

  test('any sub-track on a calendar-program curriculum → failed-precondition', async () => {
    await profileRef().collection('profile_programs').doc(C).set({
      curriculum_id: C, program_id: 'daf_yomi', tracking_start_date: '2026-09-01',
    });
    await assert.rejects(create(), (err) => {
      assert.equal(err.code, 'failed-precondition');
      assert.deepEqual(err.details?.sub_track_violations, ['calendar_program_curriculum']);
      return true;
    });
    await assertNothingWritten();
  });
});

// ── AC-3: every shared AD-45 fixture, through the tutor callable ─────────────
//
// The same files test/domain/learner_state/sub_track_limits_test.dart (Dart)
// and cf_sub_track_limits.test.mjs (pure TypeScript) run. Each case runs
// end-to-end here: the stored rows are seeded, the clock is the case's
// `today` (learner time zone UTC), and the tutor's create / edit / end
// (or the program set) goes through the callable. Success must match
// `expect: []`; a rejection must carry exactly the expected wire codes.

const FIXTURE_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'test', 'fixtures', 'sub_track_limits');

function merge(into, fields) {
  const out = { ...into };
  for (const [k, v] of Object.entries(fields)) {
    if (v === null) delete out[k];
    else out[k] = v;
  }
  return out;
}

/**
 * The fixture ids (`01JFIXTURE…`) are not Crockford ULIDs, which the tutor
 * callable requires; each maps to a stable valid test ULID.
 */
const fixtureIds = new Map();
function fixtureId(id) {
  if (!fixtureIds.has(id)) fixtureIds.set(id, ulid(600 + fixtureIds.size));
  return fixtureIds.get(id);
}

/** The tutor request a fixture op maps to. */
function fixtureCall(base, c) {
  const op = c.op;
  if (op.kind === 'set_program') {
    return () => call(fns.tutorSetProfileProgram, routing({
      programId: c.curriculum_id,
      programData: op.program_id === null
        ? { program_id: null }
        : { curriculum_id: c.curriculum_id, program_id: op.program_id, tracking_start_date: c.today },
      actionId: ulid(1),
    }));
  }
  if (op.kind === 'create') {
    return () => upsert('create', fixtureId(op.id), { fields: merge(base, op.fields) });
  }
  const { ended_at: endedAt, end_reason: endReason, ...intent } = op.fields;
  if (endedAt !== undefined) {
    // The tutor ends a sub-track with op end / delete, never a raw ended_at.
    assert.deepEqual(intent, {});
    return () => upsert(endReason === 'deleted' ? 'delete' : 'end', fixtureId(op.id), { actionId: ulid(1) });
  }
  return () => upsert('edit', fixtureId(op.id), { fields: op.fields, actionId: ulid(1) });
}

const fixtureFiles = readdirSync(FIXTURE_DIR).filter((f) => f.endsWith('.json')).sort();

describe('AC-3 — shared AD-45 fixtures through tutorUpsertSubTrack', () => {
  test('the shared suite is present', () => {
    assert.ok(fixtureFiles.length >= 4, `fixture files: ${fixtureFiles.join(', ')}`);
  });

  for (const f of fixtureFiles) {
    const { base, cases } = JSON.parse(readFileSync(join(FIXTURE_DIR, f), 'utf8'));
    for (const c of cases) {
      test(`${f}: ${c.name}`, async () => {
        await seedProfile({ time_zone: 'UTC' });
        for (const e of c.existing) await seedSubTrack(fixtureId(e.id), merge(base, e.doc));
        if (c.program_id) {
          await profileRef().collection('profile_programs').doc(c.curriculum_id).set({
            curriculum_id: c.curriculum_id, program_id: c.program_id, tracking_start_date: '2026-01-01',
          });
        }
        const before = (await changeLog()).length;
        const run = fixtureCall(base, c);
        mock.timers.enable({ apis: ['Date'], now: Date.parse(`${c.today}T12:00:00Z`) });
        let codes;
        try {
          await run();
          codes = [];
        } catch (err) {
          codes = err.details?.sub_track_violations;
          assert.ok(Array.isArray(codes), `unexpected ${err.code}: ${err.message}`);
        } finally {
          mock.timers.reset();
        }
        assert.deepEqual([...codes].sort(), c.expect);
        if (c.expect.length > 0) {
          assert.equal((await changeLog()).length, before, 'a rejected case writes no entry');
        }
      });
    }
  }
});

// ── AC-3: idempotent replay of a create ULID ──────────────────────────────────

describe('AC-3 — replay of a create ULID', () => {
  test('an identical retry by the same tutor returns the stored result and writes nothing new', async () => {
    const first = await create();
    const second = await create();
    assert.equal(second.replayed, true);
    assert.deepEqual(second.change_ids, first.change_ids);
    assert.equal(second.at, first.at);
    assert.equal((await changeLog()).length, 1);
    assert.equal((await subTrackDoc()).last_change_id, SUB);
  });

  test('the same action id from a different actor is not an identical replay', async () => {
    await create();
    await expectHttpsError(create(SUB, ONGOING, {}, parentAuth), 'already-exists');
    assert.equal((await changeLog()).length, 1);
  });

  test('the same action id for a different entity is not an identical replay', async () => {
    await create(SUB, ONGOING, { actionId: ulid(50) });
    await expectHttpsError(create(ulid(101), ONGOING, { actionId: ulid(50) }), 'already-exists');
    assert.equal(await subTrackDoc(ulid(101)), null);
    assert.equal((await changeLog()).length, 1);
  });

  test('a different create on an existing sub-track ULID is rejected, never overwritten', async () => {
    await create();
    await expectHttpsError(create(SUB, { ...ONGOING, name: 'Other' }, { actionId: ulid(51) }), 'already-exists');
    assert.equal((await subTrackDoc()).name, NAME);
    assert.equal((await changeLog()).length, 1);
  });
});

// ── AC-1 / AC-3: lifecycle and malformed-data edges ──────────────────────────

describe('AC-1 / AC-3 — malformed requests write nothing', () => {
  const malformed = [
    ['an invalid sub-track ULID', () => create('not-a-ulid')],
    ['an invalid action ULID', () => create(SUB, ONGOING, { actionId: 'abc' })],
    ['an unknown op', () => upsert('purge', SUB, { actionId: ulid(1) })],
    ['an unexpected request field', () => create(SUB, ONGOING, { ended: true })],
    ['a ground entry without ref', () => create(SUB, { ...ONGOING, ground: [{ level: 'masechta' }] })],
    ['a ground entry with an extra key', () => create(SUB, {
      ...ONGOING, ground: [{ level: 'masechta', ref: 'Berakhot', note: 'x' }],
    })],
    ['a ground that is not a list', () => create(SUB, { ...ONGOING, ground: 'Berakhot' })],
    ['a non-numeric rate', () => create(SUB, { ...ONGOING, rate_per_week: 'five' })],
    ['a bad window date', () => create(SUB, { ...ONGOING, window_start: '2026-13-01' })],
    ['an unknown type', () => create(SUB, { ...ONGOING, type: 'summer' })],
    ['a school year without academic_year', () => create(SUB, without(SCHOOL_YEAR, 'academic_year'))],
    ['a missing required field', () => create(SUB, without(ONGOING, 'name'))],
    ['empty create fields', () => create(SUB, {})],
    ['an end carrying fields', () => upsert('end', SUB, { actionId: ulid(1), fields: { name: 'x' } })],
    ['an edit without an action id', () => upsert('edit', SUB, { fields: { name: 'x' } })],
    ['an end without an action id', () => upsert('end', SUB)],
  ];
  for (const [name, run] of malformed) {
    test(`${name} → invalid-argument`, async () => {
      await expectHttpsError(run(), 'invalid-argument');
      await assertNothingWritten();
    });
  }

  for (const op of ['edit', 'end', 'delete']) {
    test(`${op} of a nonexistent sub-track → not-found, no partial doc or entry`, async () => {
      await expectHttpsError(
        upsert(op, SUB, { actionId: ulid(1), ...(op === 'edit' ? { fields: { name: 'x' } } : {}) }),
        'not-found',
      );
      await assertNothingWritten();
    });
  }

  test('an edit leaving the doc invalid (rate 0) is rejected and changes nothing', async () => {
    await create();
    await expectHttpsError(edit({ rate_per_week: 0 }, ulid(1)), 'invalid-argument');
    assert.equal((await subTrackDoc()).rate_per_week, 5);
    assert.equal((await changeLog()).length, 1);
  });

  test('curriculum_id is immutable on an edit', async () => {
    await create();
    await expectHttpsError(edit({ curriculum_id: 'mishnayos' }, ulid(1)), 'invalid-argument');
    assert.equal((await subTrackDoc()).curriculum_id, C);
  });
});

// ── AC-4: concurrent parent and tutor changes (field-level LWW) ──────────────

describe('AC-4 — parent and tutor edit the same sub-track at about the same time', () => {
  test('different fields: both values survive, each write has its own entry', async () => {
    await create();
    await Promise.all([
      edit({ name: 'Rebbe — evening' }, ulid(1)),
      parentEdit({ learns_on_shabbos: true }, ulid(2)),
    ]);
    const doc = await subTrackDoc();
    assert.equal(doc.name, 'Rebbe — evening');
    assert.equal(doc.learns_on_shabbos, true);

    const entries = await changeLog();
    const tutorEntry = entries.find((e) => e.id === ulid(1));
    const parentEntry = entries.find((e) => e.id === ulid(2));
    assert.deepEqual(tutorEntry.after, { [key('name')]: 'Rebbe — evening' });
    assert.deepEqual(tutorEntry.actor, TUTOR_ACTOR);
    assert.deepEqual(parentEntry.after, { [key('learns_on_shabbos')]: true });
    assert.equal(parentEntry.actor.role, 'parent');
  });

  test('the same field (rate_per_week): the later server commit wins, both are logged', async () => {
    await create();
    await Promise.all([
      edit({ rate_per_week: 7 }, ulid(1)),
      parentEdit({ rate_per_week: 9 }, ulid(2)),
    ]);
    const entries = (await changeLog()).filter((e) => e.id === ulid(1) || e.id === ulid(2));
    assert.equal(entries.length, 2, 'each committed write has its own entry');
    for (const e of entries) {
      assert.deepEqual(Object.keys(e.before), [key('rate_per_week')]);
      assert.deepEqual(Object.keys(e.after), [key('rate_per_week')]);
    }
    const later = entries.reduce((a, b) => (a.at.toMillis() >= b.at.toMillis() ? a : b));
    const doc = await subTrackDoc();
    assert.equal(doc.rate_per_week, later.after[key('rate_per_week')]);
    assert.equal(doc.last_change_id, later.id);
  });

  test('sequential same-field edits: the later commit wins and records the earlier value as before', async () => {
    await create();
    await edit({ rate_per_week: 7 }, ulid(1));
    await parentEdit({ rate_per_week: 9 }, ulid(2));
    assert.equal((await subTrackDoc()).rate_per_week, 9);
    const parentEntry = (await changeLog()).find((e) => e.id === ulid(2));
    assert.deepEqual(parentEntry.before, { [key('rate_per_week')]: 7 });
  });
});
