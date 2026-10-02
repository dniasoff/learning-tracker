// CF tests — stale grant transitions vs re-invite (DNI-487 review).
//
// Grant ids are deterministic per (tutor email, parent, child), so a re-invite
// re-uses the doc a decline / rescind / expiry / revoke / resign decided on.
// Each of those transitions must apply only to the grant generation it read.
//
// The race is made deterministic by interleaving: the next db.runTransaction()
// call first runs a competing action (re-invite, accept, ...) to completion,
// then starts the real transaction — exactly the window between a callable's
// read and its write. See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import admin from 'firebase-admin';
import { afterEach, beforeEach, describe, test } from 'node:test';
import {
  PARENT,
  PROFILE,
  TUTOR,
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fft,
  fns,
  parentAuth,
  seedAuthUser,
} from './_cf_helpers.mjs';

const TUTOR_EMAIL = 'tutor@example.com';
const inviteArgs = { tutorEmail: TUTOR_EMAIL, childProfileId: String(PROFILE) };

const originalRunTransaction = db.runTransaction;

/**
 * Run [action] right before the next transaction starts (once), so it commits
 * between the callable's pre-transaction read and its transactional write.
 */
function interleaveBeforeNextTransaction(action) {
  db.runTransaction = async function (...args) {
    db.runTransaction = originalRunTransaction;
    await action();
    return originalRunTransaction.apply(db, args);
  };
}

async function invite() {
  const res = await call(fns.inviteTutor, inviteArgs, parentAuth);
  return res.grantId;
}

const grantRef = (grantId) => db.collection('tutor_grants').doc(grantId);
const readGrant = async (grantId) => (await grantRef(grantId).get()).data();

function daysFromNow(days) {
  return admin.firestore.Timestamp.fromMillis(Date.now() + days * 86_400_000);
}

async function makeExpired(grantId) {
  await grantRef(grantId).update({ expires_at: daysFromNow(-1) });
}

async function makeActive(grantId) {
  await grantRef(grantId).update({
    state: 'active',
    tutor_uid: TUTOR,
    accepted_at: admin.firestore.Timestamp.now(),
    invite_token: admin.firestore.FieldValue.delete(),
  });
}

async function auditCount(grantId) {
  return (await grantRef(grantId).collection('audit_log').get()).size;
}

describe('stale grant transitions vs re-invite', () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  afterEach(() => {
    db.runTransaction = originalRunTransaction;
  });

  test('expirePendingInvites: a re-invite after the query keeps its fresh pending grant', async () => {
    const grantId = await invite();
    await makeExpired(grantId);

    let freshToken;
    interleaveBeforeNextTransaction(async () => {
      await invite();
      freshToken = (await readGrant(grantId)).invite_token;
    });
    await fft.wrap(fns.expirePendingInvites)();

    const after = await readGrant(grantId);
    assert.equal(after.state, 'pending', 're-invite must not be expired');
    assert.equal(after.invite_token, freshToken, 'fresh invite token must survive');
    assert.ok(after.expires_at.toMillis() > Date.now(), 'fresh expiry must survive');
    assert.equal(await auditCount(grantId), 0, 'no invite_expired audit entry');
  });

  test('expirePendingInvites: an unchanged expired invite is still expired', async () => {
    const grantId = await invite();
    await makeExpired(grantId);

    await fft.wrap(fns.expirePendingInvites)();

    const after = await readGrant(grantId);
    assert.equal(after.state, 'expired');
    assert.equal(after.invite_token, undefined);
    assert.equal(await auditCount(grantId), 1);
  });

  test('acceptTutorInvite on an expired invite: a concurrent re-invite is not expired', async () => {
    const grantId = await invite();
    await makeExpired(grantId);

    let freshToken;
    interleaveBeforeNextTransaction(async () => {
      await invite();
      freshToken = (await readGrant(grantId)).invite_token;
    });
    await expectHttpsError(
      call(fns.acceptTutorInvite, { grantId }),
      'failed-precondition',
    );

    const after = await readGrant(grantId);
    assert.equal(after.state, 'pending', 're-invite must not be expired');
    assert.equal(after.invite_token, freshToken);
  });

  test('acceptTutorInvite on an expired invite with no race → expired', async () => {
    const grantId = await invite();
    await makeExpired(grantId);

    await expectHttpsError(
      call(fns.acceptTutorInvite, { grantId }),
      'failed-precondition',
    );

    const after = await readGrant(grantId);
    assert.equal(after.state, 'expired');
    assert.equal(after.invite_token, undefined);
  });

  test('acceptTutorInvite: an invite that expires after the pre-check is expired, not activated', async () => {
    const grantId = await invite();
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: true });
    const token = (await readGrant(grantId)).invite_token;

    // The expiry passes between the pre-transaction check and the write.
    interleaveBeforeNextTransaction(() => makeExpired(grantId));
    await expectHttpsError(
      call(fns.acceptTutorInvite, { grantId }),
      'failed-precondition',
    );

    const after = await readGrant(grantId);
    assert.equal(after.state, 'expired', 'expired invite must not become active');
    assert.equal(after.tutor_uid ?? null, null, 'tutor must not be bound');
    assert.equal(after.accepted_at ?? null, null);
    assert.equal(after.invite_token, undefined);
    assert.ok(token, 'precondition: invite had a token');
    const access = await db
      .collection('tutor_active_access')
      .where('grant_id', '==', grantId)
      .get();
    assert.equal(access.size, 0, 'no tutor_active_access for an expired invite');
    const audit = await grantRef(grantId).collection('audit_log').get();
    assert.deepEqual(audit.docs.map((d) => d.data().action), ['invite_expired']);
  });

  test('acceptTutorInvite: an unexpired invite with no race is accepted', async () => {
    const grantId = await invite();
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: true });

    await call(fns.acceptTutorInvite, { grantId });

    const after = await readGrant(grantId);
    assert.equal(after.state, 'active');
    assert.equal(after.tutor_uid, TUTOR);
  });

  test('declineTutorInvite: a re-invite after the identity check is rejected, not declined', async () => {
    const grantId = await invite();
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: true });

    let freshToken;
    interleaveBeforeNextTransaction(async () => {
      await invite();
      freshToken = (await readGrant(grantId)).invite_token;
    });
    await expectHttpsError(
      call(fns.declineTutorInvite, { grantId }),
      'failed-precondition',
    );

    const after = await readGrant(grantId);
    assert.equal(after.state, 'pending', 're-invite must not be declined');
    assert.equal(after.invite_token, freshToken);
    assert.equal(after.declined_at, undefined);
  });

  test('declineTutorInvite: an acceptance after the identity check is not overwritten', async () => {
    const grantId = await invite();
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: true });

    interleaveBeforeNextTransaction(() => makeActive(grantId));
    await expectHttpsError(
      call(fns.declineTutorInvite, { grantId }),
      'failed-precondition',
    );

    assert.equal((await readGrant(grantId)).state, 'active');
  });

  test('rescindTutorInvite: an acceptance that commits first is not overwritten', async () => {
    const grantId = await invite();

    interleaveBeforeNextTransaction(() => makeActive(grantId));
    await expectHttpsError(
      call(fns.rescindTutorInvite, { grantId }, parentAuth),
      'failed-precondition',
    );

    const after = await readGrant(grantId);
    assert.equal(after.state, 'active', 'accepted grant must not become rescinded');
    assert.equal(after.revoked_at, undefined);
  });

  test('revokeTutorGrant: resign + re-invite after the read is rejected, not revoked', async () => {
    const grantId = await invite();
    await makeActive(grantId);

    interleaveBeforeNextTransaction(async () => {
      await grantRef(grantId).update({ state: 'revoked_by_tutor' });
      await invite();
    });
    await expectHttpsError(
      call(fns.revokeTutorGrant, { grantId }, parentAuth),
      'failed-precondition',
    );

    const after = await readGrant(grantId);
    assert.equal(after.state, 'pending', 're-invite must not be revoked');
    assert.ok(after.invite_token, 'fresh invite token must survive');
  });

  test('resignTutorGrant: revoke + re-invite after the read is rejected, not resigned', async () => {
    const grantId = await invite();
    await makeActive(grantId);

    interleaveBeforeNextTransaction(async () => {
      await grantRef(grantId).update({ state: 'revoked_by_parent' });
      await invite();
    });
    await expectHttpsError(
      call(fns.resignTutorGrant, { grantId }),
      'failed-precondition',
    );

    const after = await readGrant(grantId);
    assert.equal(after.state, 'pending', 're-invite must not be resigned');
    assert.ok(after.invite_token);
  });

  test('revokeTutorGrant: an unchanged active grant is still revoked', async () => {
    const grantId = await invite();
    await makeActive(grantId);

    const res = await call(fns.revokeTutorGrant, { grantId }, parentAuth);

    assert.equal(res.success, true);
    assert.equal((await readGrant(grantId)).state, 'revoked_by_parent');
  });
});
