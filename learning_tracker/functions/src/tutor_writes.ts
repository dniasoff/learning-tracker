import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { db, CALL_OPTS } from "./shared";
import {
  ENTITY_COLLECTION,
  GovernedEntity,
  TOMBSTONE,
  ULID_RE,
  isDocIdSafe,
  removeTrackPlan,
  runGoverned,
  writeWithChangeLog,
} from "./write_with_change_log";

// ══════════════════════════════════════════════════════════════════════════════
// Tutor write-path Cloud Functions — S4 (Talmid-View Squad)
// ══════════════════════════════════════════════════════════════════════════════
//
// Two families live here:
//
// A. GOVERNED callables (sub-tracks AD-38 / AD-53, Story 1.10 / DNI-472) —
//    tutorUpsertGoal, tutorDeleteGoal, tutorUpsertTrack, tutorDeleteTrack,
//    tutorUpsertStudyDayConfig, tutorDeleteStudyDayConfig,
//    tutorUpsertStageDefinition, tutorUpsertCurriculumScope and
//    tutorSetProfileProgram. Each one is a thin adapter: it maps its stable
//    legacy request ({grantId, ownerUid, profileId, <id>, <data>} plus the
//    optional client ULID `actionId`) onto storage-shaped patches and writes
//    ONLY through `writeWithChangeLog`, which owns authentication, the single
//    `can_edit_learning` grant check (re-read in the transaction, so a revoked
//    grant stops the next call), the server-derived actor, AD-52 payload
//    validation, field-level merges, the `change_log` entry, tombstones and
//    idempotent replay. None of these callables checks a permission itself.
//
// B. LEGACY callables not governed by AD-38 — tutorResetCompletion,
//    tutorUpdateGamificationSettings, tutorUpsertBookmark (retired at the
//    cutover) and tutorEditProfile. They keep the per-call grant contract:
//      1. Caller must be authenticated.
//      2. Grant must be active and grant.tutor_uid must equal the caller uid.
//      3. grant.parent_uid must equal the supplied ownerUid.
//      4. grant.child_profile_id must equal the supplied profileId.
//      5. The specific TutorPermissions flag must be true (except
//         tutorEditProfile, which is always allowed for active tutors).
//      6. Write targets ONLY users/{ownerUid}/learner_profiles/{profileId}/…
//      7. An audit log entry is written to tutor_grants/{grantId}/audit_log/{autoId}.
//
// Admin SDK bypasses Firestore Security Rules — these checks are the sole
// enforcement layer for these write paths.

// ── AUD-firebase-10: field whitelist for the legacy bookmark CF ──────────────
//
// Admin SDK writes bypass firestore.rules entirely, so `assertAllowedFields`
// below is the only server-side gate on WHICH fields a legacy caller may write
// and how large they may be. The governed callables are validated against the
// AD-52 storage schema by `writeWithChangeLog` instead. preferences
// (gamification_settings) has no rules `.hasOnly()` counterpart, so only the
// size cap applies there (the `null` allowedKeys call site below).

const BOOKMARK_ALLOWED_FIELDS = [
  "profile_id", "curriculum_id", "content_item_id", "sefaria_ref",
  "stage_id", "updated_at", "synced_at",
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

// ══════════════════════════════════════════════════════════════════════════════
// A. Governed callables — rerouted through writeWithChangeLog (AD-38, AD-53)
// ══════════════════════════════════════════════════════════════════════════════
//
// Request (stable legacy shape + the optional client ULID):
//   { grantId, ownerUid, profileId, <idParam>: string, <dataParam>: object,
//     actionId?: ULID }
// `actionId` is the Story 1.8 owner-port action id (B13 ruling): a retry with
// the same actionId returns the stored result instead of writing again. When
// it is omitted the server generates one (no cross-call replay protection).
//
// Returns writeWithChangeLog's result: { success: true, action_id,
// change_ids, at (server-stamped change_log.at, ISO-8601), ... }.

/**
 * Bookkeeping keys that legacy clients still send but the server now owns or
 * that AD-38 retired from governed docs (`last_change_id` replaces
 * `updated_at` / `synced_at`). They are dropped — never written — so the
 * published request payloads stay valid; every other key is validated
 * against the AD-52 storage schema by writeWithChangeLog.
 */
const LEGACY_BOOKKEEPING_KEYS = new Set([
  "id", "goal_id", "profile_id", "track_id", "created_at", "updated_at", "synced_at",
]);

/** Legacy clients send ISO datetimes for AD-52 `YYYY-MM-DD` date fields. */
const LEGACY_DATE_FIELDS = new Set(["target_date", "tracking_start_date"]);

function normalizeLegacyFields(data: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (LEGACY_BOOKKEEPING_KEYS.has(key)) continue;
    if (LEGACY_DATE_FIELDS.has(key) && typeof value === "string" &&
      /^\d{4}-\d{2}-\d{2}T/.test(value) && !Number.isNaN(Date.parse(value))) {
      out[key] = new Date(value).toISOString().slice(0, 10);
      continue;
    }
    out[key] = value;
  }
  if (Object.keys(out).length === 0) {
    throw new HttpsError("invalid-argument", "No storage fields to write");
  }
  return out;
}

interface LegacyGovernedArgs {
  grantId: string;
  ownerUid: string;
  profileId: string;
  actionId?: string;
  targetId: string;
}

function parseLegacyGovernedArgs(raw: unknown, idParam: string): LegacyGovernedArgs {
  const data = (raw ?? {}) as Record<string, unknown>;
  const { grantId, ownerUid, profileId, actionId } = data;
  const targetId = data[idParam];
  if (typeof grantId !== "string" || !grantId)
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  if (typeof ownerUid !== "string" || !ownerUid)
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  if (typeof profileId !== "string" || !profileId)
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (!isDocIdSafe(targetId))
    throw new HttpsError("invalid-argument", `${idParam} must be a non-empty string`);
  if (actionId !== undefined && actionId !== null &&
    (typeof actionId !== "string" || !ULID_RE.test(actionId)))
    throw new HttpsError("invalid-argument", "actionId must be a ULID");
  return { grantId, ownerUid, profileId, targetId, actionId: actionId ?? undefined };
}

function parseLegacyData(raw: unknown, dataParam: string): Record<string, unknown> {
  const value = ((raw ?? {}) as Record<string, unknown>)[dataParam];
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new HttpsError("invalid-argument", `${dataParam} must be an object`);
  return normalizeLegacyFields(value as Record<string, unknown>);
}

interface LegacyGovernedSpec {
  entity: GovernedEntity;
  idParam: string;
  auditAction: string;
}

/** Field-level upsert of one governed doc through writeWithChangeLog. */
function governedUpsert(spec: LegacyGovernedSpec & { dataParam: string }) {
  const collection = ENTITY_COLLECTION[spec.entity];
  return onCall(CALL_OPTS, (request) => runGoverned(spec.entity, async () => {
    const args = parseLegacyGovernedArgs(request.data, spec.idParam);
    const fields = parseLegacyData(request.data, spec.dataParam);
    // goal / mainTrack / mainTrackProgram: entity_id is the doc id. Other
    // mainTrack* entities key on curriculum_id, derived in the transaction
    // from the payload or the stored doc when the payload omits it.
    const entityId = spec.entity === "goal" || spec.entity === "mainTrack" ||
      spec.entity === "mainTrackProgram"
      ? args.targetId
      : typeof fields.curriculum_id === "string" ? fields.curriculum_id : undefined;
    return writeWithChangeLog(request.auth, {
      ownerUid: args.ownerUid,
      profileId: args.profileId,
      grantId: args.grantId,
      actionId: args.actionId,
      auditAction: spec.auditAction,
      entries: [{ entity: spec.entity, entityId, docs: [{ collection, docId: args.targetId, fields }] }],
    });
  }));
}

/** Tombstone (`ended_at`) of one governed doc — never a delete. */
function governedTombstone(spec: LegacyGovernedSpec) {
  const collection = ENTITY_COLLECTION[spec.entity];
  return onCall(CALL_OPTS, (request) => runGoverned(spec.entity, async () => {
    const args = parseLegacyGovernedArgs(request.data, spec.idParam);
    return writeWithChangeLog(request.auth, {
      ownerUid: args.ownerUid,
      profileId: args.profileId,
      grantId: args.grantId,
      actionId: args.actionId,
      auditAction: spec.auditAction,
      entries: [{
        entity: spec.entity,
        entityId: spec.entity === "goal" ? args.targetId : undefined,
        docs: [{ collection, docId: args.targetId, fields: { ended_at: TOMBSTONE } }],
      }],
    });
  }));
}

// tutorUpsertGoal — { goalId: "{curriculumId}_deadline" | "{curriculumId}_pace", goalData }
// Rejected on a calendar-program curriculum (AD-43 / AD-45).
export const tutorUpsertGoal = governedUpsert({
  entity: "goal", idParam: "goalId", dataParam: "goalData", auditAction: "goal_upserted",
});

// tutorDeleteGoal — { goalId } → `ended_at` tombstone.
export const tutorDeleteGoal = governedTombstone({
  entity: "goal", idParam: "goalId", auditAction: "goal_deleted",
});

// tutorUpsertTrack — { trackId: curriculumId, trackData } (mainTrack).
export const tutorUpsertTrack = governedUpsert({
  entity: "mainTrack", idParam: "trackId", dataParam: "trackData", auditAction: "track_upserted",
});

// tutorDeleteTrack — { trackId: curriculumId } → the AD-38 remove-track
// action: one mainTrack `ended_at` entry + one subTrack tombstone per live
// sub-track, shared action_id (same action as deleteCurriculumTrack).
export const tutorDeleteTrack = onCall(CALL_OPTS, (request) => runGoverned("mainTrack", async () => {
  const args = parseLegacyGovernedArgs(request.data, "trackId");
  return writeWithChangeLog(request.auth, {
    ownerUid: args.ownerUid,
    profileId: args.profileId,
    grantId: args.grantId,
    actionId: args.actionId,
    auditAction: "track_deleted",
    plan: removeTrackPlan(args.targetId),
    replayScope: [{ entity: "mainTrack", entityId: args.targetId }, { entity: "subTrack" }],
  });
}));

// tutorUpsertStageDefinition — { stageId, stageData } (mainTrackStages).
export const tutorUpsertStageDefinition = governedUpsert({
  entity: "mainTrackStages", idParam: "stageId", dataParam: "stageData",
  auditAction: "stage_definition_upserted",
});

// tutorUpsertStudyDayConfig — { configId, configData } (mainTrackStudyDays).
export const tutorUpsertStudyDayConfig = governedUpsert({
  entity: "mainTrackStudyDays", idParam: "configId", dataParam: "configData",
  auditAction: "study_day_config_upserted",
});

// tutorDeleteStudyDayConfig — { configId } → `ended_at` tombstone.
export const tutorDeleteStudyDayConfig = governedTombstone({
  entity: "mainTrackStudyDays", idParam: "configId", auditAction: "study_day_config_deleted",
});

// tutorSetProfileProgram — { programId: curriculumId, programData } (mainTrackProgram).
export const tutorSetProfileProgram = governedUpsert({
  entity: "mainTrackProgram", idParam: "programId", dataParam: "programData",
  auditAction: "profile_program_set",
});

// tutorUpsertCurriculumScope — { scopeId, scopeData } (mainTrackScope).
export const tutorUpsertCurriculumScope = governedUpsert({
  entity: "mainTrackScope", idParam: "scopeId", dataParam: "scopeData",
  auditAction: "curriculum_scope_upserted",
});

// ══════════════════════════════════════════════════════════════════════════════
// B. Legacy (non-governed) callables
// ══════════════════════════════════════════════════════════════════════════════

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

// ── tutorEditProfile ──────────────────────────────────────────────────────────
//
// Field-level merge of display_name, avatar and mode — and nothing else — on
// the child's learner_profiles/{profileId} doc (AD-37: governed learner
// settings and every other profile field are out of this callable's reach).
// No additional permission flag — editing the profile is parent-equivalent
// for any active tutor (FR-3 "Edit child profile: display name, avatar, mode").
//
// Expects:
//   {
//     grantId, ownerUid, profileId,
//     displayName?: string,   // new display name (1–100 chars)
//     avatar?: string,        // new avatar identifier
//     mode?: string,          // 'child' | 'adult'
//   }
// Any other request key is rejected. Returns: { success: true }

const ALLOWED_PROFILE_MODES = new Set(["child", "adult"]);
const EDIT_PROFILE_REQUEST_KEYS = new Set([
  "grantId", "ownerUid", "profileId", "displayName", "avatar", "mode", "idempotencyKey",
]);

export const tutorEditProfile = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const data = (request.data ?? {}) as Record<string, unknown>;
  for (const key of Object.keys(data)) {
    if (!EDIT_PROFILE_REQUEST_KEYS.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }
  const { grantId, ownerUid, profileId, displayName, avatar, mode } = data;

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
  if (mode !== undefined && (typeof mode !== "string" || !ALLOWED_PROFILE_MODES.has(mode))) {
    throw new HttpsError(
      "invalid-argument",
      `mode must be one of: ${[...ALLOWED_PROFILE_MODES].join(", ")}`,
    );
  }

  // tutorEditProfile is parent-equivalent — no specific permission flag (null).
  const { grant, profilePath, writtenAt } = await verifyTutorGrant(
    callerUid, grantId, ownerUid, profileId, null,
  );

  const updates: Record<string, unknown> = {};
  if (typeof displayName === "string") updates["display_name"] = displayName.trim();
  if (typeof avatar === "string") updates["avatar"] = avatar;
  if (typeof mode === "string") updates["mode"] = mode;

  // Field-level merge (AD-37 / AD-38): only the three fields are written, so a
  // concurrent writer's unrelated fields (including governed learner settings
  // and last_change_id) are never read-modify-written or clobbered. update()
  // also refuses to conjure a profile doc that does not exist.
  // The before-values are read only for the security audit entry; the write
  // itself never depends on them.
  const beforeSnap = await profilePath.get();
  try {
    await profilePath.update(updates);
  } catch (err) {
    if ((err as { code?: number }).code === 5) {
      throw new HttpsError("not-found", "Learner profile not found");
    }
    throw err;
  }

  await writeAuditLog(
    grantId, grant, callerUid,
    "profile_edited",
    `profile/${profileId}`,
    beforeSnap.exists ? {
      display_name: beforeSnap.get("display_name"),
      avatar: beforeSnap.get("avatar"),
      mode: beforeSnap.get("mode"),
    } : null,
    updates, writtenAt, data.idempotencyKey as string | undefined,
  );

  return { success: true };
});
