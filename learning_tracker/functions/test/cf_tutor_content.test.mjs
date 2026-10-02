// CF tests — tutor main-track configuration callables:
//   tutorUpsertStageDefinition, tutorUpsertStudyDayConfig, tutorDeleteStudyDayConfig,
//   tutorSetProfileProgram, tutorUpsertCurriculumScope — rerouted through
//   writeWithChangeLog (sub-tracks AD-38 / AD-53, Story 1.10 / DNI-472, AC-3/AC-6);
//   tutorReplaceStudyDays — a whole study-day schedule as one action (Story 1.24 / DNI-486);
//   tutorUpsertBookmark — legacy, unchanged until its cutover retirement.
// The shared rejection matrix lives in _governed_contract.mjs.
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
  expectHttpsError,
  fns,
  profileRef,
  seedActiveGrant,
  seedLearningGrant,
  seedProfile,
  strangerAuth,
  ulid,
} from './_cf_helpers.mjs';
import { describeGovernedContract } from './_governed_contract.mjs';

const C = 'talmud_bavli';
const base = { grantId: GRANT, ownerUid: PARENT, profileId: PROFILE };
const col = (name) => profileRef().collection(name);

const STAGE = { curriculum_id: C, stage_order: 1, stage_name: 'Stage 1' };
const STUDY_DAY = { curriculum_id: C, day_of_week: 5, day_type: 'rest' };
const PROGRAM = { program_id: 'daf_yomi', tracking_start_date: '2026-01-01', tracking_start_ref: 'Berakhot.2a' };
const SCOPE = { curriculum_id: C, scope_level: 1, scope_value: 'Berakhot' };

describeGovernedContract('tutorUpsertStageDefinition', {
  goodArgs: { ...base, stageId: `${C}_1`, stageData: STAGE },
  idParam: 'stageId', dataParam: 'stageData', entity: 'mainTrackStages',
});

describeGovernedContract('tutorUpsertStudyDayConfig', {
  goodArgs: { ...base, configId: `${C}_5`, configData: STUDY_DAY },
  idParam: 'configId', dataParam: 'configData', entity: 'mainTrackStudyDays',
});

describeGovernedContract('tutorDeleteStudyDayConfig', {
  goodArgs: { ...base, configId: `${C}_5` },
  idParam: 'configId', entity: 'mainTrackStudyDays',
  seed: () => col('study_day_configs').doc(`${C}_5`).set(STUDY_DAY),
});

describeGovernedContract('tutorReplaceStudyDays', {
  goodArgs: { ...base, curriculumId: C, upserts: [{ configId: `${C}_5`, configData: STUDY_DAY }] },
  idParam: 'curriculumId', entity: 'mainTrackStudyDays',
});

describeGovernedContract('tutorSetProfileProgram', {
  goodArgs: { ...base, programId: C, programData: PROGRAM },
  idParam: 'programId', dataParam: 'programData', entity: 'mainTrackProgram',
});

describeGovernedContract('tutorUpsertCurriculumScope', {
  goodArgs: { ...base, scopeId: `${C}_1_Berakhot`, scopeData: SCOPE },
  idParam: 'scopeId', dataParam: 'scopeData', entity: 'mainTrackScope',
});

describe('tutor main-track configuration callables — AC-3 behaviour', () => {
  beforeEach(async () => {
    await clearFirestore();
    await seedProfile();
    await seedLearningGrant();
  });

  const cases = [
    ['tutorUpsertStageDefinition', 'mainTrackStages', 'stage_definitions',
      { stageId: `${C}_1`, stageData: STAGE }, `${C}_1`],
    ['tutorUpsertStudyDayConfig', 'mainTrackStudyDays', 'study_day_configs',
      { configId: `${C}_5`, configData: STUDY_DAY }, `${C}_5`],
    ['tutorSetProfileProgram', 'mainTrackProgram', 'profile_programs',
      { programId: C, programData: PROGRAM }, C],
    ['tutorUpsertCurriculumScope', 'mainTrackScope', 'curriculum_scopes',
      { scopeId: `${C}_1_Berakhot`, scopeData: SCOPE }, `${C}_1_Berakhot`],
  ];

  for (const [name, entity, collection, args, docId] of cases) {
    test(`${name}: field-level create logged as ${entity} with entity_id = curriculumId`, async () => {
      const res = await call(fns[name], { ...base, ...args, actionId: ulid(1) });
      assert.deepEqual(res.change_ids, [ulid(1)]);
      const [entry] = await changeLog();
      assert.equal(entry.entity, entity);
      assert.equal(entry.entity_id, C);
      for (const [k, v] of Object.entries(entry.before)) {
        assert.ok(k.startsWith(`${collection}/${docId}.`), `before key ${k}`);
        assert.equal(v, null, 'a create logs null per absent field');
      }
      const doc = (await col(collection).doc(docId).get()).data();
      assert.equal(doc.curriculum_id, C);
      assert.equal(doc.last_change_id, ulid(1));
      assert.equal(doc.synced_at, undefined, 'synced_at is retired from governed docs');
    });
  }

  test('an update merges only the changed fields and keeps unrelated ones', async () => {
    await col('stage_definitions').doc(`${C}_1`).set({ ...STAGE, delay_days: 3, legacy: 'keep' });
    await call(fns.tutorUpsertStageDefinition, {
      ...base, stageId: `${C}_1`, stageData: { stage_name: 'Review', delay_days: 3 }, actionId: ulid(1),
    });
    const [entry] = await changeLog();
    assert.deepEqual(entry.before, { [`stage_definitions/${C}_1.stage_name`]: 'Stage 1' });
    assert.deepEqual(entry.after, { [`stage_definitions/${C}_1.stage_name`]: 'Review' });
    const doc = (await col('stage_definitions').doc(`${C}_1`).get()).data();
    assert.equal(doc.legacy, 'keep');
    assert.equal(doc.stage_order, 1);
  });

  test('an update without curriculum_id derives the entity from the stored doc', async () => {
    await col('study_day_configs').doc(`${C}_5`).set(STUDY_DAY);
    await call(fns.tutorUpsertStudyDayConfig, {
      ...base, configId: `${C}_5`, configData: { day_type: 'study' }, actionId: ulid(1),
    });
    const [entry] = await changeLog();
    assert.equal(entry.entity_id, C);
  });

  test('a create without curriculum_id is rejected for keyed-by-field entities', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, { ...base, configId: `${C}_5`, configData: { day_type: 'rest' } }),
      'invalid-argument',
    );
  });

  test('tutorDeleteStudyDayConfig tombstones instead of deleting', async () => {
    await col('study_day_configs').doc(`${C}_5`).set(STUDY_DAY);
    await call(fns.tutorDeleteStudyDayConfig, { ...base, configId: `${C}_5`, actionId: ulid(1) });
    const doc = await col('study_day_configs').doc(`${C}_5`).get();
    assert.equal(doc.exists, true);
    assert.ok(doc.get('ended_at'));
    const [entry] = await changeLog();
    assert.equal(entry.entity, 'mainTrackStudyDays');
    assert.deepEqual(Object.keys(entry.after), [`study_day_configs/${C}_5.ended_at`]);
  });

  test('tutorSetProfileProgram accepts the published client payload (edit_track_screen shape)', async () => {
    const res = await call(fns.tutorSetProfileProgram, {
      ...base,
      programId: C,
      programData: {
        profile_id: PROFILE,
        curriculum_id: C,
        program_id: 'daf_yomi',
        tracking_start_date: '2026-10-01T00:00:00.000Z',
        tracking_start_ref: 'Berakhot.2a',
        updated_at: '2026-10-01T09:30:00.000Z',
      },
    });
    assert.equal(res.success, true);
    const doc = (await col('profile_programs').doc(C).get()).data();
    assert.equal(doc.tracking_start_date, '2026-10-01');
    assert.equal(doc.profile_id, undefined);
    assert.equal(doc.updated_at, undefined);
  });

  test('tutorSetProfileProgram requires tracking_start_date when a program is set', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, { ...base, programId: C, programData: { program_id: 'daf_yomi' } }),
      'invalid-argument',
    );
  });

  test('tutorSetProfileProgram rejects a doc id that is not the curriculum id', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, {
        ...base, programId: 'other', programData: { ...PROGRAM, curriculum_id: C },
      }),
      'invalid-argument',
    );
  });
});

// ── tutorUpsertBookmark ───────────────────────────────────────────────────────
describe('tutorUpsertBookmark', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    bookmarkId: 'talmud_bavli_standard',
    // AUD-firebase-10: fields must be in BOOKMARK_ALLOWED_FIELDS (mirrors
    // firestore.rules' bookmarks hasOnly() whitelist).
    bookmarkData: { sefaria_ref: 'Berakhot.2a', stage_id: 'stage-1' },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('missing/blank bookmarkId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, { ...goodArgs, bookmarkId: '' }),
      'invalid-argument',
    );
  });

  test('bookmarkData is an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, { ...goodArgs, bookmarkData: [] }),
      'invalid-argument',
    );
  });

  test('bookmarkData is null → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, { ...goodArgs, bookmarkData: null }),
      'invalid-argument',
    );
  });

  // AUD-firebase-10: bookmarkData is whitelisted server-side (mirrors
  // firestore.rules' bookmarks hasOnly()).
  test('AUD-firebase-10: bookmarkData with an unexpected key → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, {
        ...goodArgs,
        bookmarkData: { sefaria_ref: 'Berakhot.2a', not_a_real_field: 'sneaky' },
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_learning: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_learning: true });
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_learning → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → upserts bookmarks doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_learning: true });

    const res = await call(fns.tutorUpsertBookmark, goodArgs);

    assert.equal(res.success, true);

    const bmRef = profileRef().collection('bookmarks').doc('talmud_bavli_standard');
    const snap = await bmRef.get();
    assert.equal(snap.exists, true, 'bookmarks doc should exist');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });
});

describe('tutorReplaceStudyDays — one action for the whole schedule (DNI-486)', () => {
  beforeEach(async () => {
    await clearFirestore();
    await seedProfile();
    await seedLearningGrant();
  });

  const day = (d, type = 'study') => ({ curriculum_id: C, day_of_week: d, day_type: type });

  test('upserts and tombstones land as ONE change_log entry under ONE action_id', async () => {
    await col('study_day_configs').doc(`${C}_7`).set(day(7));
    const res = await call(fns.tutorReplaceStudyDays, {
      ...base,
      curriculumId: C,
      upserts: [
        { configId: `${C}_1`, configData: day(1) },
        { configId: `${C}_2`, configData: day(2, 'rest') },
      ],
      removedConfigIds: [`${C}_7`],
      actionId: ulid(1),
    });
    assert.equal(res.action_id, ulid(1));
    const entries = await changeLog();
    assert.equal(entries.length, 1, 'one entity, one entry');
    const [entry] = entries;
    assert.equal(entry.entity, 'mainTrackStudyDays');
    assert.equal(entry.entity_id, C);
    assert.equal(entry.action_id, ulid(1));
    const docsTouched = new Set(Object.keys(entry.after).map((k) => k.split('.')[0]));
    assert.deepEqual([...docsTouched].sort(), [
      `study_day_configs/${C}_1`, `study_day_configs/${C}_2`, `study_day_configs/${C}_7`,
    ]);
    assert.ok((await col('study_day_configs').doc(`${C}_7`).get()).get('ended_at'));
    assert.equal((await col('study_day_configs').doc(`${C}_2`).get()).get('day_type'), 'rest');
  });

  test('a doc of another curriculum fails the whole replace: nothing is written', async () => {
    await expectHttpsError(
      call(fns.tutorReplaceStudyDays, {
        ...base,
        curriculumId: C,
        upserts: [
          { configId: `${C}_1`, configData: day(1) },
          { configId: 'mishnayos_2', configData: { ...day(2), curriculum_id: 'mishnayos' } },
        ],
        actionId: ulid(1),
      }),
      'invalid-argument',
    );
    assert.deepEqual(await changeLog(), []);
    assert.equal((await col('study_day_configs').doc(`${C}_1`).get()).exists, false);
  });

  test('a config named twice, or an empty replace, is rejected', async () => {
    await expectHttpsError(
      call(fns.tutorReplaceStudyDays, {
        ...base,
        curriculumId: C,
        upserts: [{ configId: `${C}_1`, configData: day(1) }],
        removedConfigIds: [`${C}_1`],
      }),
      'invalid-argument',
    );
    await expectHttpsError(
      call(fns.tutorReplaceStudyDays, { ...base, curriculumId: C, upserts: [] }),
      'invalid-argument',
    );
    assert.deepEqual(await changeLog(), []);
  });

  test('a retry with the same actionId replays the stored action', async () => {
    const args = {
      ...base,
      curriculumId: C,
      upserts: [{ configId: `${C}_1`, configData: day(1) }],
      actionId: ulid(1),
    };
    await call(fns.tutorReplaceStudyDays, args);
    const again = await call(fns.tutorReplaceStudyDays, args);
    assert.equal(again.replayed, true);
    assert.equal((await changeLog()).length, 1);
  });
});
