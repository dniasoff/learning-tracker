import * as crypto from "crypto";
import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { assertActiveParentSessionInTransaction } from "./parent_session_validation";
import { CALL_OPTS, db } from "./shared";
import { ULID_RE } from "./write_with_change_log";

const MAX_SCHOOLS = 20;
const MAX_PENDING_REQUESTS = 30;
const MAX_REQUESTS_PER_DAY = 20;
const MAX_ACCOUNT_REQUESTS_PER_DAY = 80;
const MAX_INBOUND_REQUESTS_PER_DAY = 50;
const MAX_PAGE_SIZE = 50;
const REQUEST_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const PROFILE_FIELDS = ["profileId", "displayName", "avatarId", "parentSessionId"] as const;
const SOCIAL_CURRICULA = new Set([
  "chumash", "nach", "tanach", "mishnayos", "bavli", "yerushalmi",
  "shnayim_mikra", "mishneh_torah", "mishna_berurah", "mussar",
]);
const SOCIAL_REF_RE = /^[\p{L}\p{N}][\p{L}\p{N} ,.:;’'"״׳–—-]{0,255}$/u;
const SOCIAL_IDENTIFIER_RE = /^[A-Za-z0-9_.-]{1,64}$/;

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
const summaries = () => db.collection("social_summaries");
const summaryRateLimits = () => db.collection("social_summary_rate_limits");

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

function summaryObject(value: unknown, keys: readonly string[], name: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${name} must be an object`);
  }
  const result = value as Record<string, unknown>;
  exactKeys(result, keys);
  return result;
}

function summaryCount(value: unknown, name: string): number {
  if (!Number.isInteger(value) || Number(value) < 0 || Number(value) > 100_000) {
    throw new HttpsError("invalid-argument", `${name} is outside its allowed range`);
  }
  return Number(value);
}

function summaryCurriculum(value: unknown): string {
  if (typeof value !== "string" || !SOCIAL_CURRICULA.has(value)) {
    throw new HttpsError("invalid-argument", "Unknown curriculum_id");
  }
  return value;
}

function summaryRef(value: unknown, name: string): string {
  if (typeof value !== "string" || value.length > 256 || !SOCIAL_REF_RE.test(value)) {
    throw new HttpsError("invalid-argument", `${name} must be a canonical reference`);
  }
  return value;
}

function uniqueCurriculumRows<T extends { curriculum_id: string }>(
  rows: T[], name: string,
): T[] {
  if (new Set(rows.map((row) => row.curriculum_id)).size !== rows.length) {
    throw new HttpsError("invalid-argument", `${name} contains duplicate curricula`);
  }
  return rows;
}

function normalizeSocialSummary(value: unknown): Record<string, unknown> {
  const input = summaryObject(value, ["streak", "current_tracks", "weekly_learning", "siyumim"], "summary");

  const streak = summaryObject(input.streak, ["by_curriculum", "overall"], "streak");
  if (!Array.isArray(streak.by_curriculum) || streak.by_curriculum.length > SOCIAL_CURRICULA.size) {
    throw new HttpsError("invalid-argument", "Invalid streak rows");
  }
  const streakRows = uniqueCurriculumRows(streak.by_curriculum.map((row) => {
    const data = summaryObject(row, ["curriculum_id", "current_days", "best_days"], "streak row");
    return {
      curriculum_id: summaryCurriculum(data.curriculum_id),
      current_days: summaryCount(data.current_days, "current_days"),
      best_days: summaryCount(data.best_days, "best_days"),
    };
  }), "streak");
  let overallStreak: Record<string, number> | undefined;
  if (streak.overall !== undefined) {
    const data = summaryObject(streak.overall, ["current_days", "best_days"], "overall streak");
    overallStreak = {
      current_days: summaryCount(data.current_days, "current_days"),
      best_days: summaryCount(data.best_days, "best_days"),
    };
  }

  if (!Array.isArray(input.current_tracks) || input.current_tracks.length > SOCIAL_CURRICULA.size) {
    throw new HttpsError("invalid-argument", "Invalid current_tracks");
  }
  const trackRows = uniqueCurriculumRows(input.current_tracks.map((row) => {
    const data = summaryObject(row, ["curriculum_id", "position_ref"], "current track");
    return {
      curriculum_id: summaryCurriculum(data.curriculum_id),
      position_ref: data.position_ref === null ? null : summaryRef(data.position_ref, "position_ref"),
    };
  }), "current_tracks");

  const weekly = summaryObject(input.weekly_learning, ["week_start", "by_curriculum", "overall"], "weekly_learning");
  if (typeof weekly.week_start !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(weekly.week_start) ||
      Number.isNaN(Date.parse(`${weekly.week_start}T00:00:00Z`)) ||
      new Date(`${weekly.week_start}T00:00:00Z`).getUTCDay() !== 0) {
    throw new HttpsError("invalid-argument", "week_start must be a Sunday civil date");
  }
  if (!Array.isArray(weekly.by_curriculum) || weekly.by_curriculum.length > SOCIAL_CURRICULA.size) {
    throw new HttpsError("invalid-argument", "Invalid weekly learning rows");
  }
  const weeklyRows = uniqueCurriculumRows(weekly.by_curriculum.map((row) => {
    const data = summaryObject(row, ["curriculum_id", "limudim", "chazaros"], "weekly learning row");
    return {
      curriculum_id: summaryCurriculum(data.curriculum_id),
      limudim: summaryCount(data.limudim, "limudim"),
      chazaros: summaryCount(data.chazaros, "chazaros"),
    };
  }), "weekly_learning");
  let overallWeekly: Record<string, number> | undefined;
  if (weekly.overall !== undefined) {
    const data = summaryObject(weekly.overall, ["limudim", "chazaros"], "overall weekly learning");
    overallWeekly = {
      limudim: summaryCount(data.limudim, "limudim"),
      chazaros: summaryCount(data.chazaros, "chazaros"),
    };
  }

  if (!Array.isArray(input.siyumim) || input.siyumim.length > 100) {
    throw new HttpsError("invalid-argument", "Invalid siyumim");
  }
  const siyumim = input.siyumim.map((row) => {
    const data = summaryObject(row, ["curriculum_id", "ref", "level"], "siyum");
    if (typeof data.level !== "string" || !SOCIAL_IDENTIFIER_RE.test(data.level)) {
      throw new HttpsError("invalid-argument", "siyum level must be an identifier");
    }
    return {
      curriculum_id: summaryCurriculum(data.curriculum_id),
      ref: summaryRef(data.ref, "siyum ref"),
      level: data.level,
    };
  });

  const result = {
    streak: { by_curriculum: streakRows, ...(overallStreak ? { overall: overallStreak } : {}) },
    current_tracks: trackRows,
    weekly_learning: {
      week_start: weekly.week_start,
      by_curriculum: weeklyRows,
      ...(overallWeekly ? { overall: overallWeekly } : {}),
    },
    siyumim,
  };
  if (Buffer.byteLength(JSON.stringify(result), "utf8") > 16_384) {
    throw new HttpsError("invalid-argument", "Social summary is too large");
  }
  return result;
}

function profileDocId(ref: ProfileRef): string {
  return opaqueId(ref.ownerUid, ref.profileId);
}

function summaryReaderRef(summaryOwner: ProfileRef, readerUid: string) {
  return summaries().doc(profileDocId(summaryOwner)).collection("readers").doc(readerUid);
}

type FollowerSummaryGrantChange = {
  summaryOwner: ProfileRef;
  follower: ProfileRef;
  allowed: boolean;
  childSchoolIds?: readonly string[];
  followerSchoolIds?: readonly string[];
};

/** Reads all affected ACL documents before applying any transaction writes. */
async function setFollowerSummaryGrants(
  txn: FirebaseFirestore.Transaction,
  changes: readonly FollowerSummaryGrantChange[],
): Promise<void> {
  const refs = new Map<string, FirebaseFirestore.DocumentReference>();
  for (const change of changes) {
    const ref = summaryReaderRef(change.summaryOwner, change.follower.ownerUid);
    refs.set(ref.path, ref);
  }
  const snapshots = new Map<string, FirebaseFirestore.DocumentSnapshot>();
  await Promise.all([...refs].map(async ([path, ref]) => {
    snapshots.set(path, await txn.get(ref));
  }));
  const grants = new Map<string, {
    ref: FirebaseFirestore.DocumentReference;
    owner: ProfileRef;
    ids: Set<string>;
    schools: string[];
    childByFollower: Record<string, string[]>;
    activeByFollower: Record<string, string[]>;
    exists: boolean;
  }>();
  for (const change of changes) {
    const ref = summaryReaderRef(change.summaryOwner, change.follower.ownerUid);
    const existing = snapshots.get(ref.path)!;
    const value = grants.get(ref.path) ?? {
      ref,
      owner: change.summaryOwner,
      ids: new Set<string>(Array.isArray(existing.get("follower_profile_ids"))
        ? existing.get("follower_profile_ids") as string[]
        : []),
      schools: Array.isArray(existing.get("school_ids"))
        ? existing.get("school_ids") as string[]
        : [],
      childByFollower: existing.get("child_school_grants") &&
        typeof existing.get("child_school_grants") === "object"
        ? { ...(existing.get("child_school_grants") as Record<string, string[]>) }
        : {},
      activeByFollower: existing.get("follower_school_memberships") &&
        typeof existing.get("follower_school_memberships") === "object"
        ? { ...(existing.get("follower_school_memberships") as Record<string, string[]>) }
        : {},
      exists: existing.exists,
    };
    const followerId = profileDocId(change.follower);
    if (change.allowed) {
      value.ids.add(followerId);
      if (change.childSchoolIds?.length) {
        value.childByFollower[followerId] = [...new Set(change.childSchoolIds)].slice(0, MAX_SCHOOLS);
        value.activeByFollower[followerId] = [...new Set(change.followerSchoolIds ?? [])].slice(0, MAX_SCHOOLS);
      }
    } else {
      value.ids.delete(followerId);
      delete value.childByFollower[followerId];
      delete value.activeByFollower[followerId];
    }
    grants.set(ref.path, value);
  }
  for (const grant of grants.values()) {
    const childSchoolIds = [...new Set(Object.values(grant.childByFollower).flat())];
    const activeSchoolIds = [...new Set(Object.values(grant.activeByFollower).flat())];
    if (grant.ids.size === 0 && grant.schools.length === 0) {
      if (grant.exists) txn.delete(grant.ref);
    } else {
      txn.set(grant.ref, {
        owner_uid: grant.owner.ownerUid,
        profile_id: grant.owner.profileId,
        follower_profile_ids: [...grant.ids],
        school_ids: grant.schools,
        child_school_ids: childSchoolIds,
        active_school_ids: activeSchoolIds,
        child_school_grants: grant.childByFollower,
        follower_school_memberships: grant.activeByFollower,
        updated_at: admin.firestore.Timestamp.now(),
      });
    }
  }
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

async function activeSchoolIds(ref: ProfileRef): Promise<string[]> {
  const snap = await schoolMembershipQuery(ref.ownerUid, ref.profileId).get();
  return [...new Set(snap.docs.map((doc) => doc.get("school_id"))
    .filter((id): id is string => typeof id === "string" && id.length > 0))].slice(0, MAX_SCHOOLS);
}

async function sharedAllowedSchoolIds(
  first: ProfileRef,
  second: ProfileRef,
  allowedSchools: readonly string[],
): Promise<string[]> {
  if (allowedSchools.length === 0) return [];
  const [firstSchools, secondSchools] = await Promise.all([
    activeSchoolIds(first), activeSchoolIds(second),
  ]);
  const firstSet = new Set(firstSchools);
  return secondSchools.filter((id) => firstSet.has(id) && allowedSchools.includes(id))
    .slice(0, MAX_SCHOOLS);
}

async function forEachQueryPage(
  query: FirebaseFirestore.Query,
  visit: (docs: FirebaseFirestore.QueryDocumentSnapshot[]) => Promise<void>,
): Promise<void> {
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let pageQuery = query.orderBy(admin.firestore.FieldPath.documentId()).limit(MAX_PAGE_SIZE);
    if (cursor) pageQuery = pageQuery.startAfter(cursor);
    const page = await pageQuery.get();
    if (page.empty) return;
    await visit(page.docs);
    if (page.size < MAX_PAGE_SIZE) return;
    cursor = page.docs[page.docs.length - 1];
  }
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? [...new Set(value.filter((item): item is string => typeof item === "string"))] : [];
}

function stringListMap(value: unknown): Record<string, string[]> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result: Record<string, string[]> = {};
  for (const [key, ids] of Object.entries(value as Record<string, unknown>)) {
    if (Array.isArray(ids)) result[key] = stringList(ids);
  }
  return result;
}

function flattenSchoolMap(value: Record<string, string[]>): string[] {
  return [...new Set(Object.values(value).flat())].slice(0, MAX_SCHOOLS);
}

async function updateFollowerMembershipMirror(
  summaryId: string,
  membershipIds: readonly string[],
  lostSchoolId?: string,
  revokeChildGrant = false,
): Promise<void> {
  const query = db.collectionGroup("readers")
    .where("follower_profile_ids", "array-contains", summaryId);
  await forEachQueryPage(query, async (docs) => {
    const batch = db.batch();
    for (const doc of docs) {
      const ids = stringList(doc.get("follower_profile_ids"));
      const childGrants = stringListMap(doc.get("child_school_grants"));
      const followerMemberships = stringListMap(doc.get("follower_school_memberships"));
      followerMemberships[summaryId] = [...membershipIds];
      const grantSchools = childGrants[summaryId];
      if (revokeChildGrant) {
        delete childGrants[summaryId];
        ids.splice(ids.indexOf(summaryId), ids.includes(summaryId) ? 1 : 0);
      } else if (grantSchools && lostSchoolId) {
        const remaining = grantSchools.filter((id) => id !== lostSchoolId);
        if (remaining.length === 0) {
          delete childGrants[summaryId];
          ids.splice(ids.indexOf(summaryId), ids.includes(summaryId) ? 1 : 0);
        } else {
          childGrants[summaryId] = remaining;
        }
      }
      const childSchoolIds = flattenSchoolMap(childGrants);
      const activeSchoolIds = flattenSchoolMap(followerMemberships);
      const schoolIds = stringList(doc.get("school_ids"));
      if (ids.length === 0 && schoolIds.length === 0) {
        batch.delete(doc.ref);
      } else {
        batch.set(doc.ref, {
          follower_profile_ids: ids,
          child_school_ids: childSchoolIds,
          active_school_ids: activeSchoolIds,
          child_school_grants: childGrants,
          follower_school_memberships: followerMemberships,
          updated_at: admin.firestore.Timestamp.now(),
        }, { merge: true });
      }
    }
    await batch.commit();
  });
}

/** Refreshes server-owned active membership mirrors after a join or restore. */
export async function refreshSocialMembershipMirror(summaryId: string): Promise<void> {
  if (!/^[a-f0-9]{64}$/.test(summaryId)) throw new Error("Invalid social summary id");
  const profileSnap = await profiles().doc(summaryId).get();
  if (!profileSnap.exists) return;
  const ownerUid = profileSnap.get("owner_uid");
  const profileId = profileSnap.get("profile_id");
  if (typeof ownerUid !== "string" || typeof profileId !== "string") {
    throw new Error("Social profile membership identity is incomplete");
  }
  const activeIds = await activeSchoolIds({ ownerUid, profileId });
  await profileSnap.ref.set({ active_school_ids: activeIds, updated_at: admin.firestore.Timestamp.now() }, { merge: true });
  await updateFollowerMembershipMirror(summaryId, activeIds);
}

/**
 * Deny-first membership cleanup. Call before changing/removing the membership
 * document. The helper is idempotent and resolves only after every ACL page
 * commits; callers must abort their membership mutation on rejection.
 */
export async function revokeSocialGrantsForMembershipChange(
  summaryId: string,
  schoolId: string,
): Promise<void> {
  if (!/^[a-f0-9]{64}$/.test(summaryId) || !schoolId.trim() || schoolId.length > 128) {
    throw new Error("Invalid social membership change identity");
  }
  const profileRefById = profiles().doc(summaryId);
  const profileSnap = await profileRefById.get();
  if (!profileSnap.exists) return;
  const ownerUid = profileSnap.get("owner_uid");
  const profileId = profileSnap.get("profile_id");
  const mode = profileSnap.get("mode");
  if (typeof ownerUid !== "string" || typeof profileId !== "string" ||
      (mode !== "adult" && mode !== "child")) {
    throw new Error("Social profile membership identity is incomplete");
  }
  const profile: ProfileRef = { ownerUid, profileId };
  const activeIds = (await activeSchoolIds(profile)).filter((id) => id !== schoolId);
  const now = admin.firestore.Timestamp.now();
  const parentControlsRef = controls().doc(summaryId);
  await db.runTransaction(async (txn) => {
    const parentControls = mode === "child" ? await txn.get(parentControlsRef) : null;
    txn.set(profileRefById, {
      active_school_ids: activeIds,
      ...(mode === "child" ? { paused: true } : {}),
      updated_at: now,
    }, { merge: true });
    if (mode === "child") {
      txn.set(parentControlsRef, {
        allowed_school_ids: stringList(parentControls?.get("allowed_school_ids"))
          .filter((id) => id !== schoolId),
        paused: true,
        controls_update_pending: true,
        updated_at: now,
      }, { merge: true });
    }
  });

  // Update every summary the departing profile follows. Child grants are
  // removed from this profile; adult-to-adult grants remain intact.
  await updateFollowerMembershipMirror(summaryId, activeIds, schoolId, mode === "child");

  // Remove the lost school from staff ACLs on this profile's summary. A child
  // summary also pauses and clears all follower grants until a parent reviews
  // the remaining school policy and re-applies it.
  const readersQuery = profileRefById.firestore.collection("social_summaries")
    .doc(summaryId).collection("readers");
  await forEachQueryPage(readersQuery, async (docs) => {
    const batch = db.batch();
    for (const doc of docs) {
      const staffSchools = stringList(doc.get("school_ids")).filter((id) => id !== schoolId);
      let followerIds = stringList(doc.get("follower_profile_ids"));
      let childGrants = stringListMap(doc.get("child_school_grants"));
      const followerMemberships = stringListMap(doc.get("follower_school_memberships"));
      if (mode === "child") {
        followerIds = [];
        childGrants = {};
      } else {
        for (const [followerId, schools] of Object.entries(childGrants)) {
          const remaining = schools.filter((id) => id !== schoolId);
          if (remaining.length === 0) {
            delete childGrants[followerId];
            followerIds = followerIds.filter((id) => id !== followerId);
          } else {
            childGrants[followerId] = remaining;
          }
        }
      }
      const childSchoolIds = flattenSchoolMap(childGrants);
      const activeSchoolIds = flattenSchoolMap(followerMemberships);
      if (staffSchools.length === 0 && followerIds.length === 0) {
        batch.delete(doc.ref);
      } else {
        batch.set(doc.ref, {
          school_ids: staffSchools,
          follower_profile_ids: followerIds,
          child_school_ids: childSchoolIds,
          active_school_ids: activeSchoolIds,
          child_school_grants: childGrants,
          updated_at: admin.firestore.Timestamp.now(),
        }, { merge: true });
      }
    }
    await batch.commit();
  });
}

async function sharedAllowedSchool(
  txn: FirebaseFirestore.Transaction,
  from: ProfileRef,
  to: ProfileRef,
  allowedSchools: readonly string[],
): Promise<string[]> {
  if (allowedSchools.length === 0) return [];
  const [fromSnap, toSnap] = await Promise.all([
    txn.get(schoolMembershipQuery(from.ownerUid, from.profileId)),
    txn.get(schoolMembershipQuery(to.ownerUid, to.profileId)),
  ]);
  const fromSchools = new Set(fromSnap.docs.map((doc) => doc.get("school_id")));
  return [...new Set(toSnap.docs.map((doc) => doc.get("school_id")))]
    .filter((id): id is string => typeof id === "string" && fromSchools.has(id) && allowedSchools.includes(id))
    .slice(0, MAX_SCHOOLS);
}

async function requireEligibleChildPair(
  txn: FirebaseFirestore.Transaction,
  from: ProfileRef,
  fromProfile: SocialProfile,
  to: ProfileRef,
  toProfile: SocialProfile,
): Promise<string[]> {
  const children = [
    ...(fromProfile.mode === "child" ? [from] : []),
    ...(toProfile.mode === "child" ? [to] : []),
  ];
  let eligibleSchools: Set<string> | null = null;
  for (const child of children) {
    const settingsSnap = await txn.get(controls().doc(profileDocId(child)));
    const allowList = settingsSnap.get("allowed_school_ids");
    if (!Array.isArray(allowList) || allowList.some((id) => typeof id !== "string")) {
      throw new HttpsError("permission-denied", "Child school policy is unavailable");
    }
    const sharedSchools = await sharedAllowedSchool(txn, from, to, allowList as string[]);
    if (sharedSchools.length === 0) {
      throw new HttpsError("permission-denied", "Learners are not eligible to connect");
    }
    const current = new Set<string>(sharedSchools);
    if (eligibleSchools === null) {
      eligibleSchools = current;
    } else {
      const previous: string[] = [...eligibleSchools];
      eligibleSchools = new Set<string>(previous.filter((schoolId) => current.has(schoolId)));
    }
    if (eligibleSchools.size === 0) {
      throw new HttpsError("permission-denied", "Learners are not eligible to connect");
    }
  }
  return [...(eligibleSchools ?? [])].slice(0, MAX_SCHOOLS);
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
    const membershipSnap = await txn.get(schoolMembershipQuery(uid, profileId));
    const memberSchools = [...new Set(membershipSnap.docs.map((doc) => doc.get("school_id"))
      .filter((id): id is string => typeof id === "string"))].slice(0, MAX_SCHOOLS);
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
      active_school_ids: memberSchools,
      updated_at: now,
    }, { merge: true });
    return opaqueProfileId;
  });
  return { success: true, socialProfileId };
});

/** Publishes only the learner engine's sanitized, identifier-only summary. */
export const publishSocialSummary = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = (request.data ?? {}) as Record<string, unknown>;
  exactKeys(data, ["profileId", "parentSessionId", "summary"]);
  const profileId = requiredString(data.profileId, "profileId");
  if (!ULID_RE.test(profileId)) throw new HttpsError("invalid-argument", "profileId must be a valid ULID");
  const normalized = normalizeSocialSummary(data.summary);
  const parentSessionId = data.parentSessionId;
  if (parentSessionId !== undefined && typeof parentSessionId !== "string") {
    throw new HttpsError("invalid-argument", "parentSessionId must be a string");
  }

  const profile: ProfileRef = { ownerUid: uid, profileId };
  const learnerRef = db.collection("users").doc(uid).collection("learner_profiles").doc(profileId);
  const summaryRef = summaries().doc(profileDocId(profile));
  const rateRef = summaryRateLimits().doc(profileDocId(profile));
  const now = admin.firestore.Timestamp.now();
  const minute = Math.floor(now.toMillis() / 60_000);

  await db.runTransaction(async (txn) => {
    const [learner, rate] = await Promise.all([
      txn.get(learnerRef), txn.get(rateRef),
    ]);
    if (!learner.exists) throw new HttpsError("not-found", "Learner profile is unavailable");
    const mode = learner.get("mode");
    if (mode !== "child" && mode !== "adult") {
      throw new HttpsError("failed-precondition", "Learner mode is unavailable");
    }
    if (mode === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, profileId, parentSessionId);
    } else if (parentSessionId !== undefined) {
      throw new HttpsError("invalid-argument", "parentSessionId is only valid for a child profile");
    }

    const previousMinute = Number(rate.get("minute"));
    const count = previousMinute === minute ? Number(rate.get("count") ?? 0) : 0;
    if (count >= 30) throw new HttpsError("resource-exhausted", "Summary publish limit reached");

    const profileName = learner.get("display_name");
    if (typeof profileName !== "string" || !profileName.trim() || profileName.length > 60) {
      throw new HttpsError("failed-precondition", "Profile display name is unavailable");
    }
    const avatarValue = learner.get("avatar");
    const parsedAvatar = typeof avatarValue === "number" ? avatarValue : Number(avatarValue);
    const avatarId = Number.isInteger(parsedAvatar) && parsedAvatar >= 0 && parsedAvatar <= 9
      ? parsedAvatar
      : 0;

    txn.set(summaryRef, {
      display_name: profileName.trim(),
      avatar_id: avatarId,
      ...normalized,
      computed_at: now,
      schema_version: 1,
    });
    txn.set(rateRef, { minute, count: count + 1, updated_at: now });
  });
  return { success: true, summaryId: profileDocId(profile) };
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
  const child: ProfileRef = { ownerUid: uid, profileId };
  const socialRef = profileRef(child);
  const controlsRef = controls().doc(profileDocId(child));
  let joinedSchools: string[] = [];
  await db.runTransaction(async (txn) => {
    const learnerRef = db.collection("users").doc(uid).collection("learner_profiles").doc(profileId);
    const learner = await txn.get(learnerRef);
    if (!learner.exists || learner.get("mode") !== "child") {
      throw new HttpsError("failed-precondition", "Profile is not a child profile");
    }
    await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    const memberSnap = await txn.get(schoolMembershipQuery(uid, profileId));
    joinedSchools = [...new Set(memberSnap.docs.map((doc) => doc.get("school_id"))
      .filter((id): id is string => typeof id === "string"))].slice(0, MAX_SCHOOLS);
    if ((allowed as string[]).some((schoolId) => !joinedSchools.includes(schoolId))) {
      throw new HttpsError("failed-precondition", "Allowed schools must be active memberships");
    }
    const social = await txn.get(socialRef);
    // Rules check this pause directly. If a page fails below, sharing stays
    // denied and a retry can safely restart from the first page.
    txn.set(socialRef, { paused: true, active_school_ids: joinedSchools }, { merge: true });
    txn.set(controlsRef, {
      owner_uid: uid,
      profile_id: profileId,
      allowed_school_ids: allowed,
      paused: true,
      controls_update_pending: true,
      updated_at: now,
      updated_by: uid,
    });
    if (!social.exists) throw new HttpsError("failed-precondition", "Child social profile is unavailable");
  });

  const applyPage = async (changes: FollowerSummaryGrantChange[]) => {
    if (changes.length === 0) return;
    await db.runTransaction(async (txn) => setFollowerSummaryGrants(txn, changes));
  };
  const outgoingQuery = follows().where("from_owner_uid", "==", uid)
    .where("from_profile_id", "==", profileId);
  await forEachQueryPage(outgoingQuery, async (edges) => {
    const changes: FollowerSummaryGrantChange[] = [];
    for (const edge of edges) {
      const target: ProfileRef = {
        ownerUid: String(edge.get("to_owner_uid")),
        profileId: String(edge.get("to_profile_id")),
      };
      const [eligibleSchools, followerSchools] = await Promise.all([
        sharedAllowedSchoolIds(child, target, allowed as string[]),
        activeSchoolIds(child),
      ]);
      const eligible = !data.paused && eligibleSchools.length > 0;
      changes.push({
        summaryOwner: target,
        follower: child,
        allowed: eligible,
        ...(eligible ? { childSchoolIds: eligibleSchools, followerSchoolIds: followerSchools } : {}),
      });
    }
    await applyPage(changes);
  });
  const incomingQuery = follows().where("to_owner_uid", "==", uid)
    .where("to_profile_id", "==", profileId);
  await forEachQueryPage(incomingQuery, async (edges) => {
    const changes: FollowerSummaryGrantChange[] = [];
    for (const edge of edges) {
      const follower: ProfileRef = {
        ownerUid: String(edge.get("from_owner_uid")),
        profileId: String(edge.get("from_profile_id")),
      };
      const [eligibleSchools, followerSchools] = await Promise.all([
        sharedAllowedSchoolIds(follower, child, allowed as string[]),
        activeSchoolIds(follower),
      ]);
      const eligible = !data.paused && eligibleSchools.length > 0;
      changes.push({
        summaryOwner: child,
        follower,
        allowed: eligible,
        ...(eligible ? { childSchoolIds: eligibleSchools, followerSchoolIds: followerSchools } : {}),
      });
    }
    await applyPage(changes);
  });

  const finalSchools = await activeSchoolIds(child);
  const finalAllowed = (allowed as string[]).filter((schoolId) => finalSchools.includes(schoolId));
  const completedAt = admin.firestore.Timestamp.now();
  await db.runTransaction(async (txn) => {
    txn.set(socialRef, {
      paused: data.paused,
      active_school_ids: finalSchools,
      updated_at: completedAt,
    }, { merge: true });
    txn.set(controlsRef, {
      allowed_school_ids: finalAllowed,
      paused: data.paused,
      controls_update_pending: false,
      updated_at: completedAt,
      updated_by: uid,
    }, { merge: true });
    txn.set(auditLogs().doc(), {
      owner_uid: uid,
      profile_id: profileId,
      actor_uid: uid,
      action: "child_social_controls_updated",
      at: completedAt,
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
    const eligibleSchools = await requireEligibleChildPair(txn, from, fromProfile, to, toProfile);
    const block = await txn.get(blocks().doc(blockId(from, to)));
    if (block.exists) throw new HttpsError("not-found", "Follow request is unavailable");
    if (req.get("expires_at")?.toMillis?.() <= now.toMillis()) {
      txn.update(reqRef, { state: "expired", updated_at: now });
      return;
    }
    const decision = data.decision as "accept" | "decline";
    if (decision === "accept") {
      const [followerMemberships, summaryMemberships] = await Promise.all([
        txn.get(schoolMembershipQuery(from.ownerUid, from.profileId)),
        txn.get(schoolMembershipQuery(to.ownerUid, to.profileId)),
      ]);
      const followerSchools = [...new Set(followerMemberships.docs.map((doc) => doc.get("school_id")))]
        .filter((id): id is string => typeof id === "string").slice(0, MAX_SCHOOLS);
      const summarySchools = [...new Set(summaryMemberships.docs.map((doc) => doc.get("school_id")))]
        .filter((id): id is string => typeof id === "string").slice(0, MAX_SCHOOLS);
      await setFollowerSummaryGrants(txn, [{
        summaryOwner: to,
        follower: from,
        allowed: true,
        ...(fromProfile.mode === "child" || toProfile.mode === "child"
          ? { childSchoolIds: eligibleSchools, followerSchoolIds: followerSchools }
          : {}),
      }]);
      if (toProfile.mode === "child") {
        txn.set(profileRef(to), { active_school_ids: summarySchools }, { merge: true });
      }
    }
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
    await setFollowerSummaryGrants(txn, [
      ...(out.exists ? [{ summaryOwner: to, follower: from, allowed: false }] : []),
      ...(incoming.exists ? [{ summaryOwner: from, follower: to, allowed: false }] : []),
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
    const blockRef = blocks().doc(blockId(from, to));
    const edgeOut = follows().doc(pairId(from, to));
    const edgeIn = follows().doc(pairId(to, from));
    const requestOut = requests().doc(pairId(from, to));
    const requestIn = requests().doc(pairId(to, from));
    const [outEdge, inEdge, outRequest, inRequest] = await Promise.all([
      txn.get(edgeOut), txn.get(edgeIn), txn.get(requestOut), txn.get(requestIn),
    ]);
    await setFollowerSummaryGrants(txn, [
      ...(outEdge.exists ? [{ summaryOwner: to, follower: from, allowed: false }] : []),
      ...(inEdge.exists ? [{ summaryOwner: from, follower: to, allowed: false }] : []),
    ]);
    txn.set(blockRef, {
      left_owner_uid: from.ownerUid,
      left_profile_id: from.profileId,
      right_owner_uid: to.ownerUid,
      right_profile_id: to.profileId,
      blocked_by_uid: uid,
      blocked_by_profile_id: from.profileId,
      created_at: now,
    });
    if (outEdge.exists) txn.delete(edgeOut);
    if (inEdge.exists) txn.delete(edgeIn);
    if (outRequest.exists) txn.delete(requestOut);
    if (inRequest.exists) txn.delete(requestIn);
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
        summaryId: profileDocId(profile),
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
  exactKeys(data, ["profileId", "limit", "parentSessionId"]);
  const profileId = requiredString(data.profileId, "profileId");
  const limit = data.limit ?? MAX_PAGE_SIZE;
  if (!Number.isInteger(limit) || Number(limit) < 1 || Number(limit) > MAX_PAGE_SIZE) {
    throw new HttpsError("invalid-argument", "limit must be between 1 and 50");
  }
  const visibleDocs = await db.runTransaction(async (txn) => {
    const learner = await txn.get(db.collection("users").doc(uid).collection("learner_profiles").doc(profileId));
    if (!learner.exists || (learner.get("mode") !== "child" && learner.get("mode") !== "adult")) {
      throw new HttpsError("not-found", "Learner profile is unavailable");
    }
    if (learner.get("mode") === "child") {
      await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    }
    const snapshots = await Promise.all([
      txn.get(requests().where("from_owner_uid", "==", uid).where("from_profile_id", "==", profileId).limit(limit)),
      txn.get(requests().where("to_owner_uid", "==", uid).where("to_profile_id", "==", profileId).limit(limit)),
      txn.get(follows().where("from_owner_uid", "==", uid).where("from_profile_id", "==", profileId).limit(limit)),
      txn.get(follows().where("to_owner_uid", "==", uid).where("to_profile_id", "==", profileId).limit(limit)),
    ]);
    const docs = snapshots.flatMap((snapshot) => snapshot.docs);
    const pairIds = new Set<string>();
    for (const doc of docs) {
      const edge = doc.data();
      const from = { ownerUid: String(edge.from_owner_uid), profileId: String(edge.from_profile_id) };
      const to = { ownerUid: String(edge.to_owner_uid), profileId: String(edge.to_profile_id) };
      pairIds.add(blockId(from, to));
    }
    const blockSnapshots = await Promise.all(
      [...pairIds].map((id) => txn.get(blocks().doc(id))),
    );
    const blockedPairs = new Set(blockSnapshots.filter((snapshot) => snapshot.exists).map((snapshot) => snapshot.id));
    const withoutBlocks = (snapshot: FirebaseFirestore.QuerySnapshot) => snapshot.docs.filter((doc) => {
      const edge = doc.data();
      return !blockedPairs.has(blockId(
        { ownerUid: String(edge.from_owner_uid), profileId: String(edge.from_profile_id) },
        { ownerUid: String(edge.to_owner_uid), profileId: String(edge.to_profile_id) },
      ));
    });
    return snapshots.map(withoutBlocks);
  });
  const [outgoingRequests, incomingRequests, outgoingFollows, incomingFollows] = visibleDocs;
  const serialize = async (docs: FirebaseFirestore.QueryDocumentSnapshot[]) => Promise.all(docs.map(async (doc) => {
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
      fromSummaryId: profileDocId(from),
      toSummaryId: profileDocId(to),
      fromDisplayName: fromProfile.get("display_name") ?? "Unavailable profile",
      fromAvatarId: fromProfile.get("avatar_id") ?? 0,
      toDisplayName: toProfile.get("display_name") ?? "Unavailable profile",
      toAvatarId: toProfile.get("avatar_id") ?? 0,
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
  const profile = { ownerUid, profileId };
  const readerGrants = await db.collectionGroup("readers")
    .where("follower_profile_ids", "array-contains", profileDocId(profile)).get();
  for (let i = 0; i < readerGrants.docs.length; i += 450) {
    const batch = db.batch();
    for (const doc of readerGrants.docs.slice(i, i + 450)) {
      const ids = (doc.get("follower_profile_ids") as unknown[])
        .filter((id) => id !== profileDocId(profile));
      const schoolIds = doc.get("school_ids");
      if (ids.length === 0 && (!Array.isArray(schoolIds) || schoolIds.length === 0)) {
        batch.delete(doc.ref);
      } else {
        batch.update(doc.ref, { follower_profile_ids: ids, updated_at: admin.firestore.Timestamp.now() });
      }
    }
    await batch.commit();
  }
  // Profile/account deletion must not claim completion while summary data or
  // nested reader grants remain. Let Admin SDK failures propagate to caller.
  await db.recursiveDelete(summaries().doc(profileDocId(profile)));
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
