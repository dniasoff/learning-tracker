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
//     profileId: string,                // learner profile ULID (AD-24)
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
// Returns: { success: true, written: number, replayed: number }
//   Create-only: a completionId that already exists rejects the request with
//   `already-exists` (nothing written), unless it is an identical replay of
//   this tutor's own earlier write under the same grant, which is skipped and
//   counted in `replayed`.
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

/**
 * Enforce bulk-prior only — no live-forward completions.
 *
 * LOAD-BEARING SECURITY CHECK: completedAt MUST be strictly in the past.
 * "Past" means before today's UTC midnight. This is the Cloud Function
 * enforcement of the canMarkLiveCompletion=false policy (W4.34).
 * Even one live completion in the batch rejects the entire request.
 */
function assertBulkPriorPayload(completions: CompletionPayload[]): void {
  const todayUtcMidnight = new Date();
  todayUtcMidnight.setUTCHours(0, 0, 0, 0);

  for (const completion of completions) {
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
}

/**
 * Completion ids become Firestore doc ids under the owner's profile, so they
 * must be a single safe path segment (ULID-like: letters, digits, `_`, `-`)
 * and unique within one request (DNI-487 review).
 */
const COMPLETION_ID_RE = /^[A-Za-z0-9_-]{1,128}$/;

function assertCompletionIds(completions: CompletionPayload[]): void {
  const seen = new Set<string>();
  for (const completion of completions) {
    if (!COMPLETION_ID_RE.test(completion.completionId)) {
      throw new HttpsError(
        "invalid-argument",
        "completionId must be 1-128 characters of [A-Za-z0-9_-]"
      );
    }
    if (seen.has(completion.completionId)) {
      throw new HttpsError(
        "invalid-argument",
        `Duplicate completionId in request: ${completion.completionId}`
      );
    }
    seen.add(completion.completionId);
  }
}

/** The payload-derived fields a stored completion must match to be a replay. */
function completionContent(
  completion: CompletionPayload,
  callerUid: string,
  grantId: string
): Record<string, unknown> {
  return {
    completion_id: completion.completionId,
    curriculum_id: completion.curriculumId,
    sefaria_ref: completion.sefariaRef,
    stage_id: completion.stageId,
    track_type: completion.trackType,
    completed_at_ms: new Date(completion.completedAt).getTime(),
    points: completion.points,
    created_by_tutor_uid: callerUid,
    grant_id: grantId,
  };
}

function isIdenticalReplay(
  existing: admin.firestore.DocumentData,
  expected: Record<string, unknown>
): boolean {
  const completedAt = existing.completed_at;
  const storedMs =
    completedAt instanceof admin.firestore.Timestamp
      ? completedAt.toMillis()
      : undefined;
  return Object.entries(expected).every(([key, value]) =>
    key === "completed_at_ms" ? storedMs === value : existing[key] === value
  );
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
  if (typeof profileId !== "string" || !profileId) {
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
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

  // ── 3. Grant verification + writes in ONE transaction (AD-53, DNI-487) ──
  // The grant is read inside the same transaction that writes the
  // completions, so a revocation (state change or can_edit_learning=false)
  // that commits first aborts this write: on retry the grant is re-read and
  // denied. A revoked tutor can never land a completion (AC-6).
  const grantRef = db.collection("tutor_grants").doc(grantId);
  const profilePath = db
    .collection("users")
    .doc(ownerUid)
    .collection("learner_profiles")
    .doc(String(profileId));
  const writtenAt = admin.firestore.Timestamp.now();

  // Firestore allows 500 writes per transaction — the input cap matches.
  const result = await db.runTransaction(async (txn) => {
    const grantSnap = await txn.get(grantRef);

    if (!grantSnap.exists) {
      throw new HttpsError("not-found", `Grant not found: ${grantId}`);
    }

    const g = grantSnap.data()!;

    // Verify grant is active.
    if (g.state !== "active") {
      throw new HttpsError(
        "permission-denied",
        `Grant ${grantId} is not active (state=${g.state})`
      );
    }

    // Verify caller is the tutor on this grant.
    if (g.tutor_uid !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "Grant tutor_uid does not match caller uid"
      );
    }

    // Verify ownerUid matches the grant's parent_uid (caller sanity check).
    if (g.parent_uid !== ownerUid) {
      throw new HttpsError(
        "permission-denied",
        "Grant parent_uid does not match supplied ownerUid"
      );
    }

    // Verify the profile ID matches the grant's child_profile_id.
    if (String(g.child_profile_id) !== String(profileId)) {
      throw new HttpsError(
        "permission-denied",
        "Grant child_profile_id does not match supplied profileId"
      );
    }

    // Permission check: can_edit_learning (AD-53, DNI-487). Recording prior
    // learning is a learning write, so it follows the single parent-set
    // `can_edit_learning` permission and fails closed: a grant without it
    // (every pre-AD-53 grant) is read-only. The legacy
    // `can_bulk_prior_completion` key is no longer consulted. This callable
    // is itself retired by Story 1.26 (DNI-488).
    const permissions = g.permissions ?? {};
    if (permissions.can_edit_learning !== true) {
      throw new HttpsError(
        "permission-denied",
        "Grant lacks can_edit_learning"
      );
    }

    // Payload checks run after the grant checks (unchanged order).
    const items = completions as CompletionPayload[];
    assertBulkPriorPayload(items);
    assertCompletionIds(items);

    // Create-only (DNI-487 review): read every target inside the transaction
    // first. A tutor may never overwrite an existing completion — owner- or
    // tutor-written — through this proxy (it records no change-log entry).
    // The one tolerated collision is an identical replay of this tutor's own
    // earlier write under the same grant (a client retry), which is skipped.
    // Anything else rejects the whole request with nothing written.
    const completionRefs = items.map((completion) =>
      profilePath.collection("completions").doc(completion.completionId)
    );
    const existingSnaps = await txn.getAll(...completionRefs);
    const toWrite: Array<{
      ref: admin.firestore.DocumentReference;
      completion: CompletionPayload;
    }> = [];
    items.forEach((completion, i) => {
      const snap = existingSnaps[i];
      if (!snap.exists) {
        toWrite.push({ ref: completionRefs[i], completion });
        return;
      }
      const expected = completionContent(completion, callerUid, grantId);
      if (!isIdenticalReplay(snap.data()!, expected)) {
        throw new HttpsError(
          "already-exists",
          `Completion ${completion.completionId} already exists; ` +
            "tutors cannot overwrite an existing completion"
        );
      }
    });

    // Write completions as the owner (Admin SDK). Each completion document
    // lands in the owner's profile subcollection, indistinguishable from an
    // owner-written completion; the tutor_uid is kept as
    // `created_by_tutor_uid` for audit purposes.
    for (const { ref: completionRef, completion } of toWrite) {
      txn.create(completionRef, {
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

    return { g, written: toWrite.length };
  });
  const grant = result.g;
  const written = result.written;
  const replayed = completions.length - written;

  // ── 4. Write audit log entry ───────────────────────────────────────────
  // A pure replay wrote nothing, so it records nothing either (idempotent).
  if (written > 0) {
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
      after_value: JSON.stringify({ count: written, replayed }),
      timestamp: writtenAt.toDate().toISOString(),
    });
  }

  logger.info(
    `tutorBulkPriorCompletions: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId} written=${written} ` +
      `replayed=${replayed}`
  );

  return { success: true, written, replayed };
});
