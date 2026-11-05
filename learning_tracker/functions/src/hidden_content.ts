import admin from "firebase-admin";
import { logger } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { db, CALL_OPTS } from "./shared";
import { isKnownHiddenContentRef } from "./hidden_content_manifest";
import { assertActiveParentSessionInTransaction } from "./parent_session_validation";
import { ULID_RE } from "./write_with_change_log";

const REQUEST_KEYS = new Set(["ownerUid", "profileId", "hiddenRefs", "grantId", "parentSessionId"]);
const MAX_HIDDEN_REFS = 500;
const MAX_REF_LENGTH = 500;

function validateHiddenRefs(value: unknown): string[] {
  if (!Array.isArray(value) || value.length > MAX_HIDDEN_REFS ||
    !value.every((ref) => typeof ref === "string" && ref.length > 0 &&
      ref.length <= MAX_REF_LENGTH && isKnownHiddenContentRef(ref))) {
    throw new HttpsError(
      "invalid-argument",
      `hiddenRefs must contain known hierarchy refs and be an array of at most ${MAX_HIDDEN_REFS} non-empty strings (max ${MAX_REF_LENGTH} characters each)`,
    );
  }
  return value as string[];
}

/**
 * Replace a child's hidden node refs. Owner calls follow the established
 * parent-session contract: parent PIN validation is device-local and the
 * callable authorizes the owning account UID. Tutor calls must carry a grant
 * that is re-read and bound to this caller, owner and child in the transaction.
 * Direct client writes to `hidden_content_refs` are denied by Firestore rules.
 */
export const setProfileHiddenContent = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) throw new HttpsError("unauthenticated", "Must be signed in");

  const data = (request.data ?? {}) as Record<string, unknown>;
  for (const key of Object.keys(data)) {
    if (!REQUEST_KEYS.has(key)) {
      throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
    }
  }

  const { ownerUid, profileId, grantId } = data;
  if (typeof ownerUid !== "string" || !ownerUid) {
    throw new HttpsError("invalid-argument", "ownerUid must be a non-empty string");
  }
  if (typeof profileId !== "string" || !ULID_RE.test(profileId)) {
    throw new HttpsError("invalid-argument", "profileId must be a valid ULID");
  }
  const hiddenRefs = validateHiddenRefs(data.hiddenRefs);
  const parentSessionRequired = request.auth?.token?.parent_session_enforced === true;
  if (parentSessionRequired && data.parentSessionId !== undefined &&
    (typeof data.parentSessionId !== "string" || !data.parentSessionId)) {
    throw new HttpsError("invalid-argument", "parentSessionId must be a non-empty string");
  }

  const isTutorCall = grantId !== undefined;
  if (isTutorCall && (typeof grantId !== "string" || !grantId)) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }
  const parentSessionId = data.parentSessionId;
  if (!isTutorCall && parentSessionRequired) {
    if (typeof parentSessionId !== "string" || !parentSessionId) {
      throw new HttpsError("permission-denied", "A server-issued parent session is required");
    }
  }
  if (!isTutorCall && callerUid !== ownerUid) {
    throw new HttpsError("permission-denied", "Only the profile owner can edit hidden content");
  }

  const profileRef = db.collection("users").doc(ownerUid)
    .collection("learner_profiles").doc(profileId);
  let tutorGrant: FirebaseFirestore.DocumentData | undefined;

  await db.runTransaction(async (txn) => {
    if (!isTutorCall && parentSessionRequired) {
      await assertActiveParentSessionInTransaction(
        txn,
        ownerUid,
        profileId,
        parentSessionId as string,
      );
    }
    if (isTutorCall) {
      const grantRef = db.collection("tutor_grants").doc(grantId as string);
      const grantSnap = await txn.get(grantRef);
      if (!grantSnap.exists) throw new HttpsError("not-found", "Tutor grant not found");

      const grant = grantSnap.data()!;
      if (grant.state !== "active" || grant.tutor_uid !== callerUid ||
        grant.parent_uid !== ownerUid || String(grant.child_profile_id) !== profileId) {
        throw new HttpsError("permission-denied", "Active tutor grant does not match this profile");
      }
      tutorGrant = grant;
    }

    const profileSnap = await txn.get(profileRef);
    if (!profileSnap.exists) throw new HttpsError("not-found", "Learner profile not found");
    if (profileSnap.get("mode") !== "child") {
      throw new HttpsError("failed-precondition", "Hidden content can only be set on a child profile");
    }

    txn.update(profileRef, {
      hidden_content_refs: hiddenRefs,
    });
  });

  if (tutorGrant) {
    try {
      await db.collection("tutor_grants").doc(grantId as string)
        .collection("audit_log").add({
          tutor_uid: callerUid,
          tutor_name_snapshot: tutorGrant.tutor_name_snapshot ?? "",
          action: "hidden_content_updated",
          target: `profile/${profileId}`,
          after_value: JSON.stringify(hiddenRefs),
          timestamp: admin.firestore.Timestamp.now().toDate().toISOString(),
        });
    } catch (error) {
      logger.warn("setProfileHiddenContent: tutor audit write failed", error);
    }
  }

  return { success: true };
});
