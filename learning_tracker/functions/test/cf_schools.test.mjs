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
    await seedSocialProfile(parentAuth.uid, 'admin-member', 'adult');
    await seedSocialProfile(strangerAuth.uid, 'staff-member', 'adult');
    const created = await call(fns.createSchool, { name: 'Shared School' }, parentAuth);
    const firstInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: firstInvite.inviteCode, profileId: 'staff-member', progressConsent: true }, strangerAuth);
    await call(fns.addSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid, profileId: 'staff-member' }, parentAuth);
    const secondInvite = await call(fns.createSchoolInvite, { schoolId: created.schoolId }, parentAuth);
    await call(fns.joinSchoolWithInvite, { inviteCode: secondInvite.inviteCode, profileId: 'admin-member', progressConsent: true }, parentAuth);
    const summary = db.collection('social_summaries').doc(summaryId(parentAuth.uid, 'admin-member'));
    assert.deepEqual((await summary.collection('readers').doc(strangerAuth.uid).get()).get('school_ids'), [created.schoolId]);
    await call(fns.leaveSchool, { schoolId: created.schoolId, profileId: 'admin-member' }, parentAuth);
    assert.equal((await summary.collection('readers').doc(strangerAuth.uid).get()).exists, false);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(parentAuth.uid, 'admin-member')).get()).get('active_school_ids'), []);
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
    const summary = db.collection('social_summaries').doc(summaryId(parentAuth.uid, 'owner-profile'));
    assert.deepEqual((await summary.collection('readers').doc(strangerAuth.uid).get()).get('school_ids'), [created.schoolId]);

    await call(fns.setSchoolSuspended, { schoolId: created.schoolId, suspended: true }, { uid: parentAuth.uid, token: { app_owner: true } });
    assert.equal((await summary.collection('readers').doc(strangerAuth.uid).get()).exists, false);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(parentAuth.uid, 'owner-profile')).get()).get('active_school_ids'), []);
    await call(fns.setSchoolSuspended, { schoolId: created.schoolId, suspended: false }, { uid: parentAuth.uid, token: { app_owner: true } });
    assert.deepEqual((await summary.collection('readers').doc(strangerAuth.uid).get()).get('school_ids'), [created.schoolId]);
    assert.deepEqual((await db.collection('social_profiles').doc(summaryId(parentAuth.uid, 'owner-profile')).get()).get('active_school_ids'), [created.schoolId]);

    await call(fns.removeSchoolAdmin, { schoolId: created.schoolId, targetUid: strangerAuth.uid }, parentAuth);
    assert.equal((await summary.collection('readers').doc(strangerAuth.uid).get()).exists, false);
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

  test('school reports are bounded categories and stored for owner review', async () => {
    const created = await call(fns.createSchool, { name: 'Reported School' }, parentAuth);
    await expectHttpsError(call(fns.reportSchool, { schoolId: created.schoolId, category: 'free text' }, strangerAuth), 'invalid-argument');
    await call(fns.reportSchool, { schoolId: created.schoolId, category: 'impersonation' }, strangerAuth);
    const reports = await db.collection('school_reports').where('school_id', '==', created.schoolId).get();
    assert.equal(reports.size, 1);
    assert.equal(reports.docs[0].get('state'), 'open');
  });
});
