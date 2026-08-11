import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { db, CALL_OPTS } from "./shared";

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

// ── AUD-firebase-10: field whitelists for tutor-write-path CFs ───────────────
//
// Admin SDK writes bypass firestore.rules entirely, so for these CFs
// `assertAllowedFields` below is the ONLY server-side gate on WHICH fields a
// caller may write and how large they may be — the permission checks above
// only gate WHO may write and WHICH collection. Each list mirrors the
// corresponding firestore.rules `request.resource.data.keys().hasOnly([...])`
// block for the owner's own direct client writes to the same collection, so
// an invited tutor (a distinct, deliberately lower-trust principal) can never
// write a field the owner is rules-blocked from writing directly.
//
// goals, curriculum_tracks, stage_definitions, study_day_configs, bookmarks
// and profile_programs all have a rules `.hasOnly()` counterpart. preferences
// (gamification_settings) and curriculum_scopes do NOT — those collections
// are intentionally open-ended even for the owner's own direct writes, so
// only the size cap (not a key whitelist) applies there; see the `null`
// allowedKeys call sites below.

const GOAL_ALLOWED_FIELDS = [
  "id", "goal_id", "profile_id", "track_id", "curriculum_id",
  "curriculumId", "description", "target_percent", "targetPercent",
  "target_date", "targetDate", "date_type", "dateType", "goal_type",
  "goalType", "pace_value", "paceValue", "pace_unit", "pacePeriod",
  "paceGranularity", "pace_granularity", "created_at", "createdAt",
  "updated_at", "updatedAt", "synced_at",
] as const;

const CURRICULUM_TRACK_ALLOWED_FIELDS = [
  "profile_id", "track_id", "curriculum_id", "state", "state_changed_at",
  "activated_at", "pace_reset_date", "progress_schema_version",
  "progress_computed_at", "progress_model", "program_progress",
  "self_paced_progress", "synced_at", "last_reorder_at", "purged", "purged_at",
] as const;

const STAGE_DEFINITION_ALLOWED_FIELDS = [
  "profile_id", "curriculum_id", "track_id", "stage_order", "stage_name",
  "schedule", "delay_days", "schedule_type", "is_default", "days_of_week",
  "rolling_window_size", "updated_at", "synced_at",
] as const;

const STUDY_DAY_CONFIG_ALLOWED_FIELDS = [
  "profile_id", "curriculum_id", "track_id", "day_of_week", "day_type",
  "updated_at", "synced_at",
] as const;

const BOOKMARK_ALLOWED_FIELDS = [
  "profile_id", "curriculum_id", "content_item_id", "sefaria_ref",
  "stage_id", "updated_at", "synced_at",
] as const;

const PROFILE_PROGRAM_ALLOWED_FIELDS = [
  "profile_id", "curriculum_id", "program_id", "tracking_start_date",
  "tracking_start_ref", "synced_at", "updated_at",
] as const;

/**
 * Throws HttpsError('invalid-argument') if `data` contains a key outside
 * `allowedKeys`, or if any string value exceeds `maxStringLength`.
 *
 * @param data            the caller-supplied payload object (e.g. goalData).
 * @param fieldParamName  its request.data field name, used in error messages.
 * @param allowedKeys     null means the collection has no field whitelist
 *                        (no rules `.hasOnly()` counterpart) — only the size
 *                        cap is enforced.
 */
function assertAllowedFields(
  data: Record<string, unknown>,
  fieldParamName: string,
  allowedKeys: readonly string[] | null,
  maxStringLength = 5000,
): void {
  if (allowedKeys !== null) {
    const allowed = new Set<string>(allowedKeys);
    for (const key of Object.keys(data)) {
      if (!allowed.has(key)) {
        throw new HttpsError(
          "invalid-argument",
          `${fieldParamName} contains an unexpected field: ${key}`,
        );
      }
    }
  }
  for (const [key, value] of Object.entries(data)) {
    if (typeof value === "string" && value.length > maxStringLength) {
      throw new HttpsError(
        "invalid-argument",
        `${fieldParamName}.${key} exceeds the maximum allowed length (${maxStringLength})`,
      );
    }
  }
}

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
 * @param profileId   Expected child profile ULID (AD-24 string doc-id).
 * @param permKey     The permissions map key to check (e.g. 'can_edit_goals').
 *                    Pass null to skip the permission check (for always-allowed ops).
 */
async function verifyTutorGrant(
  callerUid: string,
  grantId: string,
  ownerUid: string,
  profileId: string,
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

/**
 * Write an audit log entry for a tutor mutation (best-effort — errors are
 * logged but not thrown, so the primary mutation still returns success even
 * if the audit write fails).
 *
 * AUD-firebase-08: when the caller supplies `idempotencyKey` (request.data's
 * optional per-call retry token), the entry is written to a doc ID derived
 * deterministically from (grantId, action, target, idempotencyKey) via
 * `.set()` instead of an auto-ID `.add()` — a client-side retry of the same
 * logical mutation (e.g. after a timeout that actually succeeded
 * server-side) reuses the same key and so coalesces into exactly one entry
 * instead of a duplicate. Two calls with DIFFERENT idempotencyKeys (distinct
 * real actions) still get distinct entries. Callers that omit the key keep
 * the legacy auto-ID behavior — every call is a new entry.
 */
async function writeAuditLog(
  grantId: string,
  grant: FirebaseFirestore.DocumentData,
  callerUid: string,
  action: string,
  target: string,
  beforeValue: unknown,
  afterValue: unknown,
  timestamp: FirebaseFirestore.Timestamp,
  idempotencyKey?: string,
): Promise<void> {
  try {
    const auditCollection = db.collection("tutor_grants").doc(grantId).collection("audit_log");
    const payload = {
      tutor_uid: callerUid,
      tutor_name_snapshot: grant.tutor_name_snapshot ?? "",
      action,
      target,
      before_value: beforeValue !== undefined ? JSON.stringify(beforeValue) : null,
      after_value: afterValue !== undefined ? JSON.stringify(afterValue) : null,
      timestamp: timestamp.toDate().toISOString(),
    };

    if (typeof idempotencyKey === "string" && idempotencyKey) {
      // Hash rather than concatenate raw parts as the doc-id: target may
      // contain '/' (invalid inside a single path segment) and the combined
      // length could exceed Firestore's 1500-byte doc-id limit.
      const docId = crypto
        .createHash("sha256")
        .update(`${grantId}|${action}|${target}|${idempotencyKey}`)
        .digest("hex");
      await auditCollection.doc(docId).set(payload);
    } else {
      await auditCollection.add(payload);
    }
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
//     profileId: string,   // ULID
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
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
    beforeValue, null, writtenAt, request.data?.idempotencyKey,
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
//     profileId: string,   // ULID
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (typeof goalId !== "string" || !goalId)
    throw new HttpsError("invalid-argument", "goalId must be a non-empty string");
  if (!goalData || typeof goalData !== "object" || Array.isArray(goalData))
    throw new HttpsError("invalid-argument", "goalData must be an object");
  assertAllowedFields(goalData, "goalData", GOAL_ALLOWED_FIELDS);

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
    beforeValue, goalData, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
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
    beforeValue, null, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (typeof trackId !== "string" || !trackId)
    throw new HttpsError("invalid-argument", "trackId must be a non-empty string");
  if (!trackData || typeof trackData !== "object" || Array.isArray(trackData))
    throw new HttpsError("invalid-argument", "trackData must be an object");
  assertAllowedFields(trackData, "trackData", CURRICULUM_TRACK_ALLOWED_FIELDS);

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
    beforeValue, trackData, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
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
    beforeValue, null, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (typeof stageId !== "string" || !stageId)
    throw new HttpsError("invalid-argument", "stageId must be a non-empty string");
  if (!stageData || typeof stageData !== "object" || Array.isArray(stageData))
    throw new HttpsError("invalid-argument", "stageData must be an object");
  assertAllowedFields(stageData, "stageData", STAGE_DEFINITION_ALLOWED_FIELDS);

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
    beforeValue, stageData, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (typeof configId !== "string" || !configId)
    throw new HttpsError("invalid-argument", "configId must be a non-empty string");
  if (!configData || typeof configData !== "object" || Array.isArray(configData))
    throw new HttpsError("invalid-argument", "configData must be an object");
  assertAllowedFields(configData, "configData", STUDY_DAY_CONFIG_ALLOWED_FIELDS);

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
    beforeValue, configData, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
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
    beforeValue, null, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (typeof permKey !== "string" || !GAMIFICATION_PERM_KEYS.has(permKey))
    throw new HttpsError(
      "invalid-argument",
      `permKey must be one of: ${[...GAMIFICATION_PERM_KEYS].join(", ")}`,
    );
  if (!settingsData || typeof settingsData !== "object" || Array.isArray(settingsData))
    throw new HttpsError("invalid-argument", "settingsData must be an object");
  // No firestore.rules `.hasOnly()` counterpart for preferences/{scope} — it's
  // intentionally an open-ended bag even for the owner's own direct writes,
  // so only the size cap applies here (null = no key whitelist).
  assertAllowedFields(settingsData, "settingsData", null);

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
    beforeValue, settingsData, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (typeof bookmarkId !== "string" || !bookmarkId)
    throw new HttpsError("invalid-argument", "bookmarkId must be a non-empty string");
  if (!bookmarkData || typeof bookmarkData !== "object" || Array.isArray(bookmarkData))
    throw new HttpsError("invalid-argument", "bookmarkData must be an object");
  assertAllowedFields(bookmarkData, "bookmarkData", BOOKMARK_ALLOWED_FIELDS);

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
    beforeValue, bookmarkData, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (typeof programId !== "string" || !programId)
    throw new HttpsError("invalid-argument", "programId must be a non-empty string");
  if (!programData || typeof programData !== "object" || Array.isArray(programData))
    throw new HttpsError("invalid-argument", "programData must be an object");
  assertAllowedFields(programData, "programData", PROFILE_PROGRAM_ALLOWED_FIELDS);

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
    beforeValue, programData, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (typeof scopeId !== "string" || !scopeId)
    throw new HttpsError("invalid-argument", "scopeId must be a non-empty string");
  if (!scopeData || typeof scopeData !== "object" || Array.isArray(scopeData))
    throw new HttpsError("invalid-argument", "scopeData must be an object");
  // No firestore.rules `.hasOnly()` counterpart for curriculum_scopes — it's
  // intentionally open-ended even for the owner's own direct writes, so only
  // the size cap applies here (null = no key whitelist).
  assertAllowedFields(scopeData, "scopeData", null);

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
    beforeValue, scopeData, writtenAt, request.data?.idempotencyKey,
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
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");

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
  const updates: Record<string, unknown> = { updated_at: writtenAt };
  if (displayName !== undefined) updates["display_name"] = displayName.trim();
  if (avatar !== undefined) updates["avatar"] = avatar;
  if (mode !== undefined) updates["mode"] = mode;

  // AUD-firebase-11: wrap the read+merge+write in a transaction, matching
  // the runTransaction pattern already used by acceptTutorInvite /
  // revokeTutorGrant / resignTutorGrant / expirePendingInvites in
  // tutor_invites.ts. Without this, a concurrent writer (the owner's own
  // device, or a second tutor) that changes an UNRELATED field on the same doc
  // between the plain get() and the full-document set(merge:false) has its
  // write silently clobbered — a lost-update race. A transaction detects
  // that the doc changed after its read and automatically retries the
  // callback with a fresh read, so the concurrent field survives.
  const beforeValue = await db.runTransaction(async (txn) => {
    const snap = await txn.get(profilePath);
    const before = snap.exists ? snap.data()! : null;
    const fullDoc = before ? { ...before, ...updates } : updates;
    txn.set(profilePath, fullDoc, { merge: false });
    return before;
  });

  await writeAuditLog(
    grantId, grant, callerUid,
    "profile_edited",
    `profile/${profileId}`,
    beforeValue ? {
      display_name: beforeValue["display_name"],
      avatar: beforeValue["avatar"],
      mode: beforeValue["mode"],
    } : null,
    updates, writtenAt, request.data?.idempotencyKey,
  );

  logger.info(
    `tutorEditProfile: tutor=${callerUid} grant=${grantId} ` +
      `ownerUid=${ownerUid} profileId=${profileId}`,
  );

  return { success: true };
});
