// Server-owned parent PIN and session lifecycle tests (7vx).

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  PARENT,
  PROFILE,
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  parentAuth,
  profileRef,
} from './_cf_helpers.mjs';

const recentParentAuth = {
  uid: PARENT,
  token: { auth_time: Math.floor(Date.now() / 1000) },
};

function sessionRef(sessionId) {
  return db.collection('users').doc(PARENT)
    .collection('parent_sessions').doc(sessionId);
}

function pinRef() {
  return db.collection('users').doc(PARENT)
    .collection('private_security').doc('parent_pins')
    .collection('profiles').doc(PROFILE);
}

describe('parent PIN and session callables', () => {
  beforeEach(async () => {
    await clearFirestore();
    await profileRef().set({ display_name: 'Child', mode: 'child' });
  });

  test('recently reauthenticated owner can enroll and use a server PIN', async () => {
    const enrolled = await call(fns.setParentPin, {
      profileId: PROFILE,
      pin: '2468',
    }, recentParentAuth);
    assert.deepEqual(enrolled, { success: true });
    assert.match((await pinRef().get()).get('hash'), /^scrypt-v1\$/);

    const created = await call(fns.createParentSession, {
      profileId: PROFILE,
      pin: '2468',
    }, parentAuth);
    assert.equal(typeof created.sessionId, 'string');
    assert.match(created.sessionId, /^[a-f0-9]{64}$/);
    const session = await sessionRef(created.sessionId).get();
    assert.equal(session.get('profile_id'), PROFILE);
    assert.equal(session.get('revoked'), false);
    assert.ok(session.get('expires_at').toMillis() > session.get('created_at').toMillis());
  });

  test('a client cannot enroll a PIN without recent account reauthentication', async () => {
    await expectHttpsError(
      call(fns.setParentPin, { profileId: PROFILE, pin: '2468' }, parentAuth),
      'failed-precondition',
    );
    assert.equal((await pinRef().get()).exists, false);
  });

  test('incorrect PIN cannot mint a session and repeated failures lock the PIN', async () => {
    await call(fns.setParentPin, { profileId: PROFILE, pin: '2468' }, recentParentAuth);
    for (let i = 0; i < 4; i++) {
      await expectHttpsError(
        call(fns.createParentSession, { profileId: PROFILE, pin: '0000' }, parentAuth),
        'permission-denied',
      );
    }
    await expectHttpsError(
      call(fns.createParentSession, { profileId: PROFILE, pin: '0000' }, parentAuth),
      'resource-exhausted',
    );
    const sessions = await db.collection('users').doc(PARENT)
      .collection('parent_sessions').get();
    assert.equal(sessions.empty, true);
  });

  test('revoke is owner-bound and idempotent', async () => {
    await call(fns.setParentPin, { profileId: PROFILE, pin: '2468' }, recentParentAuth);
    const created = await call(fns.createParentSession, {
      profileId: PROFILE,
      pin: '2468',
    }, parentAuth);
    const revoked = await call(fns.revokeParentSession, {
      parentSessionId: created.sessionId,
    }, parentAuth);
    assert.deepEqual(revoked, { success: true, alreadyRevoked: false });
    assert.equal((await sessionRef(created.sessionId).get()).get('revoked'), true);

    const replay = await call(fns.revokeParentSession, {
      parentSessionId: created.sessionId,
    }, parentAuth);
    assert.deepEqual(replay, { success: true, alreadyRevoked: true });
  });

  test('setting a new PIN revokes all active sessions for that profile', async () => {
    await call(fns.setParentPin, { profileId: PROFILE, pin: '2468' }, recentParentAuth);
    const first = await call(fns.createParentSession, {
      profileId: PROFILE,
      pin: '2468',
    }, parentAuth);
    await call(fns.setParentPin, { profileId: PROFILE, pin: '1357' }, recentParentAuth);
    assert.equal((await sessionRef(first.sessionId).get()).get('revoked'), true);
  });
});
