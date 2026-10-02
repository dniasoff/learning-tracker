// CF tests — updateTutorGrantPermissions (sub-tracks AD-53, Story 1.25 /
// DNI-487 AC-1, AC-2, AC-6 and the duplicate/racing-update edge cases).
//
// The owning parent turns a grant's single `can_edit_learning` permission on
// or off; the five legacy per-operation edit keys are removed in the same
// update. Tutors, non-owners, and stale/revoked/pending grants are rejected
// with permission-denied and nothing is written. A tutor write after the
// parent turns editing off is rejected on that call by writeWithChangeLog's
// per-call grant check, with no mutation, while read access stays.
//
// [ASSUMPTION] (ruling B11): the AC-2 "parent call without an unlocked parent
// session" scenario becomes "owner uid required; parent-vs-child on the same
// account is enforced in the UI per the Roles convention" — the parent PIN
// never leaves the device (FR99), so no callable can verify it.
//
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { FieldValue } from 'firebase-admin/firestore';
import { beforeEach, describe, test } from 'node:test';
import {
  GRANT,
  PARENT,
  PROFILE,
  TUTOR,
  call,
  changeLog,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  parentAuth,
  profileRef,
  seedActiveGrant,
  seedProfile,
  strangerAuth,
  tutorAuth,
  ulid,
} from './_cf_helpers.mjs';

const LEGACY_KEYS = [
  'can_edit_goals',
  'can_edit_stages',
  'can_edit_study_days',
  'can_reset_completion',
  'can_bulk_prior_completion',
];

/** A pre-AD-53 grant: legacy edit keys, no can_edit_learning. */
const LEGACY_PERMISSIONS = {
  can_view_progress: true,
  can_view_content: false,
  can_bulk_prior_completion: true,
  can_reset_completion: true,
  can_edit_goals: true,
  can_edit_stages: true,
  can_edit_study_days: true,
  can_edit_rewards: true,
  can_edit_points: false,
};

const grantDoc = async () => (await db.collection('tutor_grants').doc(GRANT).get()).data();

function assertNoLegacyKeys(permissions) {
  for (const k of LEGACY_KEYS) {
    assert.equal(k in permissions, false, `legacy key ${k} must be absent`);
  }
}

describe('updateTutorGrantPermissions — AC-1 owner update', () => {
  beforeEach(async () => {
    await clearFirestore();
    await seedActiveGrant({ ...LEGACY_PERMISSIONS });
  });

  test('is exported from functions/src/index.ts and the compiled barrel', () => {
    assert.equal(typeof fns.updateTutorGrantPermissions, 'function');
    const barrel = readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
    assert.match(barrel, /export \{ updateTutorGrantPermissions \} from "\.\/tutor_invites";/);
  });

  for (const value of [true, false]) {
    test(`owner sets can_edit_learning=${value}; all five legacy keys removed; ` +
        'view/rewards/points preserved', async () => {
      const res = await call(
        fns.updateTutorGrantPermissions,
        { grantId: GRANT, canEditLearning: value },
        parentAuth,
      );
      assert.deepEqual(res, { success: true, grantId: GRANT, canEditLearning: value });

      const { permissions, state, tutor_uid: tutorUid } = await grantDoc();
      assert.equal(permissions.can_edit_learning, value);
      assertNoLegacyKeys(permissions);
      assert.equal(permissions.can_view_progress, true);
      assert.equal(permissions.can_view_content, false);
      assert.equal(permissions.can_edit_rewards, true);
      assert.equal(permissions.can_edit_points, false);
      assert.equal(state, 'active');
      assert.equal(tutorUid, TUTOR);
    });
  }

  test('a grant with no permissions map gains can_edit_learning', async () => {
    await seedActiveGrant({});
    await db.collection('tutor_grants').doc(GRANT).update({ permissions: FieldValue.delete() });
    assert.equal('permissions' in (await grantDoc()), false);
    await call(fns.updateTutorGrantPermissions, { grantId: GRANT, canEditLearning: true }, parentAuth);
    const { permissions } = await grantDoc();
    assert.equal(permissions.can_edit_learning, true);
  });

  test('repeating the same update is idempotent', async () => {
    const args = { grantId: GRANT, canEditLearning: true };
    await call(fns.updateTutorGrantPermissions, args, parentAuth);
    const first = (await grantDoc()).permissions;
    await call(fns.updateTutorGrantPermissions, args, parentAuth);
    assert.deepEqual((await grantDoc()).permissions, first);
  });

  test('ignores a client-supplied role and legacy keys in the request', async () => {
    await call(
      fns.updateTutorGrantPermissions,
      { grantId: GRANT, canEditLearning: false, role: 'parent', can_edit_goals: true },
      parentAuth,
    );
    const { permissions } = await grantDoc();
    assert.equal(permissions.can_edit_learning, false);
    assertNoLegacyKeys(permissions);
  });
});

describe('updateTutorGrantPermissions — AC-2 authorization (fails closed)', () => {
  let before;

  beforeEach(async () => {
    await clearFirestore();
    await seedActiveGrant({ ...LEGACY_PERMISSIONS, can_edit_learning: false });
    before = await grantDoc();
  });

  async function expectRejectedUnchanged(data, auth, code) {
    await expectHttpsError(call(fns.updateTutorGrantPermissions, data, auth), code);
    assert.deepEqual(await grantDoc(), before, 'a rejected update must write nothing');
  }

  test('unauthenticated → unauthenticated', async () => {
    await expectRejectedUnchanged({ grantId: GRANT, canEditLearning: true }, null, 'unauthenticated');
  });

  test('the grant\'s tutor → permission-denied', async () => {
    await expectRejectedUnchanged({ grantId: GRANT, canEditLearning: true }, tutorAuth, 'permission-denied');
  });

  test('a non-owner → permission-denied', async () => {
    await expectRejectedUnchanged({ grantId: GRANT, canEditLearning: true }, strangerAuth, 'permission-denied');
  });

  test('owner uid is required; parent-vs-child on the same account is enforced in the UI ' +
      '(B11: no server-verifiable PIN session) — a token role claim grants nothing', async () => {
    const childClaimingParent = { uid: 'stranger-uid', token: { role: 'parent' } };
    await expectRejectedUnchanged(
      { grantId: GRANT, canEditLearning: true }, childClaimingParent, 'permission-denied',
    );
  });
});

describe('updateTutorGrantPermissions — edge: stale, revoked, malformed, racing', () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  test('a stale (missing) grant id → permission-denied, nothing created', async () => {
    await expectHttpsError(
      call(fns.updateTutorGrantPermissions, { grantId: 'no-such-grant', canEditLearning: true }, parentAuth),
      'permission-denied',
    );
    assert.equal((await db.collection('tutor_grants').doc('no-such-grant').get()).exists, false);
  });

  for (const state of ['revoked_by_parent', 'revoked_by_tutor', 'pending', 'expired', 'rescinded']) {
    test(`a ${state} grant → permission-denied; legacy keys are not touched`, async () => {
      await seedActiveGrant({ ...LEGACY_PERMISSIONS }, { state });
      const before = await grantDoc();
      await expectHttpsError(
        call(fns.updateTutorGrantPermissions, { grantId: GRANT, canEditLearning: true }, parentAuth),
        'permission-denied',
      );
      assert.deepEqual(await grantDoc(), before);
    });
  }

  for (const [label, data] of [
    ['string "true"', { grantId: GRANT, canEditLearning: 'true' }],
    ['number 1', { grantId: GRANT, canEditLearning: 1 }],
    ['null', { grantId: GRANT, canEditLearning: null }],
    ['missing', { grantId: GRANT }],
    ['snake_case key only', { grantId: GRANT, can_edit_learning: true }],
    ['missing grantId', { canEditLearning: true }],
    ['non-string grantId', { grantId: 7, canEditLearning: true }],
  ]) {
    test(`malformed request (${label}) → invalid-argument, nothing written`, async () => {
      await seedActiveGrant({ ...LEGACY_PERMISSIONS });
      const before = await grantDoc();
      await expectHttpsError(call(fns.updateTutorGrantPermissions, data, parentAuth), 'invalid-argument');
      assert.deepEqual(await grantDoc(), before);
    });
  }

  test('concurrent opposite updates both resolve against the committed doc; ' +
      'the final value is one of them and no legacy key comes back', async () => {
    await seedActiveGrant({ ...LEGACY_PERMISSIONS });
    const results = await Promise.all([
      call(fns.updateTutorGrantPermissions, { grantId: GRANT, canEditLearning: true }, parentAuth),
      call(fns.updateTutorGrantPermissions, { grantId: GRANT, canEditLearning: false }, parentAuth),
    ]);
    for (const r of results) assert.equal(r.success, true);
    const { permissions } = await grantDoc();
    assert.ok([true, false].includes(permissions.can_edit_learning));
    assertNoLegacyKeys(permissions);
  });

  test('an update racing a revoke never reports success for a revoked grant', async () => {
    await seedActiveGrant({ ...LEGACY_PERMISSIONS });
    const [update, revoke] = await Promise.allSettled([
      call(fns.updateTutorGrantPermissions, { grantId: GRANT, canEditLearning: true }, parentAuth),
      call(fns.revokeTutorGrant, { grantId: GRANT }, parentAuth),
    ]);
    assert.equal(revoke.status, 'fulfilled');
    const after = await grantDoc();
    assert.equal(after.state, 'revoked_by_parent');
    if (update.status === 'fulfilled') {
      // The update committed first (while active); it must then hold.
      assert.equal(after.permissions.can_edit_learning, true);
    } else {
      assert.equal(update.reason.code ?? update.reason.httpErrorCode?.canonicalName, 'permission-denied');
    }
  });
});

describe('updateTutorGrantPermissions — AC-6 revocation applies on the next tutor write', () => {
  const C = 'mishnah';
  const goalArgs = (n) => ({
    grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, actionId: ulid(n),
    goalId: `${C}_deadline`,
    goalData: { goal_type: 'deadline', target_date: '2027-06-01', curriculum_id: C },
  });
  const goals = () => profileRef().collection('goals');

  beforeEach(async () => {
    await clearFirestore();
    await seedProfile();
    await seedActiveGrant({ can_view_progress: true, can_view_content: true, can_edit_learning: true });
    await db.collection('tutor_active_access').doc(`${TUTOR}_${PARENT}_${PROFILE}`).set({
      tutor_uid: TUTOR, parent_uid: PARENT, child_profile_id: String(PROFILE), grant_id: GRANT,
    });
  });

  test('a tutor write succeeds while editing is on, and is rejected with no mutation ' +
      'right after the parent turns it off; read access stays', async () => {
    await call(fns.tutorUpsertGoal, goalArgs(1));
    assert.equal((await goals().doc(`${C}_deadline`).get()).exists, true);
    const logBefore = await changeLog();

    await call(fns.updateTutorGrantPermissions, { grantId: GRANT, canEditLearning: false }, parentAuth);

    const goalBefore = (await goals().doc(`${C}_deadline`).get()).data();
    await expectHttpsError(
      call(fns.tutorUpsertGoal, {
        ...goalArgs(2),
        goalData: { goal_type: 'deadline', target_date: '2028-01-01', curriculum_id: C },
      }),
      'permission-denied',
    );
    assert.deepEqual((await goals().doc(`${C}_deadline`).get()).data(), goalBefore, 'nothing written');
    assert.equal((await changeLog()).length, logBefore.length, 'no change_log entry');

    // Read access is independent: the grant stays active and the Rules
    // read-index doc is untouched.
    assert.equal((await grantDoc()).state, 'active');
    assert.equal(
      (await db.collection('tutor_active_access').doc(`${TUTOR}_${PARENT}_${PROFILE}`).get()).exists,
      true,
    );
  });

  test('turning editing back on lets the next tutor write through', async () => {
    await call(fns.updateTutorGrantPermissions, { grantId: GRANT, canEditLearning: false }, parentAuth);
    await expectHttpsError(call(fns.tutorUpsertGoal, goalArgs(3)), 'permission-denied');
    await call(fns.updateTutorGrantPermissions, { grantId: GRANT, canEditLearning: true }, parentAuth);
    await call(fns.tutorUpsertGoal, goalArgs(4));
    assert.equal((await goals().doc(`${C}_deadline`).get()).exists, true);
  });
});
