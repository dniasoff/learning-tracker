import * as admin from "firebase-admin";
import { auth, logger } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();
const db = admin.firestore();

/**
 * Recursively deletes all documents in a Firestore collection.
 */
async function deleteCollection(ref: admin.firestore.CollectionReference): Promise<number> {
  const snapshot = await ref.limit(500).get();
  if (snapshot.empty) return 0;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  // Recurse for collections larger than 500 docs
  return snapshot.size + (snapshot.size === 500 ? await deleteCollection(ref) : 0);
}

/**
 * Triggered when a Firebase Auth user is deleted.
 * Cascades the deletion to all Firestore data under `users/{uid}`.
 *
 * Collection structure:
 *   users/{uid}/learner_profiles/{profileId}/{subcollection}/...
 *   users/{uid}/profile/data          (account-level)
 *   users/{uid}/streak/current        (legacy flat)
 *   users/{uid}/{subcollection}/...   (legacy flat)
 */
export const onUserDeleted = auth.user().onDelete(async (user) => {
  const uid = user.uid;
  logger.info(`Cascading delete for user ${uid}`);

  const userDocRef = db.collection("users").doc(uid);

  // --- 1. Delete profile-scoped subcollections (canonical path) ---
  const profilesSnapshot = await userDocRef.collection("learner_profiles").get();

  const profileSubcollections = [
    "completions",
    "bookmarks",
    "settings",
    "goals",
    "rewards",
    "learning_ledger",
    "active_curricula",
    "curriculum_imports",
    "curriculum_tracks",
    "profile_programs",
    "notification_settings",
    "gamification_settings",
  ];

  for (const profileDoc of profilesSnapshot.docs) {
    for (const sub of profileSubcollections) {
      await deleteCollection(profileDoc.ref.collection(sub));
    }
    // Delete streak/data within each profile
    await profileDoc.ref.collection("streak").doc("data").delete()
      .catch(() => { /* may not exist */ });
    // Delete active_curricula/data within each profile
    await profileDoc.ref.collection("active_curricula").doc("data").delete()
      .catch(() => { /* may not exist */ });
    // Delete the profile document itself
    await profileDoc.ref.delete();
  }

  // Legacy cleanup: old profile-scoped path users/{uid}/profiles/{profileId}
  const legacyProfilesSnapshot = await userDocRef.collection("profiles").get();
  for (const profileDoc of legacyProfilesSnapshot.docs) {
    for (const sub of profileSubcollections) {
      await deleteCollection(profileDoc.ref.collection(sub));
    }
    await profileDoc.ref.collection("streak").doc("data").delete()
      .catch(() => { /* may not exist */ });
    await profileDoc.ref.collection("active_curricula").doc("data").delete()
      .catch(() => { /* may not exist */ });
    await profileDoc.ref.delete().catch(() => { /* may not exist */ });
  }

  // --- 2. Delete legacy flat subcollections (pre-profile-scoping) ---
  const legacySubcollections = [
    "completions",
    "bookmarks",
    "settings",
    "goals",
    "rewards",
    "learning_ledger",
    "active_curricula",
    "curriculum_imports",
    "curriculum_tracks",
    "profile_programs",
    "notification_settings",
    "gamification_settings",
    "profile",
    "learner_profiles",
    "profiles",
  ];

  for (const sub of legacySubcollections) {
    await deleteCollection(userDocRef.collection(sub));
  }

  // Delete legacy streak/current
  await userDocRef.collection("streak").doc("current").delete()
    .catch(() => { /* may not exist */ });

  // --- 3. Delete the user document itself ---
  await userDocRef.delete();

  logger.info(`Successfully deleted all Firestore data for user ${uid}`);
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
