// CF tests — background triggers: onUserDeleted (auth), purgeExpiredAuditLogs
// (pubsub.schedule), expirePendingInvites (pubsub.schedule).
// See _cf_helpers.mjs for the harness.

import assert from 'node:assert/strict';
import admin from 'firebase-admin';
import { beforeEach, describe, test } from 'node:test';
import {
  GRANT,
  PARENT,
  PROFILE,
  TUTOR,
  clearFirestore,
  db,
  fft,
  fns,
  seedActiveGrant,
} from './_cf_helpers.mjs';

// ── Helpers ────────────────────────────────────────────────────────────────────

/** Seed a tutor_grant doc with arbitrary fields. */
async function seedGrant(id, data) {
  await db.collection('tutor_grants').doc(id).set(data);
}

/** Seed an audit_log entry under a grant. */
async function seedAuditEntry(grantId, docId, data) {
  await db
    .collection('tutor_grants')
    .doc(grantId)
    .collection('audit_log')
    .doc(docId)
    .set(data);
}

/** Return the data of a tutor_grant doc (undefined if not found). */
async function getGrant(id) {
  const snap = await db.collection('tutor_grants').doc(id).get();
  return snap.exists ? snap.data() : undefined;
}

/** List all audit_log docs under a grant. */
async function listAuditLog(grantId) {
  const snap = await db
    .collection('tutor_grants')
    .doc(grantId)
    .collection('audit_log')
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/** Firestore Timestamp shifted by the given number of months (negative = past). */
function timestampShiftMonths(months) {
  const d = new Date();
  d.setMonth(d.getMonth() + months);
  return admin.firestore.Timestamp.fromDate(d);
}

/** Firestore Timestamp shifted by the given number of days (negative = past). */
function timestampShiftDays(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return admin.firestore.Timestamp.fromDate(d);
}

// ══════════════════════════════════════════════════════════════════════════════
// onUserDeleted
// ══════════════════════════════════════════════════════════════════════════════

describe('onUserDeleted', () => {
  // auth.user().onDelete handler — fft wraps it as WrappedFunction<UserRecord>.
  // Invoke: wrapped(userRecord, options?).  We use fft.auth.makeUserRecord.

  const wrappedOnUserDeleted = fft.wrap(fns.onUserDeleted);

  beforeEach(async () => {
    await clearFirestore();
  });

  // ── User-data deletion ───────────────────────────────────────────────────

  test('deletes user subtree under users/{uid}', async () => {
    // Seed some user data.
    const userRef = db.collection('users').doc(PARENT);
    await userRef.set({ displayName: 'Parent User' });
    await userRef
      .collection('learner_profiles')
      .doc(String(PROFILE))
      .set({ name: 'Child' });

    const userRecord = fft.auth.makeUserRecord({ uid: PARENT });
    await wrappedOnUserDeleted(userRecord);

    const userSnap = await userRef.get();
    assert.equal(userSnap.exists, false, 'users/{uid} doc should be deleted');

    const profileSnap = await userRef
      .collection('learner_profiles')
      .doc(String(PROFILE))
      .get();
    assert.equal(
      profileSnap.exists,
      false,
      'learner_profiles subcollection should be recursively deleted',
    );
  });

  // ── Step 2: parent grants revoked ───────────────────────────────────────

  test('W6.23: pending grant where deleted user is parent → revoked_by_parent', async () => {
    await seedGrant('g-pending', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'pending',
    });

    const userRecord = fft.auth.makeUserRecord({ uid: PARENT });
    await wrappedOnUserDeleted(userRecord);

    const data = await getGrant('g-pending');
    assert.equal(data.state, 'revoked_by_parent');
    assert.equal(data._delete_cascade, true, 'sentinel _delete_cascade should be set');
    assert.ok(data.revoked_at, 'revoked_at should be set');
    assert.ok(data.updated_at, 'updated_at should be set');
  });

  test('W6.23: active grant where deleted user is parent → revoked_by_parent', async () => {
    await seedGrant('g-active-parent', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'active',
    });

    const userRecord = fft.auth.makeUserRecord({ uid: PARENT });
    await wrappedOnUserDeleted(userRecord);

    const data = await getGrant('g-active-parent');
    assert.equal(data.state, 'revoked_by_parent');
  });

  test('W6.23: already-revoked grant is not touched (only pending/active are queried)', async () => {
    await seedGrant('g-already-revoked', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'revoked_by_tutor',
    });

    const userRecord = fft.auth.makeUserRecord({ uid: PARENT });
    await wrappedOnUserDeleted(userRecord);

    const data = await getGrant('g-already-revoked');
    assert.equal(data.state, 'revoked_by_tutor', 'terminal grants should not be modified');
  });

  // ── Step 3: tutor grants resigned + access doc deleted ──────────────────

  test('W6.24: active grant where deleted user is tutor → revoked_by_tutor', async () => {
    await seedGrant('g-tutor-active', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'active',
    });

    const userRecord = fft.auth.makeUserRecord({ uid: TUTOR });
    await wrappedOnUserDeleted(userRecord);

    const data = await getGrant('g-tutor-active');
    assert.equal(data.state, 'revoked_by_tutor');
    assert.equal(data._delete_cascade, true, 'sentinel _delete_cascade should be set');
    assert.ok(data.revoked_at, 'revoked_at should be set');
  });

  test('W6.24: tutor_active_access doc is deleted when tutor grant is resigned', async () => {
    // buildAccessId = `${tutorUid}_${parentUid}_${profileId}`
    const accessId = `${TUTOR}_${PARENT}_${PROFILE}`;
    await db.collection('tutor_active_access').doc(accessId).set({ ok: true });

    await seedGrant('g-tutor-access', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'active',
    });

    const userRecord = fft.auth.makeUserRecord({ uid: TUTOR });
    await wrappedOnUserDeleted(userRecord);

    const accessSnap = await db
      .collection('tutor_active_access')
      .doc(accessId)
      .get();
    assert.equal(
      accessSnap.exists,
      false,
      'tutor_active_access doc should be deleted',
    );
  });

  test('W6.24: pending tutor grant is NOT resigned (query is state==active only)', async () => {
    await seedGrant('g-tutor-pending', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'pending',
    });

    const userRecord = fft.auth.makeUserRecord({ uid: TUTOR });
    await wrappedOnUserDeleted(userRecord);

    const data = await getGrant('g-tutor-pending');
    // Step 3 only matches state == 'active'; pending grant should be untouched
    // (unless step 2 also fires, but TUTOR is tutor here, not parent).
    assert.equal(data.state, 'pending', 'pending tutor grant should not be resigned');
  });

  test('deleting a user with no grants does not throw', async () => {
    const userRecord = fft.auth.makeUserRecord({ uid: 'no-grants-uid' });
    // Should resolve without error.
    await wrappedOnUserDeleted(userRecord);
  });
});

// ══════════════════════════════════════════════════════════════════════════════
// purgeExpiredAuditLogs
// ══════════════════════════════════════════════════════════════════════════════

describe('purgeExpiredAuditLogs', () => {
  // Scheduled fn — WrappedScheduledFunction: invoke as wrapped() or wrapped({}).

  const wrappedPurge = fft.wrap(fns.purgeExpiredAuditLogs);

  beforeEach(async () => {
    await clearFirestore();
  });

  // Retention = 12 months. Cutoff = now - 12 months.
  // Grants with updated_at <= cutoff AND in a TERMINAL_STATE get their
  // audit_log subcollection recursively deleted.
  // The GRANT DOC ITSELF is preserved — only audit_log is deleted.

  const TERMINAL_STATES = [
    'declined',
    'rescinded',
    'revoked_by_parent',
    'revoked_by_tutor',
    'expired',
  ];

  test('audit_log of a terminal grant older than retention cutoff is deleted', async () => {
    const oldUpdatedAt = timestampShiftMonths(-13); // 13 months ago, past cutoff
    await seedGrant('g-old-revoked', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'revoked_by_parent',
      updated_at: oldUpdatedAt,
    });
    await seedAuditEntry('g-old-revoked', 'entry1', {
      action: 'invite_sent',
      timestamp: new Date().toISOString(),
    });
    await seedAuditEntry('g-old-revoked', 'entry2', {
      action: 'grant_accepted',
      timestamp: new Date().toISOString(),
    });

    await wrappedPurge();

    const auditEntries = await listAuditLog('g-old-revoked');
    assert.equal(auditEntries.length, 0, 'audit_log entries should be purged');

    // Grant doc itself must still exist (only audit_log is purged).
    const grantData = await getGrant('g-old-revoked');
    assert.ok(grantData, 'grant doc itself should NOT be deleted');
    assert.equal(grantData.state, 'revoked_by_parent', 'grant state unchanged');
  });

  test('audit_log of a terminal grant WITHIN retention window is preserved', async () => {
    const recentUpdatedAt = timestampShiftMonths(-11); // 11 months ago, within 12-month window
    await seedGrant('g-recent-revoked', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'revoked_by_parent',
      updated_at: recentUpdatedAt,
    });
    await seedAuditEntry('g-recent-revoked', 'entry1', {
      action: 'invite_sent',
      timestamp: new Date().toISOString(),
    });

    await wrappedPurge();

    const auditEntries = await listAuditLog('g-recent-revoked');
    assert.equal(auditEntries.length, 1, 'recent grant audit_log should be preserved');
  });

  test('purge covers all terminal states', async () => {
    // Each terminal state gets its own grant doc 13 months old.
    const oldUpdatedAt = timestampShiftMonths(-13);
    for (const state of TERMINAL_STATES) {
      const grantId = `g-purge-${state}`;
      await seedGrant(grantId, {
        parent_uid: PARENT,
        tutor_uid: TUTOR,
        child_profile_id: PROFILE,
        state,
        updated_at: oldUpdatedAt,
      });
      await seedAuditEntry(grantId, 'e1', { action: 'test', timestamp: new Date().toISOString() });
    }

    await wrappedPurge();

    for (const state of TERMINAL_STATES) {
      const grantId = `g-purge-${state}`;
      const entries = await listAuditLog(grantId);
      assert.equal(
        entries.length,
        0,
        `audit_log for ${state} grant should be purged`,
      );
    }
  });

  test('active grant older than cutoff is not touched (only terminal states queried)', async () => {
    const oldUpdatedAt = timestampShiftMonths(-13);
    await seedGrant('g-old-active', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'active',
      updated_at: oldUpdatedAt,
    });
    await seedAuditEntry('g-old-active', 'e1', {
      action: 'invite_sent',
      timestamp: new Date().toISOString(),
    });

    await wrappedPurge();

    const entries = await listAuditLog('g-old-active');
    assert.equal(entries.length, 1, 'active grant audit_log must not be purged');
  });

  test('no grants → runs without error', async () => {
    // Empty Firestore — should resolve cleanly.
    await wrappedPurge();
  });
});

// ══════════════════════════════════════════════════════════════════════════════
// expirePendingInvites
// ══════════════════════════════════════════════════════════════════════════════

describe('expirePendingInvites', () => {
  // Scheduled fn — WrappedScheduledFunction.

  const wrappedExpire = fft.wrap(fns.expirePendingInvites);

  beforeEach(async () => {
    await clearFirestore();
  });

  test('pending grant past expires_at → state becomes expired', async () => {
    const pastExpiresAt = timestampShiftDays(-1); // expired yesterday
    await seedGrant('g-expired-invite', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      tutor_email: 'tutor@example.com',
      child_profile_id: PROFILE,
      state: 'pending',
      expires_at: pastExpiresAt,
      invite_token: 'tok-abc',
    });

    await wrappedExpire();

    const data = await getGrant('g-expired-invite');
    assert.equal(data.state, 'expired', 'grant state should be expired');
    assert.ok(data.updated_at, 'updated_at should be set');
  });

  test('invite_token is deleted on expiry', async () => {
    const pastExpiresAt = timestampShiftDays(-1);
    await seedGrant('g-token-del', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      tutor_email: 'tutor@example.com',
      child_profile_id: PROFILE,
      state: 'pending',
      expires_at: pastExpiresAt,
      invite_token: 'secret-token',
    });

    await wrappedExpire();

    const data = await getGrant('g-token-del');
    assert.equal(
      data.invite_token,
      undefined,
      'invite_token field should be deleted',
    );
  });

  test('audit_log entry written for each expired invite', async () => {
    const pastExpiresAt = timestampShiftDays(-1);
    await seedGrant('g-audit', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      tutor_email: 'tutor@example.com',
      child_profile_id: PROFILE,
      state: 'pending',
      expires_at: pastExpiresAt,
      invite_token: 'tok',
    });

    await wrappedExpire();

    const entries = await listAuditLog('g-audit');
    assert.equal(entries.length, 1, 'exactly one audit_log entry should be written');
    const entry = entries[0];
    assert.equal(entry.action, 'invite_expired');
    assert.equal(entry.tutor_uid, null, 'tutor_uid should be null for system-generated entry');
    assert.equal(
      entry.tutor_name_snapshot,
      'tutor@example.com',
      'tutor_name_snapshot should carry tutor_email',
    );
    assert.equal(entry.target, 'grant/g-audit');
    assert.ok(entry.timestamp, 'timestamp should be set');
  });

  test('audit_log after_value contains JSON { state: "expired" }', async () => {
    const pastExpiresAt = timestampShiftDays(-2);
    await seedGrant('g-after-val', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      tutor_email: 'tutor@test.com',
      child_profile_id: PROFILE,
      state: 'pending',
      expires_at: pastExpiresAt,
      invite_token: 'tok2',
    });

    await wrappedExpire();

    const entries = await listAuditLog('g-after-val');
    assert.equal(entries.length, 1);
    const afterObj = JSON.parse(entries[0].after_value);
    assert.equal(afterObj.state, 'expired');
  });

  test('pending grant with future expires_at is NOT expired', async () => {
    const futureExpiresAt = timestampShiftDays(7); // expires in 7 days
    await seedGrant('g-future', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      tutor_email: 'tutor@example.com',
      child_profile_id: PROFILE,
      state: 'pending',
      expires_at: futureExpiresAt,
      invite_token: 'tok-future',
    });

    await wrappedExpire();

    const data = await getGrant('g-future');
    assert.equal(data.state, 'pending', 'future-expiry grant should remain pending');
    assert.equal(data.invite_token, 'tok-future', 'invite_token should be preserved');

    const entries = await listAuditLog('g-future');
    assert.equal(entries.length, 0, 'no audit_log entries for un-expired grant');
  });

  test('active grant (not pending) is not expired even if expires_at is past', async () => {
    const pastExpiresAt = timestampShiftDays(-1);
    await seedGrant('g-active-no-expire', {
      parent_uid: PARENT,
      tutor_uid: TUTOR,
      child_profile_id: PROFILE,
      state: 'active',
      expires_at: pastExpiresAt,
    });

    await wrappedExpire();

    const data = await getGrant('g-active-no-expire');
    assert.equal(data.state, 'active', 'active grants should not be expired');
  });

  test('multiple expired invites all transitioned in one run', async () => {
    const pastExpiresAt = timestampShiftDays(-1);
    for (let i = 0; i < 3; i++) {
      await seedGrant(`g-multi-${i}`, {
        parent_uid: PARENT,
        tutor_uid: TUTOR,
        tutor_email: `tutor${i}@example.com`,
        child_profile_id: PROFILE,
        state: 'pending',
        expires_at: pastExpiresAt,
        invite_token: `tok-${i}`,
      });
    }

    await wrappedExpire();

    for (let i = 0; i < 3; i++) {
      const data = await getGrant(`g-multi-${i}`);
      assert.equal(data.state, 'expired', `grant g-multi-${i} should be expired`);
      const entries = await listAuditLog(`g-multi-${i}`);
      assert.equal(entries.length, 1, `audit_log should have one entry for g-multi-${i}`);
    }
  });

  test('no pending expired invites → runs without error and writes nothing', async () => {
    // Only active grants in Firestore — function should short-circuit.
    await seedActiveGrant();

    await wrappedExpire();

    // The active grant should be unchanged.
    const data = await getGrant(GRANT);
    assert.equal(data.state, 'active');
  });
});
