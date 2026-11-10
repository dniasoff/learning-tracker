import * as crypto from "crypto";
import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { assertActiveParentSessionInTransaction } from "./parent_session_validation";
import { CALL_OPTS, db } from "./shared";

const MAX_SCHOOLS = 20;
const MAX_PENDING_REQUESTS = 30;
const MAX_REQUESTS_PER_DAY = 20;
const MAX_ACCOUNT_REQUESTS_PER_DAY = 80;
const MAX_INBOUND_REQUESTS_PER_DAY = 50;
const MAX_PAGE_SIZE = 50;
const REQUEST_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const PROFILE_FIELDS = ["profileId", "displayName", "avatarId", "parentSessionId"] as const;

type ProfileRef = { ownerUid: string; profileId: string };
type SocialProfile = ProfileRef & {
  social_profile_id: string;
  mode: "adult" | "child";
  display_name: string;
  display_name_search: string;
  avatar_id: string;
  paused: boolean;
};

const profiles = () => db.collection("social_profiles");
const requests = () => db.collection("social_follow_requests");
const follows = () => db.collection("social_follows");
const blocks = () => db.collection("social_blocks");
const limits = () => db.collection("social_rate_limits");
const memberships = () => db.collection("school_memberships");
const controls = () => db.collection("social_parent_controls");
const auditLogs = () => db.collection("social_audit_logs");
const searchCursors = () => db.collection("social_search_cursors");

function opaqueId(...parts: string[]): string {
  return crypto.createHash("sha256").update(parts.join("\0")).digest("hex");
}

function requireAuth(request: { auth?: { uid: string } | null }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");
  return uid;
}

function exactKeys(data: Record<string, unknown>, allowed: readonly string[]): void {
  if (Object.keys(data).some((key) => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", "Request contains unsupported fields");
  }
}

function requiredString(value: unknown, name: string, max = 128): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > max) {
    throw new HttpsError("invalid-argument", `${name} must be a non-empty string`);
  }
  return value.trim();
}

function profileDocId(ref: ProfileRef): string {
  return opaqueId(ref.ownerUid, ref.profileId);
}

function profileRef(ref: ProfileRef): FirebaseFirestore.DocumentReference {
  return profiles().doc(profileDocId(ref));
}

function pairId(from: ProfileRef, to: ProfileRef): string {
  return opaqueId(from.ownerUid, from.profileId, to.ownerUid, to.profileId);
}

function blockId(a: ProfileRef, b: ProfileRef): string {
  const left = `${a.ownerUid}\0${a.profileId}`;
  const right = `${b.ownerUid}\0${b.profileId}`;
  return opaqueId(...(left < right ? [left, right] : [right, left]));
}

async function readProfile(
  txn: FirebaseFirestore.Transaction,
  ref: ProfileRef,
): Promise<SocialProfile> {
  const snap = await txn.get(profileRef(ref));
  const data = snap.data();
  const learner = await txn.get(db.collection("users").doc(ref.ownerUid)
    .collection("learner_profiles").doc(ref.profileId));
  if (!snap.exists || data?.owner_uid !== ref.ownerUid || data?.profile_id !== ref.profileId ||
      typeof data?.social_profile_id !== "string" ||
      !learner.exists || (data?.mode !== "adult" && data?.mode !== "child") ||
      learner.get("mode") !== data.mode) {
    throw new HttpsError("not-found", "Learner profile is unavailable");
  }
  if (data.paused === true) throw new HttpsError("failed-precondition", "Social sharing is paused");
  return data as SocialProfile;
}

async function resolveSocialProfile(
  txn: FirebaseFirestore.Transaction,
  socialProfileIdValue: unknown,
): Promise<ProfileRef> {
  const socialProfileId = requiredString(socialProfileIdValue, "socialProfileId", 64);
  if (!/^[A-Za-z0-9_-]{43}$/.test(socialProfileId)) {
    throw new HttpsError("invalid-argument", "socialProfileId is invalid");
  }
  const result = await txn.get(profiles().where("social_profile_id", "==", socialProfileId).limit(1));
  const data = result.docs[0]?.data();
  if (!data || typeof data.owner_uid !== "string" || typeof data.profile_id !== "string") {
    throw new HttpsError("not-found", "Learner profile is unavailable");
  }
  return { ownerUid: data.owner_uid, profileId: data.profile_id };
}

function schoolMembershipQuery(ownerUid: string, profileId: string) {
  return memberships().where("owner_uid", "==", ownerUid)
    .where("profile_id", "==", profileId).where("state", "==", "active");
}

async function sharedAllowedSchool(
  txn: FirebaseFirestore.Transaction,
  from: ProfileRef,
  to: ProfileRef,
  allowedSchools: readonly string[],
): Promise<boolean> {
  if (allowedSchools.length === 0) return false;
  const [fromSnap, toSnap] = await Promise.all([
    txn.get(schoolMembershipQuery(from.ownerUid, from.profileId)),
    txn.get(schoolMembershipQuery(to.ownerUid, to.profileId)),
  ]);
  const fromSchools = new Set(fromSnap.docs.map((doc) => doc.get("school_id")));
  return toSnap.docs.some((doc) => fromSchools.has(doc.get("school_id")) &&
    allowedSchools.includes(String(doc.get("school_id"))));
}

async function requireEligibleChildPair(
  txn: FirebaseFirestore.Transaction,
  from: ProfileRef,
  fromProfile: SocialProfile,
  to: ProfileRef,
  toProfile: SocialProfile,
): Promise<void> {
  const children = [
    ...(fromProfile.mode === "child" ? [from] : []),
    ...(toProfile.mode === "child" ? [to] : []),
  ];
  for (const child of children) {
    const settingsSnap = await txn.get(controls().doc(profileDocId(child)));
    const allowList = settingsSnap.get("allowed_school_ids");
    if (!Array.isArray(allowList) || allowList.some((id) => typeof id !== "string")) {
      throw new HttpsError("permission-denied", "Child school policy is unavailable");
    }
    if (!await sharedAllowedSchool(txn, from, to, allowList as string[])) {
      throw new HttpsError("permission-denied", "Learners are not eligible to connect");
    }
  }
}

async function enforceRateLimit(
  txn: FirebaseFirestore.Transaction,
  profile: ProfileRef,
  now: admin.firestore.Timestamp,
  target?: ProfileRef,
): Promise<void> {
  const id = profileDocId(profile);
  const profileLimitRef = limits().doc(id);
  const accountLimitRef = limits().doc(opaqueId("account", profile.ownerUid));
  const targetLimitRef = target ? limits().doc(profileDocId(target)) : null;
  const [profileSnap, accountSnap, targetSnap] = await Promise.all([
    txn.get(profileLimitRef), txn.get(accountLimitRef),
    targetLimitRef ? txn.get(targetLimitRef) : Promise.resolve(null),
  ]);
  const day = now.toDate().toISOString().slice(0, 10);
  const profileCount = profileSnap.get("day") === day ? Number(profileSnap.get("request_count") ?? 0) : 0;
  const existingInboundCount = profileSnap.get("day") === day
    ? Number(profileSnap.get("inbound_request_count") ?? 0) : 0;
  const accountCount = accountSnap.get("day") === day ? Number(accountSnap.get("request_count") ?? 0) : 0;
  const inboundCount = targetSnap?.get("day") === day
    ? Number(targetSnap.get("inbound_request_count") ?? 0) : 0;
  if (profileCount >= MAX_REQUESTS_PER_DAY || accountCount >= MAX_ACCOUNT_REQUESTS_PER_DAY ||
      inboundCount >= MAX_INBOUND_REQUESTS_PER_DAY) {
    throw new HttpsError("resource-exhausted", "Follow request limit reached");
  }
  txn.set(profileLimitRef, {
    day,
    request_count: profileCount + 1,
    inbound_request_count: existingInboundCount,
    updated_at: now,
  }, { merge: true });
  txn.set(accountLimitRef, { day, request_count: accountCount + 1, updated_at: now }, { merge: true });
  if (targetLimitRef) {
    txn.set(targetLimitRef, { day, inbound_request_count: inboundCount + 1, updated_at: now }, { merge: true });
  }
}

/** Creates or updates one profile's private social identity. */
export const upsertSocialProfile = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, PROFILE_FIELDS);
  const profileId = requiredString(data.profileId, "profileId");
  const displayName = requiredString(data.displayName, "displayName", 60);
  if (!Number.isInteger(data.avatarId) || Number(data.avatarId) < 0 || Number(data.avatarId) > 9) {
    throw new HttpsError("invalid-argument", "avatarId is outside the avatar catalog");
  }
  const avatarId = Number(data.avatarId);
  const now = admin.firestore.Timestamp.now();
  const learnerRef = db.collection("users").doc(uid).collection("learner_profiles").doc(profileId);
  const socialProfileId = await db.runTransaction(async (txn) => {
    const learner = await txn.get(learnerRef);
    if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    const mode = learner.get("mode");
    if (mode !== "child" && mode !== "adult") {
      throw new HttpsError("failed-precondition", "Learner mode is unavailable");
    }
    if (mode === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    }
    const socialRef = profileRef({ ownerUid: uid, profileId });
    const existing = await txn.get(socialRef);
    const controlsSnap = mode === "child"
      ? await txn.get(controls().doc(profileDocId({ ownerUid: uid, profileId })))
      : null;
    const opaqueProfileId = typeof existing.get("social_profile_id") === "string"
      ? existing.get("social_profile_id") as string
      : crypto.randomBytes(32).toString("base64url");
    const paused = mode === "child"
      ? controlsSnap?.get("paused") === true
      : existing.get("paused") === true;
    txn.set(socialRef, {
      owner_uid: uid,
      profile_id: profileId,
      social_profile_id: opaqueProfileId,
      mode,
      display_name: displayName,
      display_name_search: displayName.normalize("NFKC").trim().toLocaleLowerCase("en-US"),
      avatar_id: avatarId,
      paused,
      updated_at: now,
    }, { merge: true });
    return opaqueProfileId;
  });
  return { success: true, socialProfileId };
});

/** Parent-PIN protected child allow-list and sharing pause controls. */
export const setChildSocialControls = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "parentSessionId", "allowedSchoolIds", "paused"]);
  const profileId = requiredString(data.profileId, "profileId");
  const allowed = data.allowedSchoolIds;
  if (!Array.isArray(allowed) || allowed.length > MAX_SCHOOLS ||
      allowed.some((value) => typeof value !== "string" || !value || value.length > 128) ||
      new Set(allowed).size !== allowed.length || typeof data.paused !== "boolean") {
    throw new HttpsError("invalid-argument", "Child social controls are invalid");
  }
  const now = admin.firestore.Timestamp.now();
  await db.runTransaction(async (txn) => {
    const learnerRef = db.collection("users").doc(uid).collection("learner_profiles").doc(profileId);
    const learner = await txn.get(learnerRef);
    if (!learner.exists || learner.get("mode") !== "child") {
      throw new HttpsError("failed-precondition", "Profile is not a child profile");
    }
    await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    const memberSnap = await txn.get(schoolMembershipQuery(uid, profileId));
    const joinedSchools = new Set(memberSnap.docs.map((doc) => doc.get("school_id")));
    if ((allowed as string[]).some((schoolId) => !joinedSchools.has(schoolId))) {
      throw new HttpsError("failed-precondition", "Allowed schools must be active memberships");
    }
    const socialRef = profileRef({ ownerUid: uid, profileId });
    const social = await txn.get(socialRef);
    txn.set(controls().doc(profileDocId({ ownerUid: uid, profileId })), {
      owner_uid: uid,
      profile_id: profileId,
      allowed_school_ids: allowed,
      paused: data.paused,
      updated_at: now,
      updated_by: uid,
    });
    if (social.exists) txn.update(socialRef, { paused: data.paused, updated_at: now });
    txn.set(auditLogs().doc(), {
      owner_uid: uid,
      profile_id: profileId,
      actor_uid: uid,
      action: "child_social_controls_updated",
      at: now,
    });
  });
  return { success: true };
});

export const getChildSocialControls = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "parentSessionId"]);
  const profileId = requiredString(data.profileId, "profileId");
  return db.runTransaction(async (txn) => {
    const learnerRef = db.collection("users").doc(uid).collection("learner_profiles").doc(profileId);
    const learner = await txn.get(learnerRef);
    if (!learner.exists || learner.get("mode") !== "child") {
      throw new HttpsError("failed-precondition", "Profile is not a child profile");
    }
    await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    const settings = await txn.get(controls().doc(profileDocId({ ownerUid: uid, profileId })));
    const allowed = settings.get("allowed_school_ids");
    return {
      allowedSchoolIds: Array.isArray(allowed)
        ? allowed.filter((id): id is string => typeof id === "string")
        : [],
      paused: settings.get("paused") === true,
    };
  });
});

/** Creates a pending directional request. Child senders require a live parent session. */
export const sendFollowRequest = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["fromProfileId", "toSocialProfileId", "parentSessionId"]);
  const from: ProfileRef = { ownerUid: uid, profileId: requiredString(data.fromProfileId, "fromProfileId") };
  const now = admin.firestore.Timestamp.now();
  let requestId = "";
  await db.runTransaction(async (txn) => {
    const to = await resolveSocialProfile(txn, data.toSocialProfileId);
    if (from.ownerUid === to.ownerUid && from.profileId === to.profileId) {
      throw new HttpsError("invalid-argument", "A profile cannot follow itself");
    }
    const requestRef = requests().doc(pairId(from, to));
    requestId = requestRef.id;
    const fromLearnerRef = db.collection("users").doc(uid).collection("learner_profiles").doc(from.profileId);
    const fromLearner = await txn.get(fromLearnerRef);
    if (!fromLearner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    const fromMode = fromLearner.get("mode");
    if (fromMode !== "child" && fromMode !== "adult") {
      throw new HttpsError("failed-precondition", "Learner mode is unavailable");
    }
    if (fromMode === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, from.profileId, data.parentSessionId);
    }
    const fromProfile = await readProfile(txn, from);
    const toProfile = await readProfile(txn, to);
    const block = await txn.get(blocks().doc(blockId(from, to)));
    const existingFollow = await txn.get(follows().doc(pairId(from, to)));
    const existingRequest = await txn.get(requestRef);
    if (block.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    if (existingFollow.exists) throw new HttpsError("already-exists", "Follow is already active");
    if (existingRequest.exists && existingRequest.get("state") === "pending") {
      throw new HttpsError("already-exists", "Follow request is already pending");
    }
    await requireEligibleChildPair(txn, from, fromProfile, to, toProfile);
    const pending = await txn.get(requests().where("from_owner_uid", "==", uid)
      .where("from_profile_id", "==", from.profileId).where("state", "==", "pending").limit(MAX_PENDING_REQUESTS + 1));
    if (pending.size >= MAX_PENDING_REQUESTS) {
      throw new HttpsError("resource-exhausted", "Too many pending follow requests");
    }
    await enforceRateLimit(txn, from, now, to);
    txn.set(requestRef, {
      from_owner_uid: from.ownerUid,
      from_profile_id: from.profileId,
      to_owner_uid: to.ownerUid,
      to_profile_id: to.profileId,
      state: "pending",
      created_at: now,
      updated_at: now,
      expires_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + REQUEST_TTL_MS),
    });
    if (fromMode === "child") {
      txn.set(auditLogs().doc(), {
        owner_uid: uid,
        profile_id: from.profileId,
        actor_uid: uid,
        action: "child_follow_outbound_approved",
        request_id: requestRef.id,
        at: now,
      });
    }
  });
  return { success: true, requestId };
});

/** Recipient accepts/declines; child recipients require their parent's PIN session. */
export const reviewFollowRequest = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["requestId", "profileId", "decision", "parentSessionId"]);
  const requestId = requiredString(data.requestId, "requestId", 64);
  const profileId = requiredString(data.profileId, "profileId");
  if (data.decision !== "accept" && data.decision !== "decline") {
    throw new HttpsError("invalid-argument", "decision must be accept or decline");
  }
  const reqRef = requests().doc(requestId);
  const now = admin.firestore.Timestamp.now();
  await db.runTransaction(async (txn) => {
    const req = await txn.get(reqRef);
    if (!req.exists || req.get("state") !== "pending" || req.get("to_owner_uid") !== uid ||
        req.get("to_profile_id") !== profileId) {
      throw new HttpsError("not-found", "Follow request is unavailable");
    }
    const from: ProfileRef = { ownerUid: req.get("from_owner_uid"), profileId: req.get("from_profile_id") };
    const to: ProfileRef = { ownerUid: uid, profileId };
    const learnerRef = db.collection("users").doc(uid).collection("learner_profiles").doc(profileId);
    const learner = await txn.get(learnerRef);
    if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    if (learner.get("mode") === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    }
    const fromProfile = await readProfile(txn, from);
    const toProfile = await readProfile(txn, to);
    await requireEligibleChildPair(txn, from, fromProfile, to, toProfile);
    const block = await txn.get(blocks().doc(blockId(from, to)));
    if (block.exists) throw new HttpsError("not-found", "Follow request is unavailable");
    if (req.get("expires_at")?.toMillis?.() <= now.toMillis()) {
      txn.update(reqRef, { state: "expired", updated_at: now });
      return;
    }
    const decision = data.decision as "accept" | "decline";
    txn.update(reqRef, { state: decision === "accept" ? "accepted" : "declined", updated_at: now });
    if (decision === "accept") {
      txn.set(follows().doc(pairId(from, to)), {
        from_owner_uid: from.ownerUid,
        from_profile_id: from.profileId,
        to_owner_uid: to.ownerUid,
        to_profile_id: to.profileId,
        state: "active",
        created_at: now,
      });
    }
    if (learner.get("mode") === "child") {
      txn.set(auditLogs().doc(), {
        owner_uid: uid,
        profile_id: profileId,
        actor_uid: uid,
        action: decision === "accept" ? "child_follow_approved" : "child_follow_declined",
        request_id: requestId,
        at: now,
      });
    }
  });
  return { success: true };
});

/** Removes an active directional edge owned by the caller. */
export const removeFollow = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "toSocialProfileId", "parentSessionId"]);
  const from: ProfileRef = { ownerUid: uid, profileId: requiredString(data.profileId, "profileId") };
  await db.runTransaction(async (txn) => {
    const learner = await txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(from.profileId));
    if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    if (learner.get("mode") === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, from.profileId, data.parentSessionId);
    }
    const to = await resolveSocialProfile(txn, data.toSocialProfileId);
    if (from.ownerUid === to.ownerUid && from.profileId === to.profileId) return;
    const edgeOut = follows().doc(pairId(from, to));
    const edgeIn = follows().doc(pairId(to, from));
    const requestOut = requests().doc(pairId(from, to));
    const requestIn = requests().doc(pairId(to, from));
    const [out, incoming, pendingOut, pendingIn] = await Promise.all([
      txn.get(edgeOut), txn.get(edgeIn), txn.get(requestOut), txn.get(requestIn),
    ]);
    if (out.exists) txn.delete(edgeOut);
    if (incoming.exists) txn.delete(edgeIn);
    if (pendingOut.exists) txn.delete(requestOut);
    if (pendingIn.exists) txn.delete(requestIn);
    if (learner.get("mode") === "child") {
      txn.set(auditLogs().doc(), {
        owner_uid: uid,
        profile_id: from.profileId,
        actor_uid: uid,
        action: "child_social_connection_removed",
        at: admin.firestore.Timestamp.now(),
      });
    }
  });
  return { success: true };
});

/** Blocks a profile and removes both directions and pending requests. */
export const blockSocialProfile = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "toSocialProfileId", "parentSessionId"]);
  const from: ProfileRef = { ownerUid: uid, profileId: requiredString(data.profileId, "profileId") };
  let target: ProfileRef | undefined;
  const now = admin.firestore.Timestamp.now();
  await db.runTransaction(async (txn) => {
    const learner = await txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(from.profileId));
    if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    if (learner.get("mode") === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, from.profileId, data.parentSessionId);
    }
    const to = await resolveSocialProfile(txn, data.toSocialProfileId);
    if (from.ownerUid === to.ownerUid && from.profileId === to.profileId) {
      throw new HttpsError("invalid-argument", "A profile cannot block itself");
    }
    target = to;
    const blockRef = blocks().doc(blockId(from, to));
    txn.set(blockRef, {
      left_owner_uid: from.ownerUid,
      left_profile_id: from.profileId,
      right_owner_uid: to.ownerUid,
      right_profile_id: to.profileId,
      blocked_by_uid: uid,
      blocked_by_profile_id: from.profileId,
      created_at: now,
    });
    if (learner.get("mode") === "child") {
      txn.set(auditLogs().doc(), {
        owner_uid: uid,
        profile_id: from.profileId,
        actor_uid: uid,
        action: "child_social_profile_blocked",
        at: now,
      });
    }
  });
  const to = target;
  if (!to) return { success: true };
  const queries = [
    follows().where("from_owner_uid", "==", from.ownerUid).where("from_profile_id", "==", from.profileId)
      .where("to_owner_uid", "==", to.ownerUid).where("to_profile_id", "==", to.profileId),
    follows().where("from_owner_uid", "==", to.ownerUid).where("from_profile_id", "==", to.profileId)
      .where("to_owner_uid", "==", from.ownerUid).where("to_profile_id", "==", from.profileId),
    requests().where("from_owner_uid", "==", from.ownerUid).where("from_profile_id", "==", from.profileId)
      .where("to_owner_uid", "==", to.ownerUid).where("to_profile_id", "==", to.profileId),
    requests().where("from_owner_uid", "==", to.ownerUid).where("from_profile_id", "==", to.profileId)
      .where("to_owner_uid", "==", from.ownerUid).where("to_profile_id", "==", from.profileId),
  ];
  for (const query of queries) {
    const snap = await query.get();
    for (let i = 0; i < snap.docs.length; i += 450) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + 450)) batch.delete(doc.ref);
      await batch.commit();
    }
  }
  return { success: true };
});

/** Reverses only a block created by the caller. */
export const unblockSocialProfile = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "toSocialProfileId", "parentSessionId"]);
  const from: ProfileRef = { ownerUid: uid, profileId: requiredString(data.profileId, "profileId") };
  await db.runTransaction(async (txn) => {
    const learner = await txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(from.profileId));
    if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    if (learner.get("mode") === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, from.profileId, data.parentSessionId);
    }
    const to = await resolveSocialProfile(txn, data.toSocialProfileId);
    const ref = blocks().doc(blockId(from, to));
    const snap = await txn.get(ref);
    if (snap.exists && snap.get("blocked_by_uid") === uid && snap.get("blocked_by_profile_id") === from.profileId) {
      txn.delete(ref);
      if (learner.get("mode") === "child") {
        txn.set(auditLogs().doc(), {
          owner_uid: uid,
          profile_id: from.profileId,
          actor_uid: uid,
          action: "child_social_profile_unblocked",
          at: admin.firestore.Timestamp.now(),
        });
      }
    }
  });
  return { success: true };
});

/** Bounded server-mediated school search; results are exact-match adult cards only. */
export const searchSchoolMembers = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "schoolId", "exactName", "parentSessionId", "pageToken", "limit"]);
  const profileId = requiredString(data.profileId, "profileId");
  const schoolId = requiredString(data.schoolId, "schoolId");
  const exactName = requiredString(data.exactName, "exactName", 60).normalize("NFKC").toLocaleLowerCase("en-US");
  const pageToken = data.pageToken === undefined ? null : requiredString(data.pageToken, "pageToken", 1500);
  const pageSize = data.limit ?? 20;
  if (!Number.isInteger(pageSize) || Number(pageSize) < 1 || Number(pageSize) > 50) {
    throw new HttpsError("invalid-argument", "limit must be between 1 and 50");
  }
  const now = admin.firestore.Timestamp.now();
  const result = await db.runTransaction(async (txn) => {
    const callerRef: ProfileRef = { ownerUid: uid, profileId };
    let cursorAfter: string | null = null;
    if (pageToken !== null) {
      if (!/^[A-Za-z0-9_-]{43}$/.test(pageToken)) {
        throw new HttpsError("invalid-argument", "pageToken is invalid");
      }
      const cursorSnap = await txn.get(searchCursors().doc(opaqueId("cursor", pageToken)));
      const expiresAt = cursorSnap.get("expires_at");
      if (!cursorSnap.exists || cursorSnap.get("owner_uid") !== uid ||
          cursorSnap.get("profile_id") !== profileId || cursorSnap.get("school_id") !== schoolId ||
          cursorSnap.get("query_hash") !== opaqueId("search", exactName) ||
          !(expiresAt instanceof admin.firestore.Timestamp) || expiresAt.toMillis() <= now.toMillis()) {
        throw new HttpsError("not-found", "Search page is unavailable");
      }
      cursorAfter = String(cursorSnap.get("last_membership_id"));
    }
    const learner = await txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(profileId));
    if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    if (learner.get("mode") !== "child" && learner.get("mode") !== "adult") {
      throw new HttpsError("failed-precondition", "Learner mode is unavailable");
    }
    const isChild = learner.get("mode") === "child";
    if (isChild) await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    const memberSnap = await txn.get(schoolMembershipQuery(uid, profileId));
    if (!memberSnap.docs.some((doc) => doc.get("school_id") === schoolId)) {
      throw new HttpsError("permission-denied", "School membership is required");
    }
    await readProfile(txn, callerRef);
    if (isChild) {
      const controlsSnap = await txn.get(controls().doc(profileDocId(callerRef)));
      const allowedSchools = controlsSnap.get("allowed_school_ids");
      if (!Array.isArray(allowedSchools) || !allowedSchools.includes(schoolId)) {
        throw new HttpsError("permission-denied", "School is outside the parent allow-list");
      }
    }
    let memberQuery = memberships().where("school_id", "==", schoolId)
      .where("state", "==", "active")
      .orderBy(admin.firestore.FieldPath.documentId());
    if (cursorAfter !== null) memberQuery = memberQuery.startAfter(cursorAfter);
    const querySnap = await txn.get(memberQuery.limit(pageSize + 1));
    const pageDocs = querySnap.docs.slice(0, pageSize);
    const eligible: SocialProfile[] = [];
    for (const membership of pageDocs) {
      const ref: ProfileRef = { ownerUid: String(membership.get("owner_uid")), profileId: String(membership.get("profile_id")) };
      if (ref.ownerUid === uid && ref.profileId === profileId) continue;
      const card = await txn.get(profileRef(ref));
      const candidateLearner = await txn.get(db.collection("users").doc(ref.ownerUid)
        .collection("learner_profiles").doc(ref.profileId));
      const block = await txn.get(blocks().doc(blockId(callerRef, ref)));
      if (!block.exists && card.exists && candidateLearner.exists &&
          candidateLearner.get("mode") === "adult" && card.get("mode") === "adult" && card.get("paused") !== true &&
          typeof card.get("social_profile_id") === "string" &&
          card.get("display_name_search") === exactName) eligible.push(card.data() as SocialProfile);
    }
    await enforceRateLimit(txn, callerRef, now);
    const nextPageToken = querySnap.size > pageSize ? crypto.randomBytes(32).toString("base64url") : null;
    if (nextPageToken !== null) {
      txn.set(searchCursors().doc(opaqueId("cursor", nextPageToken)), {
        owner_uid: uid,
        profile_id: profileId,
        school_id: schoolId,
        query_hash: opaqueId("search", exactName),
        last_membership_id: pageDocs[pageDocs.length - 1]?.id,
        expires_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + 15 * 60 * 1000),
      });
    }
    return {
      profiles: eligible.map((profile) => ({
        socialProfileId: profile.social_profile_id,
        displayName: profile.display_name,
        avatarId: profile.avatar_id,
      })),
      nextPageToken,
    };
  });
  return result;
});

/** Returns only a caller profile's own inbound/outbound request and edge state. */
export const listSocialConnections = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "limit"]);
  const profileId = requiredString(data.profileId, "profileId");
  const limit = data.limit ?? MAX_PAGE_SIZE;
  if (!Number.isInteger(limit) || Number(limit) < 1 || Number(limit) > MAX_PAGE_SIZE) {
    throw new HttpsError("invalid-argument", "limit must be between 1 and 50");
  }
  const [outgoingRequests, incomingRequests, outgoingFollows, incomingFollows] = await Promise.all([
    requests().where("from_owner_uid", "==", uid).where("from_profile_id", "==", profileId).limit(limit).get(),
    requests().where("to_owner_uid", "==", uid).where("to_profile_id", "==", profileId).limit(limit).get(),
    follows().where("from_owner_uid", "==", uid).where("from_profile_id", "==", profileId).limit(limit).get(),
    follows().where("to_owner_uid", "==", uid).where("to_profile_id", "==", profileId).limit(limit).get(),
  ]);
  const serialize = async (snap: FirebaseFirestore.QuerySnapshot) => Promise.all(snap.docs.map(async (doc) => {
    const data = doc.data();
    const from: ProfileRef = { ownerUid: String(data.from_owner_uid), profileId: String(data.from_profile_id) };
    const to: ProfileRef = { ownerUid: String(data.to_owner_uid), profileId: String(data.to_profile_id) };
    const [fromProfile, toProfile] = await Promise.all([
      profileRef(from).get(), profileRef(to).get(),
    ]);
    const wireTime = (value: unknown): string | null =>
      value instanceof admin.firestore.Timestamp ? value.toDate().toISOString() : null;
    const result: Record<string, unknown> = {
      id: doc.id,
      fromSocialProfileId: fromProfile.get("social_profile_id") ?? "unavailable",
      toSocialProfileId: toProfile.get("social_profile_id") ?? "unavailable",
      state: data.state,
    };
    for (const key of ["created_at", "updated_at", "expires_at"]) {
      const timestamp = wireTime(data[key]);
      if (timestamp !== null) result[key] = timestamp;
    }
    return result;
  }));
  return {
    outgoingRequests: await serialize(outgoingRequests),
    incomingRequests: await serialize(incomingRequests),
    following: await serialize(outgoingFollows),
    followers: await serialize(incomingFollows),
  };
});

/** Idempotent graph/request cleanup for profile and account deletion. */
export async function cleanupSocialForProfile(ownerUid: string, profileId: string): Promise<void> {
  const queries = [
    profiles().where("owner_uid", "==", ownerUid).where("profile_id", "==", profileId),
    searchCursors().where("owner_uid", "==", ownerUid).where("profile_id", "==", profileId),
    controls().where("owner_uid", "==", ownerUid).where("profile_id", "==", profileId),
    auditLogs().where("owner_uid", "==", ownerUid).where("profile_id", "==", profileId),
    requests().where("from_owner_uid", "==", ownerUid).where("from_profile_id", "==", profileId),
    requests().where("to_owner_uid", "==", ownerUid).where("to_profile_id", "==", profileId),
    follows().where("from_owner_uid", "==", ownerUid).where("from_profile_id", "==", profileId),
    follows().where("to_owner_uid", "==", ownerUid).where("to_profile_id", "==", profileId),
    blocks().where("left_owner_uid", "==", ownerUid).where("left_profile_id", "==", profileId),
    blocks().where("right_owner_uid", "==", ownerUid).where("right_profile_id", "==", profileId),
  ];
  for (const query of queries) {
    const snap = await query.get();
    for (let i = 0; i < snap.docs.length; i += 450) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + 450)) batch.delete(doc.ref);
      await batch.commit();
    }
  }
  await limits().doc(profileDocId({ ownerUid, profileId })).delete().catch(() => undefined);
}

export async function cleanupSocialForAccount(ownerUid: string): Promise<void> {
  const snap = await profiles().where("owner_uid", "==", ownerUid).get();
  for (const profile of snap.docs) {
    const profileId = profile.get("profile_id");
    if (typeof profileId === "string") await cleanupSocialForProfile(ownerUid, profileId);
  }
  await limits().doc(opaqueId("account", ownerUid)).delete().catch(() => undefined);
}
