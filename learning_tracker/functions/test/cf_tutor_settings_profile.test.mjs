// CF tests — tutor settings/profile mutations:
//   tutorUpdateGamificationSettings, tutorEditProfile, tutorBulkPriorCompletions
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

// ── tutorUpdateGamificationSettings ──────────────────────────────────────────
describe('tutorUpdateGamificationSettings', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    permKey: 'can_edit_rewards',
    settingsData: { rewards_enabled: true },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('zero profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, profileId: 0 }),
      'invalid-argument',
    );
  });

  test('invalid permKey → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, permKey: 'can_reset_completion' }),
      'invalid-argument',
    );
  });

  test('missing settingsData → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, settingsData: null }),
      'invalid-argument',
    );
  });

  test('settingsData is array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, settingsData: [] }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_rewards: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_rewards: true });
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_rewards → permission-denied', async () => {
    await seedActiveGrant({}); // permission absent — verifyTutorGrant checks !== true
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs),
      'permission-denied',
    );
  });

  test('happy path (can_edit_rewards) → merges settings + writes one audit entry', async () => {
    await seedActiveGrant({ can_edit_rewards: true });

    const res = await call(fns.tutorUpdateGamificationSettings, goodArgs);

    assert.equal(res.success, true);

    const settingsSnap = await profileRef()
      .collection('preferences')
      .doc('gamification_settings')
      .get();
    assert.equal(settingsSnap.exists, true, 'gamification_settings doc should exist');
    assert.equal(settingsSnap.data().rewards_enabled, true);

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });

  test('happy path (can_edit_points) → accepted', async () => {
    await seedActiveGrant({ can_edit_points: true });

    const res = await call(fns.tutorUpdateGamificationSettings, {
      ...goodArgs,
      permKey: 'can_edit_points',
      settingsData: { points_per_session: 5 },
    });

    assert.equal(res.success, true);
  });
});

// ── tutorEditProfile ──────────────────────────────────────────────────────────
describe('tutorEditProfile', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    displayName: 'Yosef',
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('no editable field supplied → invalid-argument', async () => {
    // none of displayName/avatar/mode provided
    await expectHttpsError(
      call(fns.tutorEditProfile, {
        grantId: GRANT,
        ownerUid: PARENT,
        profileId: PROFILE,
      }),
      'invalid-argument',
    );
  });

  test('displayName is empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, displayName: '   ' }),
      'invalid-argument',
    );
  });

  test('displayName exceeds 100 chars → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, displayName: 'a'.repeat(101) }),
      'invalid-argument',
    );
  });

  test('avatar is empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, {
        grantId: GRANT,
        ownerUid: PARENT,
        profileId: PROFILE,
        avatar: '',
      }),
      'invalid-argument',
    );
  });

  test('mode is invalid value → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, {
        grantId: GRANT,
        ownerUid: PARENT,
        profileId: PROFILE,
        mode: 'parent',
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant({}, { state: 'revoked_by_parent' });
    await expectHttpsError(
      call(fns.tutorEditProfile, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorEditProfile, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  // tutorEditProfile passes permKey=null to verifyTutorGrant — no specific
  // permission is required; any active grant is sufficient.

  test('happy path (displayName) → updates profile doc + writes one audit entry', async () => {
    await seedActiveGrant({});
    // Seed the profile doc so it exists before the edit.
    await profileRef().set({ display_name: 'Old Name', mode: 'child', avatar: 'av1' });

    const res = await call(fns.tutorEditProfile, goodArgs);

    assert.equal(res.success, true);

    const profileSnap = await profileRef().get();
    assert.equal(profileSnap.exists, true, 'profile doc should exist');
    assert.equal(profileSnap.data().display_name, 'Yosef');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });

  test('happy path (mode=adult) → updates mode field', async () => {
    await seedActiveGrant({});
    await profileRef().set({ display_name: 'Yosef', mode: 'child', avatar: 'av1' });

    const res = await call(fns.tutorEditProfile, {
      grantId: GRANT,
      ownerUid: PARENT,
      profileId: PROFILE,
      mode: 'adult',
    });

    assert.equal(res.success, true);
    const snap = await profileRef().get();
    assert.equal(snap.data().mode, 'adult');
  });
});

// ── tutorBulkPriorCompletions ─────────────────────────────────────────────────
//
// NOTE ON PERMISSION SEMANTICS:
// can_bulk_prior_completion defaults to TRUE (absent key = allowed).
// The permission is denied only when explicitly set to false.
describe('tutorBulkPriorCompletions', () => {
  // A valid past date (well before today's UTC midnight).
  const PAST_DATE = '2020-01-01T00:00:00.000Z';

  const goodCompletion = {
    completionId: 'c1',
    curriculumId: 'talmud_bavli',
    sefariaRef: 'Berakhot.2a',
    stageId: 1,
    trackType: 'standard',
    completedAt: PAST_DATE,
    points: 10,
  };

  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    completions: [goodCompletion],
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('completions is empty array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, { ...goodArgs, completions: [] }),
      'invalid-argument',
    );
  });

  test('completions is not an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, { ...goodArgs, completions: 'bad' }),
      'invalid-argument',
    );
  });

  // Per-completion field validation (checked inside the grant check loop — but
  // tutorBulkPriorCompletions does grant verification before the per-item loop,
  // so we must seed the grant to reach the per-item checks.
  test('invalid completedAt inside item → invalid-argument', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, {
        ...goodArgs,
        completions: [{ ...goodCompletion, completedAt: 'not-a-date' }],
      }),
      'invalid-argument',
    );
  });

  test('points out of range (> 100) inside item → invalid-argument', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, {
        ...goodArgs,
        completions: [{ ...goodCompletion, points: 101 }],
      }),
      'invalid-argument',
    );
  });

  test('stageId non-integer inside item → invalid-argument', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, {
        ...goodArgs,
        completions: [{ ...goodCompletion, stageId: 1.5 }],
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant({}, { state: 'revoked_by_parent' });
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  // Permission is default-true; denied only when explicitly false.
  test('grant has can_bulk_prior_completion=false → permission-denied', async () => {
    await seedActiveGrant({ can_bulk_prior_completion: false });
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, goodArgs),
      'permission-denied',
    );
  });

  // ── Date-gating: today/future completedAt must be rejected ─────────────────
  // The CF computes todayUtcMidnight and rejects any completedAt >= that value.

  test('completedAt = today UTC midnight → permission-denied (today is not prior)', async () => {
    await seedActiveGrant({});
    // Compute today's UTC midnight the same way the CF does.
    const todayMidnight = new Date();
    todayMidnight.setUTCHours(0, 0, 0, 0);
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, {
        ...goodArgs,
        completions: [{ ...goodCompletion, completedAt: todayMidnight.toISOString() }],
      }),
      'permission-denied',
    );
  });

  test('completedAt in the future → permission-denied', async () => {
    await seedActiveGrant({});
    const future = new Date();
    future.setUTCFullYear(future.getUTCFullYear() + 1);
    await expectHttpsError(
      call(fns.tutorBulkPriorCompletions, {
        ...goodArgs,
        completions: [{ ...goodCompletion, completedAt: future.toISOString() }],
      }),
      'permission-denied',
    );
  });

  test('happy path → writes completions + one audit entry, returns success+written', async () => {
    await seedActiveGrant({});

    const res = await call(fns.tutorBulkPriorCompletions, goodArgs);

    assert.equal(res.success, true);
    assert.equal(res.written, 1);

    const compSnap = await profileRef()
      .collection('completions')
      .doc('c1')
      .get();
    assert.equal(compSnap.exists, true, 'completion doc should exist');
    assert.equal(compSnap.data().created_by_tutor_uid, TUTOR);

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });
});
