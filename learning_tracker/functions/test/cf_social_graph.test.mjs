import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { beforeEach, describe, test } from 'node:test';
import {
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  parentAuth,
  seedParentSession,
  seedSocialProfile,
  socialProfileDocId,
  socialProfileId,
  strangerAuth,
} from './_cf_helpers.mjs';

const SCHOOL = 'school-1';
const CHILD = 'child-profile';
const OTHER = 'adult-profile';

function pairDocId(fromUid, fromProfileId, toUid, toProfileId) {
  return createHash('sha256')
    .update([fromUid, fromProfileId, toUid, toProfileId].join('\0'))
    .digest('hex');
}

async function member(uid, profileId, schoolId = SCHOOL) {
  await db.collection('school_memberships').add({
    owner_uid: uid,
    profile_id: profileId,
    school_id: schoolId,
    state: 'active',
  });
}

async function seedAdultPair() {
  await seedSocialProfile(parentAuth.uid, CHILD, 'adult');
  await seedSocialProfile(strangerAuth.uid, OTHER, 'adult');
}

describe('social graph callable state', () => {
  beforeEach(async () => clearFirestore());

  test('adult follow starts pending and only the recipient can accept it', async () => {
    await seedAdultPair();
    const sent = await call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth);
    assert.equal(typeof sent.requestId, 'string');
    assert.equal((await db.collection('social_follows').get()).size, 0);
    const request = await db.collection('social_follow_requests').doc(sent.requestId).get();
    assert.equal(request.get('state'), 'pending');

    await expectHttpsError(call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: OTHER,
      decision: 'accept',
    }, parentAuth), 'not-found');
    await call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: OTHER,
      decision: 'accept',
    }, strangerAuth);
    const edges = await db.collection('social_follows').get();
    assert.equal(edges.size, 1);
    assert.equal(edges.docs[0].get('state'), 'active');
    const inbox = await call(fns.listSocialConnections, { profileId: OTHER }, strangerAuth);
    assert.equal(inbox.incomingRequests[0].fromSocialProfileId, socialProfileId(parentAuth.uid, CHILD));
    assert.equal('from_owner_uid' in inbox.incomingRequests[0], false);
  });

  test('child outbound request requires parent session and an allow-listed active school', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'child');
    await seedSocialProfile(strangerAuth.uid, OTHER, 'adult');
    await member(parentAuth.uid, CHILD);
    await member(strangerAuth.uid, OTHER);
    const sessionId = await seedParentSession(parentAuth.uid, CHILD);
    await db.collection('social_parent_controls').doc(socialProfileDocId(parentAuth.uid, CHILD)).set({
      owner_uid: parentAuth.uid,
      profile_id: CHILD,
      allowed_school_ids: [SCHOOL],
    });

    await expectHttpsError(call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth), 'invalid-argument');
    const result = await call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
      parentSessionId: sessionId,
    }, parentAuth);
    await call(fns.reviewFollowRequest, {
      requestId: result.requestId,
      profileId: OTHER,
      decision: 'accept',
    }, strangerAuth);
    assert.equal((await db.collection('social_follows').get()).size, 1);
  });

  test('child inbound request is denied outside its allow-list and needs parent approval inside it', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'child');
    await seedSocialProfile(strangerAuth.uid, OTHER, 'adult');
    await member(parentAuth.uid, CHILD, SCHOOL);
    await member(strangerAuth.uid, OTHER, 'other-school');
    const sessionId = await seedParentSession(parentAuth.uid, CHILD);
    const controlsId = socialProfileDocId(parentAuth.uid, CHILD);
    await db.collection('social_parent_controls').doc(controlsId).set({
      owner_uid: parentAuth.uid,
      profile_id: CHILD,
      allowed_school_ids: [SCHOOL],
    });
    await expectHttpsError(call(fns.sendFollowRequest, {
      fromProfileId: OTHER,
      toSocialProfileId: socialProfileId(parentAuth.uid, CHILD),
    }, strangerAuth), 'permission-denied');

    await member(strangerAuth.uid, OTHER, SCHOOL);
    const sent = await call(fns.sendFollowRequest, {
      fromProfileId: OTHER,
      toSocialProfileId: socialProfileId(parentAuth.uid, CHILD),
    }, strangerAuth);
    await expectHttpsError(call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: CHILD,
      decision: 'accept',
    }, parentAuth), 'invalid-argument');
    await call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: CHILD,
      decision: 'accept',
      parentSessionId: sessionId,
    }, parentAuth);
    assert.equal((await db.collection('social_follows').get()).size, 1);
    await expectHttpsError(call(fns.listSocialConnections, {
      profileId: CHILD,
    }, parentAuth), 'invalid-argument');
    const parentInbox = await call(fns.listSocialConnections, {
      profileId: CHILD,
      parentSessionId: sessionId,
    }, parentAuth);
    assert.equal(parentInbox.incomingRequests.length, 1);
  });

  test('child-to-child follow needs both parents and both allow-lists', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'child');
    await seedSocialProfile(strangerAuth.uid, OTHER, 'child');
    await member(parentAuth.uid, CHILD);
    await member(strangerAuth.uid, OTHER);
    const fromSession = await seedParentSession(parentAuth.uid, CHILD);
    const toSession = await seedParentSession(strangerAuth.uid, OTHER, 'b'.repeat(64));
    await db.collection('social_parent_controls').doc(socialProfileDocId(parentAuth.uid, CHILD)).set({
      owner_uid: parentAuth.uid,
      profile_id: CHILD,
      allowed_school_ids: [SCHOOL],
      paused: false,
    });
    await db.collection('social_parent_controls').doc(socialProfileDocId(strangerAuth.uid, OTHER)).set({
      owner_uid: strangerAuth.uid,
      profile_id: OTHER,
      allowed_school_ids: [SCHOOL],
      paused: false,
    });
    const sent = await call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
      parentSessionId: fromSession,
    }, parentAuth);
    await expectHttpsError(call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: OTHER,
      decision: 'accept',
    }, strangerAuth), 'invalid-argument');
    await call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: OTHER,
      decision: 'accept',
      parentSessionId: toSession,
    }, strangerAuth);
    assert.equal((await db.collection('social_follows').get()).size, 1);
  });

  test('parent control update rejects unjoined schools and keeps the profile paused server-side', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'child');
    const sessionId = await seedParentSession(parentAuth.uid, CHILD);
    await expectHttpsError(call(fns.setChildSocialControls, {
      profileId: CHILD,
      parentSessionId: sessionId,
      allowedSchoolIds: [SCHOOL],
      paused: true,
    }, parentAuth), 'failed-precondition');
    await member(parentAuth.uid, CHILD);
    await call(fns.setChildSocialControls, {
      profileId: CHILD,
      parentSessionId: sessionId,
      allowedSchoolIds: [SCHOOL],
      paused: true,
    }, parentAuth);
    const cardId = socialProfileDocId(parentAuth.uid, CHILD);
    assert.equal((await db.collection('social_profiles').doc(cardId).get()).get('paused'), true);
  });

  test('profile upsert returns a stable opaque id and cannot clear the parent pause', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'child');
    const sessionId = await seedParentSession(parentAuth.uid, CHILD);
    await call(fns.setChildSocialControls, {
      profileId: CHILD,
      parentSessionId: sessionId,
      allowedSchoolIds: [],
      paused: true,
    }, parentAuth);
    const first = await call(fns.upsertSocialProfile, {
      profileId: CHILD,
      displayName: 'Child display name',
      avatarId: 3,
      parentSessionId: sessionId,
    }, parentAuth);
    const second = await call(fns.upsertSocialProfile, {
      profileId: CHILD,
      displayName: 'Updated display name',
      avatarId: 4,
      parentSessionId: sessionId,
    }, parentAuth);
    assert.match(first.socialProfileId, /^[A-Za-z0-9_-]{43}$/);
    assert.equal(second.socialProfileId, first.socialProfileId);
    const doc = await db.collection('social_profiles').doc(socialProfileDocId(parentAuth.uid, CHILD)).get();
    assert.equal(doc.get('paused'), true);
    assert.equal(doc.get('avatar_id'), 4);
  });

  test('expired or revoked parent sessions cannot authorize child social controls', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'child');
    const sessionId = await seedParentSession(parentAuth.uid, CHILD);
    await db.collection('users').doc(parentAuth.uid).collection('parent_sessions').doc(sessionId)
      .update({ revoked: true });
    await expectHttpsError(call(fns.setChildSocialControls, {
      profileId: CHILD,
      parentSessionId: sessionId,
      allowedSchoolIds: [],
      paused: true,
    }, parentAuth), 'permission-denied');
  });

  test('block atomically removes both directional edges and requests', async () => {
    await seedAdultPair();
    for (const [fromUid, fromProfileId, toUid, toProfileId] of [
      [parentAuth.uid, CHILD, strangerAuth.uid, OTHER],
      [strangerAuth.uid, OTHER, parentAuth.uid, CHILD],
    ]) {
      const fields = {
        from_owner_uid: fromUid,
        from_profile_id: fromProfileId,
        to_owner_uid: toUid,
        to_profile_id: toProfileId,
      };
      const id = pairDocId(fromUid, fromProfileId, toUid, toProfileId);
      await db.collection('social_follows').doc(id).set({ ...fields, state: 'active' });
      await db.collection('social_follow_requests').doc(id).set({ ...fields, state: 'pending' });
    }
    await call(fns.blockSocialProfile, {
      profileId: OTHER,
      toSocialProfileId: socialProfileId(parentAuth.uid, CHILD),
    }, strangerAuth);
    assert.equal((await db.collection('social_follows').get()).size, 0);
    assert.equal((await db.collection('social_follow_requests').get()).size, 0);
    await expectHttpsError(call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth), 'not-found');
  });

  test('a stale edge or request cannot be listed or accepted after either endpoint blocks', async () => {
    await seedAdultPair();
    await call(fns.blockSocialProfile, {
      profileId: OTHER,
      toSocialProfileId: socialProfileId(parentAuth.uid, CHILD),
    }, strangerAuth);

    const staleId = pairDocId(parentAuth.uid, CHILD, strangerAuth.uid, OTHER);
    const staleFields = {
      from_owner_uid: parentAuth.uid,
      from_profile_id: CHILD,
      to_owner_uid: strangerAuth.uid,
      to_profile_id: OTHER,
    };
    await db.collection('social_follows').doc(staleId).set({ ...staleFields, state: 'active' });
    await db.collection('social_follow_requests').doc(staleId).set({ ...staleFields, state: 'pending' });

    const senderConnections = await call(fns.listSocialConnections, { profileId: CHILD }, parentAuth);
    const recipientConnections = await call(fns.listSocialConnections, { profileId: OTHER }, strangerAuth);
    assert.equal(senderConnections.following.length, 0);
    assert.equal(senderConnections.outgoingRequests.length, 0);
    assert.equal(recipientConnections.followers.length, 0);
    assert.equal(recipientConnections.incomingRequests.length, 0);
    await expectHttpsError(call(fns.reviewFollowRequest, {
      requestId: staleId,
      profileId: OTHER,
      decision: 'accept',
    }, strangerAuth), 'not-found');
    assert.equal((await db.collection('social_follows').doc(staleId).get()).exists, true);
  });

  test('either endpoint can remove the accepted follow without creating a block', async () => {
    await seedAdultPair();
    const sent = await call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth);
    await call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: OTHER,
      decision: 'accept',
    }, strangerAuth);
    await call(fns.removeFollow, {
      profileId: OTHER,
      toSocialProfileId: socialProfileId(parentAuth.uid, CHILD),
    }, strangerAuth);
    assert.equal((await db.collection('social_follows').get()).size, 0);
    assert.equal((await db.collection('social_blocks').get()).size, 0);
  });

  test('exact school search returns adult cards only and requires membership', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'adult');
    await seedSocialProfile(strangerAuth.uid, OTHER, 'adult');
    await seedSocialProfile('third-uid', 'third-child', 'child');
    await member(parentAuth.uid, CHILD);
    await member(strangerAuth.uid, OTHER);
    await member('third-uid', 'third-child');
    const result = await call(fns.searchSchoolMembers, {
      profileId: CHILD,
      schoolId: SCHOOL,
      exactName: `${strangerAuth.uid} learner`,
    }, parentAuth);
    assert.equal(result.profiles.length, 1);
    assert.equal(result.profiles[0].socialProfileId, socialProfileId(strangerAuth.uid, OTHER));
    assert.equal('ownerUid' in result.profiles[0], false);
    await expectHttpsError(call(fns.searchSchoolMembers, {
      profileId: CHILD,
      schoolId: 'unknown-school',
      exactName: `${strangerAuth.uid} learner`,
    }, parentAuth), 'permission-denied');
  });

  test('school search cursors are opaque, scoped to the query, and paginated', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'adult');
    await seedSocialProfile(strangerAuth.uid, OTHER, 'adult');
    await member(parentAuth.uid, CHILD);
    await member(strangerAuth.uid, OTHER);
    const first = await call(fns.searchSchoolMembers, {
      profileId: CHILD,
      schoolId: SCHOOL,
      exactName: `${strangerAuth.uid} learner`,
      limit: 1,
    }, parentAuth);
    assert.match(first.nextPageToken, /^[A-Za-z0-9_-]{43}$/);
    const second = await call(fns.searchSchoolMembers, {
      profileId: CHILD,
      schoolId: SCHOOL,
      exactName: `${strangerAuth.uid} learner`,
      limit: 1,
      pageToken: first.nextPageToken,
    }, parentAuth);
    assert.equal(second.nextPageToken, null);
    await expectHttpsError(call(fns.searchSchoolMembers, {
      profileId: CHILD,
      schoolId: 'different-school',
      exactName: `${strangerAuth.uid} learner`,
      pageToken: first.nextPageToken,
    }, parentAuth), 'not-found');
  });

  test('follow request quota limits a profile to twenty requests per UTC day', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'adult');
    for (let index = 0; index < 21; index++) {
      await seedSocialProfile(`recipient-${index}`, `profile-${index}`, 'adult');
    }
    for (let index = 0; index < 20; index++) {
      await call(fns.sendFollowRequest, {
        fromProfileId: CHILD,
        toSocialProfileId: socialProfileId(`recipient-${index}`, `profile-${index}`),
      }, parentAuth);
    }
    await expectHttpsError(call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId('recipient-20', 'profile-20'),
    }, parentAuth), 'resource-exhausted');
  });

  test('inbound request quota protects a profile from multi-account spam', async () => {
    await seedAdultPair();
    await db.collection('social_rate_limits').doc(socialProfileDocId(strangerAuth.uid, OTHER)).set({
      day: new Date().toISOString().slice(0, 10),
      inbound_request_count: 50,
    });
    await expectHttpsError(call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth), 'resource-exhausted');
    assert.equal((await db.collection('social_follow_requests').get()).size, 0);
  });

  test('request input rejects unknown fields and unauthenticated calls', async () => {
    await seedAdultPair();
    await expectHttpsError(call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
      targetEmail: 'private@example.test',
    }, parentAuth), 'invalid-argument');
    await expectHttpsError(call(fns.sendFollowRequest, {}, null), 'unauthenticated');
  });

  test('learner profile deletion removes its graph, requests, and private card', async () => {
    await seedAdultPair();
    const sent = await call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth);
    await call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: OTHER,
      decision: 'accept',
    }, strangerAuth);

    await call(fns.deleteLearnerProfile, { profileId: CHILD }, parentAuth);

    assert.equal((await db.collection('social_follows').get()).size, 0);
    assert.equal((await db.collection('social_follow_requests').get()).size, 0);
    assert.equal((await db.collection('social_profiles').where('owner_uid', '==', parentAuth.uid).get()).size, 0);
  });

  test('account data deletion removes all of its social edges and profile cards', async () => {
    await seedAdultPair();
    const sent = await call(fns.sendFollowRequest, {
      fromProfileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth);
    await call(fns.reviewFollowRequest, {
      requestId: sent.requestId,
      profileId: OTHER,
      decision: 'accept',
    }, strangerAuth);

    await call(fns.deleteAccountData, {}, parentAuth);

    assert.equal((await db.collection('social_follows').get()).size, 0);
    assert.equal((await db.collection('social_follow_requests').get()).size, 0);
    assert.equal((await db.collection('social_profiles').where('owner_uid', '==', parentAuth.uid).get()).size, 0);
  });
});
