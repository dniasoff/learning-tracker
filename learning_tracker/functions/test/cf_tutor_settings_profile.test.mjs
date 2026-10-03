// CF tests — tutor settings/profile mutations:
//   tutorUpdateGamificationSettings, tutorEditProfile (Story 1.10 / DNI-472
//   AC-4: restricted display_name/avatar/mode field merge),
//   tutorBulkPriorCompletions
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import admin from 'firebase-admin';
import {
  GRANT,
  PARENT,
  PROFILE,
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  profileRef,
  seedActiveGrant,
  strangerAuth,
  TUTOR,
} from './_cf_helpers.mjs';

// ── tutorUpdateGamificationSettings ──────────────────────────────────────────
describe('tutorUpdateGamificationSettings', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    permKey: 'can_edit_rewards',
    settingsData: { rewards_enabled: true },
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('zero profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, profileId: 0 }),
      'invalid-argument',
    );
  });

  test('invalid permKey → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, permKey: 'can_reset_completion' }),
      'invalid-argument',
    );
  });

  test('missing settingsData → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, settingsData: null }),
      'invalid-argument',
    );
  });

  test('settingsData is array → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, { ...goodArgs, settingsData: [] }),
      'invalid-argument',
    );
  });

  // AUD-firebase-10: preferences/{scope} has no firestore.rules hasOnly()
  // whitelist (intentionally open-ended even for owner writes), so no
  // unexpected-key test applies here — but the size cap still does.
  test('AUD-firebase-10: settingsData with an oversized string field → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, {
        ...goodArgs,
        settingsData: { notes: 'x'.repeat(5001) },
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant(
      { can_edit_rewards: true },
      { state: 'revoked_by_parent' },
    );
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({ can_edit_rewards: true });
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  test('grant lacks can_edit_rewards → permission-denied', async () => {
    await seedActiveGrant({}); // permission absent — verifyTutorGrant checks !== true
    await expectHttpsError(
      call(fns.tutorUpdateGamificationSettings, goodArgs),
      'permission-denied',
    );
  });

  test('happy path (can_edit_rewards) → merges settings + writes one audit entry', async () => {
    await seedActiveGrant({ can_edit_rewards: true });

    const res = await call(fns.tutorUpdateGamificationSettings, goodArgs);

    assert.equal(res.success, true);

    const settingsSnap = await profileRef()
      .collection('preferences')
      .doc('gamification_settings')
      .get();
    assert.equal(settingsSnap.exists, true, 'gamification_settings doc should exist');
    assert.equal(settingsSnap.data().rewards_enabled, true);

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });

  test('happy path (can_edit_points) → accepted', async () => {
    await seedActiveGrant({ can_edit_points: true });

    const res = await call(fns.tutorUpdateGamificationSettings, {
      ...goodArgs,
      permKey: 'can_edit_points',
      settingsData: { points_per_session: 5 },
    });

    assert.equal(res.success, true);
  });
});

// ── tutorEditProfile ──────────────────────────────────────────────────────────
describe('tutorEditProfile', () => {
  const goodArgs = {
    grantId: GRANT,
    ownerUid: PARENT,
    profileId: PROFILE,
    displayName: 'Yosef',
  };

  beforeEach(async () => {
    await clearFirestore();
  });

  test('unauthenticated caller → unauthenticated', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, goodArgs, null),
      'unauthenticated',
    );
  });

  test('missing/blank grantId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, grantId: '' }),
      'invalid-argument',
    );
  });

  test('missing/blank ownerUid → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, ownerUid: '' }),
      'invalid-argument',
    );
  });

  test('non-integer profileId → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, profileId: 1.5 }),
      'invalid-argument',
    );
  });

  test('no editable field supplied → invalid-argument', async () => {
    // none of displayName/avatar/mode provided
    await expectHttpsError(
      call(fns.tutorEditProfile, {
        grantId: GRANT,
        ownerUid: PARENT,
        profileId: PROFILE,
      }),
      'invalid-argument',
    );
  });

  test('displayName is empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, displayName: '   ' }),
      'invalid-argument',
    );
  });

  test('displayName exceeds 100 chars → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, { ...goodArgs, displayName: 'a'.repeat(101) }),
      'invalid-argument',
    );
  });

  test('avatar is empty string → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, {
        grantId: GRANT,
        ownerUid: PARENT,
        profileId: PROFILE,
        avatar: '',
      }),
      'invalid-argument',
    );
  });

  test('mode is invalid value → invalid-argument', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, {
        grantId: GRANT,
        ownerUid: PARENT,
        profileId: PROFILE,
        mode: 'parent',
      }),
      'invalid-argument',
    );
  });

  test('grant does not exist → not-found', async () => {
    await expectHttpsError(
      call(fns.tutorEditProfile, goodArgs),
      'not-found',
    );
  });

  test('grant not active → permission-denied', async () => {
    await seedActiveGrant({}, { state: 'revoked_by_parent' });
    await expectHttpsError(
      call(fns.tutorEditProfile, goodArgs),
      'permission-denied',
    );
  });

  test('caller is not the grant tutor → permission-denied', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorEditProfile, goodArgs, strangerAuth),
      'permission-denied',
    );
  });

  // tutorEditProfile passes permKey=null to verifyTutorGrant — no specific
  // permission is required; any active grant is sufficient.

  test('happy path (displayName) → updates profile doc + writes one audit entry', async () => {
    await seedActiveGrant({});
    // Seed the profile doc so it exists before the edit.
    await profileRef().set({ display_name: 'Old Name', mode: 'child', avatar: 'av1' });

    const res = await call(fns.tutorEditProfile, goodArgs);

    assert.equal(res.success, true);

    const profileSnap = await profileRef().get();
    assert.equal(profileSnap.exists, true, 'profile doc should exist');
    assert.equal(profileSnap.data().display_name, 'Yosef');

    const audit = await db
      .collection('tutor_grants')
      .doc(GRANT)
      .collection('audit_log')
      .get();
    assert.equal(audit.size, 1, 'exactly one audit-log entry');
  });

  test('happy path (mode=adult) → updates mode field', async () => {
    await seedActiveGrant({});
    await profileRef().set({ display_name: 'Yosef', mode: 'child', avatar: 'av1' });

    const res = await call(fns.tutorEditProfile, {
      grantId: GRANT,
      ownerUid: PARENT,
      profileId: PROFILE,
      mode: 'adult',
    });

    assert.equal(res.success, true);
    const snap = await profileRef().get();
    assert.equal(snap.data().mode, 'adult');
  });

  // AUD-firebase-11: tutorEditProfile reads the full profile doc, merges the
  // edit fields in application memory, then does a full-document
  // set(merge:false). If a concurrent writer (the owner's own device, or a
  // second tutor) changes an unrelated field on the SAME doc between the
  // read and the write, that field must not be silently lost. We prove this
  // by injecting a real concurrent (non-transactional) write immediately
  // after the FIRST `get()` the CF issues against the profile doc — whether
  // that is a plain DocumentReference.get() (pre-fix) or a
  // Transaction.get() (post-fix, which Firestore auto-retries on conflict).
  //
  // The injected write is fired WITHOUT being awaited inside the hook: the
  // emulator holds a per-document lock for the lifetime of an open
  // transaction, so awaiting a competing non-transactional write from
  // inside that transaction's own get() deadlocks (the write can't land
  // until the transaction ends, but the transaction is stuck awaiting the
  // write). Firing it and yielding one microtask tick is enough to let it
  // reach the emulator well before the CF's own commit.
  test('AUD-firebase-11: concurrent write to an unrelated field between read and write survives', async () => {
    await seedActiveGrant({});
    const ref = profileRef();
    await ref.set({ display_name: 'Old Name', mode: 'child', extra_field: 'original' });

    const originalDocGet = admin.firestore.DocumentReference.prototype.get;
    const originalTxnGet = admin.firestore.Transaction.prototype.get;
    let injected = false;
    let concurrentWriteDone = Promise.resolve();
    const fireConcurrentWrite = () => {
      if (injected) return;
      injected = true;
      // A genuinely concurrent, non-transactional writer (e.g. the owner's
      // own device syncing) touching an UNRELATED field on the same doc.
      concurrentWriteDone = ref.set({ extra_field: 'concurrent-write' }, { merge: true });
    };
    admin.firestore.DocumentReference.prototype.get = async function (...args) {
      const result = await originalDocGet.apply(this, args);
      if (this.path === ref.path) {
        fireConcurrentWrite();
        await concurrentWriteDone; // no open transaction here — safe to await
      }
      return result;
    };
    admin.firestore.Transaction.prototype.get = async function (docRef, ...rest) {
      const result = await originalTxnGet.call(this, docRef, ...rest);
      if (docRef?.path === ref.path) {
        fireConcurrentWrite(); // NOT awaited — would deadlock the open transaction
        await Promise.resolve(); // yield one microtask tick so the request is sent
      }
      return result;
    };

    try {
      const res = await call(fns.tutorEditProfile, {
        grantId: GRANT,
        ownerUid: PARENT,
        profileId: PROFILE,
        displayName: 'New Name',
      });
      assert.equal(res.success, true);
    } finally {
      admin.firestore.DocumentReference.prototype.get = originalDocGet;
      admin.firestore.Transaction.prototype.get = originalTxnGet;
    }

    await concurrentWriteDone;
    assert.equal(injected, true, 'test setup sanity: the injection hook must have fired');

    const after = (await ref.get()).data();
    assert.equal(
      after.extra_field,
      'concurrent-write',
      'the concurrent writer\'s field must survive tutorEditProfile\'s read-then-write',
    );
    assert.equal(after.display_name, 'New Name', 'tutorEditProfile\'s own edit must also land');
  });

  // Repair round 1 (codex HIGH): the grant check and the profile update run in
  // ONE transaction, so a revocation racing the edit is fail-closed: either
  // the edit is denied, or it committed no later than the revocation. A
  // standalone grant read followed by a separate update (the old shape) lets
  // the edit land AFTER the revocation — the DocumentReference.get hook below
  // revokes right after such a read and waits for it, which reproduces that.
  test('revocation racing a profile edit: the edit never commits after the revocation', async () => {
    await seedActiveGrant({});
    const ref = profileRef();
    await ref.set({ display_name: 'Old Name', mode: 'child' });
    const grantRef = db.collection('tutor_grants').doc(GRANT);

    const originalDocGet = admin.firestore.DocumentReference.prototype.get;
    const originalTxnGet = admin.firestore.Transaction.prototype.get;
    let injected = false;
    let revokeDone = Promise.resolve(null);
    const fireRevoke = () => {
      if (injected) return;
      injected = true;
      revokeDone = grantRef.update({ state: 'revoked_by_parent' });
    };
    admin.firestore.DocumentReference.prototype.get = async function (...args) {
      const result = await originalDocGet.apply(this, args);
      if (this.path === grantRef.path) {
        fireRevoke();
        await revokeDone; // no open transaction here — safe to await
      }
      return result;
    };
    admin.firestore.Transaction.prototype.get = async function (docRef, ...rest) {
      const result = await originalTxnGet.call(this, docRef, ...rest);
      if (docRef?.path === grantRef.path) {
        fireRevoke(); // NOT awaited — would deadlock the open transaction
        await Promise.resolve();
      }
      return result;
    };

    let outcome;
    try {
      outcome = await call(fns.tutorEditProfile, {
        grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, displayName: 'New Name',
      }).then((r) => ({ ok: r }), (e) => ({ err: e }));
    } finally {
      admin.firestore.DocumentReference.prototype.get = originalDocGet;
      admin.firestore.Transaction.prototype.get = originalTxnGet;
    }
    const revokeResult = await revokeDone;
    assert.equal(injected, true, 'test setup sanity: the revocation must have been injected');

    const profile = await ref.get();
    if (outcome.err) {
      assert.equal(outcome.err.code, 'permission-denied');
      assert.equal(profile.get('display_name'), 'Old Name', 'a denied edit writes nothing');
    } else {
      assert.equal(profile.get('display_name'), 'New Name');
      assert.ok(
        profile.updateTime.toMillis() <= revokeResult.writeTime.toMillis(),
        'an edit that succeeded must have committed no later than the revocation',
      );
    }
    assert.equal((await grantRef.get()).get('state'), 'revoked_by_parent');
  });

  test('a revoked grant denies the profile edit and writes nothing', async () => {
    await seedActiveGrant({}, { state: 'revoked_by_parent' });
    const ref = profileRef();
    await ref.set({ display_name: 'Old Name' });
    await expectHttpsError(
      call(fns.tutorEditProfile, { grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, displayName: 'X' }),
      'permission-denied',
    );
    assert.equal((await ref.get()).get('display_name'), 'Old Name');
  });

  // ── Story 1.10 / DNI-472 AC-4: restricted three-field merge ────────────────

  test('AC-4: writes only display_name, avatar and mode as a field-level merge', async () => {
    await seedActiveGrant({});
    const ref = profileRef();
    await ref.set({
      display_name: 'Old Name', avatar: 'av1', mode: 'child',
      time_zone: 'Asia/Jerusalem', latitude: 31.7, last_change_id: '01JTEST0000000000000000000',
      unrelated: 'keep',
    });
    const res = await call(fns.tutorEditProfile, {
      grantId: GRANT, ownerUid: PARENT, profileId: PROFILE,
      displayName: '  Yosef  ', avatar: 'av2', mode: 'adult',
    });
    assert.equal(res.success, true);
    const doc = (await ref.get()).data();
    assert.deepEqual(doc, {
      display_name: 'Yosef', avatar: 'av2', mode: 'adult',
      time_zone: 'Asia/Jerusalem', latitude: 31.7, last_change_id: '01JTEST0000000000000000000',
      unrelated: 'keep',
    }, 'no other field (not even updated_at) is written or removed');
    const log = await ref.collection('change_log').get();
    assert.equal(log.size, 0, 'profile display fields are not a governed entity');
  });

  for (const extra of [
    { display_name: 'Sneaky' },
    { time_zone: 'America/New_York' },
    { in_israel: false },
    { last_change_id: '01JTEST0000000000000000009' },
    { updated_at: '2026-01-01' },
  ]) {
    test(`AC-4: extra/governed request field ${Object.keys(extra)[0]} → invalid-argument, nothing written`, async () => {
      await seedActiveGrant({});
      await profileRef().set({ display_name: 'Old Name', time_zone: 'Asia/Jerusalem' });
      await expectHttpsError(
        call(fns.tutorEditProfile, {
          grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, displayName: 'New', ...extra,
        }),
        'invalid-argument',
      );
      assert.deepEqual((await profileRef().get()).data(), {
        display_name: 'Old Name', time_zone: 'Asia/Jerusalem',
      });
    });
  }

  test('AC-4: a missing profile → not-found (the merge never conjures a partial profile)', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.tutorEditProfile, { grantId: GRANT, ownerUid: PARENT, profileId: PROFILE, mode: 'adult' }),
      'not-found',
    );
    assert.equal((await profileRef().get()).exists, false);
  });
});
