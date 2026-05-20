import * as admin from "firebase-admin";
import { auth, logger, pubsub } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();
const db = admin.firestore();


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
 * Expects: { profileId: number }
 * Returns: { success: true }
 */
export const deleteLearnerProfile = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const profileId = request.data?.profileId;
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0) {
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  }

  const profileRef = db
    .collection("users")
    .doc(uid)
    .collection("learner_profiles")
    .doc(String(profileId));

  logger.info(`deleteLearnerProfile: uid=${uid} profileId=${profileId}`);
  await db.recursiveDelete(profileRef);
  logger.info(`deleteLearnerProfile: complete uid=${uid} profileId=${profileId}`);

  return { success: true };
});

/**
 * Callable: delete a single curriculum track document from Firestore.
 *
 * H2 fix (V3-W1): W3.22 removed trackType from curriculum_tracks; the doc-id
 * is now just curriculumId (matching the client pushTrack fix in H1).
 * The trackType parameter is no longer required or accepted.
 *
 * Expects: { profileId: number, curriculumId: string }
 * Returns: { success: true }
 */
export const deleteCurriculumTrack = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { profileId, curriculumId } = request.data ?? {};
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0) {
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  }
  if (typeof curriculumId !== "string" || !curriculumId) {
    throw new HttpsError("invalid-argument", "curriculumId must be a non-empty string");
  }

  // H1/H2 fix: doc-id = curriculumId only (W3.22 removed trackType).
  const docId = curriculumId;
  const trackRef = db
    .collection("users").doc(uid)
    .collection("learner_profiles").doc(String(profileId))
    .collection("curriculum_tracks").doc(docId);

  await trackRef.delete();
  logger.info(`deleteCurriculumTrack: uid=${uid} profileId=${profileId} doc=${docId}`);
  return { success: true };
});

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
export const deleteAccountData = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

  const userDocRef = db.collection("users").doc(uid);
  logger.info(`deleteAccountData: starting for uid=${uid}`);
  await db.recursiveDelete(userDocRef);
  logger.info(`deleteAccountData: complete for uid=${uid}`);
  return { success: true };
});

// ══════════════════════════════════════════════════════════════════════════════
// W3.42 — Tutor audit-log purge (scheduled, 12-month retention)
// ══════════════════════════════════════════════════════════════════════════════
//
// Scheduled: daily at 02:00 UTC.
//
// Retention policy (from tutor-mode-brief.md §W3.42):
//   Audit log entries are retained for 12 months after the grant's terminal
//   event (revoked_at or declined_at). After that window they are purged.
//
// Algorithm:
//   1. Query tutor_grants where state ∈ {declined, rescinded, revoked_by_parent,
//      revoked_by_tutor, expired} AND revoked_at/declined_at ≤ cutoff.
//   2. For each matching grant, recursively delete the audit_log sub-collection.
//   3. The grant document itself is NOT deleted (audit trail of the relationship).
//
// Uses a Firestore batch for audit_log entries; recursive delete for safety.
// Runs in pages of 100 grants to stay within memory limits.

const AUDIT_LOG_RETENTION_MONTHS = 12;
const PURGE_BATCH_SIZE = 100;

/** Terminal grant states whose audit logs are eligible for retention purge. */
const TERMINAL_STATES = [
  "declined",
  "rescinded",
  "revoked_by_parent",
  "revoked_by_tutor",
  "expired",
];

export const purgeExpiredAuditLogs = pubsub
  .schedule("0 2 * * *") // daily at 02:00 UTC
  .timeZone("UTC")
  .onRun(async (_context) => {
    const cutoff = new Date();
    cutoff.setMonth(cutoff.getMonth() - AUDIT_LOG_RETENTION_MONTHS);
    const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

    logger.info(
      `purgeExpiredAuditLogs: running purge for grants terminated before ${cutoff.toISOString()}`
    );

    let totalGrantsProcessed = 0;
    let totalEntriesPurged = 0;

    for (const state of TERMINAL_STATES) {
      // Query grants in this terminal state whose revoked_at/declined_at
      // field predates the cutoff. We query on `updated_at` as the canonical
      // "last state change" timestamp, which is set on every state transition.
      // This avoids needing a separate composite index per terminal-event field.
      const snapshot = await db
        .collection("tutor_grants")
        .where("state", "==", state)
        .where("updated_at", "<=", cutoffTs)
        .limit(PURGE_BATCH_SIZE)
        .get();

      for (const grantDoc of snapshot.docs) {
        const grantId = grantDoc.id;
        const auditLogRef = db
          .collection("tutor_grants")
          .doc(grantId)
          .collection("audit_log");

        // Delete all audit_log entries for this grant.
        // Using recursiveDelete rather than manual batching — simpler and
        // handles large audit logs without memory pressure.
        await db.recursiveDelete(auditLogRef);

        totalEntriesPurged++;
        totalGrantsProcessed++;

        logger.info(
          `purgeExpiredAuditLogs: purged audit_log for grant=${grantId} state=${state}`
        );
      }
    }

    logger.info(
      `purgeExpiredAuditLogs: complete — grants=${totalGrantsProcessed} ` +
        `entries-batches=${totalEntriesPurged}`
    );
  });

// ══════════════════════════════════════════════════════════════════════════════
// W3.43 — Tutor bulk-prior completion write proxy
// ══════════════════════════════════════════════════════════════════════════════
//
// SECURITY: This is the ONLY path through which a tutor can write completions
// for a learner profile they are tutoring. It uses Admin SDK, which bypasses
// client-facing Firestore Security Rules.
//
// The Cloud Function enforces:
//   1. Caller (request.auth.uid) has an active grant for the target profile.
//   2. The grant's canBulkPriorCompletion permission is true (TutorPermissions).
//   3. NONE of the submitted completions is a live-forward completion:
//      completed_at MUST be strictly before today's UTC midnight (bulk-prior only).
//      Any attempt to write a live completion is rejected entirely.
//   4. The grant's parent_uid matches the ownerUid in the request.
//
// Writes are performed as the owner uid (parentUid stored in the grant doc)
// via Admin SDK — the completion docs are indistinguishable from owner-written
// completions by the Firestore rules, which is correct and intentional.
//
// Expects:
//   {
//     grantId: string,                  // the active tutor grant doc ID
//     ownerUid: string,                 // parent/owner uid (sanity check)
//     profileId: number,                // learner profile ID (integer)
//     completions: Array<{              // 1-500 completion payloads
//       completionId: string,           // ULID — must be globally unique
//       curriculumId: string,
//       sefariaRef: string,
//       stageId: number,
//       trackType: string,
//       completedAt: string,            // ISO-8601 UTC — MUST be in the past
//       points: number,                 // 0..100
//     }>
//   }
//
// Returns: { success: true, written: number }
// Throws: HttpsError on any validation failure.

const MAX_BULK_COMPLETIONS = 500;

interface CompletionPayload {
  completionId: string;
  curriculumId: string;
  sefariaRef: string;
  stageId: number;
  trackType: string;
  completedAt: string; // ISO-8601 UTC
  points: number;
}

export const tutorBulkPriorCompletions = onCall(async (request) => {
  // ── 1. Authentication check ────────────────────────────────────────────
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  // ── 2. Input validation ────────────────────────────────────────────────
  const { grantId, ownerUid, profileId, completions } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }
  if (typeof ownerUid !== "string" || !ownerUid) {
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  }
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0) {
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  }
  if (!Array.isArray(completions) || completions.length === 0) {
    throw new HttpsError("invalid-argument", "completions must be a non-empty array");
  }
  if (completions.length > MAX_BULK_COMPLETIONS) {
    throw new HttpsError(
      "invalid-argument",
      `completions array exceeds max size of ${MAX_BULK_COMPLETIONS}`
    );
  }

  // ── 3. Grant verification ──────────────────────────────────────────────
  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();

  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  // Verify grant is active.
  if (grant.state !== "active") {
    throw new HttpsError(
      "permission-denied",
      `Grant ${grantId} is not active (state=${grant.state})`
    );
  }

  // Verify caller is the tutor on this grant.
  if (grant.tutor_uid !== callerUid) {
    throw new HttpsError(
      "permission-denied",
      "Grant tutor_uid does not match caller uid"
    );
  }

  // Verify ownerUid matches the grant's parent_uid (caller sanity check).
  if (grant.parent_uid !== ownerUid) {
    throw new HttpsError(
      "permission-denied",
      "Grant parent_uid does not match supplied ownerUid"
    );
  }

  // Verify the profile ID matches the grant's child_profile_id.
  if (String(grant.child_profile_id) !== String(profileId)) {
    throw new HttpsError(
      "permission-denied",
      "Grant child_profile_id does not match supplied profileId"
    );
  }

  // ── 4. Permission check: canBulkPriorCompletion ────────────────────────
  // The TutorPermissions model (W4.28) stores permissions as a nested map
  // in the grant document. Default: tutor can mark bulk-prior completions
  // unless explicitly disabled by the parent.
  const permissions = grant.permissions ?? {};
  const canBulkPrior = permissions.can_bulk_prior_completion !== false; // default true
  if (!canBulkPrior) {
    throw new HttpsError(
      "permission-denied",
      "This tutor does not have bulk-prior completion permission for this grant"
    );
  }

  // ── 5. Enforce bulk-prior only — no live-forward completions ─────────────
  // LOAD-BEARING SECURITY CHECK: completedAt MUST be strictly in the past.
  // "Past" means before today's UTC midnight. This is the Cloud Function
  // enforcement of the canMarkLiveCompletion=false policy (W4.34).
  // Even one live completion in the batch rejects the entire request.
  const todayUtcMidnight = new Date();
  todayUtcMidnight.setUTCHours(0, 0, 0, 0);

  for (const completion of completions as CompletionPayload[]) {
    const completedAt = new Date(completion.completedAt);
    if (isNaN(completedAt.getTime())) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid completedAt timestamp: ${completion.completedAt}`
      );
    }
    if (completedAt >= todayUtcMidnight) {
      // Tutor attempted a live or future-dated completion — hard reject.
      throw new HttpsError(
        "permission-denied",
        `Tutors cannot write live-forward completions. ` +
          `completedAt=${completion.completedAt} is not before today's UTC midnight. ` +
          `Use the standard completion flow for today's learning.`
      );
    }
    // Validate points range.
    if (
      typeof completion.points !== "number" ||
      completion.points < 0 ||
      completion.points > 100
    ) {
      throw new HttpsError(
        "invalid-argument",
        `points must be 0..100; got ${completion.points}`
      );
    }
    // Validate required string fields.
    for (const field of ["completionId", "curriculumId", "sefariaRef", "trackType"] as const) {
      if (typeof completion[field] !== "string" || !completion[field]) {
        throw new HttpsError("invalid-argument", `${field} must be a non-empty string`);
      }
    }
    if (typeof completion.stageId !== "number" || !Number.isInteger(completion.stageId)) {
      throw new HttpsError("invalid-argument", "stageId must be an integer");
    }
  }

  // ── 6. Write completions as the owner (Admin SDK) ─────────────────────
  // All writes are batched. Each completion document is written to the owner's
  // profile subcollection, indistinguishable from an owner-written completion.
  // The tutor_uid is stored as `created_by_tutor_uid` for audit purposes.
  const profilePath = db
    .collection("users")
    .doc(ownerUid)
    .collection("learner_profiles")
    .doc(String(profileId));

  // Firestore max batch size is 500 — we already validated the input cap.
  const batch = db.batch();
  const writtenAt = admin.firestore.Timestamp.now();

  for (const completion of completions as CompletionPayload[]) {
    const completionRef = profilePath
      .collection("completions")
      .doc(completion.completionId);

    batch.set(completionRef, {
      completion_id: completion.completionId,
      curriculum_id: completion.curriculumId,
      sefaria_ref: completion.sefariaRef,
      stage_id: completion.stageId,
      track_type: completion.trackType,
      completed_at: admin.firestore.Timestamp.fromDate(new Date(completion.completedAt)),
      points: completion.points,
      // Provenance — identifies this as a tutor-proxied write.
      created_by_tutor_uid: callerUid,
      grant_id: grantId,
      written_at: writtenAt,
    });
  }

  await batch.commit();

  // ── 7. Write audit log entry ───────────────────────────────────────────
  const auditRef = db
    .collection("tutor_grants")
    .doc(grantId)
    .collection("audit_log")
    .doc(); // auto-id

  await auditRef.set({
    tutor_uid: callerUid,
    tutor_name_snapshot: grant.tutor_name_snapshot ?? "",
    action: "completion_bulk_prior",
    target: `profile/${profileId}/completions`,
    after_value: JSON.stringify({ count: completions.length }),
    timestamp: writtenAt.toDate().toISOString(),
  });

  logger.info(
    `tutorBulkPriorCompletions: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} count=${completions.length}`
  );

  return { success: true, written: completions.length };
});
