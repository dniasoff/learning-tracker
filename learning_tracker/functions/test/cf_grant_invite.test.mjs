// CF tests — tutor grant invite lifecycle:
// inviteTutor, acceptTutorInvite, declineTutorInvite, rescindTutorInvite.
// See _cf_helpers.mjs for the harness.
//
// acceptTutorInvite and declineTutorInvite both call the REAL
// admin.auth().getUser() to verify the caller's email — make test-functions
// starts `--only firestore,auth`, so seedAuthUser() (_cf_helpers.mjs) creates
// a real Auth-emulator user record and those gates ARE exercised here
// (AUD-firebase-01).

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
  seedAuthUser,
  strangerAuth,
} from './_cf_helpers.mjs';

// ── inviteTutor ───────────────────────────────────────────────────────────────
// Caller is the parent (parentAuth). Creates a tutor_grants doc.
// No verifyTutorGrant / writeAuditLog used.
describe('inviteTutor', () => {
  const goodArgs = {
    tutorEmail: 'tutor@example.com',
    childProfileId: String(PROFILE),
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.inviteTutor, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing tutorEmail → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.inviteTutor, { ...goodArgs, tutorEmail: undefined }, parentAuth),
      'invalid-argument',
    );
  });

  test('tutorEmail without @ → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.inviteTutor, { ...goodArgs, tutorEmail: 'notanemail' }, parentAuth),
      'invalid-argument',
    );
  });

  test('non-string tutorEmail → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.inviteTutor, { ...goodArgs, tutorEmail: 42 }, parentAuth),
      'invalid-argument',
    );
  });

  test('missing childProfileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.inviteTutor, { ...goodArgs, childProfileId: undefined }, parentAuth),
      'invalid-argument',
    );
  });

  test('blank childProfileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.inviteTutor, { ...goodArgs, childProfileId: '' }, parentAuth),
      'invalid-argument',
    );
  });

  test('non-string childProfileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.inviteTutor, { ...goodArgs, childProfileId: 123 }, parentAuth),
      'invalid-argument',
    );
  });

  test('happy path → returns success + grantId, creates tutor_grants doc', async () => {
    const res = await call(fns.inviteTutor, goodArgs, parentAuth);

    assert.equal(res.success, true);
    assert.ok(typeof res.grantId === 'string' && res.grantId.length > 0, 'grantId must be a non-empty string');

    const grantSnap = await db.collection('tutor_grants').doc(res.grantId).get();
    assert.equal(grantSnap.exists, true, 'tutor_grants doc should be created');
    const data = grantSnap.data();
    assert.equal(data.state, 'pending');
    assert.equal(data.parent_uid, PARENT);
  });
});

// ── acceptTutorInvite ─────────────────────────────────────────────────────────
// Caller is the tutor. Validates grantId, state=pending, not expired,
// caller email === grant.tutor_email AND caller emailVerified === true
// (AUD-firebase-01 — via admin.auth().getUser(), Auth emulator).
describe('acceptTutorInvite', () => {
  const goodArgs = { grantId: GRANT };
  const TUTOR_EMAIL = 'tutor@example.com';

  beforeEach(async () => {
    await clearFirestore();
  });

  async function seedPendingGrant(overrides = {}) {
    await db.collection('tutor_grants').doc(GRANT).set({
      tutor_uid: null,
      parent_uid: PARENT,
      child_profile_id: PROFILE,
      state: 'pending',
      tutor_email: TUTOR_EMAIL,
      invite_token: 'test-token',
      ...overrides,
    });
  }

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.acceptTutorInvite, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.acceptTutorInvite, { grantId: undefined }),
      'invalid-argument',
    );
  });

  test('blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.acceptTutorInvite, { grantId: '' }),
      'invalid-argument',
    );
  });

  test('non-string grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.acceptTutorInvite, { grantId: 42 }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.acceptTutorInvite, goodArgs),
      'not-found',
    );
  });

  // State check happens BEFORE getUser(), so this is testable without Auth emulator.
  test('grant not in pending state → failed-precondition', async () => {
    // Seed with a non-pending state (active is the default from seedActiveGrant).
    await seedActiveGrant({}, { state: 'active' });
    await expectHttpsError(
      call(fns.acceptTutorInvite, goodArgs),
      'failed-precondition',
    );
  });

  test('grant in declined state → failed-precondition', async () => {
    await seedActiveGrant({}, { state: 'declined' });
    await expectHttpsError(
      call(fns.acceptTutorInvite, goodArgs),
      'failed-precondition',
    );
  });

  // AUD-firebase-01 — core regression: an unverified email must never be
  // trusted to claim an invite, even when it matches grant.tutor_email
  // exactly (e.g. an attacker front-running registration of the invited
  // tutor's email address before the real owner verifies it).
  test('AUD-firebase-01: caller email matches but is UNVERIFIED → permission-denied', async () => {
    await seedPendingGrant();
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: false });

    await expectHttpsError(
      call(fns.acceptTutorInvite, goodArgs), // default tutorAuth uid=TUTOR
      'permission-denied',
    );

    const after = (await db.collection('tutor_grants').doc(GRANT).get()).data();
    assert.equal(after.state, 'pending', 'grant must NOT be accepted');
  });

  test('caller email does not match grant.tutor_email (verified) → permission-denied', async () => {
    await seedPendingGrant();
    await seedAuthUser({
      uid: TUTOR,
      email: 'someone-else@example.com',
      emailVerified: true,
    });

    await expectHttpsError(
      call(fns.acceptTutorInvite, goodArgs),
      'permission-denied',
    );
  });

  test('caller email matches AND is verified → success, grant becomes active', async () => {
    await seedPendingGrant();
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: true });

    const res = await call(fns.acceptTutorInvite, goodArgs);

    assert.equal(res.success, true);
    const after = (await db.collection('tutor_grants').doc(GRANT).get()).data();
    assert.equal(after.state, 'active');
    assert.equal(after.tutor_uid, TUTOR);
    assert.equal(after.invite_token, undefined, 'invite_token must be cleared (single-use)');
  });
});

// ── declineTutorInvite ────────────────────────────────────────────────────────
// Caller is the tutor, either by tutor_uid (already accepted once, resigning
// via decline is not the normal path but uid-match short-circuits regardless)
// or — for a still-PENDING invite where tutor_uid is null — by email match
// AND emailVerified === true (AUD-firebase-01, mirrors acceptTutorInvite).
describe('declineTutorInvite', () => {
  const goodArgs = { grantId: GRANT };
  const TUTOR_EMAIL = 'tutor@example.com';

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.declineTutorInvite, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.declineTutorInvite, { grantId: undefined }),
      'invalid-argument',
    );
  });

  test('blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.declineTutorInvite, { grantId: '' }),
      'invalid-argument',
    );
  });

  test('non-string grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.declineTutorInvite, { grantId: 42 }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.declineTutorInvite, goodArgs),
      'not-found',
    );
  });

  // The caller-is-tutor check now resolves by uid FIRST (no admin.auth() call),
  // so the uid-match path is fully testable under the firestore emulator.
  test('caller matches tutor_uid + pending → success, grant declined', async () => {
    await db.collection('tutor_grants').doc(GRANT).set({
      tutor_uid: TUTOR,
      parent_uid: PARENT,
      child_profile_id: PROFILE,
      state: 'pending',
      tutor_email: 'tutor@example.com',
    });

    const res = await call(fns.declineTutorInvite, goodArgs); // default tutorAuth

    assert.equal(res.success, true);
    const after = (await db.collection('tutor_grants').doc(GRANT).get()).data();
    assert.equal(after.state, 'declined');
  });

  test('caller matches tutor_uid but grant not pending → failed-precondition', async () => {
    await db.collection('tutor_grants').doc(GRANT).set({
      tutor_uid: TUTOR,
      parent_uid: PARENT,
      child_profile_id: PROFILE,
      state: 'active',
      tutor_email: 'tutor@example.com',
    });

    await expectHttpsError(
      call(fns.declineTutorInvite, goodArgs),
      'failed-precondition',
    );
  });

  // AUD-firebase-01 — pending invite, tutor_uid still null (not yet
  // accepted): the caller-is-tutor check falls back to the email match, and
  // must also require emailVerified.
  test('AUD-firebase-01: pending invite, tutor_uid null, caller email matches but UNVERIFIED → permission-denied', async () => {
    await db.collection('tutor_grants').doc(GRANT).set({
      tutor_uid: null,
      parent_uid: PARENT,
      child_profile_id: PROFILE,
      state: 'pending',
      tutor_email: TUTOR_EMAIL,
    });
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: false });

    await expectHttpsError(
      call(fns.declineTutorInvite, goodArgs),
      'permission-denied',
    );

    const after = (await db.collection('tutor_grants').doc(GRANT).get()).data();
    assert.equal(after.state, 'pending', 'grant must NOT be declined');
  });

  test('pending invite, tutor_uid null, caller email matches AND verified → success', async () => {
    await db.collection('tutor_grants').doc(GRANT).set({
      tutor_uid: null,
      parent_uid: PARENT,
      child_profile_id: PROFILE,
      state: 'pending',
      tutor_email: TUTOR_EMAIL,
    });
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: true });

    const res = await call(fns.declineTutorInvite, goodArgs);

    assert.equal(res.success, true);
    const after = (await db.collection('tutor_grants').doc(GRANT).get()).data();
    assert.equal(after.state, 'declined');
  });
});

// ── rescindTutorInvite ────────────────────────────────────────────────────────
// Caller is the parent. Validates grantId, checks parent_uid === callerUid,
// checks state === 'pending'. No admin.auth().getUser() — fully testable.
describe('rescindTutorInvite', () => {
  const goodArgs = { grantId: GRANT };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.rescindTutorInvite, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.rescindTutorInvite, { grantId: undefined }, parentAuth),
      'invalid-argument',
    );
  });

  test('blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.rescindTutorInvite, { grantId: '' }, parentAuth),
      'invalid-argument',
    );
  });

  test('non-string grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.rescindTutorInvite, { grantId: 42 }, parentAuth),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.rescindTutorInvite, goodArgs, parentAuth),
      'not-found',
    );
  });

  test('caller is not the parent (stranger) → permission-denied', async () => {
    // Seed a pending grant owned by PARENT
    await seedActiveGrant({}, { state: 'pending' });
    await expectHttpsError(
      call(fns.rescindTutorInvite, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant not in pending state → failed-precondition', async () => {
    // seedActiveGrant defaults to state='active'; parent_uid=PARENT
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.rescindTutorInvite, goodArgs, parentAuth),
      'failed-precondition',
    );
  });

  test('grant in declined state → failed-precondition', async () => {
    await seedActiveGrant({}, { state: 'declined' });
    await expectHttpsError(
      call(fns.rescindTutorInvite, goodArgs, parentAuth),
      'failed-precondition',
    );
  });

  test('happy path → returns success, sets grant state to rescinded', async () => {
    // Seed a pending grant owned by PARENT
    await seedActiveGrant({}, { state: 'pending' });

    const res = await call(fns.rescindTutorInvite, goodArgs, parentAuth);

    assert.equal(res.success, true);

    const grantSnap = await db.collection('tutor_grants').doc(GRANT).get();
    assert.equal(grantSnap.exists, true);
    assert.equal(grantSnap.data().state, 'rescinded');
  });
});
