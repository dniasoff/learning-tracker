import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { db, CALL_OPTS } from "./shared";

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
