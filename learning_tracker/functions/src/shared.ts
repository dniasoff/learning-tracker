import * as admin from "firebase-admin";

// Admin SDK init lives here because every other module in this deployment
// imports `db` from this file — Node's module cache guarantees
// initializeApp() runs exactly once regardless of import order or how many
// of the sibling modules end up pulling this one in.
admin.initializeApp();

/** Shared Firestore handle used by every Cloud Function in this deployment. */
export const db = admin.firestore();

// Shared callable options. enforceAppCheck rejects any call that does not carry
// a valid App Check token, so only our genuine app builds (Play Integrity in
// release, the registered debug token in development) can invoke these
// functions. The client attaches tokens automatically once App Check is
// activated at startup (see firebase_bootstrap.dart).
export const CALL_OPTS = { enforceAppCheck: true } as const;

// ── Shared helpers ────────────────────────────────────────────────────────────

/** Encode an email for use in a Firestore doc ID (mirrors Dart TutorGrantDoc.buildGrantId). */
export function encodeEmailForDocId(email: string): string {
  return email.toLowerCase().replace(/[^a-zA-Z0-9]/g, "_");
}

/** Build the tutor_active_access doc ID: {tutorUid}_{parentUid}_{profileId}. */
export function buildAccessId(tutorUid: string, parentUid: string, profileId: string): string {
  return `${tutorUid}_${parentUid}_${profileId}`;
}
