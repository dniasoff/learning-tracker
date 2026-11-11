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
  PROFILE,
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

  const summaryPayload = () => ({
    streak: {
      by_curriculum: [{ curriculum_id: 'mishnayos', current_days: 2, best_days: 5 }],
    },
    current_tracks: [{ curriculum_id: 'mishnayos', position_ref: 'Berakhot 1' }],
    weekly_learning: {
      week_start: '2026-11-08',
      by_curriculum: [{ curriculum_id: 'mishnayos', limudim: 3, chazaros: 1 }],
    },
    siyumim: [{ curriculum_id: 'mishnayos', ref: 'Berakhot', level: 'masechta' }],
  });

  test('publishes a strict sanitized snapshot using the profileDocId path', async () => {
    await seedSocialProfile(parentAuth.uid, PROFILE, 'adult');
    const result = await call(fns.publishSocialSummary, {
      profileId: PROFILE,
      summary: summaryPayload(),
    }, parentAuth);
    const id = socialProfileDocId(parentAuth.uid, PROFILE);
    assert.equal(result.summaryId, id);
    const snapshot = await db.collection('social_summaries').doc(id).get();
    assert.deepEqual(snapshot.get('streak.by_curriculum'), summaryPayload().streak.by_curriculum);
    assert.equal(snapshot.get('weekly_learning.week_start'), '2026-11-08');
    assert.equal(snapshot.get('display_name'), `${parentAuth.uid} learner`);
    assert.equal(snapshot.get('avatar_id'), 0);
    assert.equal('owner_uid' in snapshot.data(), false);
    assert.equal('profile_id' in snapshot.data(), false);
    assert.equal('points' in snapshot.data(), false);
    assert.ok(snapshot.get('computed_at'));
  });

  test('rejects client text, points, unknown curricula and malformed references', async () => {
    await seedSocialProfile(parentAuth.uid, PROFILE, 'adult');
    for (const mutate of [
      (summary) => ({ ...summary, points: 12 }),
      (summary) => ({
        ...summary,
        current_tracks: [{ curriculum_id: 'mishnayos', position_ref: '../private' }],
      }),
      (summary) => ({
        ...summary,
        current_tracks: [{ curriculum_id: 'unknown', position_ref: null }],
      }),
      (summary) => ({
        ...summary,
        current_tracks: [{ curriculum_id: 'mishnayos', position_ref: 'Berakhot 1', display_name: 'Injected' }],
      }),
    ]) {
      await expectHttpsError(call(fns.publishSocialSummary, {
        profileId: PROFILE,
        summary: mutate(summaryPayload()),
      }, parentAuth), 'invalid-argument');
    }
  });

  test('rejects a foreign profile and requires a live parent session for child publication', async () => {
    await seedSocialProfile(parentAuth.uid, PROFILE, 'adult');
    await expectHttpsError(call(fns.publishSocialSummary, {
      profileId: PROFILE,
      summary: summaryPayload(),
    }, strangerAuth), 'not-found');

    await seedSocialProfile(parentAuth.uid, PROFILE, 'child');
    await expectHttpsError(call(fns.publishSocialSummary, {
      profileId: PROFILE,
      summary: summaryPayload(),
    }, parentAuth), 'invalid-argument');
    const parentSessionId = await seedParentSession(parentAuth.uid, PROFILE);
    await call(fns.publishSocialSummary, {
      profileId: PROFILE,
      parentSessionId,
      summary: summaryPayload(),
    }, parentAuth);
    assert.equal(
      (await db.collection('social_summaries').doc(socialProfileDocId(parentAuth.uid, PROFILE)).get()).exists,
      true,
    );
  });

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
    const reader = await db.collection('social_summaries')
      .doc(socialProfileDocId(strangerAuth.uid, OTHER))
      .collection('readers').doc(parentAuth.uid).get();
    assert.deepEqual(reader.get('follower_profile_ids'), [socialProfileDocId(parentAuth.uid, CHILD)]);
    assert.deepEqual(reader.get('school_ids'), []);

    await call(fns.removeFollow, {
      profileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth);
    assert.equal((await reader.ref.get()).exists, false);
  });

  test('blocking removes follower summary access immediately while preserving school grants', async () => {
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
    const readerRef = db.collection('social_summaries')
      .doc(socialProfileDocId(strangerAuth.uid, OTHER))
      .collection('readers').doc(parentAuth.uid);
    await readerRef.set({ school_ids: ['school-1'] }, { merge: true });
    await call(fns.blockSocialProfile, {
      profileId: CHILD,
      toSocialProfileId: socialProfileId(strangerAuth.uid, OTHER),
    }, parentAuth);
    const reader = await readerRef.get();
    assert.deepEqual(reader.get('follower_profile_ids'), []);
    assert.deepEqual(reader.get('school_ids'), ['school-1']);
    assert.equal((await db.collection('social_follows').get()).size, 0);
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

  test('child control revocation paginates beyond fifty incoming followers', async () => {
    await seedSocialProfile(parentAuth.uid, CHILD, 'child');
    await member(parentAuth.uid, CHILD);
    const sessionId = await seedParentSession(parentAuth.uid, CHILD);
    await db.collection('social_parent_controls').doc(socialProfileDocId(parentAuth.uid, CHILD)).set({
      owner_uid: parentAuth.uid,
      profile_id: CHILD,
      allowed_school_ids: [SCHOOL],
      paused: false,
    });
    const summaryId = socialProfileDocId(parentAuth.uid, CHILD);
    const summaryReaders = db.collection('social_summaries').doc(summaryId).collection('readers');
    for (let i = 0; i < 55; i++) {
      const ownerUid = `follower-${i}`;
      const profileId = `follower-profile-${i}`;
      const followerId = socialProfileDocId(ownerUid, profileId);
      await member(ownerUid, profileId);
      await db.collection('social_follows').doc(pairDocId(ownerUid, profileId, parentAuth.uid, CHILD)).set({
        from_owner_uid: ownerUid,
        from_profile_id: profileId,
        to_owner_uid: parentAuth.uid,
        to_profile_id: CHILD,
        state: 'active',
      });
      await summaryReaders.doc(ownerUid).set({
        owner_uid: parentAuth.uid,
        profile_id: CHILD,
        follower_profile_ids: [followerId],
        school_ids: [],
        child_school_ids: [SCHOOL],
        active_school_ids: [SCHOOL],
        child_school_grants: { [followerId]: [SCHOOL] },
        follower_school_memberships: { [followerId]: [SCHOOL] },
      });
    }

    await call(fns.setChildSocialControls, {
      profileId: CHILD,
      parentSessionId: sessionId,
      allowedSchoolIds: [SCHOOL],
      paused: true,
    }, parentAuth);

    assert.equal((await summaryReaders.get()).size, 0);
    assert.equal((await db.collection('social_profiles').doc(summaryId).get()).get('paused'), true);
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

  test('profile deletion fails if the social summary recursive delete fails', async () => {
    await seedAdultPair();
    const summaryId = socialProfileDocId(parentAuth.uid, CHILD);
    const summaryRef = db.collection('social_summaries').doc(summaryId);
    await summaryRef.set({ computed_at: new Date() });
    await summaryRef.collection('readers').doc(strangerAuth.uid).set({
      follower_profile_ids: [summaryId],
      school_ids: [],
    });
    const learnerRef = db.collection('users').doc(parentAuth.uid)
      .collection('learner_profiles').doc(CHILD);
    await learnerRef.set({ mode: 'adult' }, { merge: true });

    const firestorePrototype = Object.getPrototypeOf(db);
    const originalRecursiveDelete = firestorePrototype.recursiveDelete;
    firestorePrototype.recursiveDelete = async function (ref, ...args) {
      if (ref.path === summaryRef.path) throw new Error('injected summary recursiveDelete failure');
      return originalRecursiveDelete.call(this, ref, ...args);
    };
    try {
      await assert.rejects(call(fns.deleteLearnerProfile, { profileId: CHILD }, parentAuth),
        /injected summary recursiveDelete failure/);
    } finally {
      firestorePrototype.recursiveDelete = originalRecursiveDelete;
    }
    assert.equal((await summaryRef.get()).exists, true);
    assert.equal((await summaryRef.collection('readers').doc(strangerAuth.uid).get()).exists, true);
    assert.equal((await learnerRef.get()).exists, true);
  });
});
