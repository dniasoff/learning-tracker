import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { afterEach, beforeEach, describe, test } from 'node:test';
import {
  call, clearFirestore, db, expectHttpsError, fns, parentAuth, seedParentSession,
  seedSocialProfile, strangerAuth,
} from './_cf_helpers.mjs';
const notifications = await import('../lib/notifications.js');

const adminProfile = '01JADMIN0000000000000000000';
const memberProfile = '01JMEMBER000000000000000000';
const childProfile = '01JCHILD0000000000000000000';

function dateIn(days) {
  return new Date(Date.now() + days * 86400000).toISOString().slice(0, 10);
}

async function makeGroup({ includeChild = false } = {}) {
  await seedSocialProfile(strangerAuth.uid, adminProfile, 'adult');
  await seedSocialProfile(parentAuth.uid, memberProfile, 'adult');
  const group = await call(fns.createLearningGroup, { name: 'Study circle', profileId: adminProfile }, strangerAuth);
  const invite = await call(fns.createLearningGroupInvite, { groupId: group.groupId }, strangerAuth);
  const preview = await call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: memberProfile }, parentAuth);
  await call(fns.joinLearningGroup, { inviteCode: invite.inviteCode, profileId: memberProfile, memberRevision: preview.memberRevision }, parentAuth);
  if (includeChild) {
    await seedSocialProfile(parentAuth.uid, childProfile, 'child');
    const childInvite = await call(fns.createLearningGroupInvite, { groupId: group.groupId }, strangerAuth);
    const childPreview = await call(fns.getLearningGroupInvite, { inviteCode: childInvite.inviteCode, profileId: childProfile,
      parentSessionId: await seedParentSession(parentAuth.uid, childProfile) }, parentAuth);
    await call(fns.joinLearningGroup, { inviteCode: childInvite.inviteCode, profileId: childProfile,
      memberRevision: childPreview.memberRevision, parentSessionId: await seedParentSession(parentAuth.uid, childProfile) }, parentAuth);
  }
  return group.groupId;
}

async function postTask(groupId, scopeRefs = ['Mishnah Tamid']) {
  return call(fns.createLearningGroupTask, {
    groupId,
    profileId: adminProfile,
    curriculumId: 'mishnayos',
    scopeRefs,
    replyBy: dateIn(1),
    deadline: dateIn(14),
  }, strangerAuth);
}

async function accept(groupId, taskId, profileId = adminProfile, auth = strangerAuth, parentSessionId) {
  return call(fns.respondToLearningGroupTask, {
    groupId, taskId, profileId, response: 'accept', ...(parentSessionId ? { parentSessionId } : {}),
  }, auth);
}

async function preferences(groupId, taskId, profileId, auth = strangerAuth, capacity = 10) {
  return call(fns.submitLearningGroupTaskPreferences, {
    groupId,
    taskId,
    profileId,
    rankedRefs: ['Mishnah Tamid'],
    paceUnit: 'mishna',
    capacityPerStudyDay: capacity,
    studyDays: [1, 2, 3, 4, 5, 6],
  }, auth);
}

async function runDailyGroupTaskRebalance() {
  return fns.reconcileLearningGroupMissedTasks.run({ scheduleTime: new Date().toISOString() });
}

describe('group task acceptance, preferences, allocation, and daily schedule', () => {
  beforeEach(async () => clearFirestore());
  afterEach(() => notifications.setPushMessagingForTests(null));

  test('posting sends one generic data-only invite push per account with registered FCM tokens', async () => {
    const groupId = await makeGroup({ includeChild: true });
    await db.collection('users').doc(parentAuth.uid).set({
      fcm_tokens: { install_a: { token: 'member-device-token' } },
    }, { merge: true });
    const messages = [];
    notifications.setPushMessagingForTests({
      async sendEach(batch) {
        messages.push(...batch);
        return { responses: batch.map(() => ({ success: true })), successCount: batch.length, failureCount: 0 };
      },
    });
    const task = await postTask(groupId);
    assert.equal(messages.length, 1);
    assert.equal(messages[0].token, 'member-device-token');
    assert.deepEqual(messages[0].data, {
      type: 'group_task_invite',
      owner_uid: parentAuth.uid,
      profile_id: memberProfile,
      group_id: groupId,
      task_id: task.taskId,
      is_adult: 'true',
    });
    assert.equal('progress' in messages[0].data, false);
  });

  test('posting rejects a deadline more than three years away', async () => {
    const groupId = await makeGroup();
    await expectHttpsError(call(fns.createLearningGroupTask, {
      groupId,
      profileId: adminProfile,
      curriculumId: 'mishnayos',
      scopeRefs: ['Mishnah Tamid'],
      replyBy: dateIn(1),
      deadline: dateIn(365 * 3 + 5),
    }, strangerAuth), 'invalid-argument');
  });

  test('dead-token pruning follows the account and token paired with each sent message', async () => {
    const uids = [parentAuth.uid, strangerAuth.uid].sort();
    for (const [index, uid] of uids.entries()) {
      await db.collection('users').doc(uid).set({
        fcm_tokens: { install_a: { token: `device-${index}` } },
      }, { merge: true });
    }

    const messages = [];
    notifications.setPushMessagingForTests({
      async sendEach(batch) {
        messages.push(...batch);
        await db.collection('users').doc(uids[0]).update({
          'fcm_tokens.install_b': { token: 'new-device-token' },
        });
        return {
          responses: [
            { success: true },
            { success: false, error: { code: 'messaging/registration-token-not-registered' } },
          ],
          successCount: 1,
          failureCount: 1,
        };
      },
    });

    await notifications.sendGroupTaskPostedPush({
      groupId: 'group-test',
      taskId: 'task-test',
      invitees: uids.map((uid, index) => ({
        uid,
        profileId: `profile-${index}`,
        mode: 'adult',
      })),
    });

    assert.deepEqual(messages.map((message) => message.token), ['device-0', 'device-1']);
    const firstAccount = await db.collection('users').doc(uids[0]).get();
    const secondAccount = await db.collection('users').doc(uids[1]).get();
    assert.equal(firstAccount.get('fcm_tokens.install_a.token'), 'device-0');
    assert.equal(firstAccount.get('fcm_tokens.install_b.token'), 'new-device-token');
    assert.equal(secondAccount.get('fcm_tokens.install_a'), undefined);
  });

  test('acceptance and preferences are required before one atomic publication creates ordinary tracks', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);

    const result = await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    assert.equal(result.feasible, true);
    const taskDoc = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId).get();
    assert.equal(taskDoc.get('status'), 'published');
    const assignments = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('allocations').doc('v1').collection('members').get();
    assert.equal(assignments.size, 2);
    const assignment = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    assert.ok(assignment.get('sub_track_id'));
    assert.ok(Array.isArray(assignment.get('daily_tasks')));
    const track = await db.collection('users').doc(parentAuth.uid).collection('learner_profiles').doc(memberProfile)
      .collection('curriculum_tracks').doc('mishnayos').get();
    assert.equal(track.get('state'), 'active');
    const subTrack = await db.collection('users').doc(parentAuth.uid).collection('learner_profiles').doc(memberProfile)
      .collection('sub_tracks').doc(assignment.get('sub_track_id')).get();
    assert.equal(subTrack.get('curriculum_id'), 'mishnayos');
    assert.ok(Array.isArray(subTrack.get('ground')));
    const today = dateIn(0);
    const daily = await call(fns.listMyLearningGroupDailyTasks, { profileId: memberProfile, onDate: today }, parentAuth);
    assert.equal(daily.length, 1);
    assert.equal(daily[0].paceUnit, 'mishna');
    assert.ok(daily[0].paceAmount > 0);
  });

  test('published group task progress counts live sub-track learning events for group readers', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const assignments = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('allocations').doc('v1').collection('members').get();
    const member = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    const unitRef = member.get('units')[0].ref;
    await db.collection('users').doc(parentAuth.uid).collection('learner_profiles').doc(memberProfile)
      .collection('learning_events').doc('01JLEARN0000000000000000000').set({
        kind: 'learn', source: member.get('sub_track_id'), curriculum_id: 'mishnayos', ref: unitRef,
      });
    const cards = await call(fns.listLearningGroupTasks, { groupId, profileId: adminProfile }, strangerAuth);
    const shared = cards[0].allocation.members.find((row) => row.memberId === member.id);
    assert.equal(shared.progress.completed, 1);
    assert.equal(shared.progress.total, member.get('units').length);
  });

  test('published group progress is withheld when the group summary grant is absent', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const assignments = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('allocations').doc('v1').collection('members').get();
    const memberAssignment = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    const summaryId = createHash('sha256').update(`${parentAuth.uid}\0${memberProfile}`).digest('hex');
    await db.collection('social_summaries').doc(summaryId).collection('readers').doc(strangerAuth.uid).delete();
    const cards = await call(fns.listLearningGroupTasks, { groupId, profileId: adminProfile }, strangerAuth);
    const shared = cards[0].allocation.members.find((row) => row.memberId === memberAssignment.id);
    assert.ok(shared);
    assert.equal(shared.progress, null);
  });

  test('a forged future daily-task date is rejected without changing any member schedule', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const assignments = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('allocations').doc('v1').collection('members').get();
    const before = new Map(assignments.docs.map((doc) => [doc.id, doc.get('daily_tasks')]));
    await expectHttpsError(
      call(fns.listMyLearningGroupDailyTasks, { profileId: memberProfile, onDate: dateIn(3650) }, parentAuth),
      'invalid-argument',
    );
    await call(fns.listMyLearningGroupDailyTasks, { profileId: memberProfile, onDate: dateIn(1) }, parentAuth);
    for (const assignment of assignments.docs) {
      assert.deepEqual((await assignment.ref.get()).get('daily_tasks'), before.get(assignment.id));
    }
  });

  test('Learn reads are non-mutating and the daily job puts missed units on the owner future schedule first', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const assignmentsRef = db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('allocations').doc('v1').collection('members');
    const assignments = await assignmentsRef.get();
    const owner = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    const first = owner.get('daily_tasks')[0];
    const yesterday = dateIn(-1);
    await owner.ref.update({ daily_tasks: [{ ...first, date: yesterday }] });
    const today = dateIn(0);
    const beforeRead = (await owner.ref.get()).get('daily_tasks');
    await call(fns.listMyLearningGroupDailyTasks, { profileId: memberProfile, onDate: today }, parentAuth);
    assert.deepEqual((await owner.ref.get()).get('daily_tasks'), beforeRead);
    await runDailyGroupTaskRebalance();
    const updated = await owner.ref.get();
    const history = updated.get('daily_tasks').find((entry) => entry.date === yesterday);
    assert.ok(history.reconciled_at);
    assert.ok(updated.get('daily_tasks').some((entry) => entry.date >= today && entry.refs.includes(first.refs[0])), JSON.stringify(updated.get('daily_tasks')));
    assert.equal(updated.get('daily_tasks').filter((entry) => entry.date >= today)
      .reduce((count, entry) => count + entry.refs.filter((ref) => ref === first.refs[0]).length, 0), 1);
  });

  test('daily job transfers owner overflow only to a currently accepted member with capacity', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const assignmentsRef = db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('allocations').doc('v1').collection('members');
    const assignments = await assignmentsRef.get();
    const owner = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    const peer = assignments.docs.find((doc) => doc.get('profile_id') === adminProfile);
    const first = owner.get('daily_tasks')[0];
    const missedRef = first.refs[0];
    const holdingUnit = owner.get('units').find((unit) => missedRef === unit.ref || missedRef.startsWith(`${unit.ref} `));
    assert.ok(holdingUnit);
    const yesterday = dateIn(-1);
    await owner.ref.update({ daily_tasks: [{ ...first, date: yesterday }], study_days: [] });
    const today = dateIn(0);
    await runDailyGroupTaskRebalance();
    const [updatedOwner, updatedPeer, peerTrack] = await Promise.all([
      owner.ref.get(), peer.ref.get(),
      db.collection('users').doc(strangerAuth.uid).collection('learner_profiles').doc(adminProfile)
        .collection('sub_tracks').doc(peer.get('sub_track_id')).get(),
    ]);
    assert.ok(updatedOwner.get('daily_tasks').some((entry) => entry.date === yesterday && entry.reconciled_at));
    assert.ok(!updatedOwner.get('units').some((unit) => unit.ref === holdingUnit.ref));
    assert.ok(updatedPeer.get('units').some((unit) => unit.ref === missedRef));
    assert.ok(peerTrack.get('ground').some((unit) => unit.ref === missedRef));
    assert.ok(updatedPeer.get('daily_tasks').some((entry) => entry.date >= today && entry.refs.includes(missedRef)));
  });

  test('a lapsed owner is still rebalanced to an accepted active peer', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const taskRef = db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId);
    const assignments = await taskRef.collection('allocations').doc('v1').collection('members').get();
    const owner = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    const peer = assignments.docs.find((doc) => doc.get('profile_id') === adminProfile);
    const missed = owner.get('daily_tasks')[0];
    const missedRef = missed.refs[0];
    const ownerMember = db.collection('learning_groups').doc(groupId).collection('members').doc(parentAuth.uid);
    await Promise.all([
      owner.ref.update({ daily_tasks: [{ ...missed, date: dateIn(-1) }], study_days: [] }),
      ownerMember.collection('group_profiles').doc(memberProfile).update({ state: 'removed' }),
      ownerMember.update({ active_profile_ids: [] }),
    ]);
    await runDailyGroupTaskRebalance();
    const [updatedOwner, updatedPeer, peerTrack] = await Promise.all([
      owner.ref.get(), peer.ref.get(),
      db.collection('users').doc(strangerAuth.uid).collection('learner_profiles').doc(adminProfile)
        .collection('sub_tracks').doc(peer.get('sub_track_id')).get(),
    ]);
    assert.ok(!updatedOwner.get('units').some((unit) => unit.ref === missedRef));
    assert.ok(updatedPeer.get('units').some((unit) => unit.ref === missedRef));
    assert.ok(peerTrack.get('ground').some((unit) => unit.ref === missedRef));
  });

  test('a no-longer-accepted recipient is skipped and the missed ref stays pending', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const taskRef = db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId);
    const assignments = await taskRef.collection('allocations').doc('v1').collection('members').get();
    const owner = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    const peer = assignments.docs.find((doc) => doc.get('profile_id') === adminProfile);
    const missed = owner.get('daily_tasks')[0];
    const missedRef = missed.refs[0];
    await Promise.all([
      owner.ref.update({ daily_tasks: [{ ...missed, date: dateIn(-1) }], study_days: [] }),
      taskRef.collection('members').doc(peer.id).update({ state: 'declined' }),
    ]);
    await runDailyGroupTaskRebalance();
    const [updatedOwner, updatedPeer, currentTask] = await Promise.all([owner.ref.get(), peer.ref.get(), taskRef.get()]);
    assert.ok(updatedOwner.get('units').some((unit) => unit.ref === missedRef || missedRef.startsWith(`${unit.ref} `)));
    assert.ok(!updatedPeer.get('units').some((unit) => unit.ref === missedRef));
    assert.ok(currentTask.get('rebalance_unassigned_refs').includes(missedRef));
    assert.ok(updatedOwner.get('daily_tasks').some((entry) => entry.refs.includes(missedRef) && !entry.reconciled_at));
  });

  test('a recipient with a missing sub-track is logged and skipped without aborting the job', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const taskRef = db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId);
    const assignments = await taskRef.collection('allocations').doc('v1').collection('members').get();
    const owner = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    const peer = assignments.docs.find((doc) => doc.get('profile_id') === adminProfile);
    const missed = owner.get('daily_tasks')[0];
    await Promise.all([
      owner.ref.update({ daily_tasks: [{ ...missed, date: dateIn(-1) }], study_days: [] }),
      db.collection('users').doc(strangerAuth.uid).collection('learner_profiles').doc(adminProfile)
        .collection('sub_tracks').doc(peer.get('sub_track_id')).delete(),
    ]);
    await runDailyGroupTaskRebalance();
    const updated = await owner.ref.get();
    assert.ok(updated.get('daily_tasks').some((entry) => entry.refs.includes(missed.refs[0]) && !entry.reconciled_at));
  });

  test('daily job does not redistribute a missed ref already completed by the owner', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    await preferences(groupId, task.taskId, memberProfile, parentAuth);
    await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    const assignments = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('allocations').doc('v1').collection('members').get();
    const owner = assignments.docs.find((doc) => doc.get('profile_id') === memberProfile);
    const ref = owner.get('daily_tasks')[0].refs[0];
    const yesterday = dateIn(-1);
    await owner.ref.update({ daily_tasks: [{ ...owner.get('daily_tasks')[0], date: yesterday }], study_days: [] });
    await db.collection('users').doc(parentAuth.uid).collection('learner_profiles').doc(memberProfile)
      .collection('learning_events').doc('01JLEARN0000000000000000001').set({
        kind: 'learn', source: owner.get('sub_track_id'), curriculum_id: 'mishnayos', ref,
      });
    await runDailyGroupTaskRebalance();
    const updated = await owner.ref.get();
    assert.ok(updated.get('daily_tasks').some((entry) => entry.date === yesterday && entry.reconciled_at));
    assert.ok(!updated.get('daily_tasks').some((entry) => entry.date >= dateIn(0) && entry.refs.includes(ref)));
    assert.ok(updated.get('units').some((unit) => unit.ref === ref || ref.startsWith(`${unit.ref} `)));
  });

  test('child acceptance requires the parent PIN session for this task', async () => {
    const groupId = await makeGroup({ includeChild: true });
    const task = await postTask(groupId);
    await expectHttpsError(accept(groupId, task.taskId, childProfile, parentAuth), 'invalid-argument');
    const parentSessionId = await seedParentSession(parentAuth.uid, childProfile);
    await accept(groupId, task.taskId, childProfile, parentAuth, parentSessionId);
    const invitation = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('members').where('profile_id', '==', childProfile).get();
    assert.equal(invitation.docs[0].get('parent_approved'), true);
  });

  test('infeasible deadline is returned to the admin without publishing partial assignments', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile, strangerAuth, 1);
    await preferences(groupId, task.taskId, memberProfile, parentAuth, 1);
    const taskRef = db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId);
    await taskRef.update({ deadline: (await import('firebase-admin')).default.firestore.Timestamp.fromDate(new Date(`${dateIn(2)}T23:59:59.999Z`)) });
    const result = await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    assert.equal(result.feasible, false);
    assert.ok(result.shortfall > 0);
    assert.equal((await taskRef.get()).get('status'), 'capacity_review');
    assert.equal((await taskRef.collection('allocations').doc('v1').get()).exists, false);
  });

  test('concurrent preference write cannot be omitted from allocation snapshot', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    await accept(groupId, task.taskId);
    await call(fns.respondToLearningGroupTask, { groupId, taskId: task.taskId, profileId: memberProfile, response: 'accept' }, parentAuth);
    await preferences(groupId, task.taskId, adminProfile);
    const race = await Promise.allSettled([
      preferences(groupId, task.taskId, memberProfile, parentAuth),
      call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth),
    ]);
    assert.equal(race[0].status, 'fulfilled');
    const final = await call(fns.allocateLearningGroupTask, { groupId, taskId: task.taskId }, strangerAuth);
    assert.equal(final.feasible, true);
    const assignments = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('allocations').doc('v1').collection('members').get();
    assert.equal(assignments.size, 2);
  });

  test('a late member can request admission and only the admin can approve before allocation', async () => {
    const groupId = await makeGroup();
    const task = await postTask(groupId);
    const lateProfile = '01JLATE00000000000000000000';
    await seedSocialProfile(parentAuth.uid, lateProfile, 'adult');
    const invite = await call(fns.createLearningGroupInvite, { groupId }, strangerAuth);
    const preview = await call(fns.getLearningGroupInvite, { inviteCode: invite.inviteCode, profileId: lateProfile }, parentAuth);
    await call(fns.joinLearningGroup, { inviteCode: invite.inviteCode, profileId: lateProfile, memberRevision: preview.memberRevision }, parentAuth);
    const request = await call(fns.requestLateLearningGroupTaskJoin, {
      groupId, taskId: task.taskId, profileId: lateProfile,
    }, parentAuth);
    assert.equal(request.state, 'pending');
    const requestDoc = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('join_requests').where('profile_id', '==', lateProfile).get();
    assert.equal(requestDoc.size, 1);
    const reviewed = await call(fns.reviewLateLearningGroupTaskJoin, {
      groupId, taskId: task.taskId, memberId: requestDoc.docs[0].id, approved: true,
    }, strangerAuth);
    assert.equal(reviewed.state, 'approved');
    const invitation = await db.collection('learning_groups').doc(groupId).collection('tasks').doc(task.taskId)
      .collection('members').doc(requestDoc.docs[0].id).get();
    assert.equal(invitation.get('state'), 'awaiting_response');
    assert.equal(invitation.get('late_approved'), true);
  });
});
