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
  changeLog,
  parentAuth,
  profileRef,
  seedActiveGrant,
  seedAuthUser,
  seedProfile,
  strangerAuth,
  tutorAuth,
  ulid,
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
    // AUD-firebase-07: seedActiveGrant stores child_profile_id as a STRING
    // (String(PROFILE)) matching every production writer (inviteTutor
    // requires childProfileId to be a string). The outgoing-mode Firestore
    // '==' query is type-strict, so this genuinely exercises the query
    // path — a real regression in listTutorGrants' outgoing query would
    // fail this assertion.
    await seedActiveGrant();

    const res = await call(
      fns.listTutorGrants,
      { mode: 'outgoing', childProfileId: String(PROFILE) },
      parentAuth,
    );

    assert.equal(res.grants.length, 1);
    assert.equal(res.grants[0].id, GRANT);
    assert.equal(res.grants[0].parent_uid, PARENT);
    assert.equal(res.grants[0].child_profile_id, String(PROFILE));
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

// ── DNI-512 (Story 4.4) — revocation keeps the tutor's work; re-invite is new ──
// AC-1: the unchanged parent `revokeTutorGrant({grantId})` flow revokes the
// grant and removes its access index in one transaction, and every learner
// document the tutor authored — sub-tracks with their ground, learning
// events, goals and their change_log entries — stays byte-for-byte intact.
// AC-6: a re-invite is a fresh grant lifecycle over the retained data; its
// `can_edit_learning` is exactly the new invite checkbox, and nothing of the
// revoked grant is revived.
//
// [ASSUMPTION] tutor_grants ids are deterministic per (tutor email, parent,
// profile) (AUD-firebase-02), so the re-invite lands on the SAME doc id. It
// replaces the revoked doc wholesale (`merge: false`): no state, tutor_uid,
// permission, acceptance or revocation field of the old grant carries over.
// The story's "distinct grant id" edge case is filed as a follow-up bead.
describe('DNI-512 — revoke keeps tutor-authored history; a re-invite is a new grant', () => {
  const TUTOR_EMAIL = 'rebbe@example.com';
  const C = 'shas';
  const SUB = ulid(100);
  const ACCESS_ID = `${TUTOR}_${PARENT}_${PROFILE}`;
  const ONGOING = {
    curriculum_id: C,
    name: 'Rebbe Gemara',
    type: 'ongoing',
    window_start: '2026-09-01',
    rate_per_week: 5,
    weeks_per_year: 40,
    learns_on_shabbos: false,
    ground: [{ level: 'masechta', ref: 'Berakhot' }],
  };
  const LEARNER_COLLECTIONS = [
    'sub_tracks',
    'learning_events',
    'goals',
    'change_log',
    'points_ledger',
  ];

  const routing = (grantId, extra = {}) => ({
    grantId,
    ownerUid: PARENT,
    profileId: PROFILE,
    ...extra,
  });
  const learn = (id, ref, source = 'main') => ({
    id,
    fields: {
      kind: 'learn', curriculum_id: C, ref, source,
      date_state: 'dated', learned_on: '2026-10-01',
    },
  });
  const grantOf = async (grantId) =>
    (await db.collection('tutor_grants').doc(grantId).get()).data();
  const accessExists = async () =>
    (await db.collection('tutor_active_access').doc(ACCESS_ID).get()).exists;

  /** Parent invites with [canEditLearning]; the tutor accepts. */
  async function inviteAndAccept(canEditLearning) {
    const { grantId } = await call(
      fns.inviteTutor,
      {
        tutorEmail: TUTOR_EMAIL,
        childProfileId: String(PROFILE),
        childName: 'Yossi',
        permissions: { can_edit_learning: canEditLearning },
      },
      parentAuth,
    );
    await call(fns.acceptTutorInvite, { grantId });
    return grantId;
  }

  /** Every doc of the learner's subcollections: path → data + server update time. */
  async function learnerSnapshot() {
    const out = new Map();
    for (const name of LEARNER_COLLECTIONS) {
      const snap = await profileRef().collection(name).get();
      for (const d of snap.docs) {
        out.set(`${name}/${d.id}`, {
          data: d.data(),
          updateTime: d.updateTime.toMillis() * 1e6 + (d.updateTime.nanoseconds % 1e6),
        });
      }
    }
    return out;
  }

  /** The tutor creates a sub-track with ground, records learning on it and on
   *  main, and sets a goal — all through writeWithChangeLog-backed callables. */
  async function tutorAuthorsHistory(grantId) {
    await call(fns.tutorUpsertSubTrack, routing(grantId, { op: 'create', subTrackId: SUB, fields: ONGOING }));
    await call(fns.tutorRecordLearning, routing(grantId, {
      events: [learn(ulid(1), 'Berakhot 2a', SUB), learn(ulid(2), 'Berakhot 2b')],
    }));
    await call(fns.tutorUpsertGoal, routing(grantId, {
      goalId: `${C}_deadline`,
      goalData: { goal_type: 'deadline', target_date: '2027-06-01', curriculum_id: C },
      actionId: ulid(3),
    }));
  }

  beforeEach(async () => {
    await clearFirestore();
    await seedProfile();
    await seedAuthUser({ uid: TUTOR, email: TUTOR_EMAIL, emailVerified: true, displayName: 'Rebbe' });
  });

  test('AC-1: revoke leaves every tutor-authored doc and change_log entry byte-for-byte unchanged', async () => {
    const grantId = await inviteAndAccept(true);
    await tutorAuthorsHistory(grantId);
    const before = await learnerSnapshot();
    // Sanity: the tutor's work is really there and attributed to him.
    assert.ok(before.has(`sub_tracks/${SUB}`));
    assert.deepEqual(before.get(`sub_tracks/${SUB}`).data.ground, ONGOING.ground);
    assert.ok(before.has(`learning_events/${ulid(1)}`));
    assert.ok(before.has(`learning_events/${ulid(2)}`));
    assert.ok(before.has(`goals/${C}_deadline`));
    const tutorEntities = (await changeLog())
      .filter((e) => e.actor?.role === 'tutor')
      .map((e) => e.entity);
    assert.ok(tutorEntities.includes('subTrack'), 'the sub-track is logged as the tutor');
    assert.ok(tutorEntities.includes('goal'), 'the goal is logged as the tutor');
    for (const id of [ulid(1), ulid(2)]) {
      assert.equal(before.get(`learning_events/${id}`).data.actor.role, 'tutor',
        'learning events carry the tutor actor');
    }

    const res = await call(fns.revokeTutorGrant, { grantId }, parentAuth);
    assert.deepEqual(res, { success: true }, 'the revoke payload and result are unchanged');

    const grant = await grantOf(grantId);
    assert.equal(grant.state, 'revoked_by_parent');
    assert.ok(grant.revoked_at, 'revoked_at is stamped');
    assert.equal(await accessExists(), false, 'the access index is removed in the same transaction');

    const after = await learnerSnapshot();
    assert.deepEqual([...after.keys()].sort(), [...before.keys()].sort(), 'no doc is added or deleted');
    for (const [path, { data, updateTime }] of before) {
      assert.deepEqual(after.get(path).data, data, `${path} data is unchanged`);
      assert.equal(after.get(path).updateTime, updateTime, `${path} is not rewritten`);
    }
  });

  test('AC-6: a re-invite with the box checked resumes editing over the retained history', async () => {
    const oldGrantId = await inviteAndAccept(true);
    await tutorAuthorsHistory(oldGrantId);
    await call(fns.revokeTutorGrant, { grantId: oldGrantId }, parentAuth);
    const retained = await learnerSnapshot();

    const newGrantId = await inviteAndAccept(true);
    const grant = await grantOf(newGrantId);
    assert.equal(grant.state, 'active');
    assert.equal(grant.permissions.can_edit_learning, true);
    assert.equal(grant.revoked_at, undefined, 'nothing of the revoked grant is carried over');
    assert.equal(await accessExists(), true);

    // The earlier docs are untouched by the re-invite and acceptance …
    const now = await learnerSnapshot();
    for (const [path, { data, updateTime }] of retained) {
      assert.deepEqual(now.get(path).data, data, `${path} is retained as-is`);
      assert.equal(now.get(path).updateTime, updateTime, `${path} is not copied or rewritten`);
    }
    // … and the tutor works on his earlier sub-track again under the new grant.
    await call(fns.tutorUpsertSubTrack, routing(newGrantId, {
      op: 'edit', subTrackId: SUB, fields: { rate_per_week: 6 }, actionId: ulid(4),
    }));
    const sub = (await profileRef().collection('sub_tracks').doc(SUB).get()).data();
    assert.equal(sub.rate_per_week, 6);
    assert.deepEqual(sub.ground, ONGOING.ground);
  });

  test('AC-6: a re-invite with the box unchecked never inherits the old edit permission', async () => {
    const oldGrantId = await inviteAndAccept(true);
    await tutorAuthorsHistory(oldGrantId);
    await call(fns.revokeTutorGrant, { grantId: oldGrantId }, parentAuth);
    const retained = await learnerSnapshot();

    const newGrantId = await inviteAndAccept(false);
    const grant = await grantOf(newGrantId);
    assert.equal(grant.state, 'active');
    assert.equal(grant.permissions.can_edit_learning, false, 'exactly the new checkbox value');
    assert.equal(await accessExists(), true, 'read access resumes under the new grant');

    await expectHttpsError(
      call(fns.tutorUpsertSubTrack, routing(newGrantId, {
        op: 'edit', subTrackId: SUB, fields: { rate_per_week: 6 }, actionId: ulid(4),
      })),
      'permission-denied',
    );
    await expectHttpsError(
      call(fns.tutorRecordLearning, routing(newGrantId, { events: [learn(ulid(5), 'Berakhot 3a')] })),
      'permission-denied',
    );
    const now = await learnerSnapshot();
    assert.deepEqual([...now.keys()].sort(), [...retained.keys()].sort(), 'nothing is written');
  });

  test('AC-6: a pending re-invite revives nothing — no access index and every callable is denied', async () => {
    const oldGrantId = await inviteAndAccept(true);
    await tutorAuthorsHistory(oldGrantId);
    await call(fns.revokeTutorGrant, { grantId: oldGrantId }, parentAuth);

    const { grantId } = await call(
      fns.inviteTutor,
      { tutorEmail: TUTOR_EMAIL, childProfileId: String(PROFILE), permissions: { can_edit_learning: true } },
      parentAuth,
    );
    const grant = await grantOf(grantId);
    assert.equal(grant.state, 'pending');
    assert.equal(grant.tutor_uid, null, 'the old tutor binding is not carried over');
    assert.equal(grant.accepted_at, undefined);
    assert.equal(await accessExists(), false);

    const before = await learnerSnapshot();
    await expectHttpsError(
      call(fns.tutorRecordLearning, routing(grantId, { events: [learn(ulid(6), 'Berakhot 4a')] })),
      'permission-denied',
    );
    assert.equal((await learnerSnapshot()).size, before.size);
  });
});
