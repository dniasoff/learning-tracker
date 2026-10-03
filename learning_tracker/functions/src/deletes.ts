import * as admin from "firebase-admin";
import { auth, logger } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { db, CALL_OPTS, buildAccessId } from "./shared";
import {
  isDocIdSafe,
  removeTrackPlan,
  removeTrackPlanKey,
  runGoverned,
  writeWithChangeLog,
} from "./write_with_change_log";

// ══════════════════════════════════════════════════════════════════════════════
// Account & learner-data deletion
// ══════════════════════════════════════════════════════════════════════════════
//
// onUserDeleted cascades Firestore cleanup when a Firebase Auth account is
// removed. The callables below let a signed-in client delete its own data
// (one learner profile or the whole account) ahead of the Auth-account
// deletion that ultimately triggers the cascade. deleteCurriculumTrack is no
// longer a delete: it tombstones the track through writeWithChangeLog (AD-38).

/**
 * Triggered when a Firebase Auth user is deleted.
 *
 * Cascades two sets of operations:
 *
 *   1. USER DATA: Deletes all Firestore data under `users/{uid}` using
 *      Admin SDK recursiveDelete (existing behaviour).
 *
 *   2. W6.23 — PARENT GRANTS: If the user was a parent, all active/pending
 *      tutor grants they issued are revoked. Child profiles are already
 *      deleted by step 1 (under `users/{uid}/learner_profiles/`).
 *
 *   3. W6.24 — TUTOR GRANTS: If the user was a tutor, all active grants
 *      where they are the tutor are transitioned to `revoked_by_tutor` with
 *      a sentinel note that the account was deleted. The tutor_name_snapshot
 *      on audit log entries is preserved (already captured at write-time —
 *      no action needed here).
 */
export const onUserDeleted = auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const now = admin.firestore.Timestamp.now();
  logger.info(`onUserDeleted: starting cascade for uid=${uid}`);

  // ── Step 1: Delete all user data ──────────────────────────────────────────
  await db.recursiveDelete(db.collection("users").doc(uid));
  logger.info(`onUserDeleted: user data deleted for uid=${uid}`);

  // ── Step 2 (W6.23): Revoke all grants where this user is the parent ────────
  const parentGrantsSnap = await db
    .collection("tutor_grants")
    .where("parent_uid", "==", uid)
    .where("state", "in", ["pending", "active"])
    .get();

  const parentGrantBatch = db.batch();
  for (const grantDoc of parentGrantsSnap.docs) {
    parentGrantBatch.update(grantDoc.ref, {
      state: "revoked_by_parent",
      revoked_at: now,
      updated_at: now,
      _delete_cascade: true, // sentinel: revoked because parent account deleted
    });
    // AUD-firebase-06: mirror Step 3 — hasActiveTutorAccess() in
    // firestore.rules grants a tutor read access purely by the existence of
    // a tutor_active_access doc, so every code path that ends an active
    // grant must also delete it. Only an 'active' grant ever had one
    // written (by acceptTutorInvite); a still-'pending' grant has
    // tutor_uid == null and no access doc — the delete is a safe no-op in
    // that case regardless, but skip building a nonsense doc-id for it.
    const grant = grantDoc.data();
    if (grant.tutor_uid) {
      const accessId = buildAccessId(
        String(grant.tutor_uid),
        uid,
        String(grant.child_profile_id ?? "")
      );
      parentGrantBatch.delete(db.collection("tutor_active_access").doc(accessId));
    }
  }
  if (parentGrantsSnap.size > 0) {
    await parentGrantBatch.commit();
    logger.info(
      `onUserDeleted: revoked ${parentGrantsSnap.size} parent grants for uid=${uid}`
    );
  }

  // ── Step 3 (W6.24): Resign all grants where this user is the tutor ─────────
  // The tutor_name_snapshot on existing audit entries is already captured at
  // write-time and persists independently (FR-7.2 requirement satisfied).
  const tutorGrantsSnap = await db
    .collection("tutor_grants")
    .where("tutor_uid", "==", uid)
    .where("state", "==", "active")
    .get();

  const tutorGrantBatch = db.batch();
  for (const grantDoc of tutorGrantsSnap.docs) {
    tutorGrantBatch.update(grantDoc.ref, {
      state: "revoked_by_tutor",
      revoked_at: now,
      updated_at: now,
      _delete_cascade: true, // sentinel: resigned because tutor account deleted
    });
    // V2-R3 C2: also delete the tutor_active_access lookup doc so the
    // tutor immediately loses subcollection read access.
    const grant = grantDoc.data();
    const accessId = buildAccessId(
      uid,
      String(grant.parent_uid ?? ""),
      String(grant.child_profile_id ?? "")
    );
    tutorGrantBatch.delete(db.collection("tutor_active_access").doc(accessId));
  }
  if (tutorGrantsSnap.size > 0) {
    await tutorGrantBatch.commit();
    logger.info(
      `onUserDeleted: resigned ${tutorGrantsSnap.size} tutor grants for uid=${uid}`
    );
  }

  logger.info(`onUserDeleted: cascade complete for uid=${uid}`);
});

/**
 * Callable: delete a single learner profile and all its subcollections.
 *
 * Uses Admin SDK recursiveDelete so the client never needs to enumerate or
 * read subcollection documents — zero client reads, one server-side call.
 *
 * Expects: { profileId: string } (ULID)
 * Returns: { success: true }
 */
export const deleteLearnerProfile = onCall(CALL_OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const profileId = request.data?.profileId;
  if (typeof profileId !== "string" || !profileId) {
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  }

  const profileRef = db
    .collection("users")
    .doc(uid)
    .collection("learner_profiles")
    .doc(profileId);

  logger.info(`deleteLearnerProfile: uid=${uid} profileId=${profileId}`);
  await db.recursiveDelete(profileRef);
  logger.info(`deleteLearnerProfile: complete uid=${uid} profileId=${profileId}`);

  return { success: true };
});

/**
 * Callable: remove a curriculum track (the AD-38 "remove track" action).
 *
 * Sub-tracks AD-38 / Story 1.10 (DNI-472): this no longer hard-deletes
 * anything. It writes, through `writeWithChangeLog` in one transaction:
 *   - one `mainTrack` change_log entry setting `ended_at` on the
 *     curriculum_tracks/{curriculumId} doc only, and
 *   - one `subTrack` tombstone entry (`ended_at`, `end_reason =
 *     track_deleted`) per non-ended sub-track of that curriculum,
 * all sharing one `action_id`. While the track has `ended_at`, every reader
 * treats its other governed docs (goals, stages, study days, scopes, order,
 * program) as ended, so none of them is touched — "re-add" clears the
 * track's `ended_at` and keeps the prior config. learning_events,
 * points_ledger and every other history collection are never touched.
 *
 * Owner-only: the profile path is the caller's own `users/{auth.uid}/…`.
 *
 * Expects: { profileId: string, curriculumId: string, actionId?: ULID,
 *            actorRole?: 'parent' | 'child' }
 *   `actionId` is the client ULID; a retry with the same id returns the
 *   stored result. Omitted → server-generated.
 * Returns: { success: true, action_id, change_ids, at, ... } — `noop: true`
 *   when the track is absent or already ended (idempotent).
 */
export const deleteCurriculumTrack = onCall(CALL_OPTS, (request) => runGoverned("mainTrack", async () => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { profileId, curriculumId, actionId, actorRole } = request.data ?? {};
  if (typeof profileId !== "string" || !profileId) {
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  }
  if (!isDocIdSafe(curriculumId)) {
    throw new HttpsError("invalid-argument", "curriculumId must be a non-empty string");
  }

  return writeWithChangeLog(request.auth, {
    ownerUid: request.auth.uid,
    profileId,
    actorRole,
    actionId,
    callerPolicy: "owner-only",
    plan: removeTrackPlan(curriculumId),
    planKey: removeTrackPlanKey(curriculumId),
  });
}));

/**
 * Callable: delete all Firestore data for the authenticated user.
 *
 * Call this before deleting the Firebase Auth account. The `onUserDeleted`
 * trigger also runs after Auth deletion as a safety net, but by then the
 * data is already gone (no-op).
 *
 * Expects: {} (identity comes from request.auth.uid)
 * Returns: { success: true }
 */
export const deleteAccountData = onCall(CALL_OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

  const userDocRef = db.collection("users").doc(uid);
  logger.info(`deleteAccountData: starting for uid=${uid}`);
  await db.recursiveDelete(userDocRef);
  logger.info(`deleteAccountData: complete for uid=${uid}`);
  return { success: true };
});
