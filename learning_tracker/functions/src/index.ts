import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { auth, logger, pubsub } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();
const db = admin.firestore();

// Shared callable options. enforceAppCheck rejects any call that does not carry
// a valid App Check token, so only our genuine app builds (Play Integrity in
// release, the registered debug token in development) can invoke these
// functions. The client attaches tokens automatically once App Check is
// activated at startup (see firebase_bootstrap.dart).
const CALL_OPTS = { enforceAppCheck: true } as const;

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
export const deleteLearnerProfile = onCall(CALL_OPTS, async (request) => {
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
export const deleteCurriculumTrack = onCall(CALL_OPTS, async (request) => {
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

  // recursiveDelete (not a shallow delete) so any future track subcollection
  // is purged too — consistent with deleteLearnerProfile / deleteAccountData.
  await db.recursiveDelete(trackRef);
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
export const deleteAccountData = onCall(CALL_OPTS, async (request) => {
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

export const tutorBulkPriorCompletions = onCall(CALL_OPTS, async (request) => {
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

export const inviteTutor = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { tutorEmail, childProfileId, permissions, childName, parentName } =
    request.data ?? {};

  if (typeof tutorEmail !== "string" || !tutorEmail.includes("@")) {
    throw new HttpsError("invalid-argument", "tutorEmail must be a valid email address");
  }
  if (typeof childProfileId !== "string" || !childProfileId) {
    throw new HttpsError("invalid-argument", "childProfileId must be a non-empty string");
  }

  // Snapshot human-readable names at invite time so the tutor sees the child's
  // name (and inviting parent) instead of a raw profile id / generic label.
  const sanitizeName = (v: unknown): string | null =>
    typeof v === "string" && v.trim() ? v.trim().slice(0, 100) : null;
  const childNameSnapshot = sanitizeName(childName);
  const parentNameSnapshot = sanitizeName(parentName);

  // NOTE: we intentionally do NOT verify a Firestore learner_profiles doc
  // exists for childProfileId. Profiles are offline-first (Drift-local) and a
  // child may have no synced cloud doc yet, so such a check wrongly blocks a
  // legitimate invite. It is also unnecessary for isolation: parent_uid is
  // hard-set to the caller below, so the grant always lands in the caller's
  // own namespace and cannot reference another user's data.

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
    can_edit_points: false,
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
    child_name: childNameSnapshot,
    parent_name: parentNameSnapshot,
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

export const acceptTutorInvite = onCall(CALL_OPTS, async (request) => {
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

export const declineTutorInvite = onCall(CALL_OPTS, async (request) => {
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

  // Caller is the invited tutor either by uid (already linked) or by email
  // (invite not yet accepted). Check the uid first — it needs no Auth lookup —
  // and only fall back to the live getUser() email comparison when it doesn't
  // match, so the common path avoids an unnecessary Auth round-trip.
  const isTutorByUid = grant.tutor_uid === callerUid;
  let isTutorByEmail = false;
  if (!isTutorByUid) {
    const callerRecord = await admin.auth().getUser(callerUid);
    const callerEmail = (callerRecord.email ?? "").toLowerCase().trim();
    const grantEmail = (grant.tutor_email ?? "").toLowerCase().trim();
    isTutorByEmail = callerEmail === grantEmail;
  }

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

export const rescindTutorInvite = onCall(CALL_OPTS, async (request) => {
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

export const revokeTutorGrant = onCall(CALL_OPTS, async (request) => {
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

export const resignTutorGrant = onCall(CALL_OPTS, async (request) => {
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

export const listTutorGrants = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { mode, childProfileId } = request.data ?? {};
  if (mode !== "incoming" && mode !== "outgoing" && mode !== "pending_for_me") {
    throw new HttpsError(
      "invalid-argument",
      "mode must be 'incoming', 'outgoing', or 'pending_for_me'"
    );
  }

  let query: admin.firestore.Query;
  if (mode === "incoming") {
    query = db
      .collection("tutor_grants")
      .where("tutor_uid", "==", callerUid)
      .where("state", "in", ["pending", "active"]);
  } else if (mode === "pending_for_me") {
    // Pending invites are addressed by EMAIL (tutor_uid is null until accepted),
    // so a freshly signed-in tutor can discover invitations in-app and accept
    // without needing the emailed deep link. Match the caller's verified email.
    const callerEmail = (request.auth?.token?.email ?? "").toLowerCase();
    if (!callerEmail) {
      return { grants: [] };
    }
    query = db
      .collection("tutor_grants")
      .where("tutor_email", "==", callerEmail)
      .where("state", "==", "pending");
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
  // Serialise Firestore Timestamps to ISO-8601 strings so the wire format is
  // deterministic. The raw callable encoding of an Admin Timestamp is a
  // {_seconds,_nanoseconds} map, which the client parser used to choke on —
  // emit plain strings (matching the client's own toFirestore format).
  const TS_FIELDS = [
    "invited_at", "accepted_at", "declined_at",
    "revoked_at", "expires_at", "updated_at",
  ];
  const grants = snap.docs.map((d) => {
    const out: Record<string, unknown> = { id: d.id, ...d.data() };
    for (const k of TS_FIELDS) {
      const v = out[k];
      if (v instanceof admin.firestore.Timestamp) {
        out[k] = v.toDate().toISOString();
      }
    }
    return out;
  });
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
        const didExpire = await db.runTransaction(async (txn) => {
          // Re-read INSIDE the transaction: the grant may have been accepted,
          // declined, or rescinded between the query above and now. Only expire
          // a grant that is STILL pending — never clobber a newer state.
          const fresh = await txn.get(grantDoc.ref);
          if (!fresh.exists || fresh.data()?.state !== "pending") {
            return false;
          }

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
            tutor_name_snapshot: fresh.data()?.tutor_email ?? "",
            action: "invite_expired",
            target: `grant/${grantId}`,
            after_value: JSON.stringify({ state: "expired" }),
            timestamp: now.toDate().toISOString(),
          });
          return true;
        });

        if (didExpire) {
          expiredCount++;
          logger.info(`expirePendingInvites: expired grant=${grantId}`);
        }
      } catch (e) {
        logger.error(`expirePendingInvites: failed to expire grant=${grantId}`, e);
      }
    }

    logger.info(`expirePendingInvites: complete — expired=${expiredCount} total=${snapshot.size}`);
  });

// ══════════════════════════════════════════════════════════════════════════════
// Tutor write-path Cloud Functions — S4 (Talmid-View Squad)
// ══════════════════════════════════════════════════════════════════════════════
//
// All functions below follow the same security contract:
//   1. Caller must be authenticated.
//   2. Grant must be active and grant.tutor_uid must equal the caller uid.
//   3. grant.parent_uid must equal the supplied ownerUid.
//   4. grant.child_profile_id must equal the supplied profileId.
//   5. The specific TutorPermissions flag must be true (except tutorEditProfile
//      which is always allowed for active tutors — parent-equivalent).
//   6. Write targets ONLY users/{ownerUid}/learner_profiles/{profileId}/…
//      — never the tutor's own namespace.
//   7. An audit log entry is written to tutor_grants/{grantId}/audit_log/{autoId}.
//
// Admin SDK bypasses Firestore Security Rules — the permission checks above are
// the sole enforcement layer for these write paths.

// ── Shared grant-verification helper ─────────────────────────────────────────

interface GrantVerification {
  grant: FirebaseFirestore.DocumentData;
  profilePath: FirebaseFirestore.DocumentReference;
  writtenAt: FirebaseFirestore.Timestamp;
}

/**
 * Verifies an active tutor grant and returns the resolved profile path.
 *
 * Throws HttpsError('permission-denied') if any check fails.
 * Throws HttpsError('not-found') if the grant document does not exist.
 *
 * @param callerUid   Firebase Auth uid of the caller (the tutor).
 * @param grantId     The tutor_grants/{grantId} document ID.
 * @param ownerUid    Expected parent/owner uid (sanity check).
 * @param profileId   Expected child profile ID (integer).
 * @param permKey     The permissions map key to check (e.g. 'can_edit_goals').
 *                    Pass null to skip the permission check (for always-allowed ops).
 */
async function verifyTutorGrant(
  callerUid: string,
  grantId: string,
  ownerUid: string,
  profileId: number,
  permKey: string | null,
): Promise<GrantVerification> {
  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();

  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.state !== "active") {
    throw new HttpsError(
      "permission-denied",
      `Grant ${grantId} is not active (state=${grant.state})`,
    );
  }

  if (grant.tutor_uid !== callerUid) {
    throw new HttpsError("permission-denied", "Grant tutor_uid does not match caller uid");
  }

  if (grant.parent_uid !== ownerUid) {
    throw new HttpsError("permission-denied", "Grant parent_uid does not match supplied ownerUid");
  }

  if (String(grant.child_profile_id) !== String(profileId)) {
    throw new HttpsError(
      "permission-denied",
      "Grant child_profile_id does not match supplied profileId",
    );
  }

  if (permKey !== null) {
    const permissions = grant.permissions ?? {};
    if (permissions[permKey] !== true) {
      throw new HttpsError(
        "permission-denied",
        `Tutor does not have permission '${permKey}' for this grant`,
      );
    }
  }

  const profilePath = db
    .collection("users")
    .doc(ownerUid)
    .collection("learner_profiles")
    .doc(String(profileId));

  return { grant, profilePath, writtenAt: admin.firestore.Timestamp.now() };
}

/** Write an audit log entry for a tutor mutation (best-effort — errors are logged but not thrown). */
async function writeAuditLog(
  grantId: string,
  grant: FirebaseFirestore.DocumentData,
  callerUid: string,
  action: string,
  target: string,
  beforeValue: unknown,
  afterValue: unknown,
  timestamp: FirebaseFirestore.Timestamp,
): Promise<void> {
  try {
    await db
      .collection("tutor_grants")
      .doc(grantId)
      .collection("audit_log")
      .add({
        tutor_uid: callerUid,
        tutor_name_snapshot: grant.tutor_name_snapshot ?? "",
        action,
        target,
        before_value: beforeValue !== undefined ? JSON.stringify(beforeValue) : null,
        after_value: afterValue !== undefined ? JSON.stringify(afterValue) : null,
        timestamp: timestamp.toDate().toISOString(),
      });
  } catch (e) {
    logger.warn(`writeAuditLog: failed for grant=${grantId} action=${action}`, e);
  }
}

// ── tutorResetCompletion ──────────────────────────────────────────────────────
//
// Deletes a completion document from the child's profile as a correction path.
// Requires canResetCompletion permission.
//
// Expects:
//   {
//     grantId: string,
//     ownerUid: string,
//     profileId: number,
//     completionId: string,   // the doc-id to delete
//   }
//
// Returns: { success: true }

export const tutorResetCompletion = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, completionId } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof completionId !== "string" || !completionId)
    throw new HttpsError("invalid-argument", "completionId must be a non-empty string");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_reset_completion",
  );

  const completionRef = profilePath.collection("completions").doc(completionId);

  // Capture before-value for audit log.
  const beforeSnap = await completionRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await completionRef.delete();

  await writeAuditLog(
    grantId, grant, callerUid,
    "completion_reset",
    `profile/${profileId}/completions/${completionId}`,
    beforeValue, null, writtenAt,
  );

  logger.info(
    `tutorResetCompletion: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} completionId=${completionId}`,
  );

  return { success: true };
});

// ── tutorUpsertGoal ───────────────────────────────────────────────────────────
//
// Creates or updates a goal document in the child's profile.
// Requires canEditGoals permission.
//
// Expects:
//   {
//     grantId: string,
//     ownerUid: string,
//     profileId: number,
//     goalId: string,           // doc-id (matches goals/{goalId})
//     goalData: object,         // merged into the goal document
//   }
//
// Returns: { success: true }

export const tutorUpsertGoal = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, goalId, goalData } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof goalId !== "string" || !goalId)
    throw new HttpsError("invalid-argument", "goalId must be a non-empty string");
  if (!goalData || typeof goalData !== "object" || Array.isArray(goalData))
    throw new HttpsError("invalid-argument", "goalData must be an object");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_goals",
  );

  const goalRef = profilePath.collection("goals").doc(goalId);

  const beforeSnap = await goalRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await goalRef.set(
    { ...goalData, synced_at: writtenAt },
    { merge: true },
  );

  await writeAuditLog(
    grantId, grant, callerUid,
    "goal_upserted",
    `profile/${profileId}/goals/${goalId}`,
    beforeValue, goalData, writtenAt,
  );

  logger.info(
    `tutorUpsertGoal: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} goalId=${goalId}`,
  );

  return { success: true };
});

// ── tutorDeleteGoal ───────────────────────────────────────────────────────────
//
// Deletes a goal document from the child's profile.
// Requires canEditGoals permission.
//
// Expects:
//   { grantId, ownerUid, profileId, goalId }
// Returns: { success: true }

export const tutorDeleteGoal = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, goalId } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof goalId !== "string" || !goalId)
    throw new HttpsError("invalid-argument", "goalId must be a non-empty string");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_goals",
  );

  const goalRef = profilePath.collection("goals").doc(goalId);
  const beforeSnap = await goalRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await goalRef.delete();

  await writeAuditLog(
    grantId, grant, callerUid,
    "goal_deleted",
    `profile/${profileId}/goals/${goalId}`,
    beforeValue, null, writtenAt,
  );

  logger.info(
    `tutorDeleteGoal: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} goalId=${goalId}`,
  );

  return { success: true };
});

// ── tutorUpsertTrack ──────────────────────────────────────────────────────────
//
// Creates or updates a curriculum_tracks document in the child's profile.
// Requires canEditStages permission (tracks include stage/track config).
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     trackId: string,          // curriculum_tracks doc-id
//     trackData: object,
//   }
// Returns: { success: true }

export const tutorUpsertTrack = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, trackId, trackData } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof trackId !== "string" || !trackId)
    throw new HttpsError("invalid-argument", "trackId must be a non-empty string");
  if (!trackData || typeof trackData !== "object" || Array.isArray(trackData))
    throw new HttpsError("invalid-argument", "trackData must be an object");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_stages",
  );

  const trackRef = profilePath.collection("curriculum_tracks").doc(trackId);
  const beforeSnap = await trackRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await trackRef.set(
    { ...trackData, synced_at: writtenAt },
    { merge: true },
  );

  await writeAuditLog(
    grantId, grant, callerUid,
    "track_upserted",
    `profile/${profileId}/curriculum_tracks/${trackId}`,
    beforeValue, trackData, writtenAt,
  );

  logger.info(
    `tutorUpsertTrack: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} trackId=${trackId}`,
  );

  return { success: true };
});

// ── tutorDeleteTrack ──────────────────────────────────────────────────────────
//
// Deletes a curriculum_tracks document from the child's profile.
// Requires canEditStages permission.
//
// Expects: { grantId, ownerUid, profileId, trackId }
// Returns: { success: true }

export const tutorDeleteTrack = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, trackId } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof trackId !== "string" || !trackId)
    throw new HttpsError("invalid-argument", "trackId must be a non-empty string");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_stages",
  );

  const trackRef = profilePath.collection("curriculum_tracks").doc(trackId);
  const beforeSnap = await trackRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await trackRef.delete();

  await writeAuditLog(
    grantId, grant, callerUid,
    "track_deleted",
    `profile/${profileId}/curriculum_tracks/${trackId}`,
    beforeValue, null, writtenAt,
  );

  logger.info(
    `tutorDeleteTrack: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} trackId=${trackId}`,
  );

  return { success: true };
});

// ── tutorUpsertStageDefinition ────────────────────────────────────────────────
//
// Creates or updates a stage_definitions document in the child's profile.
// Requires canEditStages permission.
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     stageId: string,          // stage_definitions doc-id ("{trackId}_{stageOrder}")
//     stageData: object,
//   }
// Returns: { success: true }

export const tutorUpsertStageDefinition = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, stageId, stageData } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof stageId !== "string" || !stageId)
    throw new HttpsError("invalid-argument", "stageId must be a non-empty string");
  if (!stageData || typeof stageData !== "object" || Array.isArray(stageData))
    throw new HttpsError("invalid-argument", "stageData must be an object");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_stages",
  );

  const stageRef = profilePath.collection("stage_definitions").doc(stageId);
  const beforeSnap = await stageRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await stageRef.set(
    { ...stageData, synced_at: writtenAt },
    { merge: true },
  );

  await writeAuditLog(
    grantId, grant, callerUid,
    "stage_definition_upserted",
    `profile/${profileId}/stage_definitions/${stageId}`,
    beforeValue, stageData, writtenAt,
  );

  logger.info(
    `tutorUpsertStageDefinition: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} stageId=${stageId}`,
  );

  return { success: true };
});

// ── tutorUpsertStudyDayConfig ─────────────────────────────────────────────────
//
// Creates or updates a study_day_configs document in the child's profile.
// Requires canEditStudyDays permission.
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     configId: string,         // study_day_configs doc-id
//     configData: object,
//   }
// Returns: { success: true }

export const tutorUpsertStudyDayConfig = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, configId, configData } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof configId !== "string" || !configId)
    throw new HttpsError("invalid-argument", "configId must be a non-empty string");
  if (!configData || typeof configData !== "object" || Array.isArray(configData))
    throw new HttpsError("invalid-argument", "configData must be an object");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_study_days",
  );

  const configRef = profilePath.collection("study_day_configs").doc(configId);
  const beforeSnap = await configRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await configRef.set(
    { ...configData, synced_at: writtenAt },
    { merge: true },
  );

  await writeAuditLog(
    grantId, grant, callerUid,
    "study_day_config_upserted",
    `profile/${profileId}/study_day_configs/${configId}`,
    beforeValue, configData, writtenAt,
  );

  logger.info(
    `tutorUpsertStudyDayConfig: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} configId=${configId}`,
  );

  return { success: true };
});

// ── tutorDeleteStudyDayConfig ─────────────────────────────────────────────────
//
// Deletes a study_day_configs document from the child's profile.
// Requires canEditStudyDays permission.
//
// Expects: { grantId, ownerUid, profileId, configId }
// Returns: { success: true }

export const tutorDeleteStudyDayConfig = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, configId } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof configId !== "string" || !configId)
    throw new HttpsError("invalid-argument", "configId must be a non-empty string");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_study_days",
  );

  const configRef = profilePath.collection("study_day_configs").doc(configId);
  const beforeSnap = await configRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await configRef.delete();

  await writeAuditLog(
    grantId, grant, callerUid,
    "study_day_config_deleted",
    `profile/${profileId}/study_day_configs/${configId}`,
    beforeValue, null, writtenAt,
  );

  logger.info(
    `tutorDeleteStudyDayConfig: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} configId=${configId}`,
  );

  return { success: true };
});

// ── tutorUpdateGamificationSettings ──────────────────────────────────────────
//
// Merges into the child's preferences/gamification_settings document.
// This covers both reward catalogue configuration (canEditRewards) and points
// configuration (canEditPoints). The caller supplies a settingsData object that
// is merged — the specific fields written determine which concern is affected.
//
// The permission required depends on what is being edited:
//   - reward items (rewards, reward_items, …) → canEditRewards
//   - points config (points_per_item, …)      → canEditPoints
// The caller must pass the appropriate permKey ('can_edit_rewards' or
// 'can_edit_points'). The CF validates only the specified permission flag.
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     permKey: 'can_edit_rewards' | 'can_edit_points',
//     settingsData: object,   // merged into preferences/gamification_settings
//   }
// Returns: { success: true }

const GAMIFICATION_PERM_KEYS = new Set(["can_edit_rewards", "can_edit_points"]);

export const tutorUpdateGamificationSettings = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, permKey, settingsData } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof permKey !== "string" || !GAMIFICATION_PERM_KEYS.has(permKey))
    throw new HttpsError(
      "invalid-argument",
      `permKey must be one of: ${[...GAMIFICATION_PERM_KEYS].join(", ")}`,
    );
  if (!settingsData || typeof settingsData !== "object" || Array.isArray(settingsData))
    throw new HttpsError("invalid-argument", "settingsData must be an object");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, permKey,
  );

  const settingsRef = profilePath.collection("preferences").doc("gamification_settings");
  const beforeSnap = await settingsRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await settingsRef.set(
    { ...settingsData, synced_at: writtenAt },
    { merge: true },
  );

  await writeAuditLog(
    grantId, grant, callerUid,
    "gamification_settings_updated",
    `profile/${profileId}/preferences/gamification_settings`,
    beforeValue, settingsData, writtenAt,
  );

  logger.info(
    `tutorUpdateGamificationSettings: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} permKey=${permKey}`,
  );

  return { success: true };
});

// ── tutorUpsertBookmark ───────────────────────────────────────────────────────
//
// Creates or updates a bookmark document in the child's profile.
// Requires canEditStages permission (bookmarks are part of the programme
// enrolment path which is gated by can_edit_stages).
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     bookmarkId: string,       // bookmarks doc-id ("{curriculum_id}_{track_type}")
//     bookmarkData: object,
//   }
// Returns: { success: true }

export const tutorUpsertBookmark = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, bookmarkId, bookmarkData } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof bookmarkId !== "string" || !bookmarkId)
    throw new HttpsError("invalid-argument", "bookmarkId must be a non-empty string");
  if (!bookmarkData || typeof bookmarkData !== "object" || Array.isArray(bookmarkData))
    throw new HttpsError("invalid-argument", "bookmarkData must be an object");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_stages",
  );

  const bookmarkRef = profilePath.collection("bookmarks").doc(bookmarkId);
  const beforeSnap = await bookmarkRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await bookmarkRef.set(
    { ...bookmarkData, synced_at: writtenAt },
    { merge: true },
  );

  await writeAuditLog(
    grantId, grant, callerUid,
    "bookmark_upserted",
    `profile/${profileId}/bookmarks/${bookmarkId}`,
    beforeValue, bookmarkData, writtenAt,
  );

  logger.info(
    `tutorUpsertBookmark: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} bookmarkId=${bookmarkId}`,
  );

  return { success: true };
});

// ── tutorSetProfileProgram ────────────────────────────────────────────────────
//
// Creates or updates a profile_program document in the child's profile.
// Requires canEditStages permission (programme assignment is part of the
// enrolment path gated by can_edit_stages).
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     programId: string,         // profile_programs doc-id (curriculum_id)
//     programData: object,
//   }
// Returns: { success: true }

export const tutorSetProfileProgram = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, programId, programData } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof programId !== "string" || !programId)
    throw new HttpsError("invalid-argument", "programId must be a non-empty string");
  if (!programData || typeof programData !== "object" || Array.isArray(programData))
    throw new HttpsError("invalid-argument", "programData must be an object");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_stages",
  );

  const programRef = profilePath.collection("profile_programs").doc(programId);
  const beforeSnap = await programRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await programRef.set(
    { ...programData, synced_at: writtenAt },
    { merge: true },
  );

  await writeAuditLog(
    grantId, grant, callerUid,
    "profile_program_set",
    `profile/${profileId}/profile_programs/${programId}`,
    beforeValue, programData, writtenAt,
  );

  logger.info(
    `tutorSetProfileProgram: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} programId=${programId}`,
  );

  return { success: true };
});

// ── tutorUpsertCurriculumScope ────────────────────────────────────────────────
//
// Creates or updates a curriculum_scope document in the child's profile.
// Requires canEditStages permission (scope selection is part of the enrolment
// path gated by can_edit_stages).
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     scopeId: string,           // curriculum_scopes doc-id
//     scopeData: object,
//   }
// Returns: { success: true }

export const tutorUpsertCurriculumScope = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, scopeId, scopeData } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  if (typeof scopeId !== "string" || !scopeId)
    throw new HttpsError("invalid-argument", "scopeId must be a non-empty string");
  if (!scopeData || typeof scopeData !== "object" || Array.isArray(scopeData))
    throw new HttpsError("invalid-argument", "scopeData must be an object");

  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, "can_edit_stages",
  );

  const scopeRef = profilePath.collection("curriculum_scopes").doc(scopeId);
  const beforeSnap = await scopeRef.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  await scopeRef.set(
    { ...scopeData, synced_at: writtenAt },
    { merge: true },
  );

  await writeAuditLog(
    grantId, grant, callerUid,
    "curriculum_scope_upserted",
    `profile/${profileId}/curriculum_scopes/${scopeId}`,
    beforeValue, scopeData, writtenAt,
  );

  logger.info(
    `tutorUpsertCurriculumScope: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} scopeId=${scopeId}`,
  );

  return { success: true };
});

// ── tutorEditProfile ──────────────────────────────────────────────────────────
//
// Updates permitted fields on the child's learner_profiles/{profileId} document.
// Permitted fields: display_name, avatar, mode.
// No additional permission flag — editing profile is parent-equivalent for any
// active tutor (per FR-3 "Edit child profile: display name, avatar, mode").
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     displayName?: string,   // new display name (1–100 chars)
//     avatar?: string,        // new avatar identifier
//     mode?: string,          // 'child' | 'adult'
//   }
// Returns: { success: true }

const ALLOWED_PROFILE_MODES = new Set(["child", "adult"]);

export const tutorEditProfile = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { grantId, ownerUid, profileId, displayName, avatar, mode } = request.data ?? {};

  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0)
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");

  // At least one editable field must be provided.
  if (displayName === undefined && avatar === undefined && mode === undefined) {
    throw new HttpsError(
      "invalid-argument",
      "At least one of displayName, avatar, or mode must be supplied",
    );
  }

  // Field-level validation.
  if (displayName !== undefined) {
    if (typeof displayName !== "string" || displayName.trim().length === 0) {
      throw new HttpsError("invalid-argument", "displayName must be a non-empty string");
    }
    if (displayName.length > 100) {
      throw new HttpsError("invalid-argument", "displayName must be 100 characters or fewer");
    }
  }
  if (avatar !== undefined && (typeof avatar !== "string" || !avatar)) {
    throw new HttpsError("invalid-argument", "avatar must be a non-empty string");
  }
  if (mode !== undefined && !ALLOWED_PROFILE_MODES.has(mode)) {
    throw new HttpsError(
      "invalid-argument",
      `mode must be one of: ${[...ALLOWED_PROFILE_MODES].join(", ")}`,
    );
  }

  // tutorEditProfile is parent-equivalent — no specific permission flag (null).
  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, null,
  );

  // Learner profile is at users/{ownerUid}/learner_profiles/{profileId} (the profilePath doc itself).
  // H2 fix: read the full existing doc first, merge the edit fields on top, then
  // write the complete doc so LearnerProfileCodec.decode() never sees a partial doc.
  const beforeSnap = await profilePath.get();
  const beforeValue = beforeSnap.exists ? beforeSnap.data() : null;

  const updates: Record<string, unknown> = { updated_at: writtenAt };
  if (displayName !== undefined) updates["display_name"] = displayName.trim();
  if (avatar !== undefined) updates["avatar"] = avatar;
  if (mode !== undefined) updates["mode"] = mode;

  const fullDoc = beforeValue ? { ...beforeValue, ...updates } : updates;
  await profilePath.set(fullDoc, { merge: false });

  await writeAuditLog(
    grantId, grant, callerUid,
    "profile_edited",
    `profile/${profileId}`,
    beforeValue ? {
      display_name: beforeValue["display_name"],
      avatar: beforeValue["avatar"],
      mode: beforeValue["mode"],
    } : null,
    updates, writtenAt,
  );

  logger.info(
    `tutorEditProfile: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId}`,
  );

  return { success: true };
});
