import * as crypto from "crypto";
import admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { assertActiveParentSessionInTransaction } from "./parent_session_validation";
import {
  exactKeys,
  groupRef,
  memberFrom,
  memberRef,
  profileMemberRef,
  requireActiveGroup,
  requireAdmin,
  requireAuth,
  requiredString,
} from "./groups";
import { allocateGroupTask, AllocationUnit, rebalanceMissedWork, RebalanceParticipant } from "./group_task_allocator";
import { CALL_OPTS, db } from "./shared";
import { newUlid } from "./write_with_change_log";
import { sendGroupTaskPostedPush } from "./notifications";

type GroupTaskCatalog = typeof import("./group_task_catalog");
let groupTaskCatalog: GroupTaskCatalog | undefined;
function catalog(): GroupTaskCatalog {
  return groupTaskCatalog ??= require("./group_task_catalog") as GroupTaskCatalog;
}
const groupTaskCurriculumIds: GroupTaskCatalog["groupTaskCurriculumIds"] = (...args) => catalog().groupTaskCurriculumIds(...args);
const groupTaskPaceUnits: GroupTaskCatalog["groupTaskPaceUnits"] = (...args) => catalog().groupTaskPaceUnits(...args);
const groupTaskLeafRefs: GroupTaskCatalog["groupTaskLeafRefs"] = (...args) => catalog().groupTaskLeafRefs(...args);
const groupTaskWorkloadPerPaceUnit: GroupTaskCatalog["groupTaskWorkloadPerPaceUnit"] = (...args) => catalog().groupTaskWorkloadPerPaceUnit(...args);
const groupTaskUnitsForRefs: GroupTaskCatalog["groupTaskUnitsForRefs"] = (...args) => catalog().groupTaskUnitsForRefs(...args);
const reassignGroupTaskUnits: GroupTaskCatalog["reassignGroupTaskUnits"] = (...args) => catalog().reassignGroupTaskUnits(...args);
const listGroupTaskScopes: GroupTaskCatalog["listGroupTaskScopes"] = (...args) => catalog().listGroupTaskScopes(...args);
const resolveGroupTaskUnits: GroupTaskCatalog["resolveGroupTaskUnits"] = (...args) => catalog().resolveGroupTaskUnits(...args);

const MAX_GROUP_MEMBERS = 12;
const MAX_SCOPES = 200;
const MAX_PREFERENCE_REFS = 200;
const MAX_CAPACITY_PER_DAY = 1000;
const MAX_TASK_CREATIONS_PER_DAY = 3;
const MAX_PREFERENCE_UPDATES_PER_DAY = 20;
const MAX_GROUPS_PER_LEARN_CALL = 20;
const MAX_TASKS_PER_GROUP_CALL = 10;
const LEARNING_EVENT_PAGE_SIZE = 200;
const MAX_REBALANCE_TASKS_PER_RUN = 25;
const PROGRESS_CACHE_TTL_MS = 30_000;
const tasks = (groupId: string) => db.collection("learning_groups").doc(groupId).collection("tasks");
const DAY_MS = 24 * 60 * 60 * 1000;

function digest(...values: string[]): string {
  return crypto.createHash("sha256").update(values.join("\0")).digest("hex");
}

function date(value: unknown, field: string): string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
      Number.isNaN(Date.parse(`${value}T00:00:00.000Z`)) ||
      new Date(`${value}T00:00:00.000Z`).toISOString().slice(0, 10) !== value) {
    throw new HttpsError("invalid-argument", `${field} must be an ISO civil date`);
  }
  return value;
}

function addCivilYears(value: string, years: number): string {
  const [year, month, day] = value.split("-").map(Number);
  const targetYear = year + years;
  const lastDay = new Date(Date.UTC(targetYear, month, 0)).getUTCDate();
  const targetDay = Math.min(day, lastDay);
  return `${targetYear.toString().padStart(4, "0")}-${month.toString().padStart(2, "0")}-${targetDay.toString().padStart(2, "0")}`;
}

function timestampDate(value: unknown): string | null {
  if (!(value instanceof admin.firestore.Timestamp)) return null;
  return value.toDate().toISOString().slice(0, 10);
}

function serverToday(): string {
  return new Date().toISOString().slice(0, 10);
}

function shiftCivilDate(value: string, days: number): string {
  return new Date(Date.parse(`${value}T00:00:00.000Z`) + days * DAY_MS).toISOString().slice(0, 10);
}

function memberTaskId(groupId: string, member: { uid: string; profileId: string }): string {
  return digest("group-member", groupId, member.uid, member.profileId);
}

function flattenRefs(units: readonly AllocationUnit[], out = new Set<string>()): Set<string> {
  for (const unit of units) {
    out.add(unit.ref);
    flattenRefs(unit.children, out);
  }
  return out;
}

async function groupTaskProgress(groupId: string, readerUid: string, readerProfileId: string,
  assignment: FirebaseFirestore.DocumentSnapshot, curriculumId: string): Promise<{ completed: number; total: number } | null> {
  const ownerUid = String(assignment.get("owner_uid"));
  const ownerProfileId = String(assignment.get("profile_id"));
  const ownerProfileKey = digest(ownerUid, ownerProfileId);
  const learner = db.collection("users").doc(ownerUid).collection("learner_profiles").doc(ownerProfileId);
  const checked = await db.runTransaction(async (txn) => {
    const group = await requireActiveGroup(txn, groupRef(groupId));
    const [currentAssignment, ownerAccount, ownerProfile, readerAccount, readerProfile, acl, ownerSocial, ownerControls, ownerUserControls,
      readerSocial, readerControls, readerUserControls] = await Promise.all([
      txn.get(assignment.ref),
      txn.get(memberRef(groupId, ownerUid)), txn.get(profileMemberRef(groupId, ownerUid, ownerProfileId)),
      txn.get(memberRef(groupId, readerUid)), txn.get(profileMemberRef(groupId, readerUid, readerProfileId)),
      txn.get(db.collection("social_summaries").doc(ownerProfileKey).collection("readers").doc(readerUid)),
      txn.get(db.collection("social_profiles").doc(ownerProfileKey)),
      txn.get(db.collection("social_parent_controls").doc(ownerProfileKey)),
      txn.get(db.collection("social_user_controls").doc(ownerUid)),
      txn.get(db.collection("social_profiles").doc(digest(readerUid, readerProfileId))),
      txn.get(db.collection("social_parent_controls").doc(digest(readerUid, readerProfileId))),
      txn.get(db.collection("social_user_controls").doc(readerUid)),
    ]);
    if (!currentAssignment.exists || currentAssignment.get("state") !== "active" ||
        group.get("status") !== "active" || !ownerAccount.exists || ownerAccount.get("state") !== "active" ||
        !ownerProfile.exists || ownerProfile.get("state") !== "active" ||
        !Array.isArray(ownerAccount.get("active_profile_ids")) || !(ownerAccount.get("active_profile_ids") as string[]).includes(ownerProfileId) ||
        !readerAccount.exists || readerAccount.get("state") !== "active" || !readerProfile.exists || readerProfile.get("state") !== "active" ||
        !Array.isArray(readerAccount.get("active_profile_ids")) || !(readerAccount.get("active_profile_ids") as string[]).includes(readerProfileId)) return null;
    if (readerUid !== ownerUid) {
      if (!acl.exists || !(acl.get("group_ids") as string[] | undefined)?.includes(groupId)) return null;
      if (ownerProfile.get("mode") === "child" && (!ownerSocial.exists || ownerSocial.get("paused") === true ||
          !ownerControls.exists || ownerControls.get("paused") === true || ownerControls.get("controls_update_pending") === true ||
          !Array.isArray(ownerProfile.get("approved_reader_uids")) || !(ownerProfile.get("approved_reader_uids") as string[]).includes(readerUid) ||
          !Array.isArray(ownerUserControls.get("active_social_child_profile_ids")) ||
          !(ownerUserControls.get("active_social_child_profile_ids") as string[]).includes(ownerProfileKey))) return null;
      const readerKey = digest(readerUid, readerProfileId);
      if (readerProfile.get("mode") === "child" && (!readerSocial.exists || readerSocial.get("paused") === true ||
          !readerControls.exists || readerControls.get("paused") === true || readerControls.get("controls_update_pending") === true ||
          !Array.isArray(readerUserControls.get("active_social_child_profile_ids")) ||
          !(readerUserControls.get("active_social_child_profile_ids") as string[]).includes(readerKey))) return null;
    }
    const currentUnits = Array.isArray(currentAssignment.get("units"))
      ? currentAssignment.get("units") as Array<Record<string, unknown>> : [];
    const cache = currentAssignment.get("progress_cache") as Record<string, unknown> | undefined;
    const computedAt = cache?.computed_at;
    const refs = currentUnits.map((unit) => String(unit.ref ?? ""));
    const unitsSignature = digest(...refs);
    if (computedAt instanceof admin.firestore.Timestamp && Date.now() - computedAt.toMillis() < PROGRESS_CACHE_TTL_MS &&
        cache?.units_signature === unitsSignature && Number.isInteger(cache.completed) && cache.total === refs.length) {
      return { cached: { completed: Number(cache.completed), total: refs.length } };
    }
    return {
      assignmentRef: currentAssignment.ref,
      refs,
      unitsSignature,
      source: String(currentAssignment.get("sub_track_id")),
    };
  });
  if (!checked) return null;
  if ("cached" in checked) return checked.cached ?? null;

  const learnerEvents = learner.collection("learning_events");
  const { sourceEvents, voidEvents } = await readAllLearningEventsForSource(undefined, learnerEvents, checked.source);
  const voids = new Set(voidEvents.map((event) => String(event.get("target_id"))));
  const learned = new Set(sourceEvents.filter((event) => event.get("kind") === "learn" && !voids.has(event.id))
    .map((event) => String(event.get("ref"))));
  const completed = countCompletedUnits(curriculumId, checked.refs, learned);
  const progress = { completed, total: checked.refs.length };
  try {
    await checked.assignmentRef.update({
      progress_cache: {
        ...progress,
        units_signature: checked.unitsSignature,
        computed_at: admin.firestore.Timestamp.now(),
      },
    });
  } catch (error) {
    logger.warn("group_task_progress_cache_write_failed", {
      groupId,
      errorCode: error && typeof error === "object" && "code" in error
        ? String((error as { code: unknown }).code) : "unknown",
    });
  }
  return progress;
}

function countCompletedUnits(curriculumId: string, refs: string[], learned: Set<string>): number {
  let completed = 0;
  for (const ref of refs) {
    const leaves = groupTaskLeafRefs(curriculumId, ref);
    if (learned.has(ref) || leaves.every((leaf) => learned.has(leaf))) completed++;
  }
  return completed;
}

async function readAllLearningEventsForSource(
  txn: FirebaseFirestore.Transaction | undefined,
  events: FirebaseFirestore.CollectionReference,
  source: string,
): Promise<{ sourceEvents: FirebaseFirestore.QueryDocumentSnapshot[]; voidEvents: FirebaseFirestore.QueryDocumentSnapshot[] }> {
  const readAll = async (filterField: string, filterValue: string) => {
    const result: FirebaseFirestore.QueryDocumentSnapshot[] = [];
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    while (true) {
      let query: FirebaseFirestore.Query = events.where(filterField, "==", filterValue)
        .orderBy(admin.firestore.FieldPath.documentId()).limit(LEARNING_EVENT_PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);
      const page = txn ? await txn.get(query) : await query.get();
      result.push(...page.docs);
      if (page.size < LEARNING_EVENT_PAGE_SIZE) return result;
      cursor = page.docs[page.docs.length - 1];
    }
  };
  const [sourceEvents, voidEvents] = await Promise.all([
    readAll("source", source),
    readAll("kind", "void"),
  ]);
  return { sourceEvents, voidEvents };
}

export async function runGroupTaskSweepItems<T>(
  items: readonly T[],
  itemId: (item: T) => string,
  execute: (item: T) => Promise<void>,
): Promise<void> {
  for (const item of items) {
    try {
      await execute(item);
    } catch (error) {
      const errorCode = error && typeof error === "object" && "code" in error
        ? String((error as { code: unknown }).code) : error instanceof Error ? error.name : "unknown";
      logger.error("group_task_rebalance_sweep_item_failed", { itemId: itemId(item), errorCode });
    }
  }
}

function remainingStudyDates(start: string, deadline: string, studyDays: number[]): string[] {
  const allowed = new Set(studyDays);
  const result: string[] = [];
  for (let stamp = Date.parse(`${start}T00:00:00.000Z`), end = Date.parse(`${deadline}T00:00:00.000Z`); stamp <= end; stamp += DAY_MS) {
    const day = new Date(stamp).getUTCDay() || 7;
    if (allowed.has(day)) result.push(new Date(stamp).toISOString().slice(0, 10));
  }
  return result;
}

/** Reflows one overdue assignment; recipients are fenced by current task acceptance. */
async function rebalanceMissedGroupTask(
  groupId: string,
  taskId: string,
  ownerMemberId: string,
  onDate: string,
  missedBefore: string,
): Promise<{ changed: boolean; missingSubTracks?: Array<{ memberId: string; subTrackId: string }> }> {
  const groupRefValue = db.collection("learning_groups").doc(groupId);
  const taskRef = tasks(groupId).doc(taskId);
  const result = await db.runTransaction(async (txn) => {
    const [group, task] = await Promise.all([txn.get(groupRefValue), txn.get(taskRef)]);
    if (!group.exists || group.get("status") !== "active" || !task.exists || task.get("status") !== "published") return { changed: false };
    const deadline = timestampDate(task.get("deadline"));
    if (!deadline || deadline <= onDate) return { changed: false };
    const version = Number(task.get("allocation_version") ?? 1);
    const allocationMembers = await txn.get(taskRef.collection("allocations").doc(`v${version}`).collection("members").limit(MAX_GROUP_MEMBERS));
    const ownerSnap = allocationMembers.docs.find((doc) => doc.id === ownerMemberId && doc.get("state") === "active");
    if (!ownerSnap) return { changed: false };
    const assignmentDocs = allocationMembers.docs.filter((doc) => doc.get("state") === "active");
    const entries = await Promise.all(assignmentDocs.map(async (snap) => {
      const uid = String(snap.get("owner_uid"));
      const profileId = String(snap.get("profile_id"));
      const learner = db.collection("users").doc(uid).collection("learner_profiles").doc(profileId);
      const taskMemberRef = taskRef.collection("members").doc(snap.id);
      const trackRef = learner.collection("sub_tracks").doc(String(snap.get("sub_track_id")));
      const [taskMember, account, profileMember, learnerProfile, subTrack] = await Promise.all([
        txn.get(taskMemberRef), txn.get(memberRef(groupId, uid)), txn.get(profileMemberRef(groupId, uid, profileId)),
        txn.get(learner), txn.get(trackRef),
      ]);
      const accepted = taskMember.exists && taskMember.get("state") === "accepted" &&
        taskMember.get("uid") === uid && taskMember.get("profile_id") === profileId;
      const active = account.exists && account.get("state") === "active" && profileMember.exists && profileMember.get("state") === "active" &&
        Array.isArray(account.get("active_profile_ids")) && (account.get("active_profile_ids") as string[]).includes(profileId) &&
        learnerProfile.exists;
      return { snap, member: snap.data(), uid, profileId, taskMember, account, profileMember, learnerProfile, subTrack, trackRef,
        canReceive: accepted && active && subTrack.exists };
    }));
    const owner = entries.find((entry) => entry.snap.id === ownerMemberId);
    if (!owner) return { changed: false };
    const ownerDaily = Array.isArray(owner.member.daily_tasks) ? owner.member.daily_tasks as Array<Record<string, unknown>> : [];
    const overdue = ownerDaily.filter((daily) => typeof daily.date === "string" && daily.date < missedBefore && daily.reconciled_at == null);
    if (overdue.length === 0) return { changed: false };
    const missingSubTracks = entries.filter((entry) => !entry.subTrack.exists)
      .map((entry) => ({ memberId: entry.snap.id, subTrackId: String(entry.member.sub_track_id) }));
    if (!owner.subTrack.exists) return { changed: false, missingSubTracks };

    const curriculumId = String(task.get("curriculum_id"));
    const learner = db.collection("users").doc(owner.uid).collection("learner_profiles").doc(owner.profileId);
    const source = String(owner.member.sub_track_id);
    const { sourceEvents, voidEvents } = await readAllLearningEventsForSource(txn, learner.collection("learning_events"), source);
    const voided = new Set(voidEvents.map((event) => String(event.get("target_id"))));
    const learned = new Set(sourceEvents.filter((event) => event.get("kind") === "learn" && !voided.has(event.id))
      .map((event) => String(event.get("ref"))));
    const missedRefs = [...new Set(overdue.flatMap((daily) => Array.isArray(daily.refs)
      ? daily.refs.filter((ref): ref is string => typeof ref === "string") : []))];
    const completedRefs = missedRefs.filter((ref) => learned.has(ref) || groupTaskLeafRefs(curriculumId, ref).every((leaf) => learned.has(leaf)));
    const openRefs = missedRefs.filter((ref) => !completedRefs.includes(ref));
    const recipients = entries.filter((entry) => entry.canReceive);
    const ownerCanReceive = Boolean(owner.canReceive);
    const participantEntries = recipients.some((entry) => entry.snap.id === ownerMemberId)
      ? recipients
      : [...recipients, owner];
    const participantInputs: RebalanceParticipant[] = participantEntries.map((entry) => {
      const studyDays = Array.isArray(entry.member.study_days) ? entry.member.study_days as number[] : [];
      const dailyTasks = (Array.isArray(entry.member.daily_tasks) ? entry.member.daily_tasks as Array<Record<string, unknown>> : []);
      const refs = [...new Set(dailyTasks.flatMap((daily) => Array.isArray(daily.refs)
        ? daily.refs.filter((ref): ref is string => typeof ref === "string") : []))];
      const workloadByRef = Object.fromEntries(groupTaskUnitsForRefs(curriculumId, [...new Set([...refs, ...openRefs])])
        .map((unit) => [unit.ref, unit.weight]));
      const workloadPerPaceUnit = Number(entry.member.workload_per_pace_unit ?? 1);
      return {
        memberId: entry.snap.id,
        canReceive: entry.snap.id === ownerMemberId ? ownerCanReceive : entry.canReceive,
        capacityPerDay: Number(entry.member.capacity_per_study_day),
        workloadPerPaceUnit,
        paceUnit: String(entry.member.pace_unit),
        workloadByRef,
      futureDays: entry.snap.id === ownerMemberId && !ownerCanReceive
          ? [] : remainingStudyDates(onDate, deadline, studyDays),
        dailyTasks: dailyTasks.filter((daily) => typeof daily.date === "string" && daily.date >= onDate)
          .map((daily) => ({ date: String(daily.date), refs: Array.isArray(daily.refs)
            ? daily.refs.filter((ref): ref is string => typeof ref === "string") : [],
          workload: Number(daily.workload ?? 0), paceUnit: String(daily.paceUnit ?? entry.member.pace_unit),
          paceAmount: Number(daily.paceAmount ?? 0), ...(daily.overloaded === true ? { overloaded: true } : {}) })),
      };
    });
    const rebalanced = rebalanceMissedWork({ ownerMemberId, missedRefs: openRefs, participants: participantInputs });
    const movedByTarget = new Map<string, string[]>();
    for (const move of rebalanced.transferred) {
      const refs = movedByTarget.get(move.toMemberId) ?? [];
      refs.push(move.ref);
      movedByTarget.set(move.toMemberId, refs);
    }
    const unresolved = new Set(rebalanced.unassigned);
    const completed = new Set([...completedRefs, ...rebalanced.keptByOwner,
      ...rebalanced.transferred.map((move) => move.ref)]);
    const affected = new Set([ownerMemberId, ...movedByTarget.keys()]);
    const now = admin.firestore.Timestamp.now();
    for (const memberId of affected) {
      const entry = entries.find((candidate) => candidate.snap.id === memberId)!;
      const incomingRefs = movedByTarget.get(memberId) ?? [];
      const outgoingRefs = memberId === ownerMemberId
        ? rebalanced.transferred.filter((move) => move.fromMemberId === ownerMemberId).map((move) => move.ref) : [];
      const baseSchedule = rebalanced.schedules[memberId] ?? [];
      const updatedTasks = baseSchedule.map((daily) => ({ ...daily,
        refs: memberId === ownerMemberId ? daily.refs.filter((ref) => !outgoingRefs.includes(ref)) : daily.refs,
      })).filter((daily) => daily.refs.length > 0);
      const historical = (Array.isArray(entry.member.daily_tasks) ? entry.member.daily_tasks as Array<Record<string, unknown>> : [])
        .filter((daily) => typeof daily.date === "string" && daily.date < onDate)
        .map((daily) => {
          if (memberId !== ownerMemberId || typeof daily.date !== "string" || daily.date >= missedBefore) return daily;
          const refs = Array.isArray(daily.refs) ? daily.refs.filter((ref): ref is string => typeof ref === "string") : [];
          const pendingRefs = refs.filter((ref) => unresolved.has(ref));
          return pendingRefs.length > 0 ? { ...daily, refs: pendingRefs } : { ...daily, reconciled_at: now };
        });
      const currentUnits = Array.isArray(entry.member.units)
        ? entry.member.units as Array<{ ref: string; label: string; level: string; weight: number }> : [];
      const newUnits = reassignGroupTaskUnits(curriculumId, currentUnits, outgoingRefs, incomingRefs);
      txn.update(entry.snap.ref, {
        daily_tasks: [...historical, ...updatedTasks], units: newUnits,
        workload: newUnits.reduce((sum, unit) => sum + Number(unit.weight ?? 0), 0),
        progress_cache: admin.firestore.FieldValue.delete(), updated_at: now,
      });
      txn.update(entry.trackRef, { ground: newUnits.map((unit) => ({ level: unit.level, ref: unit.ref })) });
    }
    const priorPending = Array.isArray(task.get("rebalance_unassigned_refs"))
      ? task.get("rebalance_unassigned_refs") as string[] : [];
    const resolvedThisRun = new Set([...completed, ...openRefs.filter((ref) => !unresolved.has(ref))]);
    const remainingPending = [...new Set([...priorPending.filter((ref) => !resolvedThisRun.has(ref)), ...unresolved])];
    txn.update(taskRef, {
      rebalance_unassigned_refs: remainingPending,
      rebalance_updated_at: now,
    });
    return { changed: true, missingSubTracks };
  });
  for (const missing of result.missingSubTracks ?? []) {
    logger.warn("group_task_rebalance_skipped_missing_subtrack", { groupId, taskId, ...missing });
  }
  return result;
}

/** Daily server-side reflow never depends on a client-supplied date or Learn read. */
export const reconcileLearningGroupMissedTasks = onSchedule({
  schedule: "every 15 minutes",
  timeZone: "Etc/UTC",
  timeoutSeconds: 540,
}, async () => {
  const today = serverToday();
  const missedBefore = shiftCivilDate(today, -1);
  const cursorRef = db.collection("server_job_state").doc("group_task_rebalance");
  const cursor = await cursorRef.get();
  const lastTaskPath = cursor.get("last_task_path");
  let query = db.collectionGroup("tasks").where("status", "==", "published")
    .orderBy(admin.firestore.FieldPath.documentId()).limit(MAX_REBALANCE_TASKS_PER_RUN);
  if (typeof lastTaskPath === "string" && lastTaskPath.length > 0) query = query.startAfter(lastTaskPath);
  const page = await query.get();
  logger.info("group_task_rebalance_sweep_started", { today, missedBefore, taskCount: page.size });
  let lastProcessedPath = typeof lastTaskPath === "string" ? lastTaskPath : null;
  const finishBy = Date.now() + 480_000;
  let completedPage = true;
  for (const task of page.docs) {
    if (Date.now() >= finishBy) {
      completedPage = false;
      break;
    }
    const path = task.ref.path.split("/");
    if (path.length === 4 && path[0] === "learning_groups" && path[2] === "tasks") {
      const groupId = path[1];
      await runGroupTaskSweepItems([task], (row) => row.ref.path, async (row) => {
        const version = Number(row.get("allocation_version") ?? 1);
        const assignments = await row.ref.collection("allocations").doc(`v${version}`).collection("members")
          .where("state", "==", "active").limit(MAX_GROUP_MEMBERS).get();
        await runGroupTaskSweepItems(assignments.docs, (assignment) => assignment.id, async (assignment) => {
          const result = await rebalanceMissedGroupTask(groupId, row.id, assignment.id, today, missedBefore);
          if (result.changed || result.missingSubTracks?.length) {
            logger.info("group_task_rebalance_assignment_checked", {
              groupId, taskId: row.id, ownerMemberId: assignment.id,
              changed: result.changed, missingSubTrackCount: result.missingSubTracks?.length ?? 0,
            });
          }
        });
      });
    }
    lastProcessedPath = task.ref.path;
    await cursorRef.set({ last_task_path: lastProcessedPath, updated_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }
  if (completedPage && page.size < MAX_REBALANCE_TASKS_PER_RUN) {
    lastProcessedPath = null;
    await cursorRef.set({ last_task_path: null, updated_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }
});

async function activeRoster(txn: FirebaseFirestore.Transaction, groupId: string) {
  const accountPage = await txn.get(tasks(groupId).parent!.collection("members")
    .where("state", "==", "active").limit(MAX_GROUP_MEMBERS));
  const roster: Array<{ uid: string; profileId: string; mode: "adult" | "child"; role: string; memberId: string }> = [];
  for (const account of accountPage.docs) {
    const profiles = await txn.get(account.ref.collection("group_profiles").where("state", "==", "active").limit(MAX_GROUP_MEMBERS));
    const activeIds = Array.isArray(account.get("active_profile_ids")) ? account.get("active_profile_ids") as string[] : [];
    for (const snap of profiles.docs) {
      if (!activeIds.includes(snap.id)) continue;
      const member = memberFrom(account.id, snap);
      roster.push({
        uid: member.uid,
        profileId: member.profileId,
        mode: member.mode,
        role: member.role,
        memberId: memberTaskId(groupId, { uid: member.uid, profileId: member.profileId }),
      });
    }
  }
  return roster.slice(0, MAX_GROUP_MEMBERS);
}

function allocationWire(plan: ReturnType<typeof allocateGroupTask>) {
  return {
    feasible: plan.feasible,
    shortfall: plan.shortfall,
    totalWorkload: plan.totalWorkload,
    algorithmVersion: plan.algorithmVersion,
    unassignedRefs: plan.unassignedRefs,
    members: plan.members.map((member) => ({
      memberId: member.memberId,
      workload: member.workload,
      capacity: member.capacity,
      capacityInPaceUnits: member.capacityInPaceUnits,
      units: member.units.map(({ ref, label, level, weight }) => ({ ref, label, level, weight })),
      dailyTasks: member.dailyTasks,
    })),
  };
}

export const listGroupTaskCurricula = onCall(CALL_OPTS, async (request) => {
  requireAuth(request);
  exactKeys(request.data ?? {}, []);
  return groupTaskCurriculumIds();
});

/** Returns a current group member's task state and published allocation shares. */
export const listLearningGroupTasks = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "profileId"]);
  const ref = groupRef(data.groupId);
  const profileId = requiredString(data.profileId, "profileId");
  const membership = await db.runTransaction(async (txn) => {
    await requireActiveGroup(txn, ref);
    const [account, profile] = await Promise.all([
      txn.get(memberRef(ref.id, uid)), txn.get(profileMemberRef(ref.id, uid, profileId)),
    ]);
    if (!account.exists || account.get("state") !== "active" || !profile.exists || profile.get("state") !== "active" ||
        !Array.isArray(account.get("active_profile_ids")) || !(account.get("active_profile_ids") as string[]).includes(profileId)) {
      throw new HttpsError("permission-denied", "Active group membership is required");
    }
    return { memberId: memberTaskId(ref.id, { uid, profileId }), role: profile.get("role") };
  });
  const page = await tasks(ref.id).orderBy("created_at", "desc").limit(MAX_TASKS_PER_GROUP_CALL).get();
  const result = [];
  for (const task of page.docs) {
    const memberRef = task.ref.collection("members").doc(membership.memberId);
    const [member, joinRequest] = await Promise.all([
      memberRef.get(), task.ref.collection("join_requests").doc(membership.memberId).get(),
    ]);
    let allocation: Record<string, unknown> | null = null;
    let joinRequests: Array<Record<string, unknown>> = [];
    if (membership.role === "admin") {
      const requestPage = await task.ref.collection("join_requests").where("state", "==", "pending").limit(MAX_GROUP_MEMBERS).get();
      joinRequests = await Promise.all(requestPage.docs.map(async (requestDoc) => {
        const socialId = digest(String(requestDoc.get("uid")), String(requestDoc.get("profile_id")));
        const social = await db.collection("social_profiles").doc(socialId).get();
        return { memberId: requestDoc.id, displayName: social.get("display_name") ?? "Learner", mode: requestDoc.get("mode") };
      }));
    }
    if (task.get("status") === "published") {
      const assignmentPage = await task.ref.collection("allocations").doc("v1").collection("members").limit(MAX_GROUP_MEMBERS).get();
      const namedAssignments = await Promise.all(assignmentPage.docs.map(async (assignment) => {
        const socialProfileId = digest(String(assignment.get("owner_uid")), String(assignment.get("profile_id")));
        const [social, progress] = await Promise.all([
          db.collection("social_profiles").doc(socialProfileId).get(),
          groupTaskProgress(ref.id, uid, profileId, assignment, String(task.get("curriculum_id"))),
        ]);
        return {
          memberId: assignment.id,
          displayName: social.get("display_name") ?? "Learner",
          units: assignment.get("units"),
          workload: assignment.get("workload"),
          dailyTasks: assignment.get("daily_tasks"),
          progress,
        };
      }));
      allocation = {
        version: 1,
        members: namedAssignments,
      };
    }
    result.push({
      taskId: task.id,
      taskName: task.get("task_name"),
      curriculumId: task.get("curriculum_id"),
      status: task.get("status"),
      replyBy: timestampDate(task.get("reply_by")),
      deadline: timestampDate(task.get("deadline")),
      scopeUnits: task.get("scope_units"),
      memberState: member.exists ? member.get("state") : joinRequest.get("state") === "pending" ? "join_requested" : "not_invited",
      paceUnit: member.get("pace_unit") ?? null,
      capacityPerStudyDay: member.get("capacity_per_study_day") ?? null,
      studyDays: member.get("study_days") ?? [],
      allocation,
      joinRequests,
      feasibility: task.get("allocation_result") ? {
        feasible: (task.get("allocation_result") as Record<string, unknown>).feasible,
        shortfall: (task.get("allocation_result") as Record<string, unknown>).shortfall,
      } : null,
    });
  }
  return result;
});

export const listGroupTaskScopesForCurriculum = onCall(CALL_OPTS, async (request) => {
  requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["curriculumId"]);
  const curriculumId = requiredString(data.curriculumId, "curriculumId", 64);
  if (!groupTaskCurriculumIds().includes(curriculumId)) throw new HttpsError("invalid-argument", "Curriculum is not supported for group tasks");
  return { scopes: listGroupTaskScopes(curriculumId), paceUnits: groupTaskPaceUnits(curriculumId) };
});

/** Posts one task and snapshots every active profile invited to respond. */
export const createLearningGroupTask = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "profileId", "curriculumId", "scopeRefs", "replyBy", "deadline"]);
  const ref = groupRef(data.groupId);
  const profileId = requiredString(data.profileId, "profileId");
  const curriculumId = requiredString(data.curriculumId, "curriculumId", 64);
  if (!groupTaskCurriculumIds().includes(curriculumId)) throw new HttpsError("invalid-argument", "Curriculum is not supported for group tasks");
  if (!Array.isArray(data.scopeRefs) || data.scopeRefs.length > MAX_SCOPES ||
      data.scopeRefs.some((item: unknown) => typeof item !== "string")) {
    throw new HttpsError("invalid-argument", "scopeRefs must be a bounded list of curriculum sections");
  }
  const scopeRefs = [...new Set(data.scopeRefs as string[])];
  const replyBy = date(data.replyBy, "replyBy");
  const deadline = date(data.deadline, "deadline");
  const today = new Date().toISOString().slice(0, 10);
  if (replyBy < today || deadline <= replyBy) throw new HttpsError("invalid-argument", "The study deadline must be after the reply window");
  if (deadline > addCivilYears(today, 3)) {
    throw new HttpsError("invalid-argument", "The study deadline cannot be more than three years away");
  }
  let scopeUnits: AllocationUnit[];
  try {
    scopeUnits = resolveGroupTaskUnits(curriculumId, scopeRefs);
  } catch (error) {
    throw new HttpsError("invalid-argument", error instanceof Error ? error.message : "Task scope is invalid");
  }
  if (scopeUnits.length === 0 || scopeUnits.length > MAX_SCOPES) throw new HttpsError("invalid-argument", "Task scope has no allocatable units or is too large");
  const taskRef = ref.collection("tasks").doc();
  const now = admin.firestore.Timestamp.now();
  const response = await db.runTransaction(async (txn) => {
    await requireActiveGroup(txn, ref);
    const adminAccess = await requireAdmin(txn, ref.id, uid);
    if (adminAccess.profileId !== profileId) throw new HttpsError("permission-denied", "The selected administrator profile is not active");
    const today = new Date().toISOString().slice(0, 10);
    const limitRef = db.collection("learning_group_task_rate_limits").doc(digest("group-task-create", uid, today));
    const limit = await txn.get(limitRef);
    const count = limit.get("count") === undefined ? 0 : Number(limit.get("count"));
    if (count >= MAX_TASK_CREATIONS_PER_DAY) throw new HttpsError("resource-exhausted", "Group task creation limit reached");
    const roster = await activeRoster(txn, ref.id);
    if (roster.length === 0 || roster.length > MAX_GROUP_MEMBERS) throw new HttpsError("failed-precondition", "Group roster is unavailable");
    const profileIds = new Set(roster.map((member) => member.memberId));
    if (!profileIds.has(memberTaskId(ref.id, { uid, profileId }))) throw new HttpsError("permission-denied", "Active group membership is required");
    const label = scopeUnits.length <= 3 ? scopeUnits.map((unit) => unit.label).join(", ") : `${scopeUnits.length} sections`;
    const taskName = `${curriculumId}: ${label}`.slice(0, 180);
    txn.create(taskRef, {
      group_id: ref.id,
      task_id: taskRef.id,
      task_name: taskName,
      curriculum_id: curriculumId,
      scope_refs: scopeRefs,
      scope_units: scopeUnits,
      status: "collecting_responses",
      created_by_uid: uid,
      created_by_profile_id: profileId,
      reply_by: admin.firestore.Timestamp.fromDate(new Date(`${replyBy}T23:59:59.999Z`)),
      deadline: admin.firestore.Timestamp.fromDate(new Date(`${deadline}T23:59:59.999Z`)),
      response_revision: 1,
      preferences_revision: 0,
      created_at: now,
      updated_at: now,
    });
    txn.set(limitRef, { uid, day: today, count: count + 1, updated_at: now });
    for (const member of roster) {
      const id = memberTaskId(ref.id, member);
      txn.create(taskRef.collection("members").doc(id), {
        member_id: id,
        uid: member.uid,
        profile_id: member.profileId,
        mode: member.mode,
        role: member.role,
        state: "awaiting_response",
        sub_track_id: newUlid(),
        created_at: now,
        updated_at: now,
      });
    }
    return { taskId: taskRef.id, taskName, memberCount: roster.length };
  });
  try {
    const invitePage = await taskRef.collection("members").get();
    const delivery = await sendGroupTaskPostedPush({
      groupId: ref.id,
      taskId: taskRef.id,
      invitees: invitePage.docs.map((doc) => ({
        uid: String(doc.get("uid")),
        profileId: String(doc.get("profile_id")),
        mode: String(doc.get("mode")),
      })),
    });
    logger.info("group_task_invite_push_attempted", { groupId: ref.id, taskId: taskRef.id, ...delivery });
  } catch (error) {
    // The in-app task card is the reliable fallback if FCM is unavailable.
    logger.error("group_task_invite_push_failed", { groupId: ref.id, taskId: taskRef.id, error });
  }
  return response;
});

/** The profile (or parent after a PIN session) records the task response. */
export const respondToLearningGroupTask = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "taskId", "profileId", "response", "parentSessionId"]);
  const ref = groupRef(data.groupId);
  const taskId = requiredString(data.taskId, "taskId", 128);
  const profileId = requiredString(data.profileId, "profileId");
  if (data.response !== "accept" && data.response !== "decline") throw new HttpsError("invalid-argument", "response must be accept or decline");
  const taskRef = ref.collection("tasks").doc(taskId);
  const memberId = memberTaskId(ref.id, { uid, profileId });
  return db.runTransaction(async (txn) => {
    const group = await requireActiveGroup(txn, ref);
    const [task, member, groupAccount, groupProfile] = await Promise.all([
      txn.get(taskRef), txn.get(taskRef.collection("members").doc(memberId)),
      txn.get(memberRef(ref.id, uid)), txn.get(profileMemberRef(ref.id, uid, profileId)),
    ]);
    if (!task.exists || !member.exists || !groupAccount.exists || groupAccount.get("state") !== "active" ||
        !groupProfile.exists || groupProfile.get("state") !== "active" ||
        !Array.isArray(groupAccount.get("active_profile_ids")) || !(groupAccount.get("active_profile_ids") as string[]).includes(profileId)) {
      throw new HttpsError("permission-denied", "An active group task invitation is required");
    }
    if (task.get("status") !== "collecting_responses") throw new HttpsError("failed-precondition", "Task responses are closed");
    if (member.get("state") !== "awaiting_response") {
      if (member.get("state") === (data.response === "accept" ? "accepted" : "declined")) return { state: member.get("state") };
      throw new HttpsError("failed-precondition", "This response has already been recorded");
    }
    const replyBy = task.get("reply_by");
    const lateApproved = member.get("late_approved") === true;
    if (!(replyBy instanceof admin.firestore.Timestamp) || (!lateApproved && replyBy.toMillis() < Date.now())) {
      throw new HttpsError("deadline-exceeded", "The reply window has closed");
    }
    if (member.get("mode") === "child" && data.response === "accept") {
      await assertActiveParentSessionInTransaction(txn, uid, profileId, data.parentSessionId);
    }
    txn.update(member.ref, {
      state: data.response === "accept" ? "accepted" : "declined",
      ...(member.get("mode") === "child" && data.response === "accept" ? { parent_approved: true, parent_approved_at: admin.firestore.FieldValue.serverTimestamp() } : {}),
      responded_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    txn.update(taskRef, { response_revision: admin.firestore.FieldValue.increment(1), updated_at: admin.firestore.FieldValue.serverTimestamp() });
    return { state: data.response === "accept" ? "accepted" : "declined", groupStatus: group.get("status") };
  });
});

/** Saves a ranked preference and per-study-day capacity under the task revision fence. */
export const submitLearningGroupTaskPreferences = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "taskId", "profileId", "rankedRefs", "paceUnit", "capacityPerStudyDay", "studyDays"]);
  const ref = groupRef(data.groupId);
  const taskId = requiredString(data.taskId, "taskId", 128);
  const profileId = requiredString(data.profileId, "profileId");
  const paceUnit = requiredString(data.paceUnit, "paceUnit", 32);
  if (!Array.isArray(data.rankedRefs) || data.rankedRefs.length > MAX_PREFERENCE_REFS ||
      data.rankedRefs.some((item: unknown) => typeof item !== "string") ||
      !Number.isInteger(data.capacityPerStudyDay) || data.capacityPerStudyDay < 1 || data.capacityPerStudyDay > MAX_CAPACITY_PER_DAY ||
      !Array.isArray(data.studyDays) || data.studyDays.length < 1 || data.studyDays.length > 7 ||
      data.studyDays.some((item: unknown) => !Number.isInteger(item) || (item as number) < 1 || (item as number) > 7) ||
      new Set(data.studyDays).size !== data.studyDays.length) {
    throw new HttpsError("invalid-argument", "Preferences or daily capacity are invalid");
  }
  const rankedRefs = data.rankedRefs as string[];
  if (new Set(rankedRefs).size !== rankedRefs.length) throw new HttpsError("invalid-argument", "Preference ranks must be unique");
  const taskRef = ref.collection("tasks").doc(taskId);
  const memberId = memberTaskId(ref.id, { uid, profileId });
  return db.runTransaction(async (txn) => {
    const [group, task, member, account, profile] = await Promise.all([
      txn.get(ref), txn.get(taskRef), txn.get(taskRef.collection("members").doc(memberId)),
      txn.get(memberRef(ref.id, uid)), txn.get(profileMemberRef(ref.id, uid, profileId)),
    ]);
    if (!group.exists || group.get("status") !== "active" || !task.exists || !member.exists || member.get("state") !== "accepted" ||
        !account.exists || account.get("state") !== "active" || !profile.exists || profile.get("state") !== "active" ||
        !Array.isArray(account.get("active_profile_ids")) || !(account.get("active_profile_ids") as string[]).includes(profileId)) {
      throw new HttpsError("permission-denied", "An accepted active group task member is required");
    }
    if (task.get("status") !== "collecting_responses" && task.get("status") !== "capacity_review") {
      throw new HttpsError("failed-precondition", "Task preferences are locked");
    }
    const units = task.get("scope_units") as AllocationUnit[];
    if (!groupTaskPaceUnits(String(task.get("curriculum_id"))).includes(paceUnit)) {
      throw new HttpsError("invalid-argument", "Pace unit is not available for this curriculum");
    }
    const allowed = flattenRefs(Array.isArray(units) ? units : []);
    if (rankedRefs.some((item) => !allowed.has(item))) throw new HttpsError("invalid-argument", "A preference is outside this task's scope");
    const today = new Date().toISOString().slice(0, 10);
    const limitRef = db.collection("learning_group_task_rate_limits").doc(digest("group-task-preference", uid, profileId, taskId, today));
    const limit = await txn.get(limitRef);
    const count = limit.get("count") === undefined ? 0 : Number(limit.get("count"));
    if (count >= MAX_PREFERENCE_UPDATES_PER_DAY) throw new HttpsError("resource-exhausted", "Task preference update limit reached");
    txn.update(member.ref, {
      ranked_refs: rankedRefs,
      pace_unit: paceUnit,
      capacity_per_study_day: data.capacityPerStudyDay,
      study_days: data.studyDays,
      preferences_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    txn.update(taskRef, {
      status: "collecting_responses",
      preferences_revision: admin.firestore.FieldValue.increment(1),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    txn.set(limitRef, { uid, profile_id: profileId, task_id: taskId, day: today, count: count + 1, updated_at: admin.firestore.FieldValue.serverTimestamp() });
    return { saved: true };
  });
});

/** Allocates all accepted members in one transaction and publishes assignments atomically. */
export const allocateLearningGroupTask = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "taskId"]);
  const ref = groupRef(data.groupId);
  const taskId = requiredString(data.taskId, "taskId", 128);
  const taskRef = ref.collection("tasks").doc(taskId);
  return db.runTransaction(async (txn) => {
    await requireActiveGroup(txn, ref);
    await requireAdmin(txn, ref.id, uid);
    const task = await txn.get(taskRef);
    if (!task.exists) throw new HttpsError("not-found", "Group task is unavailable");
    if (task.get("status") === "published") return { ...task.get("allocation_result"), alreadyPublished: true };
    if (task.get("status") !== "collecting_responses" && task.get("status") !== "capacity_review") {
      throw new HttpsError("failed-precondition", "Task cannot be allocated in its current state");
    }
    const roster = await activeRoster(txn, ref.id);
    const entries = await txn.get(taskRef.collection("members").limit(MAX_GROUP_MEMBERS));
    const rosterById = new Map(roster.map((member) => [member.memberId, member]));
    const accepted: Array<{ doc: FirebaseFirestore.QueryDocumentSnapshot; roster: typeof roster[number] }> = [];
    const removedInvitations: FirebaseFirestore.QueryDocumentSnapshot[] = [];
    let pending = false;
    for (const doc of entries.docs) {
      if (doc.get("state") === "awaiting_response") pending = true;
      if (doc.get("state") !== "accepted") continue;
      const member = rosterById.get(String(doc.get("member_id")));
      if (!member || member.uid !== doc.get("uid") || member.profileId !== doc.get("profile_id")) {
        removedInvitations.push(doc);
        continue;
      }
      accepted.push({ doc, roster: member });
    }
    if (accepted.length === 0) throw new HttpsError("failed-precondition", "At least one member must accept this task");
    const replyBy = task.get("reply_by");
    if (pending && (!(replyBy instanceof admin.firestore.Timestamp) || replyBy.toMillis() > Date.now())) {
      throw new HttpsError("failed-precondition", "Wait for every member's response or the reply deadline");
    }
    const incomplete = accepted.find(({ doc }) => !Array.isArray(doc.get("ranked_refs")) ||
      typeof doc.get("pace_unit") !== "string" ||
      !Number.isInteger(doc.get("capacity_per_study_day")) || !Array.isArray(doc.get("study_days")));
    if (incomplete) throw new HttpsError("failed-precondition", "Every accepted member must submit ranked preferences and capacity");
    const units = task.get("scope_units") as AllocationUnit[];
    const startDate = new Date().toISOString().slice(0, 10);
    const deadline = timestampDate(task.get("deadline"));
    if (!deadline) throw new HttpsError("failed-precondition", "Task deadline is unavailable");
    const plan = allocateGroupTask({
      taskId,
      units: Array.isArray(units) ? units : [],
      startDate,
      deadline,
      members: accepted.map(({ doc }) => ({
        memberId: String(doc.get("member_id")),
        rankedRefs: doc.get("ranked_refs") as string[],
        paceUnit: String(doc.get("pace_unit")),
        capacityPerStudyDay: Number(doc.get("capacity_per_study_day")),
        workloadPerPaceUnit: groupTaskWorkloadPerPaceUnit(String(task.get("curriculum_id")), String(doc.get("pace_unit")), units),
        studyDays: doc.get("study_days") as number[],
      })),
    });
    const result = allocationWire(plan);
    if (!plan.feasible) {
      txn.update(taskRef, {
        status: "capacity_review",
        allocation_result: result,
        allocation_attempted_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      return result;
    }
    const membersById = new Map(accepted.map(({ doc, roster: member }) => [String(doc.get("member_id")), { doc, member }]));
    const now = admin.firestore.Timestamp.now();
    const startIso = startDate;
    const deadlineIso = deadline;
    const weekCount = Math.max(1, Math.ceil((Date.parse(`${deadlineIso}T00:00:00.000Z`) - Date.parse(`${startIso}T00:00:00.000Z`)) / (7 * 86400000)));
    const trackReads = await Promise.all(plan.members.map(({ memberId }) => {
      const assignmentMember = membersById.get(memberId)!;
      const profileRef = db.collection("users").doc(assignmentMember.member.uid).collection("learner_profiles").doc(assignmentMember.member.profileId);
      return Promise.all([
        txn.get(profileRef),
        txn.get(profileRef.collection("curriculum_tracks").doc(String(task.get("curriculum_id")))),
      ]);
    }));
    if (trackReads.some(([profile]) => !profile.exists)) throw new HttpsError("failed-precondition", "A participating learner profile is unavailable");
    for (const removed of removedInvitations) txn.update(removed.ref, { state: "removed", updated_at: now });
    const allocationRef = taskRef.collection("allocations").doc("v1");
    const assignments: Array<Record<string, unknown>> = [];
    for (let i = 0; i < plan.members.length; i++) {
      const allocation = plan.members[i];
      const { doc, member } = membersById.get(allocation.memberId)!;
      const learnerRef = db.collection("users").doc(member.uid).collection("learner_profiles").doc(member.profileId);
      const trackRef = learnerRef.collection("curriculum_tracks").doc(String(task.get("curriculum_id")));
      const subTrackId = String(doc.get("sub_track_id"));
      const subTrackRef = learnerRef.collection("sub_tracks").doc(subTrackId);
      const memberUnits = allocation.units.map((unit) => ({ ref: unit.ref, label: unit.label, level: unit.level, weight: unit.weight }));
      const scheduleRefs = allocation.dailyTasks.map((daily) => ({
        date: daily.date,
        refs: daily.refs,
        workload: daily.workload,
        paceUnit: daily.paceUnit,
        paceAmount: daily.paceAmount,
      }));
      const studyDays = doc.get("study_days") as number[];
      const capacity = Number(doc.get("capacity_per_study_day"));
      const paceUnit = String(doc.get("pace_unit"));
      const workloadPerPaceUnit = groupTaskWorkloadPerPaceUnit(String(task.get("curriculum_id")), paceUnit, units);
      const track = trackReads[i][1];
      if (!track.exists) txn.create(trackRef, {
        curriculum_id: String(task.get("curriculum_id")),
        state: "active",
        activated_at: now.toDate().toISOString(),
      });
      else if (track.get("state") !== "active") txn.update(trackRef, {
        state: "active", activated_at: now.toDate().toISOString(), ended_at: admin.firestore.FieldValue.delete(),
      });
      txn.create(subTrackRef, {
        curriculum_id: String(task.get("curriculum_id")),
        name: String(task.get("task_name")),
        type: "ongoing",
        window_start: startIso,
        window_end: deadlineIso,
        rate_per_week: Math.ceil(capacity * workloadPerPaceUnit) * studyDays.length,
        weeks_per_year: weekCount,
        learns_on_shabbos: studyDays.includes(6),
        ground: memberUnits.map((unit) => ({ level: unit.level, ref: unit.ref })),
      });
      const assignment = {
        member_id: member.memberId,
        owner_uid: member.uid,
        profile_id: member.profileId,
        task_id: taskId,
        allocation_version: 1,
        sub_track_id: subTrackId,
        units: memberUnits,
        workload: allocation.workload,
        capacity: allocation.capacity,
        capacity_in_pace_units: allocation.capacityInPaceUnits,
        pace_unit: paceUnit,
        capacity_per_study_day: capacity,
        study_days: studyDays,
        workload_per_pace_unit: workloadPerPaceUnit,
        daily_tasks: scheduleRefs,
        state: "active",
        created_at: now,
      };
      txn.create(allocationRef.collection("members").doc(member.memberId), assignment);
      assignments.push(assignment);
    }
    const published = { ...result, publishedAt: now.toDate().toISOString() };
    txn.create(allocationRef, {
      version: 1,
      algorithm_version: plan.algorithmVersion,
      status: "published",
      members: assignments.map((assignment) => ({ member_id: assignment.member_id, owner_uid: assignment.owner_uid, profile_id: assignment.profile_id, workload: assignment.workload })),
      created_at: now,
    });
    txn.update(taskRef, {
      status: "published",
      allocation_version: 1,
      allocation_result: published,
      published_at: now,
      updated_at: now,
    });
    return published;
  });
});

/** An active member can request late admission while the admin is still allocating. */
export const requestLateLearningGroupTaskJoin = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "taskId", "profileId"]);
  const ref = groupRef(data.groupId);
  const taskId = requiredString(data.taskId, "taskId", 128);
  const profileId = requiredString(data.profileId, "profileId");
  const memberId = memberTaskId(ref.id, { uid, profileId });
  const taskRef = ref.collection("tasks").doc(taskId);
  return db.runTransaction(async (txn) => {
    await requireActiveGroup(txn, ref);
    const [task, groupAccount, profile] = await Promise.all([
      txn.get(taskRef), txn.get(memberRef(ref.id, uid)), txn.get(profileMemberRef(ref.id, uid, profileId)),
    ]);
    if (!task.exists || !groupAccount.exists || groupAccount.get("state") !== "active" || !profile.exists || profile.get("state") !== "active" ||
        !Array.isArray(groupAccount.get("active_profile_ids")) || !(groupAccount.get("active_profile_ids") as string[]).includes(profileId)) {
      throw new HttpsError("permission-denied", "Active group membership is required");
    }
    if (task.get("status") !== "collecting_responses" && task.get("status") !== "capacity_review") {
      throw new HttpsError("failed-precondition", "The task has already been allocated");
    }
    const invitation = await txn.get(taskRef.collection("members").doc(memberId));
    if (invitation.exists) return { requested: true, state: invitation.get("state") };
    const requestRef = taskRef.collection("join_requests").doc(memberId);
    txn.set(requestRef, {
      member_id: memberId, uid, profile_id: profileId,
      mode: profile.get("mode"), state: "pending", created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { requested: true, state: "pending" };
  });
});

/** Lets an admin approve a late request before allocation; the member still accepts, and children need a parent session. */
export const reviewLateLearningGroupTaskJoin = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["groupId", "taskId", "memberId", "approved"]);
  const ref = groupRef(data.groupId);
  const taskId = requiredString(data.taskId, "taskId", 128);
  const memberId = requiredString(data.memberId, "memberId", 128);
  if (typeof data.approved !== "boolean") throw new HttpsError("invalid-argument", "approved must be a boolean");
  const taskRef = ref.collection("tasks").doc(taskId);
  return db.runTransaction(async (txn) => {
    await requireActiveGroup(txn, ref);
    await requireAdmin(txn, ref.id, uid);
    const [task, joinRequest] = await Promise.all([
      txn.get(taskRef), txn.get(taskRef.collection("join_requests").doc(memberId)),
    ]);
    if (!task.exists || !joinRequest.exists || joinRequest.get("state") !== "pending") throw new HttpsError("not-found", "Late join request is unavailable");
    if (task.get("status") !== "collecting_responses" && task.get("status") !== "capacity_review") throw new HttpsError("failed-precondition", "The task has already been allocated");
    const invitationRef = taskRef.collection("members").doc(memberId);
    if (data.approved === true) {
      const requestedUid = String(joinRequest.get("uid"));
      const requestedProfileId = String(joinRequest.get("profile_id"));
      const [account, profile] = await Promise.all([
        txn.get(memberRef(ref.id, requestedUid)), txn.get(profileMemberRef(ref.id, requestedUid, requestedProfileId)),
      ]);
      if (!account.exists || account.get("state") !== "active" || !profile.exists || profile.get("state") !== "active" ||
          !Array.isArray(account.get("active_profile_ids")) || !(account.get("active_profile_ids") as string[]).includes(requestedProfileId) ||
          memberTaskId(ref.id, { uid: requestedUid, profileId: requestedProfileId }) !== memberId) {
        throw new HttpsError("failed-precondition", "The requesting group profile is no longer active");
      }
      txn.create(invitationRef, {
        member_id: memberId,
        uid: requestedUid,
        profile_id: requestedProfileId,
        mode: profile.get("mode"),
        role: "member",
        state: "awaiting_response",
        late_approved: true,
        sub_track_id: newUlid(),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      txn.update(taskRef, { response_revision: admin.firestore.FieldValue.increment(1), updated_at: admin.firestore.FieldValue.serverTimestamp() });
    }
    txn.update(joinRequest.ref, { state: data.approved ? "approved" : "declined", reviewed_by_uid: uid, reviewed_at: admin.firestore.FieldValue.serverTimestamp() });
    return { state: data.approved ? "approved" : "declined" };
  });
});

/** Only the caller's own published daily tasks and track IDs are returned. */
export const listMyLearningGroupDailyTasks = onCall(CALL_OPTS, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  exactKeys(data, ["profileId", "onDate"]);
  const profileId = requiredString(data.profileId, "profileId");
  const today = serverToday();
  const onDate = data.onDate === undefined ? today : date(data.onDate, "onDate");
  if (onDate < shiftCivilDate(today, -1) || onDate > shiftCivilDate(today, 1)) {
    throw new HttpsError("invalid-argument", "onDate must be within one day of the server date");
  }
  const memberships = await db.collectionGroup("group_profiles").where("owner_uid", "==", uid)
    .where("profile_id", "==", profileId).where("state", "==", "active").limit(MAX_GROUPS_PER_LEARN_CALL).get();
  const result: Array<Record<string, unknown>> = [];
  for (const membership of memberships.docs) {
    const groupId = membership.ref.path.split("/")[1];
    if (!groupId) continue;
    const groupRefValue = db.collection("learning_groups").doc(groupId);
    const memberAllowed = await db.runTransaction(async (txn) => {
      await requireActiveGroup(txn, groupRefValue);
      const [account, profile] = await Promise.all([
        txn.get(memberRef(groupId, uid)), txn.get(profileMemberRef(groupId, uid, profileId)),
      ]);
      return account.exists && account.get("state") === "active" && profile.exists && profile.get("state") === "active" &&
        Array.isArray(account.get("active_profile_ids")) && (account.get("active_profile_ids") as string[]).includes(profileId);
    });
    if (!memberAllowed) continue;
    const group = await groupRefValue.get();
    if (!group.exists || group.get("status") !== "active") continue;
    const memberId = memberTaskId(groupId, { uid, profileId });
    const groupTasks = await db.collection("learning_groups").doc(groupId).collection("tasks")
      .where("status", "==", "published").limit(MAX_TASKS_PER_GROUP_CALL).get();
    for (const task of groupTasks.docs) {
      const assignment = await task.ref.collection("allocations").doc("v1").collection("members").doc(memberId).get();
      if (!assignment.exists || assignment.get("state") !== "active") continue;
      const daily = (assignment.get("daily_tasks") as Array<Record<string, unknown>> | undefined) ?? [];
      const today = daily.find((entry) => entry.date === onDate);
      if (!today) continue;
      result.push({
        groupId, taskId: task.id, taskName: task.get("task_name"), curriculumId: task.get("curriculum_id"),
        subTrackId: assignment.get("sub_track_id"), date: today.date, refs: today.refs,
        workload: today.workload, paceUnit: today.paceUnit, paceAmount: today.paceAmount,
        ...(today.overloaded === true ? { overloaded: true } : {}),
      });
    }
  }
  return result;
});
