import * as admin from "firebase-admin";
import { auth, logger } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();
const db = admin.firestore();


/**
 * Triggered when a Firebase Auth user is deleted.
 * Cascades deletion to all Firestore data under `users/{uid}` using
 * Admin SDK recursiveDelete — no subcollection enumeration needed.
 */
export const onUserDeleted = auth.user().onDelete(async (user) => {
  const uid = user.uid;
  logger.info(`onUserDeleted: cascading delete for uid=${uid}`);
  await db.recursiveDelete(db.collection("users").doc(uid));
  logger.info(`onUserDeleted: complete for uid=${uid}`);
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
 * Expects: { profileId: number, curriculumId: string, trackType: string }
 * Returns: { success: true }
 */
export const deleteCurriculumTrack = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { profileId, curriculumId, trackType } = request.data ?? {};
  if (typeof profileId !== "number" || !Number.isInteger(profileId) || profileId <= 0) {
    throw new HttpsError("invalid-argument", "profileId must be a positive integer");
  }
  if (typeof curriculumId !== "string" || !curriculumId) {
    throw new HttpsError("invalid-argument", "curriculumId must be a non-empty string");
  }
  if (typeof trackType !== "string" || !trackType) {
    throw new HttpsError("invalid-argument", "trackType must be a non-empty string");
  }

  const docId = `${curriculumId}_${trackType}`;
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
