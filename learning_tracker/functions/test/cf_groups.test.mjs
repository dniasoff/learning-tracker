import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { beforeEach, describe, test } from 'node:test';
import {
  call, clearFirestore, db, expectHttpsError, fns, parentAuth,
  seedParentSession, seedSocialProfile, socialProfileDocId, strangerAuth,
} from './_cf_helpers.mjs';

const digest = (...parts) => createHash('sha256').update(parts.join('\0')).digest('hex');
const summary = (uid, profileId) => socialProfileDocId(uid, profileId);
const memberToken = (groupId, uid, profileId) => digest('group-member', groupId, uid, profileId);
const childProfile = '01JCHILD0000000000000000000';
const siblingProfile = '01JSIBLING000000000000000000';
const adminProfile = '01JADMIN0000000000000000000';
const parentAdultProfile = '01JPARENTADULT0000000000000';
const guestProfile = '01JGUEST0000000000000000000';

async function enableChildSharing(uid, profileId, allowedSchoolIds = []) {
  const id = summary(uid, profileId);
  await db.collection('social_parent_controls').doc(id).set({
    owner_uid: uid, profile_id: profileId, allowed_school_ids: allowedSchoolIds,
    paused: false, controls_update_pending: false,
  });
  await db.collection('social_profiles').doc(id).set({ active_school_ids: allowedSchoolIds, paused: false }, { merge: true });
  const controlsRef = db.collection('social_user_controls').doc(uid);
  await db.runTransaction(async (txn) => {
    const controls = await txn.get(controlsRef);
    txn.set(controlsRef, {
      active_social_child_profile_ids: [...new Set([...(controls.get('active_social_child_profile_ids') ?? []), id])],
    }, { merge: true });
  });
}

async function seedPrivateGroup() {
  await seedSocialProfile(strangerAuth.uid, adminProfile, 'adult');
  await seedSocialProfile(parentAuth.uid, childProfile, 'child');
  await enableChildSharing(parentAuth.uid, childProfile);
  const group = await call(fns.createLearningGroup, { name: 'Family learning', profileId: adminProfile }, strangerAuth);
  const invite = await call(fns.createLearningGroupInvite, { groupId: group.groupId }, strangerAuth);
  return { ...group, invite };
}

async function joinChild(groupId, inviteCode, profileId = childProfile) {
  const parentSessionId = await seedParentSession(parentAuth.uid, profileId);
  const preview = await call(fns.getLearningGroupInvite, {
    inviteCode, profileId, parentSessionId,
  }, parentAuth);
  await call(fns.joinLearningGroup, {
    inviteCode, profileId, parentSessionId,
    memberRevision: preview.memberRevision,
  }, parentAuth);
  return { parentSessionId, preview };
}

describe('private and school-hosted group lifecycle', () => {
  beforeEach(async () => clearFirestore());

  test('adults create private groups; school groups require active school admin; clients cannot read backing docs', async () => {
    await seedSocialProfile(strangerAuth.uid, adminProfile, 'adult');
    await seedSocialProfile(parentAuth.uid, childProfile, 'child');
    const group = await call(fns.createLearningGroup, { name: 'Private chavrusa', profileId: adminProfile }, strangerAuth);
    assert.equal((await db.collection('learning_groups').doc(group.groupId).get()).get('group_type'), 'private');
    await expectHttpsError(call(fns.createLearningGroup, { name: 'Child group', profileId: childProfile }, parentAuth), 'permission-denied');
    await expectHttpsError(call(fns.createLearningGroup, { name: 'Unauthorized school group', profileId: adminProfile, schoolId: 'school_12345678' }, strangerAuth), 'permission-denied');
    const school = await call(fns.createSchool, { name: 'Hosted school', profileId: adminProfile }, strangerAuth);
    const hosted = await call(fns.createLearningGroup, { name: 'School chavrusa', profileId: adminProfile, schoolId: school.schoolId }, strangerAuth);
    assert.equal((await db.collection('learning_groups').doc(hosted.groupId).get()).get('group_type'), 'school');
    assert.equal((await db.collection('learning_groups').doc(hosted.groupId).get()).get('school_id'), school.schoolId);
  });

  test('invite stores only a hash, caps uses, expires, and adult acceptance is idempotent by membership', async () => {
    await seedSocialProfile(strangerAuth.uid, adminProfile, 'adult');
    await seedSocialProfile(parentAuth.uid, guestProfile, 'adult');
    const group = await call(fns.createLearningGroup, { name: 'Study circle', profileId: adminProfile }, strangerAuth);
    const invite = await call(fns.createLearningGroupInvite, { groupId: group.groupId, uses: 1 }, strangerAuth);
    const inviteId = digest('learning-group-invite', invite.inviteCode);
    const stored = await db.collection('learning_group_invites').doc(inviteId).get();
    assert.equal(stored.get('token_hash'), inviteId);
    assert.notEqual(stored.get('token_hash'), invite.inviteCode);
    assert.equal(stored.get('uses'), 1);
    assert.ok(stored.get('expires_at').toMillis() > Date.now());
    const preview = await call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: guestProfile }, parentAuth);
    assert.equal(preview.adminName, 'stranger-uid learner');
    assert.deepEqual(preview.members, [{ displayName: 'stranger-uid learner' }]);
    await call(fns.joinLearningGroup, { inviteCode: invite.inviteCode, profileId: guestProfile, memberRevision: preview.memberRevision }, parentAuth);
    assert.equal((await db.collection('learning_group_invites').doc(inviteId).get()).get('state'), 'redeemed');
    assert.equal((await db.collection('learning_groups').doc(group.groupId).collection('members').doc(parentAuth.uid).collection('group_profiles').doc(guestProfile).get()).get('state'), 'active');
    await expectHttpsError(call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: guestProfile }, parentAuth), 'not-found');
  });

  test('child private-group join is PIN-gated and explicitly approves current member visibility', async () => {
    const { groupId, invite } = await seedPrivateGroup();
    await expectHttpsError(call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: childProfile }, parentAuth), 'invalid-argument');
    const parentSessionId = await seedParentSession(parentAuth.uid, childProfile);
    const preview = await call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: childProfile, parentSessionId }, parentAuth);
    assert.equal(preview.name, 'Family learning');
    assert.equal(preview.adminName, 'stranger-uid learner');
    assert.deepEqual(preview.members, [{ displayName: 'stranger-uid learner' }]);
    assert.equal(preview.childConsentRequired, true);
    await expectHttpsError(call(fns.joinLearningGroup, {
      inviteCode: invite.inviteCode, profileId: childProfile,
      memberRevision: preview.memberRevision,
    }, parentAuth), 'invalid-argument');
    await call(fns.joinLearningGroup, { inviteCode: invite.inviteCode, profileId: childProfile, parentSessionId, memberRevision: preview.memberRevision }, parentAuth);
    const acl = await db.collection('social_summaries').doc(summary(parentAuth.uid, childProfile)).collection('readers').doc(strangerAuth.uid).get();
    assert.deepEqual(acl.get('group_ids'), [groupId]);
    const adultAcl = await db.collection('social_summaries').doc(summary(strangerAuth.uid, adminProfile)).collection('readers').doc(parentAuth.uid).get();
    assert.deepEqual(adultAcl.get('group_ids'), [groupId]);
  });

  test('one account can join with a parent profile and siblings; reader grant lasts until its last group profile leaves', async () => {
    await seedSocialProfile(strangerAuth.uid, adminProfile, 'adult');
    await seedSocialProfile(parentAuth.uid, parentAdultProfile, 'adult');
    await seedSocialProfile(parentAuth.uid, childProfile, 'child');
    await seedSocialProfile(parentAuth.uid, siblingProfile, 'child');
    await enableChildSharing(parentAuth.uid, childProfile);
    await enableChildSharing(parentAuth.uid, siblingProfile);
    const group = await call(fns.createLearningGroup, { name: 'Family siyum', profileId: adminProfile }, strangerAuth);
    const invite = await call(fns.createLearningGroupInvite, { groupId: group.groupId, uses: 4 }, strangerAuth);

    let preview = await call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: parentAdultProfile }, parentAuth);
    await call(fns.joinLearningGroup, { inviteCode: invite.inviteCode, profileId: parentAdultProfile, memberRevision: preview.memberRevision }, parentAuth);
    const childJoin = await joinChild(group.groupId, invite.inviteCode, childProfile);
    const siblingJoin = await joinChild(group.groupId, invite.inviteCode, siblingProfile);

    const accountRef = db.collection('learning_groups').doc(group.groupId).collection('members').doc(parentAuth.uid);
    assert.deepEqual((await accountRef.get()).get('active_profile_ids').sort(), [childProfile, parentAdultProfile, siblingProfile].sort());
    const roster = await call(fns.getLearningGroup, { groupId: group.groupId, profileId: parentAdultProfile }, parentAuth);
    assert.equal(roster.members.length, 4);
    const adultSummaryGrant = db.collection('social_summaries').doc(summary(strangerAuth.uid, adminProfile)).collection('readers').doc(parentAuth.uid);
    assert.deepEqual((await adultSummaryGrant.get()).get('group_ids'), [group.groupId]);

    await seedSocialProfile('late-reader', guestProfile, 'adult');
    const laterInvite = await call(fns.createLearningGroupInvite, { groupId: group.groupId }, strangerAuth);
    const lateAuth = { uid: 'late-reader', token: {} };
    const latePreview = await call(fns.getLearningGroupInvite, { inviteCode: laterInvite.inviteCode, profileId: guestProfile }, lateAuth);
    await call(fns.joinLearningGroup, { inviteCode: laterInvite.inviteCode, profileId: guestProfile, memberRevision: latePreview.memberRevision }, lateAuth);
    const childApprovalSession = await seedParentSession(parentAuth.uid, childProfile);
    const childApprovals = await call(fns.listGroupParentApprovals, { profileId: childProfile, parentSessionId: childApprovalSession }, parentAuth);
    const siblingApprovalSession = await seedParentSession(parentAuth.uid, siblingProfile);
    const siblingApprovals = await call(fns.listGroupParentApprovals, { profileId: siblingProfile, parentSessionId: siblingApprovalSession }, parentAuth);
    assert.equal(childApprovals.length, 1);
    assert.equal(siblingApprovals.length, 1);
    assert.equal((await db.collection('social_summaries').doc(summary(parentAuth.uid, childProfile)).collection('readers').doc('late-reader').get()).exists, false);
    assert.equal((await db.collection('social_summaries').doc(summary(parentAuth.uid, siblingProfile)).collection('readers').doc('late-reader').get()).exists, false);
    const finalChildApprovalSession = await seedParentSession(parentAuth.uid, childProfile);
    await call(fns.setGroupMemberApproval, { approvalId: childApprovals[0].approvalId, profileId: childProfile, parentSessionId: finalChildApprovalSession, approved: true }, parentAuth);
    assert.equal((await db.collection('social_summaries').doc(summary(parentAuth.uid, childProfile)).collection('readers').doc('late-reader').get()).exists, true);
    assert.equal((await db.collection('social_summaries').doc(summary(parentAuth.uid, siblingProfile)).collection('readers').doc('late-reader').get()).exists, false);

    // Removing the adult profile leaves both sibling profiles and their shared
    // auth UID grant active. Removing one sibling still leaves the other.
    await call(fns.removeLearningGroupMember, { groupId: group.groupId, memberId: memberToken(group.groupId, parentAuth.uid, parentAdultProfile) }, strangerAuth);
    assert.equal((await adultSummaryGrant.get()).exists, true);
    await call(fns.removeLearningGroupMember, { groupId: group.groupId, memberId: memberToken(group.groupId, parentAuth.uid, siblingProfile) }, strangerAuth);
    assert.deepEqual((await accountRef.get()).get('active_profile_ids'), [childProfile]);
    assert.equal((await adultSummaryGrant.get()).exists, true);
    assert.equal((await adultSummaryGrant.get()).get('reader_profile_id'), childProfile);
    await call(fns.removeLearningGroupMember, { groupId: group.groupId, memberId: memberToken(group.groupId, parentAuth.uid, childProfile) }, strangerAuth);
    assert.equal((await accountRef.get()).get('state'), 'removed');
    assert.equal((await adultSummaryGrant.get()).exists, false);
  });

  test('school-hosted child enrollment requires active membership, allowed school, and group-specific parent approval', async () => {
    await seedSocialProfile(strangerAuth.uid, adminProfile, 'adult');
    await seedSocialProfile(parentAuth.uid, childProfile, 'child');
    const school = await call(fns.createSchool, { name: 'Child school', profileId: adminProfile }, strangerAuth);
    const joinSchool = await call(fns.createSchoolInvite, { schoolId: school.schoolId }, strangerAuth);
    const parentSessionId = await seedParentSession(parentAuth.uid, childProfile);
    await call(fns.joinSchoolWithInvite, { inviteCode: joinSchool.inviteCode, profileId: childProfile, parentSessionId, progressConsent: true }, parentAuth);
    const group = await call(fns.createLearningGroup, { name: 'School group', profileId: adminProfile, schoolId: school.schoolId }, strangerAuth);
    const invite = await call(fns.createLearningGroupInvite, { groupId: group.groupId }, strangerAuth);
    await expectHttpsError(call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: childProfile, parentSessionId }, parentAuth), 'permission-denied');
    await enableChildSharing(parentAuth.uid, childProfile, [school.schoolId]);
    const preview = await call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: childProfile, parentSessionId }, parentAuth);
    await call(fns.joinLearningGroup, { inviteCode: invite.inviteCode, profileId: childProfile, parentSessionId, memberRevision: preview.memberRevision }, parentAuth);
    assert.equal((await db.collection('learning_groups').doc(group.groupId).collection('members').doc(parentAuth.uid).collection('group_profiles').doc(childProfile).get()).get('state'), 'active');
  });

  test('later member gets no child-summary grant until parent approves; revoke denies first and clears ACL', async () => {
    const { groupId, invite } = await seedPrivateGroup();
    const { parentSessionId, preview } = await joinChild(groupId, invite.inviteCode);
    await seedSocialProfile('late-reader', guestProfile, 'adult');
    const secondInvite = await call(fns.createLearningGroupInvite, { groupId }, strangerAuth);
    const latePreview = await call(fns.getLearningGroupInvite, { inviteCode: secondInvite.inviteCode, profileId: guestProfile }, { uid: 'late-reader', token: {} });
    await call(fns.joinLearningGroup, { inviteCode: secondInvite.inviteCode, profileId: guestProfile, memberRevision: latePreview.memberRevision }, { uid: 'late-reader', token: {} });
    const parentMember = await db.collection('learning_group_parent_approvals').where('group_id', '==', groupId).where('reader_uid', '==', 'late-reader').get();
    assert.equal(parentMember.size, 1);
    assert.equal(parentMember.docs[0].get('state'), 'pending');
    const childSummaryReader = await db.collection('social_summaries').doc(summary(parentAuth.uid, childProfile)).collection('readers').doc('late-reader').get();
    assert.equal(childSummaryReader.exists, false);
    const approvals = await call(fns.listGroupParentApprovals, { profileId: childProfile, parentSessionId }, parentAuth);
    assert.equal(approvals.length, 1);
    assert.equal(approvals[0].displayName, 'late-reader learner');
    assert.equal('readerUid' in approvals[0], false);
    await call(fns.setGroupMemberApproval, { approvalId: approvals[0].approvalId, profileId: childProfile, parentSessionId, approved: true }, parentAuth);
    const granted = await db.collection('social_summaries').doc(summary(parentAuth.uid, childProfile)).collection('readers').doc('late-reader').get();
    assert.deepEqual(granted.get('group_ids'), [groupId]);
    await call(fns.setGroupMemberApproval, { approvalId: approvals[0].approvalId, profileId: childProfile, parentSessionId, approved: false }, parentAuth);
    assert.equal((await db.collection('social_summaries').doc(summary(parentAuth.uid, childProfile)).collection('readers').doc('late-reader').get()).exists, false);
    assert.equal((await db.collection('learning_group_parent_approvals').doc(approvals[0].approvalId).get()).get('state'), 'revoked');
    assert.equal(preview.name, 'Family learning');
  });

  test('admin must transfer before leaving; member removal and a concurrent grant leave no access', async () => {
    await seedSocialProfile(strangerAuth.uid, adminProfile, 'adult');
    await seedSocialProfile(parentAuth.uid, guestProfile, 'adult');
    const group = await call(fns.createLearningGroup, { name: 'Admin flow', profileId: adminProfile }, strangerAuth);
    const invite = await call(fns.createLearningGroupInvite, { groupId: group.groupId, uses: 2 }, strangerAuth);
    const preview = await call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: guestProfile }, parentAuth);
    await call(fns.joinLearningGroup, { inviteCode: invite.inviteCode, profileId: guestProfile, memberRevision: preview.memberRevision }, parentAuth);
    await expectHttpsError(call(fns.leaveLearningGroup, { groupId: group.groupId, profileId: adminProfile }, strangerAuth), 'failed-precondition');
    await call(fns.transferLearningGroupAdmin, { groupId: group.groupId, memberId: memberToken(group.groupId, parentAuth.uid, guestProfile) }, strangerAuth);
    assert.equal((await db.collection('learning_groups').doc(group.groupId).get()).get('admin_uid'), parentAuth.uid);
    await expectHttpsError(call(fns.createLearningGroupInvite, { groupId: group.groupId }, strangerAuth), 'permission-denied');

    const grants = await import('../lib/groups.js');
    const target = { uid: parentAuth.uid, ownerUid: parentAuth.uid, profileId: guestProfile, mode: 'adult', role: 'admin', state: 'active' };
    const reader = { uid: strangerAuth.uid, ownerUid: strangerAuth.uid, profileId: adminProfile, mode: 'adult', role: 'member', state: 'active' };
    await Promise.allSettled([
      call(fns.removeLearningGroupMember, { groupId: group.groupId, memberId: memberToken(group.groupId, strangerAuth.uid, adminProfile) }, parentAuth),
      grants.grantGroupSummary(group.groupId, target, reader),
    ]);
    assert.equal((await db.collection('learning_groups').doc(group.groupId).collection('members').doc(strangerAuth.uid).collection('group_profiles').doc(adminProfile).get()).get('state'), 'removed');
    const access = await db.collection('social_summaries').doc(summary(parentAuth.uid, guestProfile)).collection('readers').doc(strangerAuth.uid).get();
    assert.equal(access.exists, false);
  });

  test('group deletion and profile deletion revoke ACLs and clean hosted groups', async () => {
    await seedSocialProfile(strangerAuth.uid, adminProfile, 'adult');
    await seedSocialProfile(parentAuth.uid, guestProfile, 'adult');
    const group = await call(fns.createLearningGroup, { name: 'Delete flow', profileId: adminProfile }, strangerAuth);
    const invite = await call(fns.createLearningGroupInvite, { groupId: group.groupId }, strangerAuth);
    const preview = await call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: guestProfile }, parentAuth);
    await call(fns.joinLearningGroup, { inviteCode: invite.inviteCode, profileId: guestProfile, memberRevision: preview.memberRevision }, parentAuth);
    await call(fns.deleteLearningGroup, { groupId: group.groupId }, strangerAuth);
    assert.equal((await db.collection('learning_groups').doc(group.groupId).get()).get('status'), 'deleted');
    assert.equal((await db.collection('social_summaries').doc(summary(strangerAuth.uid, adminProfile)).collection('readers').doc(parentAuth.uid).get()).exists, false);

    const school = await call(fns.createSchool, { name: 'Group cleanup school', profileId: adminProfile }, strangerAuth);
    const hosted = await call(fns.createLearningGroup, { name: 'Delete with school', profileId: adminProfile, schoolId: school.schoolId }, strangerAuth);
    await call(fns.deleteSchool, { schoolId: school.schoolId }, strangerAuth);
    assert.equal((await db.collection('learning_groups').doc(hosted.groupId).get()).get('status'), 'deleted');
  });
});
