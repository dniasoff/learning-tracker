import * as crypto from "crypto";
import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { assertActiveParentSessionInTransaction } from "./parent_session_validation";
import { CALL_OPTS, db } from "./shared";

const MAX_MEMBERS = 12;
const MAX_GROUPS_PER_ACCOUNT = 12;
const MAX_GROUP_NAME = 64;
const MAX_INVITE_USES = 12;
const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const PAGE_SIZE = 200;

type ProfileRef = { ownerUid: string; profileId: string; mode: "adult" | "child" };
type GroupMember = ProfileRef & { uid: string; role: "admin" | "member"; state: string };

const groups = () => db.collection("learning_groups");
const invites = () => db.collection("learning_group_invites");
const audits = () => db.collection("learning_group_audit_logs");
const limits = () => db.collection("learning_group_rate_limits");
const approvals = () => db.collection("learning_group_parent_approvals");
const schools = () => db.collection("schools");
const schoolAdmins = () => db.collection("school_admins");
const schoolMemberships = () => db.collection("school_memberships");
const socialProfiles = () => db.collection("social_profiles");
const parentControls = () => db.collection("social_parent_controls");
const socialUserControls = () => db.collection("social_user_controls");
const socialSummaries = () => db.collection("social_summaries");

function hash(...values: string[]): string {
  return crypto.createHash("sha256").update(values.join("\0")).digest("hex");
}
function profileKey(ref: Pick<ProfileRef, "ownerUid" | "profileId">): string {
  return hash(ref.ownerUid, ref.profileId);
}
function memberRef(groupId: string, uid: string) {
  return groups().doc(groupId).collection("members").doc(uid);
}
function profileMemberRef(groupId: string, uid: string, profileId: string) {
  return memberRef(groupId, uid).collection("group_profiles").doc(profileId);
}
function summaryRef(ref: Pick<ProfileRef, "ownerUid" | "profileId">) {
  return socialSummaries().doc(profileKey(ref));
}
function approvalId(groupId: string, childUid: string, childProfileId: string, readerUid: string) {
  return hash("group-parent-approval", groupId, childUid, childProfileId, readerUid);
}
function requireAuth(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Must be signed in");
  return request.auth.uid;
}
function exactKeys(data: Record<string, unknown>, allowed: readonly string[]): void {
  if (Object.keys(data).some((key) => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", "Request contains unsupported fields");
  }
}
function requiredString(value: unknown, name: string, max = 128): string {
  if (typeof value !== "string" || !value.trim() || value.length > max) {
    throw new HttpsError("invalid-argument", `${name} must be a non-empty string`);
  }
  return value.trim();
}
function groupRef(value: unknown) {
  const id = requiredString(value, "groupId", 64);
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(id)) throw new HttpsError("invalid-argument", "groupId is invalid");
  return groups().doc(id);
}
function summaryId(value: ProfileRef): string { return profileKey(value); }
function strList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}
function memberFrom(uid: string, snap: FirebaseFirestore.DocumentSnapshot): GroupMember {
  const mode = snap.get("mode");
  if (mode !== "adult" && mode !== "child") throw new Error("Group member mode is invalid");
  return {
    uid,
    ownerUid: String(snap.get("owner_uid")),
    profileId: String(snap.get("profile_id")),
    mode,
    role: snap.get("role") === "admin" ? "admin" : "member",
    state: String(snap.get("state")),
  };
}
async function requireActiveGroup(txn: FirebaseFirestore.Transaction, ref: FirebaseFirestore.DocumentReference) {
  const snap = await txn.get(ref);
  if (!snap.exists || snap.get("status") !== "active") throw new HttpsError("not-found", "Group is unavailable");
  if (snap.get("group_type") === "school") {
    const school = await txn.get(schools().doc(String(snap.get("school_id"))));
    if (!school.exists || school.get("status") !== "active") throw new HttpsError("not-found", "Group is unavailable");
  }
  return snap;
}
async function requireAdmin(txn: FirebaseFirestore.Transaction, groupId: string, uid: string) {
  const group = await txn.get(groups().doc(groupId));
  const account = await txn.get(memberRef(groupId, uid));
  const adminProfileId = String(group.get("admin_profile_id") ?? "");
  const profile = adminProfileId ? await txn.get(profileMemberRef(groupId, uid, adminProfileId)) : null;
  if (!group.exists || group.get("admin_uid") !== uid || !account.exists || account.get("state") !== "active" ||
      !profile?.exists || profile.get("state") !== "active" || profile.get("mode") !== "adult") {
    throw new HttpsError("permission-denied", "Group administrator access is required");
  }
  return { accountRef: account.ref, profileRef: profile.ref, profileId: adminProfileId };
}
async function requireAdultProfile(txn: FirebaseFirestore.Transaction, uid: string, profileId: string) {
  const learner = await txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(profileId));
  if (!learner.exists || learner.get("mode") !== "adult") throw new HttpsError("permission-denied", "An adult learner profile is required");
  return learner;
}
async function rateLimit(uid: string, action: "create" | "invite" | "join") {
  const now = admin.firestore.Timestamp.now();
  const day = now.toDate().toISOString().slice(0, 10);
  const ref = limits().doc(hash("group-rate", uid, action));
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    const count = snap.get("day") === day ? Number(snap.get("count") ?? 0) : 0;
    const cap = action === "create" ? 3 : action === "invite" ? 30 : 40;
    if (count >= cap) throw new HttpsError("resource-exhausted", "Group action limit reached");
    txn.set(ref, { day, count: count + 1, updated_at: now });
  });
}
async function audit(groupId: string, actorUid: string, action: string, details: Record<string, unknown> = {}) {
  await audits().add({ group_id: groupId, actor_uid: actorUid, action, details, at: admin.firestore.Timestamp.now() });
}
async function activeSchoolMembership(txn: FirebaseFirestore.Transaction, schoolId: string, uid: string, profileId: string) {
  const ref = schoolMemberships().doc(hash("school-member", schoolId, uid, profileId));
  const snap = await txn.get(ref);
  return snap.exists && snap.get("state") === "active";
}
async function assertGroupProfileEligibility(
  txn: FirebaseFirestore.Transaction,
  group: FirebaseFirestore.DocumentSnapshot,
  uid: string,
  profileId: string,
  mode: "adult" | "child",
  parentSessionId: unknown,
) {
  if (mode === "child") {
    await assertActiveParentSessionInTransaction(txn, uid, profileId, parentSessionId);
    const [social, controls, account] = await Promise.all([
      txn.get(socialProfiles().doc(hash(uid, profileId))),
      txn.get(parentControls().doc(hash(uid, profileId))),
      txn.get(socialUserControls().doc(uid)),
    ]);
    if (social.get("paused") === true || controls.get("paused") === true || controls.get("controls_update_pending") === true) {
      // A paused child can still participate, but no group summary grant is created.
    }
    if (group.get("group_type") === "school") {
      const schoolId = String(group.get("school_id"));
      const school = await txn.get(schools().doc(schoolId));
      if (!school.exists || school.get("status") !== "active") throw new HttpsError("not-found", "Group is unavailable");
      if (!await activeSchoolMembership(txn, schoolId, uid, profileId)) {
        throw new HttpsError("permission-denied", "The child must be an active member of this school");
      }
      if (!strList(controls.get("allowed_school_ids")).includes(schoolId)) {
        throw new HttpsError("permission-denied", "The school is not allowed for this child");
      }
    }
    void account; // The read fences concurrent parent pause/control updates.
  } else if (group.get("group_type") === "school") {
    const school = await txn.get(schools().doc(String(group.get("school_id"))));
    if (!school.exists || school.get("status") !== "active" ||
        !await activeSchoolMembership(txn, String(group.get("school_id")), uid, profileId)) {
      throw new HttpsError("permission-denied", "An active school membership is required");
    }
  }
}
function socialSharingEnabled(member: GroupMember, profileSnap: FirebaseFirestore.DocumentSnapshot, controlsSnap: FirebaseFirestore.DocumentSnapshot) {
  return member.mode !== "child" || (
    profileSnap.exists && profileSnap.get("paused") !== true &&
    controlsSnap.exists && controlsSnap.get("paused") !== true &&
    controlsSnap.get("controls_update_pending") !== true
  );
}
async function chooseActiveReaderProfile(
  txn: FirebaseFirestore.Transaction,
  account: FirebaseFirestore.DocumentSnapshot,
  profiles: readonly FirebaseFirestore.QueryDocumentSnapshot[],
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const activeIds = strList(account.get("active_profile_ids"));
  for (const profile of profiles) {
    if (!activeIds.includes(profile.id)) continue;
    const member = memberFrom(account.id, profile);
    if (member.mode === "adult") return profile;
    const [social, controls, userControls] = await Promise.all([
      txn.get(socialProfiles().doc(summaryId(member))),
      txn.get(parentControls().doc(summaryId(member))),
      txn.get(socialUserControls().doc(member.uid)),
    ]);
    if (socialSharingEnabled(member, social, controls) &&
        strList(userControls.get("active_social_child_profile_ids")).includes(summaryId(member))) return profile;
  }
  return null;
}

/** Merge a group grant only after rechecking both active memberships in the write transaction. */
export async function grantGroupSummary(groupId: string, owner: GroupMember, reader: GroupMember): Promise<void> {
  const gRef = groups().doc(groupId);
  const targetMemberRef = profileMemberRef(groupId, owner.uid, owner.profileId);
  const readerAccountRef = memberRef(groupId, reader.uid);
  const readerMemberRef = profileMemberRef(groupId, reader.uid, reader.profileId);
  const socialRef = socialProfiles().doc(summaryId(owner));
  const controlsRef = parentControls().doc(summaryId(owner));
  const userControlRef = socialUserControls().doc(owner.uid);
  const aclRef = summaryRef(owner).collection("readers").doc(reader.uid);
  await db.runTransaction(async (txn) => {
    const [group, targetMember, readerAccount, readerMember, social, controls, userControls, acl] = await Promise.all([
      txn.get(gRef), txn.get(targetMemberRef), txn.get(readerAccountRef), txn.get(readerMemberRef), txn.get(socialRef),
      txn.get(controlsRef), txn.get(userControlRef), txn.get(aclRef),
    ]);
    if (!group.exists || group.get("status") !== "active" ||
        !targetMember.exists || targetMember.get("state") !== "active" ||
        !readerAccount.exists || readerAccount.get("state") !== "active" ||
        !strList(readerAccount.get("active_profile_ids")).includes(reader.profileId) ||
        !readerMember.exists || readerMember.get("state") !== "active") return;
    if (group.get("group_type") === "school") {
      const school = await txn.get(schools().doc(String(group.get("school_id"))));
      if (!school.exists || school.get("status") !== "active") return;
    }
    const target = memberFrom(owner.uid, targetMember);
    const recipient = memberFrom(reader.uid, readerMember);
    if (!socialSharingEnabled(target, social, controls)) return;
    if (target.mode === "child" && !strList(userControls.get("active_social_child_profile_ids")).includes(summaryId(target))) return;
    if (recipient.mode === "child" && !socialSharingEnabled(recipient,
      await txn.get(socialProfiles().doc(summaryId(recipient))),
      await txn.get(parentControls().doc(summaryId(recipient))))) return;
    if (recipient.mode === "child") {
      const controls = await txn.get(socialUserControls().doc(recipient.uid));
      if (!strList(controls.get("active_social_child_profile_ids")).includes(summaryId(recipient))) return;
    }
    if (target.mode === "child" && target.uid !== recipient.uid && !strList(targetMember.get("approved_reader_uids")).includes(reader.uid)) return;
    const ids = strList(acl.get("group_ids"));
    // A per-reader ACL stores one representative active shared group. The
    // rules verify both memberships in that group directly on every read.
    // Keeping one ID also stays within Firestore's rules document-access cap.
    if (ids.length > 0 && ids[0] !== groupId) return;
    txn.set(aclRef, {
      owner_uid: owner.ownerUid,
      profile_id: owner.profileId,
      group_ids: [groupId],
      group_id: groupId,
      reader_uid: reader.uid,
      reader_profile_id: reader.profileId,
      updated_at: admin.firestore.Timestamp.now(),
    }, { merge: true });
  });
}
async function revokeGroupSummary(groupId: string, owner: ProfileRef, readerUid: string): Promise<void> {
  const aclRef = summaryRef(owner).collection("readers").doc(readerUid);
  const ownerMembers = await db.collectionGroup("group_profiles")
    .where("owner_uid", "==", owner.ownerUid)
    .where("profile_id", "==", owner.profileId)
    .where("state", "==", "active")
    .limit(100).get();
  const candidates: Array<{ groupId: string; group: FirebaseFirestore.DocumentReference; owner: FirebaseFirestore.DocumentReference; reader: FirebaseFirestore.DocumentReference }> = [];
  for (const doc of ownerMembers.docs) {
    const parent = doc.ref.parent.parent?.parent?.parent;
    if (!parent) continue;
    candidates.push({ groupId: parent.id, group: parent, owner: doc.ref, reader: memberRef(parent.id, readerUid) });
  }
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(aclRef);
    if (!snap.exists) return;
    const ids = strList(snap.get("group_ids"));
    if (!ids.includes(groupId)) return;
    let replacement: { groupId: string; readerProfileId: string } | null = null;
    for (const candidate of candidates) {
      const [group, ownerMember, readerAccount, readerProfiles] = await Promise.all([
        txn.get(candidate.group), txn.get(candidate.owner), txn.get(candidate.reader),
        txn.get(candidate.reader.collection("group_profiles").where("state", "==", "active").limit(MAX_MEMBERS)),
      ]);
      if (!group.exists || group.get("status") !== "active" || !ownerMember.exists || ownerMember.get("state") !== "active" ||
          !readerAccount.exists || readerAccount.get("state") !== "active" || readerProfiles.empty) continue;
      if (ownerMember.get("mode") === "child" && !strList(ownerMember.get("approved_reader_uids")).includes(readerUid)) continue;
      const activeReaderProfile = await chooseActiveReaderProfile(txn, readerAccount, readerProfiles.docs);
      if (!activeReaderProfile) continue;
      replacement = { groupId: candidate.groupId, readerProfileId: activeReaderProfile.id };
      break;
    }
    const nextIds = replacement === null ? [] : [replacement.groupId];
    const followerIds = strList(snap.get("follower_profile_ids"));
    const schoolIds = strList(snap.get("school_ids"));
    if (nextIds.length === 0 && followerIds.length === 0 && schoolIds.length === 0) txn.delete(aclRef);
    else txn.set(aclRef, {
      group_ids: nextIds,
      group_id: replacement === null ? admin.firestore.FieldValue.delete() : replacement.groupId,
      reader_profile_id: replacement === null ? admin.firestore.FieldValue.delete() : replacement.readerProfileId,
      updated_at: admin.firestore.Timestamp.now(),
    }, { merge: true });
  });
}
async function activeMembers(groupId: string): Promise<GroupMember[]> {
  const accounts = await groups().doc(groupId).collection("members").where("state", "==", "active").limit(MAX_MEMBERS).get();
  const result: GroupMember[] = [];
  for (const account of accounts.docs) {
    const profiles = await account.ref.collection("group_profiles").where("state", "==", "active").limit(MAX_MEMBERS).get();
    result.push(...profiles.docs.map((doc) => memberFrom(account.id, doc)));
  }
  return result.slice(0, MAX_MEMBERS);
}
async function grantMemberToGroup(groupId: string, added: GroupMember): Promise<void> {
  const all = await activeMembers(groupId);
  const others = all.filter((member) => member.uid !== added.uid);
  const sameAccountProfiles = all.filter((member) => member.uid === added.uid && member.profileId !== added.profileId);
  for (const sibling of sameAccountProfiles) {
    await grantGroupSummary(groupId, added, sibling);
    await grantGroupSummary(groupId, sibling, added);
  }
  // The newly joined member receives grants from all existing members. Granting
  // the reverse direction is automatic only for adults; each child owner must
  // explicitly approve later joiners.
  for (const other of others) await grantGroupSummary(groupId, added, other);
  for (const other of others) {
    if (other.mode === "child") {
      const id = approvalId(groupId, other.uid, other.profileId, added.uid);
      const ref = approvals().doc(id);
      const existing = await ref.get();
      if (existing.get("state") === "approved") {
        await grantGroupSummary(groupId, other, added);
        continue;
      }
      await ref.set({
        group_id: groupId, child_uid: other.uid, child_profile_id: other.profileId,
        reader_uid: added.uid, reader_profile_id: added.profileId,
        state: "pending", created_at: admin.firestore.Timestamp.now(),
      }, { merge: true });
    } else {
      await grantGroupSummary(groupId, other, added);
    }
  }
}

/** Any adult can create a private group; school groups require a school admin. */
export const createLearningGroup = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["name", "profileId", "schoolId"]);
  const name = requiredString(data.name, "name", MAX_GROUP_NAME);
  const profileId = requiredString(data.profileId, "profileId");
  const schoolId = data.schoolId === undefined || data.schoolId === null ? null : requiredString(data.schoolId, "schoolId", 64);
  await rateLimit(uid, "create");
  const now = admin.firestore.Timestamp.now();
  const groupRef = groups().doc();
  const account = memberRef(groupRef.id, uid);
  const member = profileMemberRef(groupRef.id, uid, profileId);
  await db.runTransaction(async (txn) => {
    await requireAdultProfile(txn, uid, profileId);
    const owned = await txn.get(groups().where("created_by_uid", "==", uid).where("status", "==", "active").limit(MAX_GROUPS_PER_ACCOUNT));
    if (owned.size >= MAX_GROUPS_PER_ACCOUNT) throw new HttpsError("resource-exhausted", "Group creation limit reached");
    if (schoolId !== null) {
      const school = await txn.get(schools().doc(schoolId));
      const adminSnap = await txn.get(schoolAdmins().doc(hash("school-staff", schoolId, uid)));
      if (!school.exists || school.get("status") !== "active" || !adminSnap.exists ||
          adminSnap.get("state") !== "active" || adminSnap.get("role") !== "admin") {
        throw new HttpsError("permission-denied", "An active school administrator is required");
      }
    }
    txn.create(groupRef, {
      name, group_type: schoolId === null ? "private" : "school",
      ...(schoolId === null ? {} : { school_id: schoolId }),
      status: "active", created_by_uid: uid, admin_uid: uid, admin_profile_id: profileId, member_revision: 1,
      created_at: now, updated_at: now,
    });
    txn.create(account, { owner_uid: uid, active_profile_ids: [profileId], state: "active", created_at: now });
    txn.create(member, {
      group_id: groupRef.id, owner_uid: uid, profile_id: profileId,
      social_profile_id: hash(uid, profileId), member_id: hash("group-member", groupRef.id, uid, profileId),
      mode: "adult", role: "admin", state: "active", approved_reader_uids: [], created_at: now, joined_at: now,
    });
  });
  await audit(groupRef.id, uid, "group_created", { group_type: schoolId === null ? "private" : "school" });
  return { groupId: groupRef.id };
});

/** Creates a high-entropy, hashed, expiring, use-capped group invite. */
export const createLearningGroupInvite = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "uses"]);
  const ref = groupRef(data.groupId);
  const uses = data.uses === undefined ? 1 : Number(data.uses);
  if (!Number.isInteger(uses) || uses < 1 || uses > MAX_INVITE_USES) throw new HttpsError("invalid-argument", "uses is out of range");
  await rateLimit(uid, "invite");
  const token = crypto.randomBytes(32).toString("base64url");
  const now = admin.firestore.Timestamp.now();
  const expiry = admin.firestore.Timestamp.fromMillis(now.toMillis() + INVITE_TTL_MS);
  await db.runTransaction(async (txn) => {
    await requireActiveGroup(txn, ref);
    await requireAdmin(txn, ref.id, uid);
    txn.create(invites().doc(hash("learning-group-invite", token)), {
      group_id: ref.id, token_hash: hash("learning-group-invite", token),
      created_by_uid: uid, state: "active", uses, use_count: 0,
      created_at: now, expires_at: expiry,
    });
  });
  await audit(ref.id, uid, "group_invite_created");
  return { inviteCode: token, expiresAt: expiry.toDate().toISOString(), uses };
});

/** Bounded preview shown before an adult accepts or a parent approves a child. */
export const getLearningGroupInvite = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["inviteCode", "profileId", "parentSessionId"]);
  const token = requiredString(data.inviteCode, "inviteCode", 100);
  const profileId = requiredString(data.profileId, "profileId");
  const now = admin.firestore.Timestamp.now();
  const invite = await invites().doc(hash("learning-group-invite", token)).get();
  if (!invite.exists || invite.get("state") !== "active" ||
      !(invite.get("expires_at") instanceof admin.firestore.Timestamp) ||
      invite.get("expires_at").toMillis() <= now.toMillis() ||
      Number(invite.get("use_count")) >= Number(invite.get("uses"))) {
    throw new HttpsError("not-found", "Group invite is unavailable");
  }
  const group = await groups().doc(String(invite.get("group_id"))).get();
  const learner = await db.collection("users").doc(uid).collection("learner_profiles").doc(profileId).get();
  if (!group.exists || group.get("status") !== "active" || !learner.exists) throw new HttpsError("not-found", "Group invite is unavailable");
  const mode = learner.get("mode");
  if (mode !== "adult" && mode !== "child") throw new HttpsError("failed-precondition", "Learner profile is unavailable");
  await db.runTransaction(async (txn) => assertGroupProfileEligibility(txn, group, uid, profileId, mode, data.parentSessionId));
  const members = await activeMembers(group.id);
  const cards = await Promise.all(members.map(async (member) => {
    const profile = await socialProfiles().doc(summaryId(member)).get();
    return { displayName: profile.get("display_name") ?? "Learner" };
  }));
  const adminMember = members.find((item) => item.role === "admin");
  const adminCard = adminMember ? await socialProfiles().doc(summaryId(adminMember)).get() : null;
  return {
    groupId: group.id,
    name: group.get("name"),
    groupType: group.get("group_type"),
    memberRevision: Number(group.get("member_revision") ?? 0),
    schoolId: group.get("school_id") ?? null,
    adminName: adminCard?.get("display_name") ?? "Group administrator",
    members: cards,
    childConsentRequired: mode === "child",
  };
});

/** Accepts an invite. Child profile acceptance is a parent PIN-gated consent. */
export const joinLearningGroup = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["inviteCode", "profileId", "parentSessionId", "memberRevision"]);
  const token = requiredString(data.inviteCode, "inviteCode", 100);
  const profileId = requiredString(data.profileId, "profileId");
  await rateLimit(uid, "join");
  const now = admin.firestore.Timestamp.now();
  const inviteRef = invites().doc(hash("learning-group-invite", token));
  const joinedResult = await db.runTransaction(async (txn) => {
    const [invite, learner] = await Promise.all([
      txn.get(inviteRef),
      txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(profileId)),
    ]);
    if (!invite.exists || invite.get("state") !== "active" ||
        !(invite.get("expires_at") instanceof admin.firestore.Timestamp) ||
        invite.get("expires_at").toMillis() <= now.toMillis() ||
        Number(invite.get("use_count")) >= Number(invite.get("uses"))) {
      throw new HttpsError("not-found", "Group invite is unavailable");
    }
    if (!learner.exists || (learner.get("mode") !== "adult" && learner.get("mode") !== "child")) {
      throw new HttpsError("failed-precondition", "Learner profile is unavailable");
    }
    const mode = learner.get("mode") as "adult" | "child";
    const groupId = String(invite.get("group_id"));
    const gRef = groups().doc(groupId);
    const group = await requireActiveGroup(txn, gRef);
    if (!Number.isInteger(data.memberRevision) || Number(data.memberRevision) !== Number(group.get("member_revision") ?? 0)) {
      throw new HttpsError("aborted", "Group members changed; review the group again before joining");
    }
    await assertGroupProfileEligibility(txn, group, uid, profileId, mode, data.parentSessionId);
    const accountRef = memberRef(groupId, uid);
    const profileRef = profileMemberRef(groupId, uid, profileId);
    const [accountSnap, memberSnap] = await Promise.all([txn.get(accountRef), txn.get(profileRef)]);
    if (memberSnap.exists && memberSnap.get("state") === "active") {
      return { groupId, member: memberFrom(uid, memberSnap) }; // Idempotent acceptance retries can finish mirror work below.
    }
    const accounts = await txn.get(gRef.collection("members").where("state", "==", "active").limit(MAX_MEMBERS));
    const profilePages = await Promise.all(accounts.docs.map((account) => txn.get(account.ref.collection("group_profiles").where("state", "==", "active").limit(MAX_MEMBERS))));
    const members = profilePages.flatMap((page, index) => page.docs.map((doc) => memberFrom(accounts.docs[index].id, doc)));
    if (members.length >= MAX_MEMBERS) throw new HttpsError("resource-exhausted", "Group is full");
    const used = Number(invite.get("use_count")) + 1;
    txn.update(inviteRef, { use_count: used, state: used >= Number(invite.get("uses")) ? "redeemed" : "active", updated_at: now });
    const approvedReaders = mode === "child" ? [...new Set(members.map((member) => member.uid).filter((id) => id !== uid))] : [];
    txn.set(accountRef, {
      owner_uid: uid,
      active_profile_ids: [...new Set([...strList(accountSnap.get("active_profile_ids")), profileId])],
      state: "active", updated_at: now,
      ...(!accountSnap.exists ? { created_at: now } : {}),
    }, { merge: true });
    txn.set(profileRef, {
      group_id: groupId, owner_uid: uid, profile_id: profileId,
      social_profile_id: hash(uid, profileId), member_id: hash("group-member", groupId, uid, profileId),
      mode, role: "member", state: "active", approved_reader_uids: approvedReaders,
      created_at: now, joined_at: now,
    });
    txn.update(gRef, { member_revision: admin.firestore.FieldValue.increment(1), updated_at: now });
    return { groupId, member: { uid, ownerUid: uid, profileId, mode, role: "member", state: "active" } as GroupMember };
  });
  await grantMemberToGroup(joinedResult.groupId, joinedResult.member);
  await audit(joinedResult.groupId, uid, "group_member_joined", { mode: joinedResult.member.mode });
  return { success: true, groupId: joinedResult.groupId };
});

/** Lists the caller's active groups for a selected learner profile. */
export const listMyLearningGroups = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "parentSessionId"]);
  const profileId = requiredString(data.profileId, "profileId");
  const learner = await db.collection("users").doc(uid).collection("learner_profiles").doc(profileId).get();
  if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
  const membershipSnap = await db.collectionGroup("group_profiles")
    .where("owner_uid", "==", uid)
    .where("profile_id", "==", profileId)
    .where("state", "==", "active")
    .limit(50).get();
  const result = [];
  for (const member of membershipSnap.docs) {
    const groupRef = groups().doc(String(member.get("group_id")));
    if (!groupRef) continue;
    const group = await groupRef.get();
    if (!group.exists || group.get("status") !== "active") continue;
    if (group.get("group_type") === "school") {
      const school = await schools().doc(String(group.get("school_id"))).get();
      if (!school.exists || school.get("status") !== "active") continue;
    }
    const roster = await activeMembers(groupRef.id);
    result.push({
      groupId: groupRef.id, name: group.get("name"), groupType: group.get("group_type"),
      schoolId: group.get("school_id") ?? null, role: member.get("role"), memberCount: roster.length,
    });
  }
  return result;
});

export const getLearningGroup = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "profileId", "parentSessionId"]);
  const ref = groupRef(data.groupId);
  const profileId = requiredString(data.profileId, "profileId");
  const result = await db.runTransaction(async (txn) => {
    const group = await requireActiveGroup(txn, ref);
    const [requester, account, learner] = await Promise.all([
      txn.get(profileMemberRef(ref.id, uid, profileId)),
      txn.get(memberRef(ref.id, uid)),
      txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(profileId)),
    ]);
    if (!requester.exists || requester.get("state") !== "active" || !account.exists || account.get("state") !== "active" ||
        !strList(account.get("active_profile_ids")).includes(profileId) || !learner.exists) {
      throw new HttpsError("permission-denied", "Active group membership is required");
    }
    return { groupId: ref.id, name: group.get("name"), groupType: group.get("group_type"), schoolId: group.get("school_id") ?? null, role: requester.get("role") };
  });
  const members = await activeMembers(ref.id);
  const roster = await Promise.all(members.map(async (member) => {
    const social = await socialProfiles().doc(summaryId(member)).get();
    return { memberId: hash("group-member", ref.id, member.uid, member.profileId), summaryId: summaryId(member), displayName: social.get("display_name") ?? "Learner", avatarId: social.get("avatar_id") ?? "", role: member.role, mode: member.mode, isSelf: member.uid === uid && member.profileId === profileId };
  }));
  return { ...result, members: roster };
});

/** Parent-only queue for later members requesting access to a child summary. */
export const listGroupParentApprovals = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "parentSessionId"]);
  const profileId = requiredString(data.profileId, "profileId");
  await db.runTransaction((txn) => assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId));
  const page = await approvals().where("child_uid", "==", uid).where("child_profile_id", "==", profileId).where("state", "in", ["pending", "approved"]).limit(50).get();
  const result = [];
  for (const item of page.docs) {
    const group = await groups().doc(String(item.get("group_id"))).get();
    const readerUid = String(item.get("reader_uid"));
    const account = await memberRef(String(item.get("group_id")), readerUid).get();
    if (!group.exists || group.get("status") !== "active" || !account.exists || account.get("state") !== "active") continue;
    const reader = (await activeMembers(group.id)).find((member) => member.uid === readerUid);
    if (!reader) continue;
    const readerSocial = await socialProfiles().doc(summaryId(reader)).get();
    result.push({ approvalId: item.id, groupId: group.id, groupName: group.get("name"), displayName: readerSocial.get("display_name") ?? "Learner", approved: item.get("state") === "approved" });
  }
  return result;
});

/** Grant or revoke a specific member's access to a child profile. */
export const setGroupMemberApproval = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["approvalId", "profileId", "parentSessionId", "approved"]);
  const profileId = requiredString(data.profileId, "profileId");
  const approvalIdValue = requiredString(data.approvalId, "approvalId", 64);
  if (!/^[a-f0-9]{64}$/.test(approvalIdValue)) throw new HttpsError("invalid-argument", "approvalId is invalid");
  if (typeof data.approved !== "boolean") throw new HttpsError("invalid-argument", "approved must be boolean");
  const approvalRef = approvals().doc(approvalIdValue);
  const approvalSnapshot = await approvalRef.get();
  if (!approvalSnapshot.exists || approvalSnapshot.get("child_uid") !== uid || approvalSnapshot.get("child_profile_id") !== profileId) {
    throw new HttpsError("not-found", "Group approval is unavailable");
  }
  const group = groups().doc(String(approvalSnapshot.get("group_id")));
  const readerUid = String(approvalSnapshot.get("reader_uid"));
  const child: GroupMember = { uid, ownerUid: uid, profileId, mode: "child", role: "member", state: "active" };
  const childRef = profileMemberRef(group.id, uid, profileId);
  const readerRef = memberRef(group.id, readerUid);
  if (!data.approved) {
    // Deny first in the transaction; rule reads stop succeeding before ACL cleanup.
    await db.runTransaction(async (txn) => {
      const [g, member, reader, readerProfiles, approval] = await Promise.all([txn.get(group), txn.get(childRef), txn.get(readerRef), txn.get(readerRef.collection("group_profiles").where("state", "==", "active").limit(MAX_MEMBERS)), txn.get(approvalRef)]);
      if (!member.exists || member.get("profile_id") !== profileId || member.get("mode") !== "child") throw new HttpsError("permission-denied", "Child group membership is unavailable");
      await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
      if (!reader.exists || reader.get("state") !== "active" || readerProfiles.empty) throw new HttpsError("not-found", "Group member is unavailable");
      const allowed = strList(member.get("approved_reader_uids")).filter((id) => id !== readerUid);
      txn.set(childRef, { approved_reader_uids: allowed, updated_at: admin.firestore.Timestamp.now() }, { merge: true });
      if (approval.exists && approval.get("child_uid") === uid && approval.get("child_profile_id") === profileId && approval.get("reader_uid") === readerUid) txn.set(approvalRef, { state: "revoked", updated_at: admin.firestore.Timestamp.now() }, { merge: true });
      if (!g.exists) throw new HttpsError("not-found", "Group is unavailable");
    });
    await revokeGroupSummary(group.id, child, readerUid);
  } else {
    await db.runTransaction(async (txn) => {
      const [g, member, reader, readerProfiles, learner, approval] = await Promise.all([txn.get(group), txn.get(childRef), txn.get(readerRef), txn.get(readerRef.collection("group_profiles").where("state", "==", "active").limit(MAX_MEMBERS)), txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(profileId)), txn.get(approvalRef)]);
      if (!g.exists || g.get("status") !== "active" || !member.exists || member.get("state") !== "active" ||
          member.get("profile_id") !== profileId || member.get("mode") !== "child" || !approval.exists ||
          approval.get("child_uid") !== uid || approval.get("child_profile_id") !== profileId || approval.get("reader_uid") !== readerUid ||
          !reader.exists || reader.get("state") !== "active" || readerProfiles.empty || !learner.exists) throw new HttpsError("not-found", "Group approval is unavailable");
      await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
      const social = await txn.get(socialProfiles().doc(hash(uid, profileId)));
      const controls = await txn.get(parentControls().doc(hash(uid, profileId)));
      if (!socialSharingEnabled(child, social, controls)) throw new HttpsError("failed-precondition", "Child social sharing is paused");
      txn.set(childRef, { approved_reader_uids: [...new Set([...strList(member.get("approved_reader_uids")), readerUid])], updated_at: admin.firestore.Timestamp.now() }, { merge: true });
      txn.set(approvalRef, { state: "approved", updated_at: admin.firestore.Timestamp.now() }, { merge: true });
    });
    const reader = (await activeMembers(group.id)).find((member) => member.uid === readerUid);
    if (reader) await grantGroupSummary(group.id, child, reader);
  }
  await audit(group.id, uid, data.approved ? "child_group_member_approved" : "child_group_member_access_revoked");
  return { success: true };
});

/** Add an active account member; a parent's approval is required for child profiles. */
export const removeLearningGroupMember = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "memberId"]);
  const group = groupRef(data.groupId);
  const memberId = requiredString(data.memberId, "memberId", 64);
  if (!/^[a-f0-9]{64}$/.test(memberId)) throw new HttpsError("invalid-argument", "memberId is invalid");
  let memberUid = "";
  let profileId = "";
  await db.runTransaction(async (txn) => {
    await requireActiveGroup(txn, group);
    await requireAdmin(txn, group.id, uid);
    const matches = await txn.get(db.collectionGroup("group_profiles").where("group_id", "==", group.id).where("member_id", "==", memberId).limit(2));
    if (matches.size !== 1) throw new HttpsError("not-found", "Group member is unavailable");
    const targetRef = matches.docs[0].ref;
    profileId = targetRef.id;
    const accountRef = targetRef.parent.parent;
    if (!accountRef) throw new HttpsError("not-found", "Group member is unavailable");
    memberUid = accountRef.id;
    const target = await txn.get(targetRef);
    if (!target.exists || !["active", "revoking"].includes(String(target.get("state")))) throw new HttpsError("not-found", "Group member is unavailable");
    if (target.get("role") === "admin") throw new HttpsError("failed-precondition", "Transfer group admin before removing this member");
    if (target.get("state") === "active") {
      const [account, profiles, aclDocs] = await Promise.all([
        txn.get(accountRef),
        txn.get(accountRef.collection("group_profiles").where("state", "==", "active").limit(MAX_MEMBERS)),
        txn.get(db.collectionGroup("readers").where("reader_uid", "==", memberUid).where("group_id", "==", group.id).limit(MAX_MEMBERS)),
      ]);
      const activeIds = strList(account.get("active_profile_ids")).filter((id) => id !== profileId);
      const replacement = await chooseActiveReaderProfile(txn, account, profiles.docs.filter((profile) => profile.id !== profileId));
      if (replacement) {
        for (const acl of aclDocs.docs) {
          if (strList(acl.get("group_ids")).includes(group.id)) txn.set(acl.ref, { reader_profile_id: replacement.id, updated_at: admin.firestore.Timestamp.now() }, { merge: true });
        }
      }
      txn.update(targetRef, { state: "revoking", updated_at: admin.firestore.Timestamp.now() });
      txn.set(accountRef, { active_profile_ids: activeIds, state: activeIds.length ? "active" : "revoking", updated_at: admin.firestore.Timestamp.now() }, { merge: true });
      txn.update(group, { member_revision: admin.firestore.FieldValue.increment(1), updated_at: admin.firestore.Timestamp.now() });
    }
  });
  await finishMemberRemoval(group.id, memberUid, profileId);
  await audit(group.id, uid, "group_member_removed");
  return { success: true };
});

async function finishMemberRemoval(groupId: string, memberUid: string, profileId: string): Promise<void> {
  const targetRef = profileMemberRef(groupId, memberUid, profileId);
  const target = await targetRef.get();
  if (!target.exists || target.get("state") === "removed") return;
  if (target.get("state") !== "revoking") throw new HttpsError("failed-precondition", "Member removal was not fenced");
  const removed = memberFrom(memberUid, target);
  const roster = await activeMembers(groupId);
  for (const other of roster) {
    if (other.uid !== memberUid) await revokeGroupSummary(groupId, other, memberUid);
    await revokeGroupSummary(groupId, removed, other.uid);
  }
  const pending = await approvals().where("group_id", "==", groupId).where("reader_uid", "==", memberUid).limit(100).get();
  const pendingAsChild = await approvals().where("group_id", "==", groupId).where("child_uid", "==", memberUid).where("child_profile_id", "==", profileId).limit(100).get();
  const sameAccountProfiles = await memberRef(groupId, memberUid).collection("group_profiles").where("state", "==", "active").limit(MAX_MEMBERS).get();
  if (sameAccountProfiles.empty) {
    const batch = db.batch();
    for (const doc of [...pending.docs, ...pendingAsChild.docs]) batch.set(doc.ref, { state: "revoked", updated_at: admin.firestore.Timestamp.now() }, { merge: true });
    if (!pending.empty || !pendingAsChild.empty) await batch.commit();
    const children = await groups().doc(groupId).collection("members").get();
    for (const account of children.docs) {
      const profiles = await account.ref.collection("group_profiles").where("mode", "==", "child").where("state", "==", "active").get();
      for (const childDoc of profiles.docs) {
        if (!strList(childDoc.get("approved_reader_uids")).includes(memberUid)) continue;
        await childDoc.ref.update({ approved_reader_uids: strList(childDoc.get("approved_reader_uids")).filter((id) => id !== memberUid), updated_at: admin.firestore.Timestamp.now() });
      }
    }
  }
  await db.runTransaction(async (txn) => {
    const [current, account] = await Promise.all([txn.get(targetRef), txn.get(memberRef(groupId, memberUid))]);
    if (current.exists && current.get("state") === "revoking") txn.update(targetRef, { state: "removed", removed_at: admin.firestore.Timestamp.now(), updated_at: admin.firestore.Timestamp.now() });
    if (account.exists && account.get("state") === "revoking" && strList(account.get("active_profile_ids")).length === 0) txn.update(account.ref, { state: "removed", updated_at: admin.firestore.Timestamp.now() });
  });
}

export const leaveLearningGroup = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "profileId", "parentSessionId"]);
  const group = groupRef(data.groupId);
  const profileId = requiredString(data.profileId, "profileId");
  await db.runTransaction(async (txn) => {
    await requireActiveGroup(txn, group);
    const [member, account] = await Promise.all([txn.get(profileMemberRef(group.id, uid, profileId)), txn.get(memberRef(group.id, uid))]);
    if (!member.exists || !["active", "revoking"].includes(String(member.get("state"))) || member.get("profile_id") !== profileId) throw new HttpsError("not-found", "Group membership is unavailable");
    if (member.get("role") === "admin") throw new HttpsError("failed-precondition", "Transfer group admin before leaving");
    if (member.get("state") === "active") {
      const learner = await txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(profileId));
      if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
      if (learner.get("mode") === "child") await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
      const activeIds = strList(account.get("active_profile_ids")).filter((id) => id !== profileId);
      txn.update(member.ref, { state: "revoking", updated_at: admin.firestore.Timestamp.now() });
      txn.set(account.ref, { active_profile_ids: activeIds, state: activeIds.length ? "active" : "revoking", updated_at: admin.firestore.Timestamp.now() }, { merge: true });
      txn.update(group, { member_revision: admin.firestore.FieldValue.increment(1), updated_at: admin.firestore.Timestamp.now() });
    }
  });
  await finishMemberRemoval(group.id, uid, profileId);
  await audit(group.id, uid, "group_member_left");
  return { success: true };
});

export const transferLearningGroupAdmin = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "memberId"]);
  const group = groupRef(data.groupId);
  const memberId = requiredString(data.memberId, "memberId", 64);
  if (!/^[a-f0-9]{64}$/.test(memberId)) throw new HttpsError("invalid-argument", "memberId is invalid");
  let nextUid = "";
  await db.runTransaction(async (txn) => {
    const g = await requireActiveGroup(txn, group);
    const matches = await txn.get(db.collectionGroup("group_profiles").where("group_id", "==", group.id).where("member_id", "==", memberId).limit(2));
    const oldAccount = await txn.get(memberRef(group.id, uid));
    if (matches.size !== 1) throw new HttpsError("not-found", "Group member is unavailable");
    const nextRef = matches.docs[0].ref;
    const nextAccountRef = nextRef.parent.parent;
    if (!nextAccountRef) throw new HttpsError("not-found", "Group member is unavailable");
    nextUid = nextAccountRef.id;
    const next = await txn.get(nextRef);
    const oldProfileRef = profileMemberRef(group.id, uid, String(g.get("admin_profile_id") ?? ""));
    const oldProfile = await txn.get(oldProfileRef);
    const nextAccount = await txn.get(nextAccountRef);
    if (!g.exists || g.get("status") !== "active" || g.get("admin_uid") !== uid || !oldAccount.exists || oldAccount.get("state") !== "active" ||
        !oldProfile.exists || oldProfile.get("state") !== "active" || oldProfile.get("role") !== "admin" ||
        !nextAccount.exists || nextAccount.get("state") !== "active" || !next.exists || next.get("state") !== "active" || next.get("mode") !== "adult") throw new HttpsError("failed-precondition", "An active adult group member is required");
    txn.update(oldProfile.ref, { role: "member", updated_at: admin.firestore.Timestamp.now() });
    txn.update(next.ref, { role: "admin", updated_at: admin.firestore.Timestamp.now() });
    txn.update(group, { admin_uid: nextUid, admin_profile_id: next.get("profile_id"), member_revision: admin.firestore.FieldValue.increment(1), updated_at: admin.firestore.Timestamp.now() });
  });
  await audit(group.id, uid, "group_admin_transferred");
  return { success: true };
});

export const deleteLearningGroup = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId"]);
  const ref = groupRef(data.groupId);
  await db.runTransaction(async (txn) => {
    const group = await txn.get(ref);
    if (!group.exists || !["active", "deleting"].includes(String(group.get("status")))) throw new HttpsError("not-found", "Group is unavailable");
    if (group.get("status") === "active") await requireAdmin(txn, ref.id, uid);
    else if (group.get("admin_uid") !== uid) throw new HttpsError("permission-denied", "Group administrator access is required");
    if (group.get("status") === "active") txn.update(ref, { status: "deleting", cleanup_pending: true, updated_at: admin.firestore.Timestamp.now() });
  });
  await finishGroupDeletion(ref.id);
  await audit(ref.id, uid, "group_deleted");
  return { success: true };
});

async function finishGroupDeletion(groupId: string): Promise<void> {
  const ref = groups().doc(groupId);
  const group = await ref.get();
  if (!group.exists || group.get("status") === "deleted") return;
  if (group.get("status") !== "deleting") throw new HttpsError("failed-precondition", "Group deletion was not fenced");
  const roster = await activeMembers(groupId);
  for (const member of roster) {
    for (const reader of roster) if (reader.uid !== member.uid) await revokeGroupSummary(groupId, member, reader.uid);
    for (const owner of roster) if (owner.uid !== member.uid) await revokeGroupSummary(groupId, owner, member.uid);
  }
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let query = invites().where("group_id", "==", groupId).limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    const batch = db.batch();
    page.docs.forEach((doc) => batch.set(doc.ref, { state: "revoked", updated_at: admin.firestore.Timestamp.now() }, { merge: true }));
    await batch.commit();
    if (page.size < PAGE_SIZE) break;
    cursor = page.docs[page.docs.length - 1];
  }
  const approvalQuery = await approvals().where("group_id", "==", groupId).limit(PAGE_SIZE).get();
  if (!approvalQuery.empty) {
    const batch = db.batch();
    approvalQuery.docs.forEach((doc) => batch.set(doc.ref, { state: "revoked", updated_at: admin.firestore.Timestamp.now() }, { merge: true }));
    await batch.commit();
  }
  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();
  const accounts = await ref.collection("members").limit(MAX_MEMBERS).get();
  for (const account of accounts.docs) {
    const profiles = await account.ref.collection("group_profiles").get();
    for (const profile of profiles.docs) batch.set(profile.ref, { state: "removed", removed_at: now, updated_at: now }, { merge: true });
    batch.set(account.ref, { active_profile_ids: [], state: "removed", updated_at: now }, { merge: true });
  }
  batch.update(ref, { status: "deleted", cleanup_pending: false, deleted_at: now, updated_at: now });
  await batch.commit();
}

/** School deletion fences school-hosted groups before their resumable cleanup. */
export async function cleanupLearningGroupsForSchool(schoolId: string): Promise<void> {
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let query = groups().where("school_id", "==", schoolId).orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const group of page.docs) {
      if (group.get("status") === "deleted") continue;
      if (group.get("status") === "active") {
        await db.runTransaction(async (txn) => {
          const current = await txn.get(group.ref);
          if (current.exists && current.get("status") === "active") txn.update(group.ref, { status: "deleting", cleanup_pending: true, updated_at: admin.firestore.Timestamp.now() });
        });
      }
      await finishGroupDeletion(group.id);
    }
    if (page.size < PAGE_SIZE) break;
    cursor = page.docs[page.docs.length - 1];
  }
}

/** Deny-first account/profile cleanup used by learner and account deletion. */
export async function cleanupGroupsForAccount(ownerUid: string, profileId?: string): Promise<void> {
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let query = db.collectionGroup("group_profiles").where("owner_uid", "==", ownerUid).where("state", "in", ["active", "revoking"])
      .orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const memberDoc of page.docs.filter((doc) => profileId === undefined || doc.get("profile_id") === profileId)) {
    const groupRef = memberDoc.ref.parent.parent;
    if (!groupRef) continue;
    const groupId = groupRef.id;
    const accountRef = memberDoc.ref.parent.parent;
    if (!accountRef) continue;
    const uid = accountRef.id;
    const group = await groupRef.get();
    if (!group.exists || group.get("status") === "deleted") continue;
    if (group.get("status") === "deleting") { await finishGroupDeletion(groupId); continue; }
    if (memberDoc.get("role") === "admin") {
      const candidates = (await activeMembers(groupId)).filter((item) => (item.uid !== uid || item.profileId !== memberDoc.id) && item.mode === "adult");
      const next = candidates[0];
      if (!next) {
        await db.runTransaction(async (txn) => {
          const current = await txn.get(groupRef);
          if (current.exists && current.get("status") === "active") txn.update(groupRef, { status: "deleting", cleanup_pending: true, updated_at: admin.firestore.Timestamp.now() });
        });
        await finishGroupDeletion(groupId);
        continue;
      }
      await db.runTransaction(async (txn) => {
        const [g, old, target, account] = await Promise.all([txn.get(groupRef), txn.get(memberDoc.ref), txn.get(profileMemberRef(groupId, next.uid, next.profileId)), txn.get(accountRef)]);
        if (g.exists && g.get("status") === "active" && old.exists && old.get("state") === "active" && target.exists && target.get("state") === "active") {
          txn.update(old.ref, { role: "member", state: "revoking", updated_at: admin.firestore.Timestamp.now() });
          txn.update(target.ref, { role: "admin", updated_at: admin.firestore.Timestamp.now() });
          const activeIds = strList(account.get("active_profile_ids")).filter((id) => id !== memberDoc.id);
          txn.set(accountRef, { active_profile_ids: activeIds, state: activeIds.length ? "active" : "revoking", updated_at: admin.firestore.Timestamp.now() }, { merge: true });
          txn.update(groupRef, { admin_uid: next.uid, admin_profile_id: next.profileId, member_revision: admin.firestore.FieldValue.increment(1), updated_at: admin.firestore.Timestamp.now() });
        }
      });
    } else if (memberDoc.get("state") === "active") {
      await db.runTransaction(async (txn) => {
        const [current, account] = await Promise.all([txn.get(memberDoc.ref), txn.get(accountRef)]);
        if (current.exists && current.get("state") === "active") {
          txn.update(memberDoc.ref, { state: "revoking", updated_at: admin.firestore.Timestamp.now() });
          const activeIds = strList(account.get("active_profile_ids")).filter((id) => id !== memberDoc.id);
          txn.set(accountRef, { active_profile_ids: activeIds, state: activeIds.length ? "active" : "revoking", updated_at: admin.firestore.Timestamp.now() }, { merge: true });
          txn.update(groupRef, { member_revision: admin.firestore.FieldValue.increment(1), updated_at: admin.firestore.Timestamp.now() });
        }
      });
    }
    const current = await memberDoc.ref.get();
    if (current.exists && current.get("state") === "revoking") await finishMemberRemoval(groupId, uid, memberDoc.id);
    }
    if (page.size < PAGE_SIZE) break;
    cursor = page.docs[page.docs.length - 1];
  }
}
