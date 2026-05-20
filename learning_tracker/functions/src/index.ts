import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { auth, logger, pubsub } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();
const db = admin.firestore();

// ── Shared helpers ────────────────────────────────────────────────────────────

/** Encode an email for use in a Firestore doc ID (mirrors Dart TutorGrantDoc.buildGrantId). */
function encodeEmailForDocId(email: string): string {
  return email.toLowerCase().replace(/[^a-zA-Z0-9]/g, "_");
}

/** Build the tutor_active_access doc ID: {tutorUid}_{parentUid}_{profileId}. */
function buildAccessId(tutorUid: string, parentUid: string, profileId: string): string {
  return `${tutorUid}_${parentUid}_${profileId}`;
}

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

// ══════════════════════════════════════════════════════════════════════════════
// V2-R3 C3 — Tutor grant lifecycle Cloud Functions
// ══════════════════════════════════════════════════════════════════════════════
//
// All grant state mutations are server-side (Admin SDK) to prevent clients from
// forging active grants. The `tutor_active_access` secondary index is maintained
// alongside grant-state changes to enable O(1) subcollection read checks in
// Firestore Security Rules (V2-R3 C2).
//
// Doc-id formula for tutor_active_access: {tutorUid}_{parentUid}_{profileId}
// This mirrors the hasActiveTutorAccess() helper in firestore.rules.
//
// Grant doc-id formula: {encodedEmail}__{parentUid}__{childProfileId}
// The encoded email replaces any non-alphanumeric char with '_'.

// ── inviteTutor ───────────────────────────────────────────────────────────────
//
// Creates a pending grant document for a tutor invite.
//
// Expects:
//   {
//     tutorEmail: string,           // tutor's email address (lower-cased by CF)
//     childProfileId: string,       // profile ID (string) of the tutored child
//     permissions: object,          // TutorPermissions serialised map (optional)
//   }
//
// Returns: { success: true, grantId: string }

export const inviteTutor = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { tutorEmail, childProfileId, permissions } = request.data ?? {};

  if (typeof tutorEmail !== "string" || !tutorEmail.includes("@")) {
    throw new HttpsError("invalid-argument", "tutorEmail must be a valid email address");
  }
  if (typeof childProfileId !== "string" || !childProfileId) {
    throw new HttpsError("invalid-argument", "childProfileId must be a non-empty string");
  }

  const normalEmail = tutorEmail.trim().toLowerCase();
  const encodedEmail = encodeEmailForDocId(normalEmail);
  const grantId = `${encodedEmail}__${callerUid}__${childProfileId}`;
  const now = admin.firestore.Timestamp.now();
  const expiresAt = new Date(now.toDate().getTime() + 7 * 24 * 60 * 60 * 1000);

  // Generate a 256-bit random invite token (NFR-3).
  const inviteToken = crypto.randomBytes(32).toString("hex");

  const defaultPermissions = {
    can_view_progress: true,
    can_view_content: true,
    can_bulk_prior_completion: true,
    can_reset_completion: false,
    can_edit_goals: false,
    can_edit_stages: false,
    can_edit_rewards: false,
    can_edit_study_days: false,
  };

  const grantData = {
    grant_id: grantId,
    parent_uid: callerUid,
    child_profile_id: childProfileId,
    tutor_email: normalEmail,
    tutor_uid: null,
    state: "pending",
    invite_token: inviteToken,
    permissions: permissions ?? defaultPermissions,
    invited_at: now,
    updated_at: now,
    expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
  };

  await db.collection("tutor_grants").doc(grantId).set(grantData, { merge: false });

  logger.info(`inviteTutor: parent=${callerUid} grantId=${grantId} email=${normalEmail}`);
  return { success: true, grantId };
});

// ── acceptTutorInvite ─────────────────────────────────────────────────────────
//
// Tutor accepts a pending invite. Validates that:
//   1. The grant exists and is in pending state.
//   2. The grant has not expired (server-side, not relying on client state).
//   3. The caller's authenticated email matches grant.tutor_email.
//      (This is the security check that prevents anyone from claiming an invite
//       without owning the invited email address.)
//
// On success:
//   - Updates grant state to 'active', sets tutor_uid and accepted_at.
//   - Writes tutor_active_access/{tutorUid}_{parentUid}_{profileId}.
//   - Clears the invite_token (single-use, per NFR-3).
//   - Captures tutor_name_snapshot from Firebase Auth (fixes H3 from V2-R3).
//
// Expects: { grantId: string }
// Returns: { success: true, grantId: string }

export const acceptTutorInvite = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.state !== "pending") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not in pending state (state=${grant.state})`
    );
  }

  // Check expiry — server-side enforcement.
  if (grant.expires_at && grant.expires_at.toDate() < new Date()) {
    // Transition to expired while we're here (opportunistic).
    await grantRef.update({
      state: "expired",
      updated_at: admin.firestore.Timestamp.now(),
    });
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} has expired`
    );
  }

  // Security gate: caller's email MUST match the invited email.
  // This prevents anyone from claiming an invite not addressed to them.
  const callerRecord = await admin.auth().getUser(callerUid);
  const callerEmail = (callerRecord.email ?? "").toLowerCase().trim();
  const grantEmail = (grant.tutor_email ?? "").toLowerCase().trim();
  if (callerEmail !== grantEmail) {
    throw new HttpsError(
      "permission-denied",
      "Your account email does not match the invited tutor email"
    );
  }

  const now = admin.firestore.Timestamp.now();
  // Capture tutor display name for audit log snapshot (fixes H3).
  const tutorNameSnapshot = callerRecord.displayName ?? callerEmail;
  const profileId = String(grant.child_profile_id);
  const parentUid = String(grant.parent_uid);
  const accessId = buildAccessId(callerUid, parentUid, profileId);

  await db.runTransaction(async (txn) => {
    // 1. Update the grant document.
    txn.update(grantRef, {
      state: "active",
      tutor_uid: callerUid,
      tutor_name_snapshot: tutorNameSnapshot,
      accepted_at: now,
      updated_at: now,
      invite_token: admin.firestore.FieldValue.delete(), // single-use cleared
    });

    // 2. Write the tutor_active_access lookup document.
    const accessRef = db.collection("tutor_active_access").doc(accessId);
    txn.set(accessRef, {
      tutor_uid: callerUid,
      parent_uid: parentUid,
      child_profile_id: profileId,
      grant_id: grantId,
      created_at: now,
    });
  });

  // Write audit log entry (outside transaction — audit is best-effort).
  try {
    await db
      .collection("tutor_grants")
      .doc(grantId)
      .collection("audit_log")
      .add({
        tutor_uid: callerUid,
        tutor_name_snapshot: tutorNameSnapshot,
        action: "invite_accepted",
        target: `grant/${grantId}`,
        after_value: JSON.stringify({ state: "active" }),
        timestamp: now.toDate().toISOString(),
      });
  } catch (e) {
    logger.warn(`acceptTutorInvite: audit log write failed for grant=${grantId}`, e);
  }

  logger.info(`acceptTutorInvite: tutor=${callerUid} grantId=${grantId}`);
  return { success: true, grantId };
});

// ── declineTutorInvite ────────────────────────────────────────────────────────
//
// Tutor declines a pending invite. Validates caller email matches grant email.
//
// Expects: { grantId: string }
// Returns: { success: true }

export const declineTutorInvite = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  // Allow decline if pending OR if tutor_uid matches (already accepted but wants to resign via this path).
  // Primary path: caller email matches invited email.
  const callerRecord = await admin.auth().getUser(callerUid);
  const callerEmail = (callerRecord.email ?? "").toLowerCase().trim();
  const grantEmail = (grant.tutor_email ?? "").toLowerCase().trim();
  const isTutorByEmail = callerEmail === grantEmail;
  const isTutorByUid = grant.tutor_uid === callerUid;

  if (!isTutorByEmail && !isTutorByUid) {
    throw new HttpsError("permission-denied", "You are not the invited tutor for this grant");
  }

  if (grant.state !== "pending") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not in pending state (state=${grant.state})`
    );
  }

  const now = admin.firestore.Timestamp.now();
  await grantRef.update({
    state: "declined",
    declined_at: now,
    updated_at: now,
    invite_token: admin.firestore.FieldValue.delete(),
  });

  logger.info(`declineTutorInvite: tutor=${callerUid} grantId=${grantId}`);
  return { success: true };
});

// ── rescindTutorInvite ────────────────────────────────────────────────────────
//
// Parent rescinds a pending invite (before tutor has accepted).
//
// Expects: { grantId: string }
// Returns: { success: true }

export const rescindTutorInvite = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.parent_uid !== callerUid) {
    throw new HttpsError("permission-denied", "Only the parent can rescind an invite");
  }
  if (grant.state !== "pending") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not in pending state (state=${grant.state})`
    );
  }

  const now = admin.firestore.Timestamp.now();
  await grantRef.update({
    state: "rescinded",
    revoked_at: now,
    updated_at: now,
    invite_token: admin.firestore.FieldValue.delete(),
  });

  logger.info(`rescindTutorInvite: parent=${callerUid} grantId=${grantId}`);
  return { success: true };
});

// ── revokeTutorGrant ──────────────────────────────────────────────────────────
//
// Parent revokes an active grant. Deletes tutor_active_access lookup doc.
//
// Expects: { grantId: string }
// Returns: { success: true }

export const revokeTutorGrant = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.parent_uid !== callerUid) {
    throw new HttpsError("permission-denied", "Only the parent can revoke a grant");
  }
  if (grant.state !== "active") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not active (state=${grant.state})`
    );
  }

  const now = admin.firestore.Timestamp.now();
  const tutorUid = String(grant.tutor_uid ?? "");
  const profileId = String(grant.child_profile_id);
  const accessId = buildAccessId(tutorUid, callerUid, profileId);

  await db.runTransaction(async (txn) => {
    txn.update(grantRef, {
      state: "revoked_by_parent",
      revoked_at: now,
      updated_at: now,
    });
    // Remove the access index so the tutor can no longer read subcollections.
    const accessRef = db.collection("tutor_active_access").doc(accessId);
    txn.delete(accessRef);
  });

  logger.info(`revokeTutorGrant: parent=${callerUid} grantId=${grantId} tutor=${tutorUid}`);
  return { success: true };
});

// ── resignTutorGrant ──────────────────────────────────────────────────────────
//
// Tutor resigns from an active grant. Deletes tutor_active_access lookup doc.
//
// Expects: { grantId: string }
// Returns: { success: true }

export const resignTutorGrant = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.tutor_uid !== callerUid) {
    throw new HttpsError("permission-denied", "Only the tutor can resign a grant");
  }
  if (grant.state !== "active") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not active (state=${grant.state})`
    );
  }

  const now = admin.firestore.Timestamp.now();
  const parentUid = String(grant.parent_uid);
  const profileId = String(grant.child_profile_id);
  const accessId = buildAccessId(callerUid, parentUid, profileId);

  await db.runTransaction(async (txn) => {
    txn.update(grantRef, {
      state: "revoked_by_tutor",
      revoked_at: now,
      updated_at: now,
    });
    const accessRef = db.collection("tutor_active_access").doc(accessId);
    txn.delete(accessRef);
  });

  logger.info(`resignTutorGrant: tutor=${callerUid} grantId=${grantId}`);
  return { success: true };
});

// ── listTutorGrants ───────────────────────────────────────────────────────────
//
// Returns tutor grants for the authenticated user.
// Mode 'incoming': grants where the caller is the tutor (all non-terminal states).
// Mode 'outgoing': grants where the caller is the parent, for a specific child.
//
// Expects: { mode: 'incoming' | 'outgoing', childProfileId?: string }
// Returns: { grants: TutorGrantDoc[] }

export const listTutorGrants = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { mode, childProfileId } = request.data ?? {};
  if (mode !== "incoming" && mode !== "outgoing") {
    throw new HttpsError("invalid-argument", "mode must be 'incoming' or 'outgoing'");
  }

  let query: admin.firestore.Query;
  if (mode === "incoming") {
    query = db
      .collection("tutor_grants")
      .where("tutor_uid", "==", callerUid)
      .where("state", "in", ["pending", "active"]);
  } else {
    if (typeof childProfileId !== "string" || !childProfileId) {
      throw new HttpsError("invalid-argument", "childProfileId required for outgoing mode");
    }
    query = db
      .collection("tutor_grants")
      .where("parent_uid", "==", callerUid)
      .where("child_profile_id", "==", childProfileId);
  }

  const snap = await query.get();
  const grants = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return { grants };
});

// ══════════════════════════════════════════════════════════════════════════════
// V2-R3 C4 — Expire pending invites (scheduled, 7-day TTL)
// ══════════════════════════════════════════════════════════════════════════════
//
// Scheduled: daily at 01:00 UTC (offset from purgeExpiredAuditLogs at 02:00).
//
// Queries pending grants where expires_at < now, transitions them to 'expired'.
// Writes an audit log entry for each expiration.

export const expirePendingInvites = pubsub
  .schedule("0 1 * * *") // daily at 01:00 UTC
  .timeZone("UTC")
  .onRun(async (_context) => {
    const now = admin.firestore.Timestamp.now();
    logger.info(`expirePendingInvites: running at ${now.toDate().toISOString()}`);

    const snapshot = await db
      .collection("tutor_grants")
      .where("state", "==", "pending")
      .where("expires_at", "<=", now)
      .get();

    if (snapshot.empty) {
      logger.info("expirePendingInvites: no expired pending grants found");
      return;
    }

    let expiredCount = 0;
    for (const grantDoc of snapshot.docs) {
      const grantId = grantDoc.id;
      try {
        await db.runTransaction(async (txn) => {
          txn.update(grantDoc.ref, {
            state: "expired",
            updated_at: now,
            invite_token: admin.firestore.FieldValue.delete(),
          });

          // Write audit log entry.
          const auditRef = db
            .collection("tutor_grants")
            .doc(grantId)
            .collection("audit_log")
            .doc();
          txn.set(auditRef, {
            tutor_uid: null,
            tutor_name_snapshot: grantDoc.data().tutor_email ?? "",
            action: "invite_expired",
            target: `grant/${grantId}`,
            after_value: JSON.stringify({ state: "expired" }),
            timestamp: now.toDate().toISOString(),
          });
        });

        expiredCount++;
        logger.info(`expirePendingInvites: expired grant=${grantId}`);
      } catch (e) {
        logger.error(`expirePendingInvites: failed to expire grant=${grantId}`, e);
      }
    }

    logger.info(`expirePendingInvites: complete — expired=${expiredCount} total=${snapshot.size}`);
  });
