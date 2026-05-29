// CF tests — tutor goal and track mutations:
//   tutorUpsertGoal, tutorDeleteGoal, tutorUpsertTrack, tutorDeleteTrack
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  GRANT,
  PARENT,
  PROFILE,
  TUTOR,
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  profileRef,
  seedActiveGrant,
  strangerAuth,
} from './_cf_helpers.mjs';

// ── tutorUpsertGoal ───────────────────────────────────────────────────────────

describe('tutorUpsertGoal', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    goalId: 'goal-1',
    goalData: { title: 'Finish Berakhot' },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('profileId of zero → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, { ...goodArgs, profileId: 0 }),
      'invalid-argument',
    );
  });

  test('missing/blank goalId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, { ...goodArgs, goalId: '' }),
      'invalid-argument',
    );
  });

  test('goalData is an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, { ...goodArgs, goalData: [1, 2, 3] }),
      'invalid-argument',
    );
  });

  test('goalData is null → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertGoal, { ...goodArgs, goalData: null }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(call(fns.tutorUpsertGoal, goodArgs), 'not-found');
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_goals: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_goals: true });
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_goals → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorUpsertGoal, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → upserts goal doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_goals: true });

    const res = await call(fns.tutorUpsertGoal, goodArgs);

    assert.equal(res.success, true);

    const goalRef = profileRef().collection('goals').doc('goal-1');
    const snap = await goalRef.get();
    assert.equal(snap.exists, true, 'goal document should be created');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
    assert.equal(audit.docs[0].data().tutor_uid, TUTOR);
  });
});

// ── tutorDeleteGoal ───────────────────────────────────────────────────────────

describe('tutorDeleteGoal', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    goalId: 'goal-2',
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteGoal, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteGoal, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteGoal, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteGoal, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('profileId of zero → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteGoal, { ...goodArgs, profileId: 0 }),
      'invalid-argument',
    );
  });

  test('missing/blank goalId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteGoal, { ...goodArgs, goalId: '' }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(call(fns.tutorDeleteGoal, goodArgs), 'not-found');
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_goals: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorDeleteGoal, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_goals: true });
    await expectHttpsError(
      call(fns.tutorDeleteGoal, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_goals → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorDeleteGoal, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → deletes goal doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_goals: true });

    const goalRef = profileRef().collection('goals').doc('goal-2');
    await goalRef.set({ title: 'Finish Shabbat' });

    const res = await call(fns.tutorDeleteGoal, goodArgs);

    assert.equal(res.success, true);
    assert.equal((await goalRef.get()).exists, false, 'goal document should be deleted');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
    assert.equal(audit.docs[0].data().tutor_uid, TUTOR);
  });
});

// ── tutorUpsertTrack ──────────────────────────────────────────────────────────

describe('tutorUpsertTrack', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    trackId: 'track-1',
    trackData: { curriculum: 'mishnayos' },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertTrack, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertTrack, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertTrack, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertTrack, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('profileId of zero → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertTrack, { ...goodArgs, profileId: 0 }),
      'invalid-argument',
    );
  });

  test('missing/blank trackId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertTrack, { ...goodArgs, trackId: '' }),
      'invalid-argument',
    );
  });

  test('trackData is an array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertTrack, { ...goodArgs, trackData: [] }),
      'invalid-argument',
    );
  });

  test('trackData is null → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpsertTrack, { ...goodArgs, trackData: null }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(call(fns.tutorUpsertTrack, goodArgs), 'not-found');
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_stages: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpsertTrack, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_stages: true });
    await expectHttpsError(
      call(fns.tutorUpsertTrack, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_stages → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorUpsertTrack, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → upserts track doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_stages: true });

    const res = await call(fns.tutorUpsertTrack, goodArgs);

    assert.equal(res.success, true);

    const trackRef = profileRef().collection('curriculum_tracks').doc('track-1');
    const snap = await trackRef.get();
    assert.equal(snap.exists, true, 'track document should be created');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
    assert.equal(audit.docs[0].data().tutor_uid, TUTOR);
  });
});

// ── tutorDeleteTrack ──────────────────────────────────────────────────────────

describe('tutorDeleteTrack', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    trackId: 'track-2',
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteTrack, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteTrack, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteTrack, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteTrack, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('profileId of zero → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteTrack, { ...goodArgs, profileId: 0 }),
      'invalid-argument',
    );
  });

  test('missing/blank trackId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorDeleteTrack, { ...goodArgs, trackId: '' }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(call(fns.tutorDeleteTrack, goodArgs), 'not-found');
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_stages: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorDeleteTrack, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_stages: true });
    await expectHttpsError(
      call(fns.tutorDeleteTrack, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_stages → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorDeleteTrack, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → deletes track doc + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_edit_stages: true });

    const trackRef = profileRef().collection('curriculum_tracks').doc('track-2');
    await trackRef.set({ curriculum: 'gemara' });

    const res = await call(fns.tutorDeleteTrack, goodArgs);

    assert.equal(res.success, true);
    assert.equal((await trackRef.get()).exists, false, 'track document should be deleted');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
    assert.equal(audit.docs[0].data().tutor_uid, TUTOR);
  });
});
