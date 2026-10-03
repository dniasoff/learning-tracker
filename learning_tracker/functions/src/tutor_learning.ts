import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { CALL_OPTS } from "./shared";
import {
  ENTITY_COLLECTION,
  LearningEventIntent,
  PlanContext,
  GovernedPlan,
  MAX_WRITES_PER_CALL,
  TOMBSTONE,
  ULID_RE,
  newUlid,
  runGoverned,
  writeWithChangeLog,
} from "./write_with_change_log";

// ══════════════════════════════════════════════════════════════════════════════
// Tutor learning callables — sub-tracks Story 1.23 (DNI-485) and Story 4.1
// (DNI-509)
// ══════════════════════════════════════════════════════════════════════════════
//
// The server-side entry points through which a tutor records, corrects and
// removes a talmid's learning (AD-31 / AD-53), and maintains his sub-track
// for the talmid (AD-38 `subTrack`, Story 4.1):
//
//   tutorRecordLearning — `learn` events, `source = main`, `date_state`
//                         `dated` (leaf ref + learned_on) or `before_tracking`
//                         (leaf, or node ref + level; learned_on null). Covers
//                         task tick, tick-to-here and before-tracking marking.
//                         Story 4.1: `source` may instead be the ULID of an
//                         existing sub-track of the same curriculum (`dated`
//                         only — the Rebbe row's +1 and Up to…); such events
//                         earn no `pts_` entry (AD-50).
//   tutorVoidLearning   — one `void` of a stored `source = main` learn event,
//                         or REPLACE: the void plus a corrected learn copy on
//                         the target's curriculum, in one transaction.
//   tutorUnlearn        — AD-31 un-learn of a leaf set, executing the client's
//                         unlearn plan (ruling B9): void every counted main
//                         learn event of the curriculum whose ref is in the
//                         leaf set, and void each named partially covered node
//                         event, re-issuing the client-computed maximal
//                         complement nodes as before_tracking events carrying
//                         `original_recorded_at = effectiveAt(target)`.
//   tutorUpsertSubTrack — the `subTrack` entity: create (also *Add next
//                         year*: a new ULID for `academic_year + 1`), edit of
//                         any field but `curriculum_id` (ground add, reorder
//                         and remove replace `ground` whole), end and delete
//                         (`ended_at` + `end_reason` tombstones, never a
//                         hard delete).
//
// Each one is a thin adapter over `writeWithChangeLog`, which owns
// authentication, the single `can_edit_learning` grant check (AD-53 — these
// callables check no grant or permission themselves), the server-derived
// tutor actor, the server-stamped `recorded_at`, AD-52/AD-31 payload
// validation, the AD-50 `pts_{eventId}` entries (every new dated main learn
// event, same transaction), the transaction itself and idempotent replay on
// the client action id (default: the first event's client ULID — the
// capture's action id, AD-52 `reverts_action_id`). No analytics are emitted;
// failures are logged as `{entity, code}` only (AD-54).
//
// The response is the helper's result, including the server-stamped
// `recorded_at`: a capture stamped inside the learner's lock window is stored,
// never rejected (AD-36, deviation #2) — the client re-runs CaptureGate on the
// returned stamp and labels it.
//
// Wire shape (B13: internal contract, ships with the app at the AD-49
// cutover). Events are storage-shaped `{id, fields}` — the client ULID is the
// learning_events doc id and `fields` use AD-52 storage names. The caller never
// supplies `actor`, `recorded_at` or `original_recorded_at`.
//
//   tutorRecordLearning {grantId, ownerUid, profileId, actionId?,
//                        events: [{id, fields: {kind: "learn", curriculum_id,
//                        ref, source: "main" | <sub-track ULID>, date_state,
//                        learned_on, level?, stage?}}]}
//   tutorVoidLearning   {grantId, ownerUid, profileId, actionId?, eventId,
//                        targetId, replacement?: {id, fields: <learn fields>}}
//   tutorUnlearn        {grantId, ownerUid, profileId, actionId (required),
//                        curriculumId, leafSet: string[], leafEventIds?:
//                        string[], nodeReissues?: [{targetEventId, reissues:
//                        [{eventId, ref, level}]}]}
//   tutorUpsertSubTrack {grantId, ownerUid, profileId, actionId?, subTrackId,
//                        op: "create" | "edit" | "end" | "delete",
//                        fields?: <AD-52 sub_tracks fields>}
//                        create: `fields` is the full new doc (the doc must be
//                        absent; a null field is simply not written);
//                        actionId defaults to subTrackId. edit:
//                        `fields` holds only the changed fields, `null`
//                        clears a nullable one (the doc must exist); actionId
//                        required. end / delete: no `fields`; actionId
//                        required. `ended_at`, `end_reason` and
//                        `last_change_id` are never caller fields.
//
// `leafEventIds` (DNI-486) names the exact leaf learn events the client's
// engine counts. The server cannot evaluate the AD-36 lock-window / count
// predicate (it needs the learner's calendar and settings history), so when
// the client sends the ids the server voids exactly those and never a stored
// but uncounted (lock-ignored) event that happens to share a ref. Without
// the field the legacy ref match over `leafSet` applies.
//
// Chunking (AD-54): one call is one transaction of at most
// MAX_WRITES_PER_CALL writes (events + their pts_ entries + the receipt);
// a larger capture or un-learn is split by the client into self-contained
// calls, each with its own action id. An oversized call is rejected
// (invalid-argument) before anything is written.

/** Log label for these callables' `{entity, code}` failure lines. */
const LOG_ENTITY = "learningEvent";

/** The main-track learning source; any other tutor source is a sub-track ULID (Story 4.1). */
const MAIN_SOURCE = "main";

/** date_state values a tutor capture may carry (catch_up is owner/sub-track only). */
const TUTOR_DATE_STATES: ReadonlySet<unknown> = new Set(["dated", "before_tracking"]);

/** Fields a tutor learn event may carry — anything else is rejected here or by the helper. */
const TUTOR_LEARN_FIELDS: ReadonlySet<string> = new Set([
  "kind", "curriculum_id", "ref", "level", "source", "date_state", "learned_on", "stage",
]);

const bad = (message: string): never => {
  throw new HttpsError("invalid-argument", message);
};

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function isUlid(v: unknown): v is string {
  return typeof v === "string" && ULID_RE.test(v);
}

function nonEmptyString(v: unknown, max = 500): v is string {
  return typeof v === "string" && v.length > 0 && v.length <= max;
}

interface Target {
  grantId: unknown;
  ownerUid: string;
  profileId: string;
  actionId: string | undefined;
}

/**
 * Parses the routing fields every tutor learning call carries. `grantId` is
 * passed through untouched: writeWithChangeLog alone decides authorisation
 * (a missing or foreign grant is `permission-denied` there, AD-53).
 */
function parseTarget(data: Record<string, unknown>, allowed: readonly string[]): Target {
  const known = new Set(["grantId", "ownerUid", "profileId", "actionId", ...allowed]);
  for (const k of Object.keys(data)) {
    if (!known.has(k)) bad(`Unexpected request field: ${k}`);
  }
  if (!nonEmptyString(data.ownerUid, 700)) bad("ownerUid must be a non-empty string");
  if (!nonEmptyString(data.profileId, 700)) bad("profileId must be a non-empty string (ULID)");
  if (data.actionId !== undefined && data.actionId !== null && !isUlid(data.actionId)) {
    bad("actionId must be a ULID");
  }
  return {
    grantId: data.grantId,
    ownerUid: data.ownerUid as string,
    profileId: data.profileId as string,
    actionId: (data.actionId as string | null | undefined) ?? undefined,
  };
}

function requestObject(raw: unknown): Record<string, unknown> {
  if (!isObject(raw)) bad("request must be an object");
  return raw as Record<string, unknown>;
}

/**
 * Validates one tutor learn event `{id, fields}` against the tutor
 * contract — `kind = learn`, `source = main` (or, with
 * [allowSubTrackSource], a sub-track ULID on a `dated` event — Story 4.1),
 * `date_state` dated or before_tracking, no caller-supplied time or
 * actor — and normalises a
 * before_tracking event's absent `learned_on` to the stored `null`. The
 * helper re-validates the full AD-52 shape (types, level only on
 * before_tracking, learned_on required on dated, stage on main only).
 */
function parseTutorLearnEvent(
  raw: unknown,
  { allowSubTrackSource = false }: { allowSubTrackSource?: boolean } = {},
): LearningEventIntent {
  if (!isObject(raw)) bad("event must be an object");
  const ev = raw as Record<string, unknown>;
  for (const k of Object.keys(ev)) {
    if (k !== "id" && k !== "fields") bad(`Unexpected event field: ${k}`);
  }
  if (!isUlid(ev.id)) bad("event id must be a client ULID");
  if (!isObject(ev.fields)) bad("event fields must be an object");
  const fields = { ...(ev.fields as Record<string, unknown>) };
  for (const k of Object.keys(fields)) {
    if (!TUTOR_LEARN_FIELDS.has(k)) bad(`Field not allowed on a tutor learn event: ${k}`);
  }
  if (fields.kind !== "learn") bad("a tutor capture writes learn events only");
  if (fields.source !== MAIN_SOURCE) {
    // Story 4.1 (DNI-509): a capture on the tutor's sub-track row carries
    // the sub-track's ULID; it is a dated leaf event with no stage (stage is
    // main-track only, AD-52). Corrections stay main-only.
    if (!allowSubTrackSource || !isUlid(fields.source)) bad("source must be main or a sub-track ULID");
    if (fields.date_state !== "dated") bad("a sub-track capture is dated");
  }
  if (!TUTOR_DATE_STATES.has(fields.date_state)) bad("date_state must be dated or before_tracking");
  if (fields.date_state === "before_tracking") {
    if (fields.learned_on === undefined) fields.learned_on = null;
    if (fields.learned_on !== null) bad("a before_tracking event has learned_on = null");
  } else if (fields.level !== undefined) {
    bad("level is only allowed on a before_tracking node event");
  }
  return { id: ev.id as string, fields };
}

function assertUniqueIds(ids: string[]): void {
  if (new Set(ids).size !== ids.length) bad("event ids must be unique");
}

// ── tutorRecordLearning ───────────────────────────────────────────────────────

export const tutorRecordLearning = onCall(CALL_OPTS, (request) => runGoverned(LOG_ENTITY, async () => {
  const data = requestObject(request.data);
  const target = parseTarget(data, ["events"]);
  if (!Array.isArray(data.events) || data.events.length === 0) {
    bad("events must be a non-empty array");
  }
  const events = (data.events as unknown[])
    .map((e) => parseTutorLearnEvent(e, { allowSubTrackSource: true }));
  assertUniqueIds(events.map((e) => e.id));
  const subTrackSources = [...new Set(events
    .map((e) => String(e.fields.source))
    .filter((source) => source !== MAIN_SOURCE))].sort();
  return writeWithChangeLog(request.auth, {
    ownerUid: target.ownerUid,
    profileId: target.profileId,
    grantId: target.grantId as string | null | undefined,
    actionId: target.actionId ?? events[0].id,
    auditAction: "learning_recorded",
    events,
    // Only a sub-track capture reads anything: a main-track capture keeps
    // its plan-free request (and so its replay fingerprint).
    ...(subTrackSources.length === 0 ? {} : {
      plan: subTrackSourcePlan(events),
      planKey: `tutorRecordLearning:subTrackSources:${JSON.stringify(subTrackSources)}`,
    }),
  });
}));

/**
 * Validates, inside the transaction, every sub-track `source` of [events]:
 * the `sub_tracks/{source}` doc exists in this learner's profile and belongs
 * to the event's curriculum (an event never names another curriculum's or
 * another learner's sub-track). Reads only; the events themselves are the
 * request's static events.
 */
function subTrackSourcePlan(events: LearningEventIntent[]): (ctx: PlanContext) => Promise<GovernedPlan> {
  return async (ctx) => {
    const ids = [...new Set(events
      .map((e) => String(e.fields.source))
      .filter((source) => source !== MAIN_SOURCE))];
    const snaps = await ctx.txn.getAll(
      ...ids.map((id) => ctx.profileRef.collection(ENTITY_COLLECTION.subTrack).doc(id)));
    const curriculumOf = new Map<string, unknown>(snaps.map((snap, i) => {
      if (!snap.exists) throw new HttpsError("not-found", "Sub-track source does not exist");
      return [ids[i], snap.get("curriculum_id")];
    }));
    for (const e of events) {
      if (e.fields.source === MAIN_SOURCE) continue;
      if (curriculumOf.get(String(e.fields.source)) !== e.fields.curriculum_id) {
        bad("A sub-track capture must be on the sub-track's curriculum");
      }
    }
    return { entries: [] };
  };
}

// ── tutorVoidLearning ─────────────────────────────────────────────────────────

/** Firestore Timestamp (or absent) → ISO-8601, for `original_recorded_at`. */
function effectiveAtIso(target: FirebaseFirestore.DocumentData): string {
  const t = target.original_recorded_at ?? target.recorded_at;
  if (!(t instanceof admin.firestore.Timestamp)) {
    throw new HttpsError("failed-precondition", "Target event has no recorded time");
  }
  return t.toDate().toISOString();
}

/** Is [eventId] already the target of a stored void? */
async function isVoided(ctx: PlanContext, eventId: string): Promise<boolean> {
  const voids = await ctx.txn.get(
    ctx.profileRef.collection("learning_events").where("target_id", "==", eventId).limit(1));
  return !voids.empty;
}

export const tutorVoidLearning = onCall(CALL_OPTS, (request) => runGoverned(LOG_ENTITY, async () => {
  const data = requestObject(request.data);
  const target = parseTarget(data, ["eventId", "targetId", "replacement"]);
  if (!isUlid(data.eventId)) bad("eventId must be a client ULID");
  if (!isUlid(data.targetId)) bad("targetId must be a ULID");
  const voidId = data.eventId as string;
  const targetId = data.targetId as string;
  const voidEvent: LearningEventIntent = { id: voidId, fields: { kind: "void", target_id: targetId } };
  const replacement = data.replacement === undefined || data.replacement === null
    ? null
    : parseTutorLearnEvent(data.replacement);
  if (replacement) assertUniqueIds([voidId, targetId, replacement.id]);
  else if (voidId === targetId) bad("event ids must be unique");

  // Both shapes read the stored target in the transaction and require a
  // counted-source learn event a tutor may void: `kind = learn` (AD-31) and
  // `source = main` (Epic 1 tutors write main-track learning only, so they
  // may not void a sub-track event either). A replacement must stay on the
  // target's curriculum: a correction never moves learning to another track.
  const readTarget = async (ctx: PlanContext): Promise<FirebaseFirestore.DocumentData> => {
    const snap = await ctx.txn.get(ctx.profileRef.collection("learning_events").doc(targetId));
    if (!snap.exists) throw new HttpsError("not-found", "Void target does not exist");
    const stored = snap.data()!;
    if (stored.kind !== "learn") bad("A void must target a learn event");
    if (stored.source !== MAIN_SOURCE) bad("A tutor may void only a main-track learn event");
    return stored;
  };

  if (!replacement) {
    const plan = async (ctx: PlanContext): Promise<GovernedPlan> => {
      await readTarget(ctx);
      return { entries: [], events: [voidEvent] };
    };
    return writeWithChangeLog(request.auth, {
      ownerUid: target.ownerUid,
      profileId: target.profileId,
      grantId: target.grantId as string | null | undefined,
      actionId: target.actionId ?? voidId,
      auditAction: "learning_voided",
      plan,
      planKey: `tutorVoidLearning:${JSON.stringify([voidId, targetId])}`,
    });
  }

  // Replace = void + learn copy in ONE transaction. The copy keeps the
  // target's effective instant (`original_recorded_at = effectiveAt(target)`,
  // read from the stored target, never from input), so a correction does not
  // move the learning to "now" for lock, streak or earning order.
  const replacementEvent = replacement;
  const plan = async (ctx: PlanContext): Promise<GovernedPlan> => {
    const stored = await readTarget(ctx);
    if (replacementEvent.fields.curriculum_id !== stored.curriculum_id) {
      bad("A replacement must keep the target's curriculum");
    }
    if (await isVoided(ctx, targetId)) {
      throw new HttpsError("failed-precondition", "Replace target is already voided");
    }
    return {
      entries: [],
      events: [
        voidEvent,
        { id: replacementEvent.id, fields: { ...replacementEvent.fields, original_recorded_at: effectiveAtIso(stored) } },
      ],
    };
  };
  return writeWithChangeLog(request.auth, {
    ownerUid: target.ownerUid,
    profileId: target.profileId,
    grantId: target.grantId as string | null | undefined,
    actionId: target.actionId ?? voidId,
    auditAction: "learning_replaced",
    plan,
    planKey: `tutorReplaceLearning:${JSON.stringify([voidId, targetId, replacementEvent.id,
      Object.keys(replacementEvent.fields).sort().map((k) => [k, replacementEvent.fields[k]])])}`,
  });
}));

// ── tutorUnlearn ──────────────────────────────────────────────────────────────

interface NodeReissuePlan {
  targetEventId: string;
  reissues: Array<{ eventId: string; ref: string; level: string | number }>;
}

/** Firestore `in` filters take at most 30 values. */
const IN_CHUNK = 30;

function chunks<T>(xs: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < xs.length; i += size) out.push(xs.slice(i, i + size));
  return out;
}

function parseUnlearn(data: Record<string, unknown>): {
  curriculumId: string; leafSet: string[]; leafEventIds: string[] | null; nodeReissues: NodeReissuePlan[];
} {
  if (!nonEmptyString(data.curriculumId, 200)) bad("curriculumId must be a non-empty string");
  if (!Array.isArray(data.leafSet) || data.leafSet.length === 0) bad("leafSet must be a non-empty array");
  const leafSet = data.leafSet as unknown[];
  if (leafSet.length > MAX_WRITES_PER_CALL) bad("leafSet is too large for one call");
  if (!leafSet.every((r) => nonEmptyString(r))) bad("leafSet entries must be refs");
  if (new Set(leafSet).size !== leafSet.length) bad("leafSet entries must be unique");
  const leaves = new Set(leafSet as string[]);

  let leafEventIds: string[] | null = null;
  if (data.leafEventIds !== undefined && data.leafEventIds !== null) {
    if (!Array.isArray(data.leafEventIds)) bad("leafEventIds must be an array");
    const ids = data.leafEventIds as unknown[];
    if (ids.length > MAX_WRITES_PER_CALL) bad("leafEventIds is too large for one call");
    if (!ids.every(isUlid)) bad("leafEventIds entries must be ULIDs");
    if (new Set(ids).size !== ids.length) bad("leafEventIds entries must be unique");
    leafEventIds = ids as string[];
  }

  const rawReissues = data.nodeReissues ?? [];
  if (!Array.isArray(rawReissues)) bad("nodeReissues must be an array");
  const seenIds = new Set<string>();
  const claim = (id: string) => {
    if (seenIds.has(id)) bad("event ids must be unique");
    seenIds.add(id);
  };
  const nodeReissues = (rawReissues as unknown[]).map((raw): NodeReissuePlan => {
    if (!isObject(raw)) bad("nodeReissue must be an object");
    const n = raw as Record<string, unknown>;
    for (const k of Object.keys(n)) {
      if (k !== "targetEventId" && k !== "reissues") bad(`Unexpected nodeReissue field: ${k}`);
    }
    if (!isUlid(n.targetEventId)) bad("targetEventId must be a ULID");
    claim(n.targetEventId as string);
    const reissuesRaw = n.reissues ?? [];
    if (!Array.isArray(reissuesRaw)) bad("reissues must be an array");
    const reissues = (reissuesRaw as unknown[]).map((r) => {
      if (!isObject(r)) bad("reissue must be an object");
      const x = r as Record<string, unknown>;
      for (const k of Object.keys(x)) {
        if (k !== "eventId" && k !== "ref" && k !== "level") bad(`Unexpected reissue field: ${k}`);
      }
      if (!isUlid(x.eventId)) bad("reissue eventId must be a client ULID");
      claim(x.eventId as string);
      if (!nonEmptyString(x.ref)) bad("reissue ref must be a ref");
      if (leaves.has(x.ref as string)) bad("a re-issued ref may not be in leafSet");
      const levelOk = (typeof x.level === "string" && x.level.length > 0 && x.level.length <= 64) ||
        (typeof x.level === "number" && Number.isInteger(x.level));
      if (!levelOk) bad("a re-issued node event requires level");
      return { eventId: x.eventId as string, ref: x.ref as string, level: x.level as string | number };
    });
    return { targetEventId: n.targetEventId as string, reissues };
  });
  for (const n of nodeReissues) {
    if (leafEventIds?.includes(n.targetEventId)) bad("a node target may not be in leafEventIds");
  }
  return { curriculumId: data.curriculumId as string, leafSet: leafSet as string[], leafEventIds, nodeReissues };
}

/**
 * The in-transaction AD-31 un-learn expansion (reads only). Voids every
 * counted (unvoided) `source = main` learn event of [curriculumId] whose ref
 * is in [leafSet] (exact ref match — no hierarchy needed), then voids each
 * named partially covered node event and re-issues the client-computed
 * complement nodes as before_tracking events with
 * `original_recorded_at = effectiveAt(target)` read from the stored target.
 * Void ids are server-generated; replay safety comes from the required client
 * action id (the receipt returns the stored result, never re-plans).
 */
function unlearnPlan(
  curriculumId: string,
  leafSet: string[],
  leafEventIds: string[] | null,
  nodeReissues: NodeReissuePlan[],
): (ctx: PlanContext) => Promise<GovernedPlan> {
  return async (ctx) => {
    const events = ctx.profileRef.collection("learning_events");

    // (a) counted leaf learn events with ref ∈ leafSet. When the client names
    // them (leafEventIds — the engine's counted set), exactly those, each
    // checked against the store; a stored but uncounted (lock-ignored) event
    // with the same ref is never voided.
    const candidates = new Set<string>();
    if (leafEventIds !== null) {
      const leaves = new Set(leafSet);
      const snaps = leafEventIds.length
        ? await ctx.txn.getAll(...leafEventIds.map((id) => events.doc(id)))
        : [];
      for (const snap of snaps) {
        if (!snap.exists) throw new HttpsError("not-found", "Un-learn leaf event does not exist");
        const e = snap.data()!;
        if (e.kind !== "learn") bad("A void must target a learn event");
        if (e.curriculum_id !== curriculumId || e.source !== MAIN_SOURCE || !leaves.has(e.ref)) {
          bad("Un-learn leaf event must be a main learn event of this curriculum with a ref in leafSet");
        }
        candidates.add(snap.id);
      }
    }
    for (const refs of leafEventIds === null ? chunks(leafSet, IN_CHUNK) : []) {
      const snap = await ctx.txn.get(events.where("ref", "in", refs));
      for (const d of snap.docs) {
        const e = d.data();
        if (e.kind === "learn" && e.curriculum_id === curriculumId && e.source === MAIN_SOURCE) {
          candidates.add(d.id);
        }
      }
    }

    // (b) the named node targets, read from the store (never trusted input).
    const targetSnaps = nodeReissues.length
      ? await ctx.txn.getAll(...nodeReissues.map((n) => events.doc(n.targetEventId)))
      : [];
    targetSnaps.forEach((snap) => {
      if (!snap.exists) throw new HttpsError("not-found", "Un-learn target does not exist");
      const t = snap.data()!;
      if (t.kind !== "learn") bad("A void must target a learn event");
      if (t.curriculum_id !== curriculumId || t.source !== MAIN_SOURCE ||
        t.date_state !== "before_tracking" || t.level === undefined || t.level === null) {
        bad("Un-learn target must be a main before_tracking node event of this curriculum");
      }
    });

    // Counted = not already voided (voids form a set of target ids).
    const toCheck = [...new Set([...candidates, ...nodeReissues.map((n) => n.targetEventId)])];
    const voided = new Set<string>();
    for (const ids of chunks(toCheck, IN_CHUNK)) {
      const snap = await ctx.txn.get(events.where("target_id", "in", ids));
      for (const d of snap.docs) voided.add(String(d.get("target_id")));
    }
    for (const n of nodeReissues) {
      if (voided.has(n.targetEventId)) {
        throw new HttpsError("failed-precondition", "Un-learn target is already voided");
      }
    }

    const out: LearningEventIntent[] = [];
    const voidOnce = new Set<string>();
    const voidOf = (targetId: string) => {
      if (voidOnce.has(targetId)) return;
      voidOnce.add(targetId);
      out.push({ id: newUlid(), fields: { kind: "void", target_id: targetId } });
    };
    [...candidates].filter((id) => !voided.has(id)).sort().forEach(voidOf);
    nodeReissues.forEach((n, i) => {
      const t = targetSnaps[i].data()!;
      voidOf(n.targetEventId);
      const originalRecordedAt = effectiveAtIso(t);
      for (const r of n.reissues) {
        const fields: Record<string, unknown> = {
          kind: "learn",
          curriculum_id: curriculumId,
          ref: r.ref,
          level: r.level,
          source: MAIN_SOURCE,
          date_state: "before_tracking",
          learned_on: null,
          original_recorded_at: originalRecordedAt,
        };
        if (typeof t.stage === "number") fields.stage = t.stage;
        out.push({ id: r.eventId, fields });
      }
    });
    return { entries: [], events: out };
  };
}

export const tutorUnlearn = onCall(CALL_OPTS, (request) => runGoverned(LOG_ENTITY, async () => {
  const data = requestObject(request.data);
  const target = parseTarget(data, ["curriculumId", "leafSet", "leafEventIds", "nodeReissues"]);
  // Void ids are minted on the server, so cross-call replay safety needs the
  // client's action id: a retry returns the stored receipt, never re-plans.
  if (!target.actionId) bad("actionId (client ULID) is required for tutorUnlearn");
  const plan = parseUnlearn(data);
  return writeWithChangeLog(request.auth, {
    ownerUid: target.ownerUid,
    profileId: target.profileId,
    grantId: target.grantId as string | null | undefined,
    actionId: target.actionId,
    auditAction: "learning_unlearned",
    plan: unlearnPlan(plan.curriculumId, plan.leafSet, plan.leafEventIds, plan.nodeReissues),
    planKey: `tutorUnlearn:${JSON.stringify(plan.leafEventIds === null
      ? [plan.curriculumId, plan.leafSet, plan.nodeReissues]
      : [plan.curriculumId, plan.leafSet, plan.nodeReissues, plan.leafEventIds])}`,
  });
}));

// ── tutorUpsertSubTrack (Story 4.1, DNI-509) ─────────────────────────────────

/** Log label for tutorUpsertSubTrack's `{entity, code}` failure lines. */
const SUB_TRACK_ENTITY = "subTrack";

const SUB_TRACKS = ENTITY_COLLECTION.subTrack;

/** The sub-track lifecycle operations a tutor may request. */
type SubTrackOp = "create" | "edit" | "end" | "delete";

const SUB_TRACK_OPS: ReadonlySet<unknown> = new Set(["create", "edit", "end", "delete"]);

/**
 * Intent fields a tutor create or edit may carry (AD-52 `sub_tracks`). The
 * lifecycle pair `ended_at` / `end_reason` is set only by `end` / `delete`
 * (a tutor never re-adds through an edit) and `last_change_id` only by the
 * helper; writeWithChangeLog validates every value's type, the final doc's
 * shape and the AD-45 limits.
 */
const SUB_TRACK_INTENT_FIELDS: ReadonlySet<string> = new Set([
  "curriculum_id", "name", "type", "academic_year", "window_start", "window_end",
  "rate_per_week", "weeks_per_year", "learns_on_shabbos", "ground",
]);

const END_REASON: Readonly<Record<"end" | "delete", string>> = { end: "ended", delete: "deleted" };

const AUDIT_ACTION: Readonly<Record<SubTrackOp, string>> = {
  create: "sub_track_created",
  edit: "sub_track_edited",
  end: "sub_track_ended",
  delete: "sub_track_deleted",
};

function parseSubTrackFields(raw: unknown, op: "create" | "edit"): Record<string, unknown> {
  if (!isObject(raw)) bad("fields must be an object");
  const fields = raw as Record<string, unknown>;
  const keys = Object.keys(fields);
  if (keys.length === 0) bad("fields must not be empty");
  for (const k of keys) {
    if (!SUB_TRACK_INTENT_FIELDS.has(k)) bad(`Field not allowed on a tutor sub-track ${op}: ${k}`);
  }
  return { ...fields };
}

export const tutorUpsertSubTrack = onCall(CALL_OPTS, (request) => runGoverned(SUB_TRACK_ENTITY, async () => {
  const data = requestObject(request.data);
  const target = parseTarget(data, ["subTrackId", "op", "fields"]);
  if (!isUlid(data.subTrackId)) bad("subTrackId must be a client ULID");
  const subTrackId = data.subTrackId as string;
  if (!SUB_TRACK_OPS.has(data.op)) bad("op must be create, edit, end or delete");
  const op = data.op as SubTrackOp;

  let fields: Record<string, unknown>;
  if (op === "create" || op === "edit") {
    fields = parseSubTrackFields(data.fields, op);
  } else {
    if (data.fields !== undefined && data.fields !== null) bad(`${op} takes no fields`);
    fields = { ended_at: TOMBSTONE, end_reason: END_REASON[op] };
  }
  // A create's stable replay key is the new doc's own client ULID; every
  // other operation is a new user action that must name its own.
  const actionId = target.actionId ?? (op === "create" ? subTrackId : undefined);
  if (!actionId) bad(`actionId (client ULID) is required for ${op}`);

  return writeWithChangeLog(request.auth, {
    ownerUid: target.ownerUid,
    profileId: target.profileId,
    grantId: target.grantId as string | null | undefined,
    actionId,
    auditAction: AUDIT_ACTION[op],
    entries: [{
      entity: "subTrack",
      entityId: subTrackId,
      docs: [{
        collection: SUB_TRACKS,
        docId: subTrackId,
        fields,
        // create: the doc must be absent (never overwritten); edit, end and
        // delete: the doc must exist, so an edit never makes a partial doc.
        mode: op === "create" ? "create" : "update",
      }],
    }],
  });
}));
