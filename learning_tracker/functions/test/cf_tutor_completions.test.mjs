// CF tests — tutor completion mutations: tutorResetCompletion,
// tutorBulkPriorCompletions. See _cf_helpers.mjs for the harness.

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

// ── tutorResetCompletion (representative gate: auth → args → grant → perm) ────
describe('tutorResetCompletion', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    completionId: 'c1',
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorResetCompletion, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorResetCompletion, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorResetCompletion, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(call(fns.tutorResetCompletion, goodArgs), 'not-found');
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_reset_completion: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorResetCompletion, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_reset_completion: true });
    await expectHttpsError(
      call(fns.tutorResetCompletion, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_reset_completion → permission-denied', async () => {
    await seedActiveGrant({}); // permission absent
    await expectHttpsError(
      call(fns.tutorResetCompletion, goodArgs),
      'permission-denied',
    );
  });

  test('happy path → deletes completion + writes one audit-log entry', async () => {
    await seedActiveGrant({ can_reset_completion: true });
    const compRef = profileRef().collection('completions').doc('c1');
    await compRef.set({ points: 10, sefaria_ref: 'Berakhot.2a' });

    const res = await call(fns.tutorResetCompletion, goodArgs);

    assert.equal(res.success, true);
    assert.equal((await compRef.get()).exists, false, 'completion should be deleted');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
    assert.equal(audit.docs[0].data().tutor_uid, TUTOR);
  });
});
