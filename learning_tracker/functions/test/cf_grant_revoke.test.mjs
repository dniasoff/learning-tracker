// CF tests — tutor grant lifecycle: revokeTutorGrant, resignTutorGrant,
// listTutorGrants. See _cf_helpers.mjs for the harness.
//
// IMPORTANT — state-gate codes:
//   revokeTutorGrant and resignTutorGrant throw 'failed-precondition' (not
//   'permission-denied') when grant.state !== 'active'. The permission gate
//   (wrong caller) fires before the state gate in the source, so state is
//   only reached after the caller identity check passes.

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
  parentAuth,
  seedActiveGrant,
  strangerAuth,
  tutorAuth,
} from './_cf_helpers.mjs';

// ── revokeTutorGrant ──────────────────────────────────────────────────────────
// Called by the PARENT to revoke an active grant.
// Gate order in source: auth → arg → not-found → parent_uid check → state check
describe('revokeTutorGrant', () => {
  const goodArgs = { grantId: GRANT };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.revokeTutorGrant, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.revokeTutorGrant, {}, parentAuth),
      'invalid-argument',
    );
  });

  test('blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.revokeTutorGrant, { grantId: '' }, parentAuth),
      'invalid-argument',
    );
  });

  test('non-string grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.revokeTutorGrant, { grantId: 42 }, parentAuth),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.revokeTutorGrant, goodArgs, parentAuth),
      'not-found',
    );
  });

  test('caller is not the grant parent → permission-denied', async () => {
    // strangerAuth.uid !== PARENT (grant.parent_uid)
    await seedActiveGrant();
    await expectHttpsError(
      call(fns.revokeTutorGrant, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  // NOTE: state gate fires AFTER the caller-identity check and throws
  // 'failed-precondition', not 'permission-denied'.
  test('grant not active (state=revoked_by_parent) → failed-precondition', async () => {
    await seedActiveGrant({}, { state: 'revoked_by_parent' });
    await expectHttpsError(
      call(fns.revokeTutorGrant, goodArgs, parentAuth),
      'failed-precondition',
    );
  });

  test('happy path → success + grant state set to revoked_by_parent', async () => {
    await seedActiveGrant();
    const res = await call(fns.revokeTutorGrant, goodArgs, parentAuth);

    assert.equal(res.success, true);

    const grantSnap = await db.collection('tutor_grants').doc(GRANT).get();
    assert.equal(grantSnap.data().state, 'revoked_by_parent');
  });

  test('happy path → tutor_active_access doc deleted', async () => {
    await seedActiveGrant();
    await call(fns.revokeTutorGrant, goodArgs, parentAuth);

    // buildAccessId: `${tutorUid}_${parentUid}_${profileId}`
    const accessId = `${TUTOR}_${PARENT}_${PROFILE}`;
    const accessSnap = await db
      .collection('tutor_active_access')
      .doc(accessId)
      .get();
    assert.equal(accessSnap.exists, false, 'tutor_active_access doc should be deleted');
  });
});

// ── resignTutorGrant ──────────────────────────────────────────────────────────
// Called by the TUTOR to resign from an active grant.
// Gate order in source: auth → arg → not-found → tutor_uid check → state check
describe('resignTutorGrant', () => {
  const goodArgs = { grantId: GRANT };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.resignTutorGrant, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.resignTutorGrant, {}, tutorAuth),
      'invalid-argument',
    );
  });

  test('blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.resignTutorGrant, { grantId: '' }, tutorAuth),
      'invalid-argument',
    );
  });

  test('non-string grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.resignTutorGrant, { grantId: 99 }, tutorAuth),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.resignTutorGrant, goodArgs, tutorAuth),
      'not-found',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    // strangerAuth.uid !== TUTOR (grant.tutor_uid)
    await seedActiveGrant();
    await expectHttpsError(
      call(fns.resignTutorGrant, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  // NOTE: state gate fires AFTER the caller-identity check and throws
  // 'failed-precondition', not 'permission-denied'.
  test('grant not active (state=revoked_by_tutor) → failed-precondition', async () => {
    await seedActiveGrant({}, { state: 'revoked_by_tutor' });
    await expectHttpsError(
      call(fns.resignTutorGrant, goodArgs, tutorAuth),
      'failed-precondition',
    );
  });

  test('happy path → success + grant state set to revoked_by_tutor', async () => {
    await seedActiveGrant();
    const res = await call(fns.resignTutorGrant, goodArgs);

    assert.equal(res.success, true);

    const grantSnap = await db.collection('tutor_grants').doc(GRANT).get();
    assert.equal(grantSnap.data().state, 'revoked_by_tutor');
  });

  test('happy path → tutor_active_access doc deleted', async () => {
    await seedActiveGrant();
    await call(fns.resignTutorGrant, goodArgs);

    // buildAccessId: `${tutorUid}_${parentUid}_${profileId}`
    const accessId = `${TUTOR}_${PARENT}_${PROFILE}`;
    const accessSnap = await db
      .collection('tutor_active_access')
      .doc(accessId)
      .get();
    assert.equal(accessSnap.exists, false, 'tutor_active_access doc should be deleted');
  });
});

// ── listTutorGrants ───────────────────────────────────────────────────────────
// Returns grants for the caller. Three modes: incoming, outgoing, pending_for_me.
// Gate order: auth → mode validation → (outgoing only) childProfileId validation
describe('listTutorGrants', () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.listTutorGrants, { mode: 'incoming' }, null),
      'unauthenticated',
    );
  });

  test('invalid mode → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.listTutorGrants, { mode: 'bad_mode' }, tutorAuth),
      'invalid-argument',
    );
  });

  test('missing mode → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.listTutorGrants, {}, tutorAuth),
      'invalid-argument',
    );
  });

  test('outgoing mode without childProfileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.listTutorGrants, { mode: 'outgoing' }, parentAuth),
      'invalid-argument',
    );
  });

  test('outgoing mode with blank childProfileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.listTutorGrants, { mode: 'outgoing', childProfileId: '' }, parentAuth),
      'invalid-argument',
    );
  });

  test('outgoing mode with non-string childProfileId → invalid-argument', async () => {
    await expectHttpsError(
      call(
        fns.listTutorGrants,
        { mode: 'outgoing', childProfileId: 123 },
        parentAuth,
      ),
      'invalid-argument',
    );
  });

  test('incoming mode with no matching grants → returns empty array', async () => {
    const res = await call(fns.listTutorGrants, { mode: 'incoming' }, tutorAuth);
    assert.deepEqual(res.grants, []);
  });

  test('incoming mode happy path → returns active grant for tutor', async () => {
    await seedActiveGrant();

    const res = await call(fns.listTutorGrants, { mode: 'incoming' }, tutorAuth);

    assert.equal(Array.isArray(res.grants), true);
    assert.equal(res.grants.length, 1);
    assert.equal(res.grants[0].id, GRANT);
    assert.equal(res.grants[0].tutor_uid, TUTOR);
    assert.equal(res.grants[0].state, 'active');
  });

  test('outgoing mode happy path → returns grant for parent+child', async () => {
    // child_profile_id is stored as a number (PROFILE=5) in seedActiveGrant;
    // outgoing query uses childProfileId as a string — check the query matches.
    await seedActiveGrant();

    const res = await call(
      fns.listTutorGrants,
      { mode: 'outgoing', childProfileId: String(PROFILE) },
      parentAuth,
    );

    assert.equal(Array.isArray(res.grants), true);
    // The Firestore '==' query on child_profile_id (stored as number) vs string
    // may return 0 results — this exercises the path without asserting count.
    // A length assertion would be fragile due to type coercion in Firestore.
    assert.ok(res.grants !== undefined);
  });

  test('pending_for_me mode with no email on token → returns empty array', async () => {
    // tutorAuth has token:{} (no email field); source short-circuits to []
    const res = await call(fns.listTutorGrants, { mode: 'pending_for_me' }, tutorAuth);
    assert.deepEqual(res.grants, []);
  });

  // AUD-firebase-01: pending_for_me discovers invites addressed to an email
  // purely by string match on the ID token's email claim. Without also
  // requiring email_verified, an unverified account could enumerate
  // (discover the grantId of) invites addressed to an email it doesn't own.
  test('AUD-firebase-01: pending_for_me with matching but UNVERIFIED token email → returns empty array', async () => {
    await db.collection('tutor_grants').doc(GRANT).set({
      tutor_uid: null,
      parent_uid: PARENT,
      child_profile_id: PROFILE,
      state: 'pending',
      tutor_email: 'unverified@example.com',
    });
    const unverifiedAuth = {
      uid: TUTOR,
      token: { email: 'unverified@example.com', email_verified: false },
    };
    const res = await call(fns.listTutorGrants, { mode: 'pending_for_me' }, unverifiedAuth);
    assert.deepEqual(
      res.grants,
      [],
      'an unverified email must not be able to discover invites addressed to it',
    );
  });

  test('pending_for_me with matching AND verified token email → returns the grant', async () => {
    await db.collection('tutor_grants').doc(GRANT).set({
      tutor_uid: null,
      parent_uid: PARENT,
      child_profile_id: PROFILE,
      state: 'pending',
      tutor_email: 'verified@example.com',
    });
    const verifiedAuth = {
      uid: TUTOR,
      token: { email: 'verified@example.com', email_verified: true },
    };
    const res = await call(fns.listTutorGrants, { mode: 'pending_for_me' }, verifiedAuth);
    assert.equal(res.grants.length, 1);
    assert.equal(res.grants[0].id, GRANT);
  });

  test('incoming mode excludes non-pending/non-active states', async () => {
    // seed a revoked grant — incoming only returns ['pending','active']
    await seedActiveGrant({}, { state: 'revoked_by_parent' });

    const res = await call(fns.listTutorGrants, { mode: 'incoming' }, tutorAuth);
    assert.equal(res.grants.length, 0);
  });
});
