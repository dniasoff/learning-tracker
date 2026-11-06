import admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

import { db } from "./shared";

const SESSION_ID_RE = /^[a-f0-9]{64}$/;

export function requireParentSessionId(value: unknown): string {
  if (typeof value !== "string" || !SESSION_ID_RE.test(value)) {
    throw new HttpsError("invalid-argument", "parentSessionId must be a valid session id");
  }
  return value;
}

export function parentSessionRef(
  uid: string,
  sessionId: string,
): FirebaseFirestore.DocumentReference {
  return db.collection("users").doc(uid)
    .collection("parent_sessions").doc(sessionId);
}

function timestamp(value: unknown): admin.firestore.Timestamp | null {
  return value instanceof admin.firestore.Timestamp ? value : null;
}

function activeSessionData(
  data: FirebaseFirestore.DocumentData | undefined,
  profileId: string,
  now = admin.firestore.Timestamp.now(),
): boolean {
  if (!data || data.profile_id !== profileId || data.revoked !== false) return false;
  const createdAt = timestamp(data.created_at);
  const expiresAt = timestamp(data.expires_at);
  return createdAt !== null && expiresAt !== null &&
    createdAt.toMillis() <= now.toMillis() && expiresAt.toMillis() > now.toMillis();
}

/**
 * Reads the lease in the same transaction as the Admin-SDK write. A revoke
 * that commits before this transaction commits therefore forces a retry and
 * cannot leave a stale parent write behind.
 */
export async function assertActiveParentSessionInTransaction(
  transaction: FirebaseFirestore.Transaction,
  uid: string,
  profileId: string,
  sessionId: unknown,
): Promise<void> {
  const ref = parentSessionRef(uid, requireParentSessionId(sessionId));
  const snapshot = await transaction.get(ref);
  if (!snapshot.exists || !activeSessionData(snapshot.data(), profileId)) {
    throw new HttpsError("permission-denied", "Parent session is missing, revoked, or expired");
  }
}
