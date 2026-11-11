import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { beforeEach, describe, test } from 'node:test';
import {
  call, clearFirestore, db, expectHttpsError, fns, parentAuth,
  seedParentSession, seedSocialProfile, strangerAuth,
} from './_cf_helpers.mjs';

const digest = (...parts) => createHash('sha256').update(parts.join('\0')).digest('hex');
const summaryId = (uid, profileId) => digest(uid, profileId);
const memberId = (schoolId, uid, profileId) => digest('school-member', schoolId, uid, profileId);
const staffId = (schoolId, uid) => digest('school-staff', schoolId, uid);
const { grantSocialStaffSchoolAccess, refreshSocialMembershipMirror } = await import('../lib/social_graph.js');

async function seedLastAdminSchool() {
  await db.collection('users').doc(parentAuth.uid).set({ email: 'admin@example.com' });
  await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
  await seedSocialProfile(strangerAuth.uid, 'member-profile', 'adult');
  const created = await call(fns.createSchool, {
    name: 'Account Deletion School', profileId: 'owner-profile',
  }, parentAuth);
  const ownerInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
  await call(fns.joinSchoolWithInvite, {
    inviteCode: ownerInvite.inviteCode, profileId: 'owner-profile', progressConsent: true,
  }, parentAuth);
  const memberInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
  await call(fns.joinSchoolWithInvite, {
    inviteCode: memberInvite.inviteCode, profileId: 'member-profile', progressConsent: true,
  }, strangerAuth);
  const unusedInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
  return { schoolId: created.schoolId, inviteCode: unusedInvite.inviteCode };
}

describe('school profile and membership callables', () => {
  beforeEach(async () => clearFirestore());

  test('any account creates an unverified profile; only app_owner can verify or suspend', async () => {
    const created = await call(fns.createSchool, { name: 'Community Beit Midrash' }, parentAuth);
    const school = await db.collection('schools').doc(created.schoolId).get();
    assert.equal(school.get('verified'), false);
    assert.equal(school.get('status'), 'active');
    assert.equal((await db.collection('school_admins').doc(staffId(created.schoolId, parentAuth.uid)).get()).get('role'), 'admin');
    const profile = await call(fns.getSchoolProfile, { schoolId: created.schoolId }, strangerAuth);
    assert.equal(profile.verified, false);
    await expectHttpsError(call(fns.setSchoolVerified, { schoolId: created.schoolId, verified: true }, parentAuth), 'permission-denied');
    await expectHttpsError(call(fns.setSchoolSuspended, { schoolId: created.schoolId, suspended: true }, { uid: parentAuth.uid, token: { admin: true } }), 'permission-denied');
    await call(fns.setSchoolVerified, { schoolId: created.schoolId, verified: true }, { uid: parentAuth.uid, token: { app_owner: true } });
    assert.equal((await db.collection('schools').doc(created.schoolId).get()).get('verified'), true);
    await call(fns.setSchoolSuspended, { schoolId: created.schoolId, suspended: true }, { uid: parentAuth.uid, token: { app_owner: true } });
    assert.equal((await db.collection('schools').doc(created.schoolId).get()).get('status'), 'suspended');
  });

  test('adult invite requires progress disclosure consent and grants staff only the shared summary ACL', async () => {
    await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'member-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Open School', profileId: 'owner-profile' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await expectHttpsError(call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'member-profile' }, strangerAuth), 'failed-precondition');
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'member-profile', progressConsent: true }, strangerAuth);
    const membership = await db.collection('school_memberships').doc(memberId(created.schoolId, strangerAuth.uid, 'member-profile')).get();
    assert.equal(membership.get('state'), 'active');
    assert.equal(membership.get('progress_consent'), true);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(strangerAuth.uid, 'member-profile')).get()).get('active_school_ids'), [created.schoolId]);
    const admins = await db.collection('school_admins').where('school_id', '==', created.schoolId).get();
    assert.equal(admins.size, 1);
    const summary = db.collection('social_summaries').doc(summaryId(strangerAuth.uid, 'member-profile'));
    const reader = await summary.collection('readers').doc(parentAuth.uid).get();
    assert.deepEqual(reader.get('school_ids'), [created.schoolId]);
    assert.deepEqual(reader.get('follower_profile_ids'), undefined);
    assert.equal((await db.collection('users').doc(strangerAuth.uid).collection('learner_profiles').doc('member-profile').get()).exists, true);
  });

  test('child invite requires live parent session and explicit staff-progress consent', async () => {
    await seedSocialProfile(parentAuth.uid, 'child-profile', 'child');
    const created = await call(fns.createSchool, { name: 'Family School' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    const sessionId = await seedParentSession(parentAuth.uid, 'child-profile');
    await expectHttpsError(call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'child-profile', parentSessionId: sessionId }, parentAuth), 'failed-precondition');
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'child-profile', parentSessionId: sessionId, progressConsent: true }, parentAuth);
    const membership = await db.collection('school_memberships').doc(memberId(created.schoolId, parentAuth.uid, 'child-profile')).get();
    assert.equal(membership.get('mode'), 'child');
    assert.equal(membership.get('progress_consent'), true);
  });

  test('school staff read grant is revoked when member leaves', async () => {
    await seedSocialProfile(strangerAuth.uid, 'staff-member', 'adult');
    const created = await call(fns.createSchool, { name: 'Shared School' }, parentAuth);
    const firstInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: firstInvite.inviteCode, profileId: 'staff-member', progressConsent: true }, strangerAuth);
    const summary = db.collection('social_summaries').doc(summaryId(strangerAuth.uid, 'staff-member'));
    assert.deepEqual((await summary.collection('readers').doc(parentAuth.uid).get()).get('school_ids'), [created.schoolId]);
    await call(fns.leaveSchool, { schoolId: created.schoolId, profileId: 'staff-member' }, strangerAuth);
    assert.equal((await summary.collection('readers').doc(parentAuth.uid).get()).exists, false);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(strangerAuth.uid, 'staff-member')).get()).get('active_school_ids'), []);
  });

  test('staff summary reads stop on admin removal and school suspension, then restore on unsuspension', async () => {
    await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'member-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Staff Access School', profileId: 'owner-profile' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'owner-profile', progressConsent: true }, parentAuth);
    const memberInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: memberInvite.inviteCode, profileId: 'member-profile', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'member-profile' }, parentAuth);
    const otherSchool = await call(fns.createSchool, { name: 'Unrelated Staff School', profileId: 'owner-profile' }, parentAuth);
    const otherInvite = await call(fns.createSchoolInvite, { schoolId: otherSchool.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: otherInvite.inviteCode, profileId: 'member-profile', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: otherSchool.schoolId, targetUid: strangerAuth.uid, profileId: 'member-profile' }, parentAuth);
    const summary = db.collection('social_summaries').doc(summaryId(parentAuth.uid, 'owner-profile'));
    const staffControls = db.collection('social_user_controls').doc(strangerAuth.uid);
    assert.deepEqual((await summary.collection('readers').doc(strangerAuth.uid).get()).get('school_ids'), [created.schoolId]);
    assert.deepEqual(new Set((await staffControls.get()).get('active_staff_school_ids')), new Set([created.schoolId, otherSchool.schoolId]));

    await call(fns.setSchoolSuspended, { schoolId: created.schoolId, suspended: true }, { uid: parentAuth.uid, token: { app_owner: true } });
    assert.equal((await summary.collection('readers').doc(strangerAuth.uid).get()).exists, false);
    assert.deepEqual((await staffControls.get()).get('active_staff_school_ids'), [otherSchool.schoolId]);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(parentAuth.uid, 'owner-profile')).get()).get('active_school_ids'), []);
    await call(fns.setSchoolSuspended, { schoolId: created.schoolId, suspended: false }, { uid: parentAuth.uid, token: { app_owner: true } });
    assert.deepEqual((await summary.collection('readers').doc(strangerAuth.uid).get()).get('school_ids'), [created.schoolId]);
    assert.deepEqual(new Set((await staffControls.get()).get('active_staff_school_ids')), new Set([created.schoolId, otherSchool.schoolId]));
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(parentAuth.uid, 'owner-profile')).get()).get('active_school_ids'), [created.schoolId]);

    await call(fns.removeSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid }, parentAuth);
    assert.equal((await summary.collection('readers').doc(strangerAuth.uid).get()).exists, false);
    assert.deepEqual((await staffControls.get()).get('active_staff_school_ids'), [otherSchool.schoolId]);
  });

  test('active admins must be demoted before leaving or being removed as members', async () => {
    await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'admin-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Admin Membership School', profileId: 'owner-profile' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'admin-profile', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'admin-profile' }, parentAuth);

    for (const attempt of [
      () => call(fns.leaveSchool, { schoolId: created.schoolId, profileId: 'admin-profile' }, strangerAuth),
      () => call(fns.removeSchoolMember, { schoolId: created.schoolId, ownerUid: strangerAuth.uid, profileId: 'admin-profile' }, parentAuth),
    ]) {
      await assert.rejects(attempt(), (error) => {
        assert.equal(error.code, 'failed-precondition');
        assert.match(error.message, /Remove or transfer admin role first/);
        return true;
      });
    }
    const membershipRef = db.collection('school_memberships').doc(memberId(created.schoolId, strangerAuth.uid, 'admin-profile'));
    assert.equal((await membershipRef.get()).get('state'), 'active');
    assert.deepEqual((await db.collection('social_user_controls').doc(strangerAuth.uid).get()).get('active_staff_school_ids'), [created.schoolId]);

    await call(fns.removeSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid }, parentAuth);
    await call(fns.leaveSchool, { schoolId: created.schoolId, profileId: 'admin-profile' }, strangerAuth);
    assert.equal((await membershipRef.get()).get('state'), 'removed');
    assert.deepEqual((await db.collection('social_user_controls').doc(strangerAuth.uid).get()).get('active_staff_school_ids'), []);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(strangerAuth.uid, 'admin-profile')).get()).get('active_school_ids'), []);
  });

  test('a demoted admin can be removed as a member and staff access is revoked', async () => {
    await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'target-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Admin Transfer School', profileId: 'owner-profile' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'target-profile', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'target-profile' }, parentAuth);
    const controls = db.collection('social_user_controls');
    assert.deepEqual((await controls.doc(parentAuth.uid).get()).get('active_staff_school_ids'), [created.schoolId]);
    assert.deepEqual((await controls.doc(strangerAuth.uid).get()).get('active_staff_school_ids'), [created.schoolId]);
    await expectHttpsError(call(fns.removeSchoolMember, { schoolId: created.schoolId, ownerUid: strangerAuth.uid, profileId: 'target-profile' }, parentAuth), 'failed-precondition');
    await call(fns.removeSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid }, parentAuth);
    await call(fns.removeSchoolMember, { schoolId: created.schoolId, ownerUid: strangerAuth.uid, profileId: 'target-profile' }, parentAuth);
    assert.equal((await db.collection('school_memberships').doc(memberId(created.schoolId, strangerAuth.uid, 'target-profile')).get()).get('state'), 'removed');
    assert.deepEqual((await controls.doc(strangerAuth.uid).get()).get('active_staff_school_ids'), []);
  });

  test('transferring admin rights revokes only the source staff school grant', async () => {
    await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'target-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Admin Transfer School', profileId: 'owner-profile' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'target-profile', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'target-profile' }, parentAuth);
    await call(fns.transferSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'target-profile' }, parentAuth);

    const controls = db.collection('social_user_controls');
    assert.deepEqual((await controls.doc(parentAuth.uid).get()).get('active_staff_school_ids'), []);
    assert.deepEqual((await controls.doc(strangerAuth.uid).get()).get('active_staff_school_ids'), [created.schoolId]);
    assert.equal((await db.collection('school_admins').doc(staffId(created.schoolId, parentAuth.uid)).get()).get('state'), 'transferred');
    assert.equal((await db.collection('school_admins').doc(staffId(created.schoolId, strangerAuth.uid)).get()).get('state'), 'active');
  });

  test('staff refresh cannot re-grant access after the admin removal fence', async () => {
    await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'target-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Fenced Staff Removal', profileId: 'owner-profile' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'target-profile', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'target-profile' }, parentAuth);

    let releaseFence;
    let signalFence;
    const fenceCommitted = new Promise((resolve) => { signalFence = resolve; });
    const waitAtFence = new Promise((resolve) => { releaseFence = resolve; });
    const originalRunTransaction = db.runTransaction;
    let pauseAfterFirstTransaction = true;
    db.runTransaction = async function (...args) {
      const result = await originalRunTransaction.apply(this, args);
      if (pauseAfterFirstTransaction) {
        pauseAfterFirstTransaction = false;
        signalFence();
        await waitAtFence;
      }
      return result;
    };
    try {
      const removal = call(fns.removeSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid }, parentAuth);
      await Promise.race([
        fenceCommitted,
        removal.then(() => { throw new Error('admin removal completed without fencing the staff row'); }),
      ]);
      const staffRef = db.collection('school_admins').doc(staffId(created.schoolId, strangerAuth.uid));
      assert.equal((await staffRef.get()).get('state'), 'removing');
      await grantSocialStaffSchoolAccess(strangerAuth.uid, created.schoolId);
      releaseFence();
      await removal;
      assert.equal((await staffRef.get()).get('state'), 'removed');
    } finally {
      releaseFence();
      db.runTransaction = originalRunTransaction;
    }
    const controls = await db.collection('social_user_controls').doc(strangerAuth.uid).get();
    assert.deepEqual(controls.get('active_staff_school_ids') ?? [], []);
    const reader = await db.collection('social_summaries').doc(summaryId(parentAuth.uid, 'owner-profile'))
      .collection('readers').doc(strangerAuth.uid).get();
    assert.equal(reader.exists, false);
  });

  test('staff refresh cannot re-grant access to the outgoing admin during transfer', async () => {
    await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'target-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Fenced Admin Transfer', profileId: 'owner-profile' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'target-profile', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'target-profile' }, parentAuth);

    let releaseFence;
    let signalFence;
    const fenceCommitted = new Promise((resolve) => { signalFence = resolve; });
    const waitAtFence = new Promise((resolve) => { releaseFence = resolve; });
    const originalRunTransaction = db.runTransaction;
    let pauseAfterFirstTransaction = true;
    db.runTransaction = async function (...args) {
      const result = await originalRunTransaction.apply(this, args);
      if (pauseAfterFirstTransaction) {
        pauseAfterFirstTransaction = false;
        signalFence();
        await waitAtFence;
      }
      return result;
    };
    try {
      const transfer = call(fns.transferSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'target-profile' }, parentAuth);
      await Promise.race([
        fenceCommitted,
        transfer.then(() => { throw new Error('admin transfer completed without fencing the source staff row'); }),
      ]);
      const sourceRef = db.collection('school_admins').doc(staffId(created.schoolId, parentAuth.uid));
      assert.equal((await sourceRef.get()).get('state'), 'removing');
      await grantSocialStaffSchoolAccess(parentAuth.uid, created.schoolId);
      releaseFence();
      await transfer;
      assert.equal((await sourceRef.get()).get('state'), 'transferred');
    } finally {
      releaseFence();
      db.runTransaction = originalRunTransaction;
    }
    assert.deepEqual((await db.collection('social_user_controls').doc(parentAuth.uid).get())
      .get('active_staff_school_ids') ?? [], []);
    assert.deepEqual((await db.collection('social_user_controls').doc(strangerAuth.uid).get())
      .get('active_staff_school_ids'), [created.schoolId]);
  });

  test('account cleanup fences a non-last admin before staff refresh can re-grant access', async () => {
    await db.collection('users').doc(parentAuth.uid).set({ email: 'admin@example.com' });
    await seedSocialProfile(parentAuth.uid, 'owner-profile', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'member-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Fenced Non-Last Admin Cleanup', profileId: 'owner-profile' }, parentAuth);
    const ownerInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: ownerInvite.inviteCode, profileId: 'owner-profile', progressConsent: true }, parentAuth);
    const memberInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: memberInvite.inviteCode, profileId: 'member-profile', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'member-profile' }, parentAuth);

    let releaseFence;
    let signalFence;
    const fenceCommitted = new Promise((resolve) => { signalFence = resolve; });
    const waitAtFence = new Promise((resolve) => { releaseFence = resolve; });
    const originalRunTransaction = db.runTransaction;
    let pauseAtFence = true;
    db.runTransaction = async function (...args) {
      const result = await originalRunTransaction.apply(this, args);
      if (pauseAtFence && (await db.collection('school_admins').doc(staffId(created.schoolId, parentAuth.uid)).get()).get('state') === 'removing') {
        pauseAtFence = false;
        signalFence();
        await waitAtFence;
      }
      return result;
    };
    try {
      const deletion = call(fns.deleteAccountData, {}, parentAuth);
      await Promise.race([
        fenceCommitted,
        deletion.then(() => { throw new Error('account deletion completed without fencing the staff row'); }),
      ]);
      const school = await db.collection('schools').doc(created.schoolId).get();
      assert.equal(school.get('status'), 'active');
      assert.equal((await db.collection('school_admins').doc(staffId(created.schoolId, parentAuth.uid)).get()).get('state'), 'removing');
      await grantSocialStaffSchoolAccess(parentAuth.uid, created.schoolId);
      releaseFence();
      await deletion;
    } finally {
      releaseFence();
      db.runTransaction = originalRunTransaction;
    }
    assert.deepEqual((await db.collection('social_user_controls').doc(parentAuth.uid).get())
      .get('active_staff_school_ids') ?? [], []);
    assert.equal((await db.collection('school_admins').doc(staffId(created.schoolId, parentAuth.uid)).get()).get('state'), 'removed');
    assert.equal((await db.collection('school_admins').doc(staffId(created.schoolId, strangerAuth.uid)).get()).get('state'), 'active');
    const reader = await db.collection('social_summaries').doc(summaryId(strangerAuth.uid, 'member-profile'))
      .collection('readers').doc(parentAuth.uid).get();
    assert.equal(reader.exists, false);
  });

  test('admin removal of a member deletes that member school read grant', async () => {
    await seedSocialProfile(strangerAuth.uid, 'member-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Removal School' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'member-profile', progressConsent: true }, strangerAuth);
    const summary = db.collection('social_summaries').doc(summaryId(strangerAuth.uid, 'member-profile'));
    assert.deepEqual((await summary.collection('readers').doc(parentAuth.uid).get()).get('school_ids'), [created.schoolId]);

    await call(fns.removeSchoolMember, { schoolId: created.schoolId, ownerUid: strangerAuth.uid, profileId: 'member-profile' }, parentAuth);
    assert.equal((await summary.collection('readers').doc(parentAuth.uid).get()).exists, false);
    assert.equal((await db.collection('school_memberships').doc(memberId(created.schoolId, strangerAuth.uid, 'member-profile')).get()).get('state'), 'removed');
  });

  test('school deletion cleans active member summary grants and membership rows', async () => {
    await seedSocialProfile(strangerAuth.uid, 'member-profile', 'adult');
    const created = await call(fns.createSchool, { name: 'Delete School' }, parentAuth);
    const invite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: invite.inviteCode, profileId: 'member-profile', progressConsent: true }, strangerAuth);
    const summary = db.collection('social_summaries').doc(summaryId(strangerAuth.uid, 'member-profile'));

    await call(fns.deleteSchool, { schoolId: created.schoolId }, parentAuth);
    assert.equal((await summary.collection('readers').doc(parentAuth.uid).get()).exists, false);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(strangerAuth.uid, 'member-profile')).get()).get('active_school_ids'), []);
    assert.equal((await db.collection('school_memberships').doc(memberId(created.schoolId, strangerAuth.uid, 'member-profile')).get()).get('state'), 'deleted');
    assert.equal((await db.collection('schools').doc(created.schoolId).get()).get('status'), 'deleted');
  });

  test('deleting the last admin fences the school, revokes invites, and removes staff reads', async () => {
    const { schoolId, inviteCode } = await seedLastAdminSchool();
    const memberSummary = db.collection('social_summaries').doc(summaryId(strangerAuth.uid, 'member-profile'));
    assert.deepEqual((await memberSummary.collection('readers').doc(parentAuth.uid).get()).get('school_ids'), [schoolId]);

    await call(fns.deleteAccountData, {}, parentAuth);

    const school = await db.collection('schools').doc(schoolId).get();
    assert.equal(school.get('status'), 'suspended');
    assert.equal(school.get('cleanup_pending'), false);
    assert.equal((await db.collection('school_admins').doc(staffId(schoolId, parentAuth.uid)).get()).get('state'), 'removed');
    assert.equal((await memberSummary.collection('readers').doc(parentAuth.uid).get()).exists, false);
    assert.equal((await db.collection('social_user_controls').doc(parentAuth.uid).get())
      .get('active_staff_school_ids')?.includes(schoolId) ?? false, false);
    const inviteRef = db.collection('school_invites').doc(digest('school-invite', inviteCode));
    assert.equal((await inviteRef.get()).get('state'), 'revoked');
    await expectHttpsError(call(fns.joinSchoolWithInvite, {
      inviteCode, profileId: 'member-profile', progressConsent: true,
    }, strangerAuth), 'not-found');
  });

  test('a last-admin status transaction failure aborts account deletion before cleanup', async () => {
    const { schoolId } = await seedLastAdminSchool();
    const schoolRef = db.collection('schools').doc(schoolId);
    const adminRef = db.collection('school_admins').doc(staffId(schoolId, parentAuth.uid));
    const originalRunTransaction = db.runTransaction;
    db.runTransaction = async () => { throw new Error('injected school status transaction failure'); };
    try {
      await assert.rejects(call(fns.deleteAccountData, {}, parentAuth));
    } finally {
      db.runTransaction = originalRunTransaction;
    }
    assert.equal((await schoolRef.get()).get('status'), 'active');
    assert.equal((await schoolRef.get()).get('cleanup_pending'), undefined);
    assert.equal((await adminRef.get()).get('state'), 'active');
    assert.equal((await db.collection('users').doc(parentAuth.uid).get()).exists, true);
  });

  test('a failed cleanup resumes from the fence when account deletion is retried', async () => {
    const { schoolId, inviteCode } = await seedLastAdminSchool();
    const schoolRef = db.collection('schools').doc(schoolId);
    const originalRunTransaction = db.runTransaction;
    let transactionCount = 0;
    db.runTransaction = function (...args) {
      transactionCount += 1;
      if (transactionCount === 2) return Promise.reject(new Error('injected ACL revoke failure'));
      return originalRunTransaction.apply(this, args);
    };
    try {
      await assert.rejects(call(fns.deleteAccountData, {}, parentAuth));
    } finally {
      db.runTransaction = originalRunTransaction;
    }
    assert.equal((await schoolRef.get()).get('status'), 'suspended');
    assert.equal((await schoolRef.get()).get('cleanup_pending'), true);
    assert.equal((await db.collection('school_admins').doc(staffId(schoolId, parentAuth.uid)).get()).get('state'), 'active');
    assert.equal((await db.collection('school_invites').doc(digest('school-invite', inviteCode)).get()).get('state'), 'active');

    await call(fns.deleteAccountData, {}, parentAuth);

    assert.equal((await schoolRef.get()).get('status'), 'suspended');
    assert.equal((await schoolRef.get()).get('cleanup_pending'), false);
    assert.equal((await db.collection('school_admins').doc(staffId(schoolId, parentAuth.uid)).get()).get('state'), 'removed');
    assert.equal((await db.collection('school_invites').doc(digest('school-invite', inviteCode)).get()).get('state'), 'revoked');
  });

  test('staff and membership refresh grants after the deletion fence cannot survive cleanup', async () => {
    const { schoolId } = await seedLastAdminSchool();
    let releaseFence;
    let signalFence;
    const fenceCommitted = new Promise((resolve) => { signalFence = resolve; });
    const waitAtFence = new Promise((resolve) => { releaseFence = resolve; });
    const originalRunTransaction = db.runTransaction;
    let pauseAfterFirstTransaction = true;
    db.runTransaction = async function (...args) {
      const result = await originalRunTransaction.apply(this, args);
      if (pauseAfterFirstTransaction) {
        pauseAfterFirstTransaction = false;
        signalFence();
        await waitAtFence;
      }
      return result;
    };
    try {
      const deletion = call(fns.deleteAccountData, {}, parentAuth);
      await Promise.race([
        fenceCommitted,
        deletion.then(() => { throw new Error('deletion completed without fencing the school'); }),
      ]);
      const school = await db.collection('schools').doc(schoolId).get();
      assert.equal(school.get('status'), 'suspended');
      assert.equal(school.get('cleanup_pending'), true);
      assert.equal((await db.collection('school_admins').doc(staffId(schoolId, parentAuth.uid)).get()).get('state'), 'active');

      await Promise.all([
        grantSocialStaffSchoolAccess(parentAuth.uid, schoolId),
        refreshSocialMembershipMirror(summaryId(strangerAuth.uid, 'member-profile')),
      ]);
      releaseFence();
      await deletion;
    } finally {
      releaseFence();
      db.runTransaction = originalRunTransaction;
    }
    const reader = await db.collection('social_summaries').doc(summaryId(strangerAuth.uid, 'member-profile'))
      .collection('readers').doc(parentAuth.uid).get();
    assert.equal(reader.exists, false);
    assert.deepEqual((await db.collection('social_user_controls').doc(parentAuth.uid).get())
      .get('active_staff_school_ids') ?? [], []);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(strangerAuth.uid, 'member-profile')).get())
      .get('active_school_ids'), []);
  });

  test('school reports are bounded categories and stored for owner review', async () => {
    const created = await call(fns.createSchool, { name: 'Reported School' }, parentAuth);
    await expectHttpsError(call(fns.reportSchool, { schoolId: created.schoolId, category: 'free text' }, strangerAuth), 'invalid-argument');
    await call(fns.reportSchool, { schoolId: created.schoolId, category: 'impersonation' }, strangerAuth);
    const reports = await db.collection('school_reports').where('school_id', '==', created.schoolId).get();
    assert.equal(reports.size, 1);
    assert.equal(reports.docs[0].get('state'), 'open');
  });
});
