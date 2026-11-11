import * as crypto from "crypto";
import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { assertActiveParentSessionInTransaction } from "./parent_session_validation";
import {
  grantSocialStaffSchoolAccess,
  refreshSocialMembershipMirror,
  revokeSocialGrantsForMembershipChange,
  revokeStaffSchoolAccess,
} from "./social_graph";
import { cleanupLearningGroupsForSchool } from "./groups";
import { CALL_OPTS, db } from "./shared";

const MAX_SCHOOLS_PER_ACCOUNT = 10;
const MAX_SCHOOL_NAME = 80;
const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_CREATES_PER_DAY = 3;
const MAX_INVITES_PER_DAY = 30;

type ProfileRef = { ownerUid: string; profileId: string };
const schools = () => db.collection("schools");
const memberships = () => db.collection("school_memberships");
const admins = () => db.collection("school_admins");
const invites = () => db.collection("school_invites");
const audit = () => db.collection("school_audit_logs");
const reports = () => db.collection("school_reports");
const rateLimits = () => db.collection("school_rate_limits");
const summaries = () => db.collection("social_summaries");

function hash(...parts: string[]): string {
  return crypto.createHash("sha256").update(parts.join("\0")).digest("hex");
}
function membershipId(schoolId: string, ref: ProfileRef): string {
  return hash("school-member", schoolId, ref.ownerUid, ref.profileId);
}
function summaryId(ref: ProfileRef): string {
  return hash(ref.ownerUid, ref.profileId);
}
function staffId(schoolId: string, uid: string): string {
  return hash("school-staff", schoolId, uid);
}
function requireAuth(request: { auth?: { uid: string; token?: Record<string, unknown> } | null }): string {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Must be signed in");
  return request.auth.uid;
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
function schoolRef(value: unknown): FirebaseFirestore.DocumentReference {
  const id = requiredString(value, "schoolId", 64);
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(id)) throw new HttpsError("invalid-argument", "schoolId is invalid");
  return schools().doc(id);
}
async function requireActiveSchool(txn: FirebaseFirestore.Transaction, ref: FirebaseFirestore.DocumentReference) {
  const snap = await txn.get(ref);
  if (!snap.exists || snap.get("status") !== "active") throw new HttpsError("not-found", "School is unavailable");
  return snap;
}
async function requireAdmin(txn: FirebaseFirestore.Transaction, schoolId: string, uid: string) {
  const ref = admins().doc(staffId(schoolId, uid));
  const snap = await txn.get(ref);
  if (!snap.exists || snap.get("state") !== "active" || snap.get("role") !== "admin") {
    throw new HttpsError("permission-denied", "School administrator access is required");
  }
  return { ref, snap };
}
async function auditEvent(schoolId: string, uid: string, action: string, details: Record<string, unknown> = {}) {
  await audit().add({ school_id: schoolId, actor_uid: uid, action, details, at: admin.firestore.Timestamp.now() });
}
async function rateLimit(uid: string, kind: "create" | "invite" | "report") {
  const now = admin.firestore.Timestamp.now();
  const day = now.toDate().toISOString().slice(0, 10);
  const ref = rateLimits().doc(hash("school-rate", uid, kind));
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    const prior = snap.get("day") === day ? Number(snap.get("count") ?? 0) : 0;
    const cap = kind === "create" ? MAX_CREATES_PER_DAY : kind === "invite" ? MAX_INVITES_PER_DAY : 20;
    if (prior >= cap) throw new HttpsError("resource-exhausted", "School action limit reached");
    txn.set(ref, { day, count: prior + 1, updated_at: now });
  });
}
async function setSummaryReader(ref: ProfileRef, uid: string, schoolId: string, active: boolean) {
  const reader = summaries().doc(summaryId(ref)).collection("readers").doc(uid);
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(reader);
    if (active) {
      const [school, member, staff] = await Promise.all([
        txn.get(schools().doc(schoolId)),
        txn.get(memberships().doc(membershipId(schoolId, ref))),
        txn.get(admins().doc(staffId(schoolId, uid))),
      ]);
      if (!school.exists || school.get("status") !== "active" ||
          !member.exists || member.get("state") !== "active" ||
          !staff.exists || staff.get("state") !== "active") return;
    }
    const existing = snap.get("school_ids");
    const schoolIds: string[] = Array.isArray(existing)
      ? existing.filter((value): value is string => typeof value === "string") : [];
    const next = active
      ? [...new Set([...schoolIds, schoolId])]
      : schoolIds.filter((value) => value !== schoolId);
    if (active || snap.exists) {
      if (!active && next.length === 0 && (!Array.isArray(snap.get("follower_profile_ids")) || snap.get("follower_profile_ids").length === 0)) {
        txn.delete(reader);
      } else {
        txn.set(reader, {
          owner_uid: ref.ownerUid,
          profile_id: ref.profileId,
          school_ids: next,
          updated_at: admin.firestore.Timestamp.now(),
          ...(active ? { created_at: snap.get("created_at") ?? admin.firestore.Timestamp.now() } : {}),
        }, { merge: true });
      }
    }
  });
}
async function refreshSchoolReaders(schoolId: string, forceInactive = false) {
  const [school, members, staff] = await Promise.all([
    schools().doc(schoolId).get(),
    memberships().where("school_id", "==", schoolId).get(),
    admins().where("school_id", "==", schoolId).get(),
  ]);
  const schoolIsActive = !forceInactive && school.exists && school.get("status") === "active";
  await Promise.all(staff.docs.map((doc) => {
    const uid = String(doc.get("owner_uid"));
    return schoolIsActive && doc.get("state") === "active"
      ? grantSocialStaffSchoolAccess(uid, schoolId)
      : revokeStaffSchoolAccess(uid, schoolId);
  }));
  for (const member of members.docs) {
    const ref = { ownerUid: String(member.get("owner_uid")), profileId: String(member.get("profile_id")) };
    const memberIsActive = member.get("state") === "active";
    await Promise.all(staff.docs.map((doc) => {
      const canRead = schoolIsActive && memberIsActive && doc.get("state") === "active";
      return setSummaryReader(ref, String(doc.get("owner_uid")), schoolId, canRead);
    }));
  }
}
async function revokeSchoolDependentSocial(ref: ProfileRef, schoolId: string) {
  await revokeSocialGrantsForMembershipChange(summaryId(ref), schoolId);
}
async function revokeSchoolReaderForMember(schoolId: string, ref: ProfileRef) {
  const staff = await admins().where("school_id", "==", schoolId).get();
  await Promise.all(staff.docs.map((doc) =>
    setSummaryReader(ref, String(doc.get("owner_uid")), schoolId, false),
  ));
}
async function revokeSchoolReaderForUid(schoolId: string, uid: string) {
  const members = await memberships().where("school_id", "==", schoolId).get();
  for (const member of members.docs) {
    await setSummaryReader({
      ownerUid: String(member.get("owner_uid")),
      profileId: String(member.get("profile_id")),
    }, uid, schoolId, false);
  }
}

/** Fence schools whose last active administrator is being deleted. */
async function beginLastAdminCleanup(schoolId: string, ownerUid: string): Promise<boolean> {
  const schoolRef = schools().doc(schoolId);
  const adminRef = admins().doc(staffId(schoolId, ownerUid));
  return db.runTransaction(async (txn) => {
    const [school, staff] = await Promise.all([txn.get(schoolRef), txn.get(adminRef)]);
    if (!school.exists || school.get("status") === "deleted") return false;
    if (school.get("cleanup_pending") === true) {
      if (school.get("status") !== "suspended") {
        throw new HttpsError("failed-precondition", "School cleanup is pending in an invalid state");
      }
      return true;
    }
    if (!staff.exists || staff.get("state") !== "active") return false;
    if (!["active", "suspended"].includes(String(school.get("status")))) {
      throw new HttpsError("failed-precondition", "School cannot be cleaned up in its current state");
    }
    const activeAdmins = await txn.get(admins().where("school_id", "==", schoolId).where("state", "==", "active"));
    if (activeAdmins.size !== 1 || activeAdmins.docs[0].id !== adminRef.id) return false;
    txn.update(schoolRef, {
      status: "suspended",
      cleanup_pending: true,
      updated_at: admin.firestore.Timestamp.now(),
    });
    return true;
  });
}

async function revokeActiveSchoolInvites(schoolId: string): Promise<void> {
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let query = invites().where("school_id", "==", schoolId).where("state", "==", "active")
      .orderBy(admin.firestore.FieldPath.documentId()).limit(400);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) return;
    const batch = db.batch();
    page.docs.forEach((doc) => batch.update(doc.ref, {
      state: "revoked", updated_at: admin.firestore.Timestamp.now(),
    }));
    await batch.commit();
    if (page.size < 400) return;
    cursor = page.docs[page.docs.length - 1];
  }
}

/** Complete a fenced last-admin cleanup; repeated calls safely resume it. */
async function finishLastAdminCleanup(schoolId: string, ownerUid: string): Promise<void> {
  const staff = await admins().where("school_id", "==", schoolId).get();
  await Promise.all(staff.docs.map((doc) =>
    revokeStaffSchoolAccess(String(doc.get("owner_uid")), schoolId),
  ));
  await revokeActiveSchoolInvites(schoolId);

  const schoolMembers = await memberships().where("school_id", "==", schoolId).get();
  const revokeFollowerGrants = async () => {
    for (const member of schoolMembers.docs) {
      await revokeSchoolDependentSocial({
        ownerUid: String(member.get("owner_uid")),
        profileId: String(member.get("profile_id")),
      }, schoolId);
    }
  };
  await revokeFollowerGrants();
  await refreshSchoolReaders(schoolId, true);
  // Re-run follower revocation after the staff/summary ACL sweep. This is the
  // final pass before the cleanup marker is cleared.
  await revokeFollowerGrants();

  await db.runTransaction(async (txn) => {
    const schoolRef = schools().doc(schoolId);
    const adminRef = admins().doc(staffId(schoolId, ownerUid));
    const [school, target] = await Promise.all([txn.get(schoolRef), txn.get(adminRef)]);
    if (!school.exists || school.get("status") !== "suspended" || school.get("cleanup_pending") !== true ||
        !target.exists || target.get("state") !== "active") {
      throw new HttpsError("aborted", "School cleanup state changed; retry account deletion");
    }
    txn.update(schoolRef, { cleanup_pending: false, updated_at: admin.firestore.Timestamp.now() });
    txn.update(adminRef, { state: "removed", ended_at: admin.firestore.Timestamp.now() });
  });
}

/** Any signed-in adult account can create a school identity immediately. */
export const createSchool = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["name", "profileId"]);
  const name = requiredString(data.name, "name", MAX_SCHOOL_NAME);
  const profileId = data.profileId === undefined ? null : requiredString(data.profileId, "profileId");
  if (profileId !== null) {
    const learner = await db.collection("users").doc(uid).collection("learner_profiles").doc(profileId).get();
    if (!learner.exists || learner.get("mode") !== "adult") throw new HttpsError("permission-denied", "An adult learner profile is required");
  }
  await rateLimit(uid, "create");
  const now = admin.firestore.Timestamp.now();
  const schoolRef = schools().doc();
  const adminRef = admins().doc(staffId(schoolRef.id, uid));
  await db.runTransaction(async (txn) => {
    const existing = await txn.get(admins().where("owner_uid", "==", uid).where("state", "==", "active"));
    if (existing.size >= MAX_SCHOOLS_PER_ACCOUNT) throw new HttpsError("resource-exhausted", "School administrator limit reached");
    txn.create(schoolRef, {
      name, created_by_uid: uid, created_by_profile_id: profileId,
      created_at: now, updated_at: now, status: "active", verified: false, membership_revision: 0,
    });
    txn.create(adminRef, { school_id: schoolRef.id, owner_uid: uid, profile_id: profileId, role: "admin", state: "active", created_at: now });
  });
  await auditEvent(schoolRef.id, uid, "school_created");
  await refreshSchoolReaders(schoolRef.id);
  return { schoolId: schoolRef.id, name, createdAt: now.toDate().toISOString(), verified: false };
});

/** Public school identity lookup; memberships and member identities remain private. */
export const getSchoolProfile = onCall(CALL_OPTS, async (request) => {
  requireAuth(request);
  const ref = schoolRef(request.data?.schoolId);
  const snap = await ref.get();
  if (!snap.exists || snap.get("status") === "deleted") throw new HttpsError("not-found", "School is unavailable");
  const data = snap.data()!;
  const adminSnap = await admins().where("school_id", "==", ref.id).where("state", "==", "active").get();
  const adminCards = await Promise.all(adminSnap.docs.map(async (doc) => {
    const ownerUid = String(doc.get("owner_uid"));
    const profileId = doc.get("profile_id");
    const profile = typeof profileId === "string"
      ? await db.collection("social_profiles").doc(hash(ownerUid, profileId)).get() : null;
    return {
      displayName: profile?.get("display_name") ?? "School administrator",
    };
  }));
  return {
    schoolId: ref.id, name: data.name, verified: data.verified === true,
    createdAt: data.created_at?.toDate?.().toISOString() ?? null,
    admins: adminCards,
    status: data.status,
  };
});

/** Creates a capped, expiring invite. Only a hash of the token is persisted. */
export const createSchoolInvite = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "uses"]);
  const ref = schoolRef(data.schoolId);
  const uses = data.uses === undefined ? 1 : Number(data.uses);
  if (!Number.isInteger(uses) || uses < 1 || uses > 20) throw new HttpsError("invalid-argument", "uses must be between 1 and 20");
  await rateLimit(uid, "invite");
  const token = crypto.randomBytes(32).toString("base64url");
  const now = admin.firestore.Timestamp.now();
  const expiry = admin.firestore.Timestamp.fromMillis(now.toMillis() + INVITE_TTL_MS);
  await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, ref);
    await requireAdmin(txn, ref.id, uid);
    txn.create(invites().doc(hash("school-invite", token)), {
      school_id: ref.id, created_by_uid: uid, token_hash: hash("school-invite", token),
      state: "active", uses, use_count: 0, created_at: now, expires_at: expiry,
    });
  });
  await auditEvent(ref.id, uid, "school_invite_created");
  return { inviteCode: token, expiresAt: expiry.toDate().toISOString(), uses };
});

/** Redeems an admin invite; child joins require PIN-gated, explicit consent. */
export const joinSchoolWithInvite = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["inviteCode", "profileId", "parentSessionId", "progressConsent"]);
  const token = requiredString(data.inviteCode, "inviteCode", 100);
  const profileId = requiredString(data.profileId, "profileId");
  const learnerRef = db.collection("users").doc(uid).collection("learner_profiles").doc(profileId);
  const inviteRef = invites().doc(hash("school-invite", token));
  const now = admin.firestore.Timestamp.now();
  const result = await db.runTransaction(async (txn) => {
    const [learner, invite] = await Promise.all([txn.get(learnerRef), txn.get(inviteRef)]);
    if (!learner.exists || !invite.exists || invite.get("state") !== "active") throw new HttpsError("not-found", "Invite is unavailable");
    const expiresAt = invite.get("expires_at");
    if (!(expiresAt instanceof admin.firestore.Timestamp) || expiresAt.toMillis() <= now.toMillis() || Number(invite.get("use_count")) >= Number(invite.get("uses"))) {
      throw new HttpsError("failed-precondition", "Invite is expired or has been used");
    }
    const mode = learner.get("mode");
    if (mode !== "adult" && mode !== "child") throw new HttpsError("failed-precondition", "Learner mode is unavailable");
    if (data.progressConsent !== true) throw new HttpsError("failed-precondition", "Joining confirms school staff can view progress");
    if (mode === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    }
    const schoolId = String(invite.get("school_id"));
    const school = await requireActiveSchool(txn, schools().doc(schoolId));
    const memberRef = memberships().doc(membershipId(schoolId, { ownerUid: uid, profileId }));
    const member = await txn.get(memberRef);
    if (member.exists && member.get("state") === "active") throw new HttpsError("already-exists", "Learner is already a member");
    const count = Number(invite.get("use_count")) + 1;
    txn.set(inviteRef, { use_count: count, state: count >= Number(invite.get("uses")) ? "redeemed" : "active", updated_at: now }, { merge: true });
    txn.set(memberRef, {
      school_id: schoolId, owner_uid: uid, profile_id: profileId, mode,
      role: "member", state: "active", progress_consent: true,
      joined_at: now, updated_at: now,
    });
    txn.update(schools().doc(schoolId), { membership_revision: admin.firestore.FieldValue.increment(1), updated_at: now });
    txn.set(audit().doc(), { school_id: schoolId, actor_uid: uid, subject_uid: uid, action: "school_member_joined", at: now, details: { mode } });
    return { schoolId, name: school.get("name") };
  });
  await refreshSocialMembershipMirror(summaryId({ ownerUid: uid, profileId }));
  await refreshSchoolReaders(result.schoolId);
  return { ...result, success: true };
});

export const listMySchools = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "parentSessionId"]);
  const profileId = requiredString(data.profileId, "profileId");
  const learner = await db.collection("users").doc(uid).collection("learner_profiles").doc(profileId).get();
  if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
  if (learner.get("mode") === "child") {
    await db.runTransaction((txn) => assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId));
  }
  const snap = await memberships().where("owner_uid", "==", uid).where("profile_id", "==", profileId).where("state", "==", "active").limit(50).get();
  return Promise.all(snap.docs.map(async (member) => {
    const school = await schools().doc(String(member.get("school_id"))).get();
    if (!school.exists || school.get("status") === "deleted") return null;
    return { schoolId: school.id, name: school.get("name"), verified: school.get("verified") === true, role: member.get("role"), joinedAt: member.get("joined_at")?.toDate?.().toISOString() ?? null };
  })).then((items) => items.filter(Boolean));
});

/** Staff-only roster. Child members are included only for school staff; the
 * ordinary school search path continues to return adult cards only. */
export const listSchoolRoster = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "limit"]);
  const ref = schoolRef(data.schoolId);
  const limit = data.limit === undefined ? 50 : Number(data.limit);
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) throw new HttpsError("invalid-argument", "limit must be between 1 and 100");
  const members = await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, ref);
    await requireAdmin(txn, ref.id, uid);
    return txn.get(memberships().where("school_id", "==", ref.id).where("state", "==", "active").limit(limit));
  });
  return Promise.all(members.docs.map(async (member) => {
    const ownerUid = String(member.get("owner_uid"));
    const profileId = String(member.get("profile_id"));
    const social = await db.collection("social_profiles").doc(hash(ownerUid, profileId)).get();
    return {
      summaryId: summaryId({ ownerUid, profileId }),
      displayName: social.get("display_name") ?? "Learner",
      avatarId: Number(social.get("avatar_id") ?? 0),
      mode: member.get("mode") === "child" ? "child" : "adult",
    };
  }));
});

async function changeMember(schoolId: string, targetUid: string, profileId: string, actorUid: string, action: "remove" | "leave", reason?: string) {
  const memberRef = memberships().doc(membershipId(schoolId, { ownerUid: targetUid, profileId }));
  const now = admin.firestore.Timestamp.now();
  await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, schools().doc(schoolId));
    if (action === "remove") await requireAdmin(txn, schoolId, actorUid);
    else if (targetUid !== actorUid) throw new HttpsError("permission-denied", "A learner can only leave their own membership");
    const snap = await txn.get(memberRef);
    if (!snap.exists || snap.get("state") !== "active") throw new HttpsError("not-found", "Membership is unavailable");
    const staff = await txn.get(admins().doc(staffId(schoolId, targetUid)));
    if (staff.exists && staff.get("state") === "active") {
      throw new HttpsError("failed-precondition", "Remove or transfer admin role first");
    }
  });
  await revokeStaffSchoolAccess(targetUid, schoolId);
  await revokeSchoolDependentSocial({ ownerUid: targetUid, profileId }, schoolId);
  await revokeSchoolReaderForMember(schoolId, { ownerUid: targetUid, profileId });
  await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, schools().doc(schoolId));
    if (action === "remove") await requireAdmin(txn, schoolId, actorUid);
    else if (targetUid !== actorUid) throw new HttpsError("permission-denied", "A learner can only leave their own membership");
    const snap = await txn.get(memberRef);
    if (!snap.exists || snap.get("state") !== "active") throw new HttpsError("not-found", "Membership is unavailable");
    const staff = await txn.get(admins().doc(staffId(schoolId, targetUid)));
    if (staff.exists && staff.get("state") === "active") {
      throw new HttpsError("failed-precondition", "Remove or transfer admin role first");
    }
    txn.update(memberRef, { state: "removed", ended_at: now, ended_by_uid: actorUid, reason_code: reason ?? null, updated_at: now });
    txn.update(schools().doc(schoolId), { membership_revision: admin.firestore.FieldValue.increment(1), updated_at: now });
    txn.set(audit().doc(), { school_id: schoolId, actor_uid: actorUid, subject_uid: targetUid, action: action === "remove" ? "school_member_removed" : "school_member_left", at: now, details: { profile_id: profileId, reason_code: reason ?? null } });
  });
  await setSummaryReader({ ownerUid: targetUid, profileId }, actorUid, schoolId, false);
  await refreshSchoolReaders(schoolId);
}
export const removeSchoolMember = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "ownerUid", "profileId", "reasonCode"]);
  const schoolId = schoolRef(data.schoolId).id;
  const reason = data.reasonCode === undefined ? undefined : requiredString(data.reasonCode, "reasonCode", 40);
  if (reason !== undefined && !new Set(["requested", "policy", "safety", "other"]).has(reason)) {
    throw new HttpsError("invalid-argument", "Unsupported member removal reason");
  }
  await changeMember(schoolId, requiredString(data.ownerUid, "ownerUid"), requiredString(data.profileId, "profileId"), uid, "remove", reason);
  return { success: true };
});
export const leaveSchool = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "profileId", "parentSessionId"]);
  const profileId = requiredString(data.profileId, "profileId");
  const learner = await db.collection("users").doc(uid).collection("learner_profiles").doc(profileId).get();
  if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
  if (learner.get("mode") === "child") await db.runTransaction((txn) => assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId));
  const schoolId = schoolRef(data.schoolId).id;
  await changeMember(schoolId, uid, profileId, uid, "leave");
  return { success: true };
});

export const addSchoolAdmin = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "targetUid", "profileId"]);
  const schoolId = schoolRef(data.schoolId).id;
  const targetUid = requiredString(data.targetUid, "targetUid");
  const profileId = requiredString(data.profileId, "profileId");
  const now = admin.firestore.Timestamp.now();
  await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, schools().doc(schoolId));
    await requireAdmin(txn, schoolId, uid);
    const memberRef = memberships().doc(membershipId(schoolId, { ownerUid: targetUid, profileId }));
    const member = await txn.get(memberRef);
    if (!member.exists || member.get("state") !== "active") throw new HttpsError("failed-precondition", "Only active members can become admins");
    txn.set(admins().doc(staffId(schoolId, targetUid)), { school_id: schoolId, owner_uid: targetUid, profile_id: profileId, role: "admin", state: "active", created_at: now, updated_at: now });
    txn.set(memberRef, { role: "admin", updated_at: now }, { merge: true });
    txn.update(schools().doc(schoolId), { membership_revision: admin.firestore.FieldValue.increment(1), updated_at: now });
    txn.set(audit().doc(), { school_id: schoolId, actor_uid: uid, subject_uid: targetUid, action: "school_admin_added", at: now });
  });
  await refreshSchoolReaders(schoolId);
  return { success: true };
});
export const removeSchoolAdmin = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "targetUid"]);
  const schoolId = schoolRef(data.schoolId).id;
  const targetUid = requiredString(data.targetUid, "targetUid");
  const targetRef = admins().doc(staffId(schoolId, targetUid));
  await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, schools().doc(schoolId));
    await requireAdmin(txn, schoolId, uid);
    if (uid === targetUid) throw new HttpsError("failed-precondition", "Transfer admin rights before leaving the school");
    const target = await txn.get(targetRef);
    if (!target.exists || !["active", "removing"].includes(String(target.get("state")))) {
      throw new HttpsError("not-found", "School administrator is unavailable");
    }
    if (target.get("state") === "removing" && target.get("removal_action") !== "removed") {
      throw new HttpsError("failed-precondition", "A different administrator change is already in progress");
    }
    if (target.get("state") === "active") {
      txn.update(targetRef, {
        state: "removing", removal_action: "removed", removal_started_at: admin.firestore.Timestamp.now(),
      });
    }
  });
  await revokeStaffSchoolAccess(targetUid, schoolId);
  await revokeSchoolReaderForUid(schoolId, targetUid);
  // A second pass catches grants committed before the removing fence. New
  // refreshes cannot grant because the admin row is no longer active.
  await revokeStaffSchoolAccess(targetUid, schoolId);
  await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, schools().doc(schoolId));
    await requireAdmin(txn, schoolId, uid);
    if (uid === targetUid) throw new HttpsError("failed-precondition", "Transfer admin rights before leaving the school");
    const target = await txn.get(targetRef);
    if (!target.exists || target.get("state") !== "removing" || target.get("removal_action") !== "removed") {
      throw new HttpsError("aborted", "School administrator removal changed; retry the operation");
    }
    txn.update(targetRef, { state: "removed", ended_at: admin.firestore.Timestamp.now() });
    const memberRef = memberships().doc(membershipId(schoolId, { ownerUid: targetUid, profileId: String(target.get("profile_id") ?? "") }));
    txn.set(memberRef, { role: "member", updated_at: admin.firestore.Timestamp.now() }, { merge: true });
    txn.update(schools().doc(schoolId), { membership_revision: admin.firestore.FieldValue.increment(1), updated_at: admin.firestore.Timestamp.now() });
    txn.set(audit().doc(), { school_id: schoolId, actor_uid: uid, subject_uid: targetUid, action: "school_admin_removed", at: admin.firestore.Timestamp.now() });
  });
  await refreshSchoolReaders(schoolId);
  await revokeStaffSchoolAccess(targetUid, schoolId);
  return { success: true };
});

export const transferSchoolAdmin = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "targetUid", "profileId"]);
  const schoolId = schoolRef(data.schoolId).id;
  const targetUid = requiredString(data.targetUid, "targetUid");
  const profileId = requiredString(data.profileId, "profileId");
  if (uid === targetUid) throw new HttpsError("invalid-argument", "A different administrator must receive the transfer");
  const now = admin.firestore.Timestamp.now();
  const sourceRef = admins().doc(staffId(schoolId, uid));
  await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, schools().doc(schoolId));
    const source = await txn.get(sourceRef);
    if (!source.exists || !["active", "removing"].includes(String(source.get("state")))) {
      throw new HttpsError("permission-denied", "School administrator access required");
    }
    if (source.get("state") === "removing" &&
        (source.get("removal_action") !== "transferred" || source.get("transferred_to_uid") !== targetUid ||
         source.get("transferred_to_profile_id") !== profileId)) {
      throw new HttpsError("failed-precondition", "A different administrator change is already in progress");
    }
    const memberRef = memberships().doc(membershipId(schoolId, { ownerUid: targetUid, profileId }));
    const member = await txn.get(memberRef);
    if (!member.exists || member.get("state") !== "active") throw new HttpsError("failed-precondition", "Only an active member can receive admin rights");
    if (source.get("state") === "active") {
      txn.update(sourceRef, {
        state: "removing", removal_action: "transferred", transferred_to_uid: targetUid,
        transferred_to_profile_id: profileId, removal_started_at: now,
      });
    }
  });
  await revokeStaffSchoolAccess(uid, schoolId);
  await revokeSchoolReaderForUid(schoolId, uid);
  await revokeStaffSchoolAccess(uid, schoolId);
  await db.runTransaction(async (txn) => {
    await requireActiveSchool(txn, schools().doc(schoolId));
    const source = await txn.get(sourceRef);
    if (!source.exists || source.get("state") !== "removing" || source.get("removal_action") !== "transferred" ||
        source.get("transferred_to_uid") !== targetUid || source.get("transferred_to_profile_id") !== profileId) {
      throw new HttpsError("aborted", "School administrator transfer changed; retry the operation");
    }
    const memberRef = memberships().doc(membershipId(schoolId, { ownerUid: targetUid, profileId }));
    const member = await txn.get(memberRef);
    if (!member.exists || member.get("state") !== "active") throw new HttpsError("failed-precondition", "Only an active member can receive admin rights");
    txn.set(admins().doc(staffId(schoolId, targetUid)), { school_id: schoolId, owner_uid: targetUid, profile_id: profileId, role: "admin", state: "active", created_at: now, updated_at: now });
    txn.update(sourceRef, { state: "transferred", ended_at: now });
    txn.set(memberRef, { role: "admin", updated_at: now }, { merge: true });
    txn.update(schools().doc(schoolId), { membership_revision: admin.firestore.FieldValue.increment(1), updated_at: now });
    txn.set(audit().doc(), { school_id: schoolId, actor_uid: uid, subject_uid: targetUid, action: "school_admin_transferred", at: now });
  });
  await refreshSchoolReaders(schoolId);
  await revokeStaffSchoolAccess(uid, schoolId);
  return { success: true };
});

export const reportSchool = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "category"]);
  const ref = schoolRef(data.schoolId);
  const category = requiredString(data.category, "category", 40);
  if (!new Set(["impersonation", "abuse", "other"]).has(category)) throw new HttpsError("invalid-argument", "Unsupported report category");
  await rateLimit(uid, "report");
  await db.runTransaction(async (txn) => {
    const school = await txn.get(ref);
    if (!school.exists || school.get("status") === "deleted") throw new HttpsError("not-found", "School is unavailable");
    txn.create(reports().doc(), { school_id: ref.id, reporter_uid: uid, category, state: "open", created_at: admin.firestore.Timestamp.now() });
  });
  return { success: true };
});

async function requireAppOwner(request: { auth?: { token?: Record<string, unknown> } | null }) {
  if (request.auth?.token?.app_owner !== true) throw new HttpsError("permission-denied", "App owner access is required");
}
export const setSchoolVerified = onCall(CALL_OPTS, async (request) => {
  await requireAppOwner(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "verified"]);
  if (typeof data.verified !== "boolean") throw new HttpsError("invalid-argument", "verified must be a boolean");
  const ref = schoolRef(data.schoolId);
  await ref.update({ verified: data.verified, verified_at: data.verified ? admin.firestore.Timestamp.now() : null, updated_at: admin.firestore.Timestamp.now() });
  await auditEvent(ref.id, request.auth!.uid, data.verified ? "school_verified" : "school_unverified");
  return { success: true };
});
export const setSchoolSuspended = onCall(CALL_OPTS, async (request) => {
  await requireAppOwner(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId", "suspended"]);
  if (typeof data.suspended !== "boolean") throw new HttpsError("invalid-argument", "suspended must be a boolean");
  const ref = schoolRef(data.schoolId);
  if (data.suspended) {
    await db.runTransaction(async (txn) => {
      const current = await txn.get(ref);
      if (!current.exists || !["active", "suspended"].includes(String(current.get("status")))) {
        throw new HttpsError("failed-precondition", "School cannot be suspended in its current state");
      }
      txn.update(ref, { status: "suspended", access_cleanup_pending: true, updated_at: admin.firestore.Timestamp.now() });
    });
    const staffSnap = await admins().where("school_id", "==", ref.id).where("state", "==", "active").get();
    await Promise.all(staffSnap.docs.map((staff) =>
      revokeStaffSchoolAccess(String(staff.get("owner_uid")), ref.id),
    ));
    const memberSnap = await memberships().where("school_id", "==", ref.id).get();
    for (const member of memberSnap.docs) {
      await revokeSchoolDependentSocial({
        ownerUid: String(member.get("owner_uid")),
        profileId: String(member.get("profile_id")),
      }, ref.id);
    }
    await refreshSchoolReaders(ref.id, true);
    await db.runTransaction(async (txn) => {
      const current = await txn.get(ref);
      if (!current.exists || current.get("status") !== "suspended") {
        throw new HttpsError("aborted", "School changed during suspension; retry the operation");
      }
      txn.update(ref, { access_cleanup_pending: false, updated_at: admin.firestore.Timestamp.now() });
    });
  } else {
    await db.runTransaction(async (txn) => {
      const current = await txn.get(ref);
      if (!current.exists || current.get("status") !== "suspended" || current.get("access_cleanup_pending") === true) {
        throw new HttpsError("failed-precondition", "School cannot be unsuspended while access cleanup is pending");
      }
      txn.update(ref, { status: "active", updated_at: admin.firestore.Timestamp.now() });
    });
    const memberSnap = await memberships().where("school_id", "==", ref.id).where("state", "==", "active").get();
    for (const member of memberSnap.docs) {
      await refreshSocialMembershipMirror(summaryId({
        ownerUid: String(member.get("owner_uid")),
        profileId: String(member.get("profile_id")),
      }));
    }
  }
  if (data.suspended) {
    const inviteSnap = await invites().where("school_id", "==", ref.id).where("state", "==", "active").get();
    const batch = db.batch();
    inviteSnap.docs.forEach((doc) => batch.update(doc.ref, { state: "revoked", updated_at: admin.firestore.Timestamp.now() }));
    await batch.commit();
  }
  if (!data.suspended) await refreshSchoolReaders(ref.id);
  await auditEvent(ref.id, request.auth!.uid, data.suspended ? "school_suspended" : "school_unsuspended");
  return { success: true };
});

export const deleteSchool = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["schoolId"]);
  const ref = schoolRef(data.schoolId);
  const preflight = await db.runTransaction(async (txn) => {
    const school = await txn.get(ref);
    if (!school.exists || !["active", "suspended"].includes(String(school.get("status")))) {
      throw new HttpsError("not-found", "School is unavailable");
    }
    await requireAdmin(txn, ref.id, uid);
    const members = await txn.get(memberships().where("school_id", "==", ref.id));
    txn.update(ref, { status: "deleting", access_cleanup_pending: true, updated_at: admin.firestore.Timestamp.now() });
    txn.set(audit().doc(), { school_id: ref.id, actor_uid: uid, action: "school_deletion_started", at: admin.firestore.Timestamp.now() });
    return { members };
  });
  await cleanupLearningGroupsForSchool(ref.id);
  const staffSnap = await admins().where("school_id", "==", ref.id).where("state", "==", "active").get();
  await Promise.all(staffSnap.docs.map((staff) =>
    revokeStaffSchoolAccess(String(staff.get("owner_uid")), ref.id),
  ));
  for (const member of preflight.members.docs) {
    await revokeSchoolDependentSocial({
      ownerUid: String(member.get("owner_uid")),
      profileId: String(member.get("profile_id")),
    }, ref.id);
  }
  await refreshSchoolReaders(ref.id, true);
  const [memberSnap, adminSnap, inviteSnap] = await Promise.all([
    memberships().where("school_id", "==", ref.id).get(),
    admins().where("school_id", "==", ref.id).get(),
    invites().where("school_id", "==", ref.id).get(),
  ]);
  const staffUids = adminSnap.docs.map((doc) => String(doc.get("owner_uid")));
  for (const member of memberSnap.docs) {
    const memberRef = { ownerUid: String(member.get("owner_uid")), profileId: String(member.get("profile_id")) };
    await Promise.all(staffUids.map((staffUid) => setSummaryReader(memberRef, staffUid, ref.id, false)));
    await member.ref.update({ state: "deleted", ended_at: admin.firestore.Timestamp.now() });
  }
  const batch = db.batch();
  [...adminSnap.docs, ...inviteSnap.docs].forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  await refreshSchoolReaders(ref.id, true);
  await ref.update({ status: "deleted", deleted_at: admin.firestore.Timestamp.now() });
  return { success: true };
});

/** Idempotent membership/admin cleanup used by profile and account deletion. */
export async function cleanupSchoolAccess(ownerUid: string, profileId?: string): Promise<void> {
  let adminQuery: FirebaseFirestore.Query = admins().where("owner_uid", "==", ownerUid);
  if (profileId) adminQuery = adminQuery.where("profile_id", "==", profileId);
  const adminSnap = await adminQuery.get();
  // Fence every school for which this account is the last active admin before
  // revoking any staff/member ACL or changing any membership row.
  const lastAdminCleanup = new Set<string>();
  for (const doc of adminSnap.docs) {
    const schoolId = String(doc.get("school_id"));
    if (doc.get("state") === "active" && await beginLastAdminCleanup(schoolId, ownerUid)) {
      lastAdminCleanup.add(schoolId);
      continue;
    }
    const schoolRef = schools().doc(schoolId);
    const adminRef = admins().doc(doc.id);
    const fencedAsLast = await db.runTransaction(async (txn) => {
      const [school, staff] = await Promise.all([txn.get(schoolRef), txn.get(adminRef)]);
      if (!school.exists || school.get("status") === "deleted") return false;
      if (school.get("cleanup_pending") === true) return true;
      if (!staff.exists || staff.get("state") === "removed" || staff.get("state") === "transferred") return false;
      if (staff.get("state") === "removing") {
        if (staff.get("removal_action") !== "account_deleted") {
          throw new HttpsError("aborted", "Another school administrator change is in progress; retry account deletion");
        }
        return false;
      }
      if (staff.get("state") !== "active") return false;
      const activeAdmins = await txn.get(admins().where("school_id", "==", schoolId).where("state", "==", "active"));
      if (activeAdmins.size <= 1) {
        txn.update(schoolRef, {
          status: "suspended", cleanup_pending: true, updated_at: admin.firestore.Timestamp.now(),
        });
        return true;
      }
      txn.update(adminRef, {
        state: "removing", removal_action: "account_deleted", removal_started_at: admin.firestore.Timestamp.now(),
      });
      return false;
    });
    if (fencedAsLast) lastAdminCleanup.add(schoolId);
  }
  await Promise.all(adminSnap.docs.map((doc) =>
    revokeStaffSchoolAccess(ownerUid, String(doc.get("school_id"))),
  ));
  let query: FirebaseFirestore.Query = memberships().where("owner_uid", "==", ownerUid);
  if (profileId) query = query.where("profile_id", "==", profileId);
  const members = await query.get();
  for (const member of members.docs) {
    const schoolId = String(member.get("school_id"));
    const ref = { ownerUid, profileId: String(member.get("profile_id")) };
    await revokeSchoolDependentSocial(ref, schoolId);
    await revokeSchoolReaderForMember(schoolId, ref);
    await member.ref.update({ state: "removed", ended_at: admin.firestore.Timestamp.now(), removal_reason: "account_deleted" });
  }
  for (const doc of adminSnap.docs) {
    const schoolId = String(doc.get("school_id"));
    if (lastAdminCleanup.has(schoolId)) {
      await finishLastAdminCleanup(schoolId, ownerUid);
    } else {
      const currentAdmin = await doc.ref.get();
      if (currentAdmin.get("state") !== "removing" || currentAdmin.get("removal_action") !== "account_deleted") {
        throw new HttpsError("aborted", "Last administrator cleanup was not fenced; retry account deletion");
      }
      await revokeSchoolReaderForUid(schoolId, ownerUid);
      await doc.ref.update({ state: "removed", ended_at: admin.firestore.Timestamp.now() });
      await refreshSchoolReaders(schoolId);
      await revokeStaffSchoolAccess(ownerUid, schoolId);
    }
  }
}
