// CF tests — tutor content mutations:
//   tutorUpsertStageDefinition, tutorUpsertStudyDayConfig, tutorDeleteStudyDayConfig,
//   tutorUpsertBookmark, tutorSetProfileProgram, tutorUpsertCurriculumScope
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  GRANT,
  PARENT,
  PROFILE,
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  profileRef,
  seedActiveGrant,
  strangerAuth,
  TUTOR,
} from './_cf_helpers.mjs';

// ── tutorUpsertStageDefinition ────────────────────────────────────────────────
describe('tutorUpsertStageDefinition', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    stageId: 'track1_1',
    // AUD-firebase-10: fields must be in STAGE_DEFINITION_ALLOWED_FIELDS
    // (mirrors firestore.rules' stage_definitions hasOnly() whitelist).
    stageData: { stage_order: 1, stage_name: 'Stage 1' },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('missing/blank stageId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, { ...goodArgs, stageId: '' }),
      'invalid-argument',
    );
  });

  test('stageData is an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, { ...goodArgs, stageData: [] }),
      'invalid-argument',
    );
  });

  test('stageData is null → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, { ...goodArgs, stageData: null }),
      'invalid-argument',
    );
  });

  // AUD-firebase-10: stageData is whitelisted server-side (mirrors
  // firestore.rules' stage_definitions hasOnly()).
  test('AUD-firebase-10: stageData with an unexpected key → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, {
        ...goodArgs,
        stageData: { stage_order: 1, not_a_real_field: 'sneaky' },
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_stages: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_stages: true });
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_stages → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorUpsertStageDefinition, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → upserts stage_definitions doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_stages: true });

    const res = await call(fns.tutorUpsertStageDefinition, goodArgs);

    assert.equal(res.success, true);

    const stageRef = profileRef().collection('stage_definitions').doc('track1_1');
    const snap = await stageRef.get();
    assert.equal(snap.exists, true, 'stage_definitions doc should exist');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });
});

// ── tutorUpsertStudyDayConfig ─────────────────────────────────────────────────
describe('tutorUpsertStudyDayConfig', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    configId: 'config-1',
    // AUD-firebase-10: fields must be in STUDY_DAY_CONFIG_ALLOWED_FIELDS
    // (mirrors firestore.rules' study_day_configs hasOnly() whitelist).
    configData: { day_of_week: 'monday', day_type: 'study' },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, { ...goodArgs, profileId: 0 }),
      'invalid-argument',
    );
  });

  test('missing/blank configId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, { ...goodArgs, configId: '' }),
      'invalid-argument',
    );
  });

  test('configData is an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, { ...goodArgs, configData: [] }),
      'invalid-argument',
    );
  });

  test('configData is null → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, { ...goodArgs, configData: null }),
      'invalid-argument',
    );
  });

  // AUD-firebase-10: configData is whitelisted server-side (mirrors
  // firestore.rules' study_day_configs hasOnly()).
  test('AUD-firebase-10: configData with an unexpected key → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, {
        ...goodArgs,
        configData: { day_of_week: 'monday', not_a_real_field: 'sneaky' },
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_study_days: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_study_days: true });
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_study_days → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorUpsertStudyDayConfig, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → upserts study_day_configs doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_study_days: true });

    const res = await call(fns.tutorUpsertStudyDayConfig, goodArgs);

    assert.equal(res.success, true);

    const configRef = profileRef().collection('study_day_configs').doc('config-1');
    const snap = await configRef.get();
    assert.equal(snap.exists, true, 'study_day_configs doc should exist');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });
});

// ── tutorDeleteStudyDayConfig ─────────────────────────────────────────────────
describe('tutorDeleteStudyDayConfig', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    configId: 'config-to-delete',
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, { ...goodArgs, profileId: -1 }),
      'invalid-argument',
    );
  });

  test('missing/blank configId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, { ...goodArgs, configId: '' }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_study_days: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_study_days: true });
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_study_days → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorDeleteStudyDayConfig, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → deletes study_day_configs doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_study_days: true });

    const configRef = profileRef().collection('study_day_configs').doc('config-to-delete');
    await configRef.set({ day: 'tuesday', enabled: true });

    const res = await call(fns.tutorDeleteStudyDayConfig, goodArgs);

    assert.equal(res.success, true);
    assert.equal((await configRef.get()).exists, false, 'config doc should be deleted');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
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
      { can_edit_stages: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_stages: true });
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_stages → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorUpsertBookmark, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → upserts bookmarks doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_stages: true });

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

// ── tutorSetProfileProgram ────────────────────────────────────────────────────
describe('tutorSetProfileProgram', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    programId: 'talmud_bavli',
    // AUD-firebase-10: fields must be in PROFILE_PROGRAM_ALLOWED_FIELDS
    // (mirrors firestore.rules' profile_programs hasOnly() whitelist).
    programData: { tracking_start_date: '2026-01-01', tracking_start_ref: 'Berakhot.2a' },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, { ...goodArgs, profileId: 0 }),
      'invalid-argument',
    );
  });

  test('missing/blank programId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, { ...goodArgs, programId: '' }),
      'invalid-argument',
    );
  });

  test('programData is an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, { ...goodArgs, programData: [] }),
      'invalid-argument',
    );
  });

  test('programData is null → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, { ...goodArgs, programData: null }),
      'invalid-argument',
    );
  });

  // AUD-firebase-10: programData is whitelisted server-side (mirrors
  // firestore.rules' profile_programs hasOnly()).
  test('AUD-firebase-10: programData with an unexpected key → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, {
        ...goodArgs,
        programData: { tracking_start_date: '2026-01-01', not_a_real_field: 'sneaky' },
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_stages: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_stages: true });
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_stages → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorSetProfileProgram, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → upserts profile_programs doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_stages: true });

    const res = await call(fns.tutorSetProfileProgram, goodArgs);

    assert.equal(res.success, true);

    const programRef = profileRef().collection('profile_programs').doc('talmud_bavli');
    const snap = await programRef.get();
    assert.equal(snap.exists, true, 'profile_programs doc should exist');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });
});

// ── tutorUpsertCurriculumScope ────────────────────────────────────────────────
describe('tutorUpsertCurriculumScope', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    scopeId: 'talmud_bavli_scope',
    scopeData: { masekhtot: ['Berakhot', 'Shabbat'] },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('missing/blank scopeId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, { ...goodArgs, scopeId: '' }),
      'invalid-argument',
    );
  });

  test('scopeData is an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, { ...goodArgs, scopeData: [] }),
      'invalid-argument',
    );
  });

  test('scopeData is null → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, { ...goodArgs, scopeData: null }),
      'invalid-argument',
    );
  });

  // AUD-firebase-10: curriculum_scopes has no firestore.rules hasOnly()
  // whitelist (intentionally open-ended even for owner writes), so no
  // unexpected-key test applies here — but the size cap still does.
  test('AUD-firebase-10: scopeData with an oversized string field → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, {
        ...goodArgs,
        scopeData: { notes: 'x'.repeat(5001) },
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_stages: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_stages: true });
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_stages → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorUpsertCurriculumScope, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → upserts curriculum_scopes doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_stages: true });

    const res = await call(fns.tutorUpsertCurriculumScope, goodArgs);

    assert.equal(res.success, true);

    const scopeRef = profileRef().collection('curriculum_scopes').doc('talmud_bavli_scope');
    const snap = await scopeRef.get();
    assert.equal(snap.exists, true, 'curriculum_scopes doc should exist');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });
});
