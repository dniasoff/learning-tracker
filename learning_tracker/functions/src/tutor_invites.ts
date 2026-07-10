import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { logger, pubsub } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { db, CALL_OPTS, encodeEmailForDocId, buildAccessId } from "./shared";

// ══════════════════════════════════════════════════════════════════════════════
// V2-R3 C3 — Tutor grant lifecycle Cloud Functions
// ══════════════════════════════════════════════════════════════════════════════
//
// All grant state mutations are server-side (Admin SDK) to prevent clients from
// forging active grants. The `tutor_active_access` secondary index is maintained
// alongside grant-state changes to enable O(1) subcollection read checks in
// Firestore Security Rules (V2-R3 C2).
//
// Doc-id formula for tutor_active_access: {tutorUid}_{parentUid}_{profileId}
// This mirrors the hasActiveTutorAccess() helper in firestore.rules.
//
// Grant doc-id formula: {encodedEmail}__{parentUid}__{childProfileId}
// The encoded email replaces any non-alphanumeric char with '_'.

// ── inviteTutor ───────────────────────────────────────────────────────────────
//
// Creates a pending grant document for a tutor invite.
//
// Expects:
//   {
//     tutorEmail: string,           // tutor's email address (lower-cased by CF)
//     childProfileId: string,       // profile ID (string) of the tutored child
//     permissions: object,          // TutorPermissions serialised map (optional)
//   }
//
// Returns: { success: true, grantId: string }

export const inviteTutor = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { tutorEmail, childProfileId, permissions, childName, parentName } =
    request.data ?? {};

  if (typeof tutorEmail !== "string" || !tutorEmail.includes("@")) {
    throw new HttpsError("invalid-argument", "tutorEmail must be a valid email address");
  }
  if (typeof childProfileId !== "string" || !childProfileId) {
    throw new HttpsError("invalid-argument", "childProfileId must be a non-empty string");
  }

  // Snapshot human-readable names at invite time so the tutor sees the child's
  // name (and inviting parent) instead of a raw profile id / generic label.
  const sanitizeName = (v: unknown): string | null =>
    typeof v === "string" && v.trim() ? v.trim().slice(0, 100) : null;
  const childNameSnapshot = sanitizeName(childName);
  const parentNameSnapshot = sanitizeName(parentName);

  // NOTE: we intentionally do NOT verify a Firestore learner_profiles doc
  // exists for childProfileId. Profiles are offline-first (Drift-local) and a
  // child may have no synced cloud doc yet, so such a check wrongly blocks a
  // legitimate invite. It is also unnecessary for isolation: parent_uid is
  // hard-set to the caller below, so the grant always lands in the caller's
  // own namespace and cannot reference another user's data.

  const normalEmail = tutorEmail.trim().toLowerCase();
  const encodedEmail = encodeEmailForDocId(normalEmail);
  const grantId = `${encodedEmail}__${callerUid}__${childProfileId}`;

  // AUD-firebase-02: grantId is deterministic, so a second inviteTutor call
  // for the same tutor+child pair would otherwise silently overwrite the
  // SAME doc unconditionally — resetting an already-active grant back to
  // 'pending' with fresh request-supplied default permissions (while the
  // existing tutor_active_access index doc is untouched, leaving the tutor
  // with live read access even though tutor_grants.state now says
  // 'pending'). Reject re-invites while the grant is active; the caller
  // should use the permission-editing flow instead.
  const existingSnap = await db.collection("tutor_grants").doc(grantId).get();
  if (existingSnap.exists && existingSnap.data()!.state === "active") {
    throw new HttpsError(
      "failed-precondition",
      `A tutor grant for ${normalEmail} on this child is already active. ` +
        "Use the permission-editing flow to change it instead of re-inviting."
    );
  }

  const now = admin.firestore.Timestamp.now();
  const expiresAt = new Date(now.toDate().getTime() + 7 * 24 * 60 * 60 * 1000);

  // Generate a 256-bit random invite token (NFR-3).
  const inviteToken = crypto.randomBytes(32).toString("hex");

  const defaultPermissions = {
    can_view_progress: true,
    can_view_content: true,
    can_bulk_prior_completion: true,
    can_reset_completion: false,
    can_edit_goals: false,
    can_edit_stages: false,
    can_edit_rewards: false,
    can_edit_study_days: false,
    can_edit_points: false,
  };

  const grantData = {
    grant_id: grantId,
    parent_uid: callerUid,
    child_profile_id: childProfileId,
    tutor_email: normalEmail,
    tutor_uid: null,
    state: "pending",
    invite_token: inviteToken,
    permissions: permissions ?? defaultPermissions,
    child_name: childNameSnapshot,
    parent_name: parentNameSnapshot,
    invited_at: now,
    updated_at: now,
    expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
  };

  await db.collection("tutor_grants").doc(grantId).set(grantData, { merge: false });

  logger.info(`inviteTutor: parent=${callerUid} grantId=${grantId} email=${normalEmail}`);
  return { success: true, grantId };
});

// ── acceptTutorInvite ─────────────────────────────────────────────────────────
//
// Tutor accepts a pending invite. Validates that:
//   1. The grant exists and is in pending state.
//   2. The grant has not expired (server-side, not relying on client state).
//   3. The caller's authenticated email matches grant.tutor_email.
//      (This is the security check that prevents anyone from claiming an invite
//       without owning the invited email address.)
//
// On success:
//   - Updates grant state to 'active', sets tutor_uid and accepted_at.
//   - Writes tutor_active_access/{tutorUid}_{parentUid}_{profileId}.
//   - Clears the invite_token (single-use, per NFR-3).
//   - Captures tutor_name_snapshot from Firebase Auth (fixes H3 from V2-R3).
//
// Expects: { grantId: string }
// Returns: { success: true, grantId: string }

export const acceptTutorInvite = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.state !== "pending") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not in pending state (state=${grant.state})`
    );
  }

  // Check expiry — server-side enforcement.
  if (grant.expires_at && grant.expires_at.toDate() < new Date()) {
    // Transition to expired while we're here (opportunistic).
    await grantRef.update({
      state: "expired",
      updated_at: admin.firestore.Timestamp.now(),
    });
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} has expired`
    );
  }

  // Security gate: caller's email MUST match the invited email, AND that
  // email must be VERIFIED (AUD-firebase-01). Firebase Auth lets anyone
  // register an account with any unverified email string, so an attacker
  // could front-run registration of the invited tutor's email address and
  // otherwise pass the bare string-equality check below without ever
  // proving ownership of that inbox.
  const callerRecord = await admin.auth().getUser(callerUid);
  const callerEmail = (callerRecord.email ?? "").toLowerCase().trim();
  const grantEmail = (grant.tutor_email ?? "").toLowerCase().trim();
  if (callerEmail !== grantEmail || !callerRecord.emailVerified) {
    throw new HttpsError(
      "permission-denied",
      "Your account email does not match the invited tutor email, or is not verified"
    );
  }

  const now = admin.firestore.Timestamp.now();
  // Capture tutor display name for audit log snapshot (fixes H3).
  const tutorNameSnapshot = callerRecord.displayName ?? callerEmail;
  const profileId = String(grant.child_profile_id);
  const parentUid = String(grant.parent_uid);
  const accessId = buildAccessId(callerUid, parentUid, profileId);

  await db.runTransaction(async (txn) => {
    // 1. Update the grant document.
    txn.update(grantRef, {
      state: "active",
      tutor_uid: callerUid,
      tutor_name_snapshot: tutorNameSnapshot,
      accepted_at: now,
      updated_at: now,
      invite_token: admin.firestore.FieldValue.delete(), // single-use cleared
    });

    // 2. Write the tutor_active_access lookup document.
    const accessRef = db.collection("tutor_active_access").doc(accessId);
    txn.set(accessRef, {
      tutor_uid: callerUid,
      parent_uid: parentUid,
      child_profile_id: profileId,
      grant_id: grantId,
      created_at: now,
    });
  });

  // Write audit log entry (outside transaction — audit is best-effort).
  try {
    await db
      .collection("tutor_grants")
      .doc(grantId)
      .collection("audit_log")
      .add({
        tutor_uid: callerUid,
        tutor_name_snapshot: tutorNameSnapshot,
        action: "invite_accepted",
        target: `grant/${grantId}`,
        after_value: JSON.stringify({ state: "active" }),
        timestamp: now.toDate().toISOString(),
      });
  } catch (e) {
    logger.warn(`acceptTutorInvite: audit log write failed for grant=${grantId}`, e);
  }

  logger.info(`acceptTutorInvite: tutor=${callerUid} grantId=${grantId}`);
  return { success: true, grantId };
});

// ── declineTutorInvite ────────────────────────────────────────────────────────
//
// Tutor declines a pending invite. Validates caller email matches grant email.
//
// Expects: { grantId: string }
// Returns: { success: true }

export const declineTutorInvite = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  // Caller is the invited tutor either by uid (already linked) or by email
  // (invite not yet accepted). Check the uid first — it needs no Auth lookup —
  // and only fall back to the live getUser() email comparison when it doesn't
  // match, so the common path avoids an unnecessary Auth round-trip. The
  // email branch also requires emailVerified (AUD-firebase-01) — see
  // acceptTutorInvite's identical gate for why a bare string match isn't
  // sufficient proof of inbox ownership.
  const isTutorByUid = grant.tutor_uid === callerUid;
  let isTutorByEmail = false;
  if (!isTutorByUid) {
    const callerRecord = await admin.auth().getUser(callerUid);
    const callerEmail = (callerRecord.email ?? "").toLowerCase().trim();
    const grantEmail = (grant.tutor_email ?? "").toLowerCase().trim();
    isTutorByEmail = callerEmail === grantEmail && callerRecord.emailVerified === true;
  }

  if (!isTutorByEmail && !isTutorByUid) {
    throw new HttpsError("permission-denied", "You are not the invited tutor for this grant");
  }

  if (grant.state !== "pending") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not in pending state (state=${grant.state})`
    );
  }

  const now = admin.firestore.Timestamp.now();
  await grantRef.update({
    state: "declined",
    declined_at: now,
    updated_at: now,
    invite_token: admin.firestore.FieldValue.delete(),
  });

  logger.info(`declineTutorInvite: tutor=${callerUid} grantId=${grantId}`);
  return { success: true };
});

// ── rescindTutorInvite ────────────────────────────────────────────────────────
//
// Parent rescinds a pending invite (before tutor has accepted).
//
// Expects: { grantId: string }
// Returns: { success: true }

export const rescindTutorInvite = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.parent_uid !== callerUid) {
    throw new HttpsError("permission-denied", "Only the parent can rescind an invite");
  }
  if (grant.state !== "pending") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not in pending state (state=${grant.state})`
    );
  }

  const now = admin.firestore.Timestamp.now();
  await grantRef.update({
    state: "rescinded",
    revoked_at: now,
    updated_at: now,
    invite_token: admin.firestore.FieldValue.delete(),
  });

  logger.info(`rescindTutorInvite: parent=${callerUid} grantId=${grantId}`);
  return { success: true };
});

// ── revokeTutorGrant ──────────────────────────────────────────────────────────
//
// Parent revokes an active grant. Deletes tutor_active_access lookup doc.
//
// Expects: { grantId: string }
// Returns: { success: true }

export const revokeTutorGrant = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.parent_uid !== callerUid) {
    throw new HttpsError("permission-denied", "Only the parent can revoke a grant");
  }
  if (grant.state !== "active") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not active (state=${grant.state})`
    );
  }

  const now = admin.firestore.Timestamp.now();
  const tutorUid = String(grant.tutor_uid ?? "");
  const profileId = String(grant.child_profile_id);
  const accessId = buildAccessId(tutorUid, callerUid, profileId);

  await db.runTransaction(async (txn) => {
    txn.update(grantRef, {
      state: "revoked_by_parent",
      revoked_at: now,
      updated_at: now,
    });
    // Remove the access index so the tutor can no longer read subcollections.
    const accessRef = db.collection("tutor_active_access").doc(accessId);
    txn.delete(accessRef);
  });

  logger.info(`revokeTutorGrant: parent=${callerUid} grantId=${grantId} tutor=${tutorUid}`);
  return { success: true };
});

// ── resignTutorGrant ──────────────────────────────────────────────────────────
//
// Tutor resigns from an active grant. Deletes tutor_active_access lookup doc.
//
// Expects: { grantId: string }
// Returns: { success: true }

export const resignTutorGrant = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { grantId } = request.data ?? {};
  if (typeof grantId !== "string" || !grantId) {
    throw new HttpsError("invalid-argument", "grantId must be a non-empty string");
  }

  const grantRef = db.collection("tutor_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `Grant not found: ${grantId}`);
  }

  const grant = grantSnap.data()!;

  if (grant.tutor_uid !== callerUid) {
    throw new HttpsError("permission-denied", "Only the tutor can resign a grant");
  }
  if (grant.state !== "active") {
    throw new HttpsError(
      "failed-precondition",
      `Grant ${grantId} is not active (state=${grant.state})`
    );
  }

  const now = admin.firestore.Timestamp.now();
  const parentUid = String(grant.parent_uid);
  const profileId = String(grant.child_profile_id);
  const accessId = buildAccessId(callerUid, parentUid, profileId);

  await db.runTransaction(async (txn) => {
    txn.update(grantRef, {
      state: "revoked_by_tutor",
      revoked_at: now,
      updated_at: now,
    });
    const accessRef = db.collection("tutor_active_access").doc(accessId);
    txn.delete(accessRef);
  });

  logger.info(`resignTutorGrant: tutor=${callerUid} grantId=${grantId}`);
  return { success: true };
});

// ── listTutorGrants ───────────────────────────────────────────────────────────
//
// Returns tutor grants for the authenticated user.
// Mode 'incoming': grants where the caller is the tutor (all non-terminal states).
// Mode 'outgoing': grants where the caller is the parent, for a specific child.
//
// Expects: { mode: 'incoming' | 'outgoing', childProfileId?: string }
// Returns: { grants: TutorGrantDoc[] }

export const listTutorGrants = onCall(CALL_OPTS, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { mode, childProfileId } = request.data ?? {};
  if (mode !== "incoming" && mode !== "outgoing" && mode !== "pending_for_me") {
    throw new HttpsError(
      "invalid-argument",
      "mode must be 'incoming', 'outgoing', or 'pending_for_me'"
    );
  }

  let query: admin.firestore.Query;
  if (mode === "incoming") {
    query = db
      .collection("tutor_grants")
      .where("tutor_uid", "==", callerUid)
      .where("state", "in", ["pending", "active"]);
  } else if (mode === "pending_for_me") {
    // Pending invites are addressed by EMAIL (tutor_uid is null until accepted),
    // so a freshly signed-in tutor can discover invitations in-app and accept
    // without needing the emailed deep link. Match the caller's VERIFIED
    // email — the ID token's `email` claim being present does NOT imply
    // `email_verified`; those are separate claims (AUD-firebase-01). Without
    // this gate, an unverified account could enumerate (discover the
    // grantId of) an invite addressed to an email it doesn't own.
    const callerEmail = (request.auth?.token?.email ?? "").toLowerCase();
    const callerEmailVerified = request.auth?.token?.email_verified === true;
    if (!callerEmail || !callerEmailVerified) {
      return { grants: [] };
    }
    query = db
      .collection("tutor_grants")
      .where("tutor_email", "==", callerEmail)
      .where("state", "==", "pending");
  } else {
    if (typeof childProfileId !== "string" || !childProfileId) {
      throw new HttpsError("invalid-argument", "childProfileId required for outgoing mode");
    }
    query = db
      .collection("tutor_grants")
      .where("parent_uid", "==", callerUid)
      .where("child_profile_id", "==", childProfileId);
  }

  const snap = await query.get();
  // Serialise Firestore Timestamps to ISO-8601 strings so the wire format is
  // deterministic. The raw callable encoding of an Admin Timestamp is a
  // {_seconds,_nanoseconds} map, which the client parser used to choke on —
  // emit plain strings (matching the client's own toFirestore format).
  const TS_FIELDS = [
    "invited_at", "accepted_at", "declined_at",
    "revoked_at", "expires_at", "updated_at",
  ];
  const grants = snap.docs.map((d) => {
    const out: Record<string, unknown> = { id: d.id, ...d.data() };
    for (const k of TS_FIELDS) {
      const v = out[k];
      if (v instanceof admin.firestore.Timestamp) {
        out[k] = v.toDate().toISOString();
      }
    }
    return out;
  });
  return { grants };
});

// ══════════════════════════════════════════════════════════════════════════════
// V2-R3 C4 — Expire pending invites (scheduled, 7-day TTL)
// ══════════════════════════════════════════════════════════════════════════════
//
// Scheduled: daily at 01:00 UTC (offset from purgeExpiredAuditLogs at 02:00).
//
// Queries pending grants where expires_at < now, transitions them to 'expired'.
// Writes an audit log entry for each expiration.

export const expirePendingInvites = pubsub
  .schedule("0 1 * * *") // daily at 01:00 UTC
  .timeZone("UTC")
  .onRun(async (_context) => {
    const now = admin.firestore.Timestamp.now();
    logger.info(`expirePendingInvites: running at ${now.toDate().toISOString()}`);

    const snapshot = await db
      .collection("tutor_grants")
      .where("state", "==", "pending")
      .where("expires_at", "<=", now)
      .get();

    if (snapshot.empty) {
      logger.info("expirePendingInvites: no expired pending grants found");
      return;
    }

    let expiredCount = 0;
    for (const grantDoc of snapshot.docs) {
      const grantId = grantDoc.id;
      try {
        const didExpire = await db.runTransaction(async (txn) => {
          // Re-read INSIDE the transaction: the grant may have been accepted,
          // declined, or rescinded between the query above and now. Only expire
          // a grant that is STILL pending — never clobber a newer state.
          const fresh = await txn.get(grantDoc.ref);
          if (!fresh.exists || fresh.data()?.state !== "pending") {
            return false;
          }

          txn.update(grantDoc.ref, {
            state: "expired",
            updated_at: now,
            invite_token: admin.firestore.FieldValue.delete(),
          });

          // Write audit log entry.
          const auditRef = db
            .collection("tutor_grants")
            .doc(grantId)
            .collection("audit_log")
            .doc();
          txn.set(auditRef, {
            tutor_uid: null,
            tutor_name_snapshot: fresh.data()?.tutor_email ?? "",
            action: "invite_expired",
            target: `grant/${grantId}`,
            after_value: JSON.stringify({ state: "expired" }),
            timestamp: now.toDate().toISOString(),
          });
          return true;
        });

        if (didExpire) {
          expiredCount++;
          logger.info(`expirePendingInvites: expired grant=${grantId}`);
        }
      } catch (e) {
        logger.error(`expirePendingInvites: failed to expire grant=${grantId}`, e);
      }
    }

    logger.info(`expirePendingInvites: complete — expired=${expiredCount} total=${snapshot.size}`);
  });
