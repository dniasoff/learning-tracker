// CF tests — tutor completion mutations: tutorResetCompletion.
// tutorBulkPriorCompletions is tested in cf_tutor_settings_profile.test.mjs.
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

  // AUD-firebase-08: audit_log writes must be idempotent on retry. A
  // client-side retry of a timed-out-but-actually-succeeded call (same
  // logical mutation, same idempotencyKey) must coalesce into exactly one
  // audit_log entry instead of a duplicate from the old auto-ID .add().
  test('AUD-firebase-08: repeated call with the same idempotencyKey writes exactly one audit-log entry', async () => {
    await seedActiveGrant({ can_reset_completion: true });
    const compRef = profileRef().collection('completions').doc('c1');
    await compRef.set({ points: 10, sefaria_ref: 'Berakhot.2a' });

    const args = { ...goodArgs, idempotencyKey: 'retry-key-1' };

    const res1 = await call(fns.tutorResetCompletion, args);
    assert.equal(res1.success, true);

    // Simulate the client retrying the SAME logical call (e.g. after a
    // timeout that actually succeeded server-side) with the SAME key.
    const res2 = await call(fns.tutorResetCompletion, args);
    assert.equal(res2.success, true);

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(
      audit.size,
      1,
      'retries with the same idempotencyKey must coalesce to one audit-log entry',
    );
  });

  test('AUD-firebase-08: different idempotencyKeys produce distinct audit-log entries', async () => {
    await seedActiveGrant({ can_reset_completion: true });
    const compRef = profileRef().collection('completions').doc('c1');
    await compRef.set({ points: 10, sefaria_ref: 'Berakhot.2a' });

    await call(fns.tutorResetCompletion, { ...goodArgs, idempotencyKey: 'key-a' });
    // Different completionId so the second call is a real (non-retry)
    // mutation, still exercised with a distinct idempotencyKey.
    const compRef2 = profileRef().collection('completions').doc('c2');
    await compRef2.set({ points: 5, sefaria_ref: 'Shabbat.3a' });
    await call(fns.tutorResetCompletion, {
      ...goodArgs,
      completionId: 'c2',
      idempotencyKey: 'key-b',
    });

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 2, 'distinct idempotencyKeys must not collide');
  });
});
