import * as crypto from "crypto";

import admin from "firebase-admin";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";

import { db, CALL_OPTS } from "./shared";
import { ULID_RE } from "./write_with_change_log";

const PIN_RE = /^\d{4}$/;
const SESSION_ID_RE = /^[a-f0-9]{64}$/;
const PIN_HASH_VERSION = "scrypt-v1";
const PIN_KEY_LENGTH = 32;
const SESSION_TTL_MS = 30 * 60 * 1000;
const MAX_PIN_ATTEMPTS = 5;
const PIN_LOCKOUT_MS = 15 * 60 * 1000;
const MAX_REAUTH_AGE_SECONDS = 5 * 60;

type AuthenticatedCall = CallableRequest<unknown>;

function dataOf(request: AuthenticatedCall): Record<string, unknown> {
  return (request.data ?? {}) as Record<string, unknown>;
}

function requireKnownKeys(data: Record<string, unknown>, keys: Set<string>): void {
  for (const key of Object.keys(data)) {
    if (!keys.has(key)) throw new HttpsError("invalid-argument", `Unexpected field: ${key}`);
  }
}

function requireAuth(request: AuthenticatedCall): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");
  return uid;
}

function requireRecentReauthentication(request: AuthenticatedCall): void {
  const authTime = Number(request.auth?.token?.auth_time);
  const now = Math.floor(Date.now() / 1000);
  if (!Number.isFinite(authTime) || authTime <= 0 || now - authTime > MAX_REAUTH_AGE_SECONDS) {
    throw new HttpsError("failed-precondition", "Recent account reauthentication is required");
  }
}

function requireProfileId(value: unknown): string {
  if (typeof value !== "string" || !ULID_RE.test(value)) {
    throw new HttpsError("invalid-argument", "profileId must be a valid ULID");
  }
  return value;
}

function requirePin(value: unknown): string {
  if (typeof value !== "string" || !PIN_RE.test(value)) {
    throw new HttpsError("invalid-argument", "pin must be exactly four digits");
  }
  return value;
}

function requireSessionId(value: unknown): string {
  if (typeof value !== "string" || !SESSION_ID_RE.test(value)) {
    throw new HttpsError("invalid-argument", "parentSessionId must be a valid session id");
  }
  return value;
}

function pinSecretRef(uid: string, profileId: string): FirebaseFirestore.DocumentReference {
  return db.collection("users").doc(uid)
    .collection("private_security").doc("parent_pins")
    .collection("profiles").doc(profileId);
}

export function parentSessionRef(uid: string, sessionId: string): FirebaseFirestore.DocumentReference {
  return db.collection("users").doc(uid)
    .collection("parent_sessions").doc(sessionId);
}

function scrypt(password: string, salt: Buffer, keyLength: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, keyLength, (error, derived) => {
      if (error) reject(error);
      else resolve(derived);
    });
  });
}

async function hashPin(pin: string): Promise<string> {
  const salt = crypto.randomBytes(16);
  const derived = await scrypt(pin, salt, PIN_KEY_LENGTH);
  return `${PIN_HASH_VERSION}$${salt.toString("base64url")}$${derived.toString("base64url")}`;
}

async function verifyPin(pin: string, encoded: unknown): Promise<boolean> {
  if (typeof encoded !== "string") return false;
  const [version, saltText, digestText] = encoded.split("$");
  if (version !== PIN_HASH_VERSION || !saltText || !digestText) return false;
  try {
    const salt = Buffer.from(saltText, "base64url");
    const expected = Buffer.from(digestText, "base64url");
    const actual = await scrypt(pin, salt, expected.length);
    return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
  } catch {
    return false;
  }
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
 * Validates a parent session inside a Firestore transaction. Reading the
 * session before writing the profile makes a concurrent revoke conflict the
 * transaction rather than allowing a stale owner call to commit.
 */
export async function assertActiveParentSessionInTransaction(
  transaction: FirebaseFirestore.Transaction,
  uid: string,
  profileId: string,
  sessionId: string,
): Promise<void> {
  const ref = parentSessionRef(uid, requireSessionId(sessionId));
  const snapshot = await transaction.get(ref);
  if (!snapshot.exists || !activeSessionData(snapshot.data(), profileId)) {
    throw new HttpsError("permission-denied", "Parent session is missing, revoked, or expired");
  }
}

/** Sets the server-owned parent PIN after recent Firebase account reauth. */
export const setParentPin = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  requireRecentReauthentication(request);
  const data = dataOf(request);
  requireKnownKeys(data, new Set(["profileId", "pin"]));
  const profileId = requireProfileId(data.profileId);
  const pin = requirePin(data.pin);
  const profileRef = db.collection("users").doc(uid)
    .collection("learner_profiles").doc(profileId);
  const profile = await profileRef.get();
  if (!profile.exists) throw new HttpsError("not-found", "Learner profile not found");
  if (profile.get("mode") !== "child" && profile.get("mode") !== "adult") {
    throw new HttpsError("failed-precondition", "Parent PINs are only set for learner profiles");
  }

  await pinSecretRef(uid, profileId).set({
    hash: await hashPin(pin),
    failed_attempts: 0,
    locked_until: null,
    updated_at: admin.firestore.Timestamp.now(),
  });
  await revokeAllParentSessions(uid, profileId);
  return { success: true };
});

/** Creates a 30-minute parent session after server-side PIN verification. */
export const createParentSession = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = dataOf(request);
  requireKnownKeys(data, new Set(["profileId", "pin"]));
  const profileId = requireProfileId(data.profileId);
  const profileRef = db.collection("users").doc(uid)
    .collection("learner_profiles").doc(profileId);
  const profile = await profileRef.get();
  if (!profile.exists) throw new HttpsError("not-found", "Learner profile not found");

  // An adult profile without a server PIN intentionally remains usable by
  // anyone holding the already-signed-in device; that is the product's
  // existing boundary, and the server cannot make it stricter without
  // changing that UX. If an adult profile does have a server PIN, however,
  // it follows the same verification and lockout path as a child profile.
  const secretRef = pinSecretRef(uid, profileId);
  const secret = await secretRef.get();
  if (secret.exists || profile.get("mode") === "child") {
    const pin = requirePin(data.pin);
    if (!secret.exists) {
      throw new HttpsError("failed-precondition", "Parent PIN enrollment is required");
    }
    const result = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(secretRef);
      if (!current.exists) {
        return { verified: false, locked: false };
      }
      const secretData = current.data()!;
      const lockedUntil = timestamp(secretData.locked_until);
      if (lockedUntil && lockedUntil.toMillis() > Date.now()) {
        return { verified: false, locked: true };
      }
      if (await verifyPin(pin, secretData.hash)) {
        transaction.set(secretRef, { failed_attempts: 0, locked_until: null }, { merge: true });
        return { verified: true, locked: false };
      }

      const attempts = Number(secretData.failed_attempts ?? 0) + 1;
      const locked = attempts >= MAX_PIN_ATTEMPTS;
      const update: FirebaseFirestore.UpdateData<FirebaseFirestore.DocumentData> = {
        failed_attempts: attempts,
        ...(locked
          ? { locked_until: admin.firestore.Timestamp.fromMillis(Date.now() + PIN_LOCKOUT_MS) }
          : {}),
      };
      transaction.set(secretRef, update, { merge: true });
      return { verified: false, locked };
    });
    if (!result.verified) {
      throw new HttpsError(
        result.locked ? "resource-exhausted" : "permission-denied",
        result.locked ? "Parent PIN is temporarily locked" : "Incorrect parent PIN",
      );
    }
  }

  const sessionId = crypto.randomBytes(32).toString("hex");
  const createdAt = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(createdAt.toMillis() + SESSION_TTL_MS);
  await parentSessionRef(uid, sessionId).set({
    profile_id: profileId,
    created_at: createdAt,
    expires_at: expiresAt,
    revoked: false,
  });
  return { sessionId, expiresAt };
});

/** Revokes a session; repeated revocation is intentionally idempotent. */
export const revokeParentSession = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = dataOf(request);
  requireKnownKeys(data, new Set(["parentSessionId"]));
  const sessionId = requireSessionId(data.parentSessionId);
  const ref = parentSessionRef(uid, sessionId);
  const snapshot = await ref.get();
  if (!snapshot.exists) return { success: true, alreadyRevoked: true };
  await ref.set({ revoked: true, revoked_at: admin.firestore.Timestamp.now() }, { merge: true });
  return { success: true, alreadyRevoked: snapshot.get("revoked") === true };
});

async function revokeAllParentSessions(uid: string, profileId: string): Promise<void> {
  const sessions = await db.collection("users").doc(uid)
    .collection("parent_sessions")
    .where("profile_id", "==", profileId)
    .where("revoked", "==", false)
    .get();
  if (sessions.empty) return;
  const batch = db.batch();
  const revokedAt = admin.firestore.Timestamp.now();
  for (const session of sessions.docs) batch.update(session.ref, { revoked: true, revoked_at: revokedAt });
  await batch.commit();
}
