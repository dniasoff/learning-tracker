import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v1";
import { HttpsError } from "firebase-functions/v2/https";

import { db } from "./shared";
import {
  calendarProgramSetViolations,
  civilDateIn,
  subTrackIntentViolations,
  subTrackLimitViolations,
  subTrackViolationCodes,
  type SubTrackRow,
  type SubTrackViolation,
} from "./sub_track_limits";

// ══════════════════════════════════════════════════════════════════════════════
// writeWithChangeLog — the one server-side write path for governed entities
// (sub-tracks AD-38 callable contract, AD-53, AD-54).
// ══════════════════════════════════════════════════════════════════════════════
//
// Admin SDK writes bypass firestore.rules, so this helper IS the rule for every
// callable that writes a governed entity (goal, main track and its config,
// sub-track, learner settings) or a learning event. On every call it:
//
//   1. requires request.auth;
//   2. verifies the caller owns the profile path, or holds an ACTIVE
//      tutor_grants grant for it with permissions.can_edit_learning == true —
//      re-read inside the transaction, so a revocation stops the next call;
//      no callable checks permissions separately (AD-53);
//   3. derives `actor` server-side: uid from auth; role = tutor and
//      display_name = grant.tutor_name_snapshot for grant callers; an owner's
//      asserted parent/child role is accepted (Roles convention) with
//      display_name from the account doc;
//   4. validates the full storage-shaped payload (AD-52 field names/types,
//      the AD-38 entity ↔ collection mapping, AD-31 void targets, AD-43/AD-45
//      calendar-program goal rejection) before writing anything;
//   5. runs everything — doc patches, one change_log entry per entity, learning
//      events — in ONE Firestore transaction;
//   6. attaches `points_ledger/pts_{eventId}` to every NEW `source = main`
//      `dated` or `catch_up` learn event in the same transaction (AD-50):
//      amount = point_configs[curriculum, stage ?? firstStageOrder] (the
//      default ladder when no override exists), `created_at` = the event's
//      `recorded_at`. Never for a void, a before_tracking event, a sub-track
//      source or a replayed event; no reversal entries are ever written;
//   7. is idempotent on the client action id (the request actionId, else the
//      first entry's ULID): every client action — no-ops included — leaves an
//      immutable receipt at `governed_action_receipts/{actionId}` (Admin-only,
//      default-denied by the rules) holding the actor, a canonical request
//      fingerprint and the result. A retry with the same actor and fingerprint
//      returns the stored result (change ids, event ids, server times) without
//      re-planning; a different actor or ANY payload difference (entity ids,
//      doc ids, modes, fields, plan, events) under the same id is rejected
//      (already-exists).
//
// Writes are field-level (`mergeFields` of the changed fields only, including
// first writes); removal is an `ended_at` tombstone, never a delete. A create
// is claimed only after the transaction has confirmed the doc is absent: an
// explicit `create` on an existing doc is rejected (never overwritten), an `upsert` of
// an existing doc becomes an ordinary update entry (AC-2).
//
// Failures are logged as structured `{entity, code}` only — never a uid,
// profile id, payload or any other learner data (AD-54 observability).

// ── Wire / storage constants ──────────────────────────────────────────────────

export const ULID_RE = /^[0-9A-HJKMNP-TV-Z]{26}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Firestore's per-transaction write ceiling is 500; leave headroom (AD-54 chunk size). */
export const MAX_WRITES_PER_CALL = 450;

export type GovernedEntity =
  | "subTrack"
  | "goal"
  | "mainTrack"
  | "mainTrackOrder"
  | "mainTrackProgram"
  | "mainTrackStudyDays"
  | "mainTrackStages"
  | "mainTrackScope"
  | "learnerSettings";

/** AD-38 entity ↔ collection mapping. */
export const ENTITY_COLLECTION: Readonly<Record<GovernedEntity, string>> = {
  subTrack: "sub_tracks",
  goal: "goals",
  mainTrack: "curriculum_tracks",
  mainTrackOrder: "track_learning_order",
  mainTrackProgram: "profile_programs",
  mainTrackStudyDays: "study_day_configs",
  mainTrackStages: "stage_definitions",
  mainTrackScope: "curriculum_scopes",
  learnerSettings: "learner_profiles",
};

const MAIN_TRACK_ENTITIES: ReadonlySet<GovernedEntity> = new Set<GovernedEntity>([
  "mainTrack",
  "mainTrackOrder",
  "mainTrackProgram",
  "mainTrackStudyDays",
  "mainTrackStages",
  "mainTrackScope",
]);

export function isGovernedEntity(v: unknown): v is GovernedEntity {
  return typeof v === "string" && Object.prototype.hasOwnProperty.call(ENTITY_COLLECTION, v);
}

/**
 * Wire value for `ended_at`: `true` = tombstone now (server-stamped);
 * `null` = clear the tombstone (re-add). Any other value is rejected.
 */
export const TOMBSTONE = true;

// ── Field validators (AD-52 storage schema) ───────────────────────────────────

type Check = (v: unknown) => boolean;

const str = (max = 500): Check => (v) => typeof v === "string" && v.length > 0 && v.length <= max;
const int: Check = (v) => typeof v === "number" && Number.isInteger(v);
const intIn = (lo: number, hi: number): Check => (v) => int(v) && (v as number) >= lo && (v as number) <= hi;
const num: Check = (v) => typeof v === "number" && Number.isFinite(v);
const posNum: Check = (v) => num(v) && (v as number) > 0;
const bool: Check = (v) => typeof v === "boolean";
const oneOf = (...xs: string[]): Check => (v) => typeof v === "string" && xs.includes(v);
const nullable = (c: Check): Check => (v) => v === null || c(v);
const either = (...cs: Check[]): Check => (v) => cs.some((c) => c(v));
const listOf = (c: Check, max = 500): Check => (v) => Array.isArray(v) && v.length <= max && v.every(c);
const date: Check = (v) => {
  if (typeof v !== "string" || !DATE_RE.test(v)) return false;
  const d = new Date(`${v}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
};
const groundItem: Check = (v) =>
  typeof v === "object" && v !== null && !Array.isArray(v) &&
  Object.keys(v).every((k) => k === "level" || k === "ref") &&
  either(str(64), int)((v as Record<string, unknown>).level) &&
  str(500)((v as Record<string, unknown>).ref);

const CURRICULUM_ID = str(200);
const ENDED_AT: Check = (v) => v === TOMBSTONE || v === null;

/**
 * Client-writable fields per governed collection. `last_change_id` is never
 * client-writable (the helper stamps it); `updated_at` / `synced_at` are
 * retired from governed docs (AD-38) and are rejected.
 *
 * Nullability is per field: `null` on the wire means "remove this field", so
 * only fields the AD-52 schema allows to be absent are wrapped in
 * `nullable(...)`. A `null` for any other field is rejected — a caller can
 * never delete required data (e.g. `curriculum_tracks.state`) by patching it
 * to null. `ended_at` accepts `null` (clear the tombstone / re-add).
 */
const FIELD_SPECS: Readonly<Record<string, Readonly<Record<string, Check>>>> = {
  sub_tracks: {
    curriculum_id: CURRICULUM_ID,
    name: str(200),
    type: oneOf("school_year", "ongoing"),
    // school-year only; absent on an ongoing sub-track.
    academic_year: nullable(int),
    window_start: date,
    // null = open window.
    window_end: nullable(date),
    rate_per_week: num,
    weeks_per_year: num,
    learns_on_shabbos: bool,
    ground: listOf(groundItem),
    end_reason: nullable(oneOf("ended", "deleted", "undo", "track_deleted")),
    ended_at: ENDED_AT,
  },
  goals: {
    goal_type: oneOf("deadline", "pace"),
    target_date: nullable(date),
    pace_value: nullable(posNum),
    pace_unit: nullable(str(64)),
    pace_granularity: nullable(str(64)),
    curriculum_id: CURRICULUM_ID,
    ended_at: ENDED_AT,
  },
  curriculum_tracks: {
    state: oneOf("active", "retired", "archived"),
    curriculum_id: CURRICULUM_ID,
    ended_at: ENDED_AT,
  },
  track_learning_order: {
    curriculum_id: CURRICULUM_ID,
    level: either(str(64), int),
    ref: str(500),
    user_sort_order: int,
    ended_at: ENDED_AT,
  },
  profile_programs: {
    program_id: nullable(str(200)),
    tracking_start_date: nullable(date),
    tracking_start_ref: nullable(str(500)),
    curriculum_id: CURRICULUM_ID,
    ended_at: ENDED_AT,
  },
  study_day_configs: {
    curriculum_id: CURRICULUM_ID,
    day_of_week: intIn(0, 7),
    day_type: str(64),
    ended_at: ENDED_AT,
  },
  stage_definitions: {
    curriculum_id: CURRICULUM_ID,
    stage_order: int,
    stage_name: str(200),
    schedule: nullable(either(str(2000), listOf(either(int, str(200))))),
    delay_days: nullable(int),
    schedule_type: nullable(str(64)),
    is_default: bool,
    days_of_week: nullable(listOf(intIn(0, 7), 7)),
    rolling_window_size: nullable(int),
    ended_at: ENDED_AT,
  },
  curriculum_scopes: {
    curriculum_id: CURRICULUM_ID,
    scope_level: either(int, str(64)),
    scope_value: either(str(500), int),
    ended_at: ENDED_AT,
  },
  learner_profiles: {
    // Location may be unknown; the IANA time_zone and in_israel are required
    // once written (AD-37 / AD-41) and can never be cleared.
    latitude: nullable((v) => num(v) && Math.abs(v as number) <= 90),
    longitude: nullable((v) => num(v) && Math.abs(v as number) <= 180),
    time_zone: str(64),
    in_israel: bool,
  },
};

/**
 * Fields every LIVE (non-tombstoned) doc of a collection must carry, checked
 * on the final state of every write — create, update or re-add — so no patch
 * can leave a live doc without required data (AD-52).
 */
const REQUIRED_LIVE_FIELDS: Readonly<Record<string, readonly string[]>> = {
  curriculum_tracks: ["state"],
  track_learning_order: ["level", "ref", "user_sort_order"],
};

const EVENT_LEARN_FIELDS: Readonly<Record<string, Check>> = {
  kind: oneOf("learn"),
  curriculum_id: CURRICULUM_ID,
  ref: str(500),
  level: either(str(64), int),
  source: (v) => v === "main" || (typeof v === "string" && ULID_RE.test(v)),
  date_state: oneOf("dated", "catch_up", "before_tracking"),
  // AD-40 / AD-52: a civil date, required on dated and catch_up events (the
  // streak and projection count on it); null/absent only on before_tracking.
  learned_on: nullable(date),
  stage: int,
  original_recorded_at: (v) => typeof v === "string" && !Number.isNaN(Date.parse(v)),
};

const EVENT_VOID_FIELDS: Readonly<Record<string, Check>> = {
  kind: oneOf("void"),
  target_id: (v) => typeof v === "string" && ULID_RE.test(v),
  reverts_action_id: (v) => typeof v === "string" && ULID_RE.test(v),
};

// ── AD-50 points attachment ───────────────────────────────────────────────────

/** `points_ledger/pts_{eventId}` — the one event-bound points entry (AD-50 / AD-46). */
export function pointsDocId(eventId: string): string {
  return `pts_${eventId}`;
}

/** True for a learn event that AD-50 pairs with a `pts_` entry. */
export function earnsPointsEntry(fields: Record<string, unknown>): boolean {
  return fields.kind === "learn" && fields.source === "main" &&
    (fields.date_state === "dated" || fields.date_state === "catch_up");
}

/**
 * The default per-stage ladder used when a curriculum/stage has no
 * `point_configs` override — identical to the client app's default stage
 * ladder (Learn=10, Chazara1=5, Chazara2=3, else 1).
 */
export function defaultPointsForStage(stageOrder: number): number {
  switch (stageOrder) {
    case 1: return 10;
    case 2: return 5;
    case 3: return 3;
    default: return 1;
  }
}

// ── Request / result types ────────────────────────────────────────────────────

export type DocMode = "create" | "upsert" | "update";

export interface GovernedDocPatch {
  collection: string;
  docId: string;
  /** Storage-named fields to set; `null` = remove (nullable fields only); `ended_at: true` = tombstone now. */
  fields: Record<string, unknown>;
  /** create: doc must be absent; update: doc must exist; upsert (default): either. */
  mode?: DocMode;
}

export interface GovernedEntryIntent {
  /** Client ULID for this change_log entry; server-generated when omitted. */
  id?: string;
  entity: GovernedEntity;
  /** Omit for mainTrack* entities to derive it from the docs' curriculum_id. */
  entityId?: string;
  docs: GovernedDocPatch[];
}

export interface LearningEventIntent {
  /** Client ULID — the learning_events doc id. */
  id: string;
  fields: Record<string, unknown>;
}

/** Reads available to an in-transaction plan builder. */
export interface PlanContext {
  txn: FirebaseFirestore.Transaction;
  profileRef: FirebaseFirestore.DocumentReference;
}

export interface GovernedPlan {
  entries: GovernedEntryIntent[];
  events?: LearningEventIntent[];
}

export interface GovernedWriteRequest {
  ownerUid: string;
  profileId: string;
  /** Tutor callers: the grant that authorises the write. */
  grantId?: string | null;
  /** Owner callers: asserted role, parent (default) or child. */
  actorRole?: unknown;
  /** The client ULID (Story 1.8 action id). Server-generated when omitted. */
  actionId?: string | null;
  revertsActionId?: string | null;
  entries?: GovernedEntryIntent[];
  events?: LearningEventIntent[];
  /**
   * Optional in-transaction expansion (e.g. remove-track enumerates the live
   * sub-tracks). Runs after authorisation, may only READ, and returns entries
   * appended after the static ones.
   */
  plan?: (ctx: PlanContext) => Promise<GovernedPlan>;
  /**
   * Stable identity of `plan` and its parameters (e.g. `removeTrack:{c}`),
   * part of the replay fingerprint. Required whenever `plan` is set: the
   * expansion depends on state at write time, so a replay compares the
   * request that produced it, never a re-run of the plan.
   */
  planKey?: string;
  /** owner-only rejects every non-owner caller (ownerOversizedGovernedWrite). */
  callerPolicy?: "owner-or-tutor" | "owner-only";
  /** Security-audit action label for tutor writes (tutor_grants/{id}/audit_log). */
  auditAction?: string;
}

export interface GovernedWriteResult {
  success: true;
  action_id: string;
  /** This action's change_log entry ids, sorted (a replay returns the same list). */
  change_ids: string[];
  event_ids: string[];
  /** Server-stamped `change_log.at` (ISO-8601), null when nothing was logged. */
  at: string | null;
  /** Server-stamped `learning_events.recorded_at` (ISO-8601), null when no event was written. */
  recorded_at: string | null;
  replayed: boolean;
  noop: boolean;
}

export interface Actor {
  uid: string;
  role: "parent" | "child" | "tutor";
  display_name: string;
}

// ── Errors & structured logging ───────────────────────────────────────────────

function reject(code: "invalid-argument" | "permission-denied" | "unauthenticated" |
  "not-found" | "failed-precondition" | "already-exists", message: string): never {
  throw new HttpsError(code, message);
}

/**
 * Logs a governed-write failure as `{entity, code}` only. Never pass a uid,
 * profile id, doc id, payload or message text here (AD-54).
 */
export function logGovernedFailure(entity: string, code: string): void {
  logger.warn("governed_write_rejected", { entity, code });
}

/**
 * Wraps a governed callable body: HttpsErrors are logged as `{entity, code}`
 * and re-thrown unchanged; anything else is logged as `{entity, code:
 * "internal"}` and surfaced as a generic internal error (no raw text leaks).
 */
export async function runGoverned<T>(entity: string, body: () => Promise<T>): Promise<T> {
  try {
    return await body();
  } catch (err) {
    if (err instanceof HttpsError) {
      logGovernedFailure(entity, err.code);
      throw err;
    }
    logGovernedFailure(entity, "internal");
    throw new HttpsError("internal", "Governed write failed");
  }
}

// ── ULIDs ─────────────────────────────────────────────────────────────────────

const CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/** Generates a ULID (48-bit ms time + 80 random bits, Crockford base32). */
export function newUlid(nowMs: number = Date.now()): string {
  let time = "";
  let t = nowMs;
  for (let i = 0; i < 10; i++) {
    time = CROCKFORD[t % 32] + time;
    t = Math.floor(t / 32);
  }
  const bytes = crypto.randomBytes(16);
  let rand = "";
  for (let i = 0; i < 16; i++) rand += CROCKFORD[bytes[i] % 32];
  return time + rand;
}

// ── Pure helpers ──────────────────────────────────────────────────────────────

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v) &&
    !(v instanceof admin.firestore.Timestamp);
}

export function isDocIdSafe(v: unknown): v is string {
  return typeof v === "string" && v.length > 0 && v.length <= 700 &&
    !v.includes("/") && v !== "." && v !== ".." && !/^__.*__$/.test(v);
}

function deepEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a instanceof admin.firestore.Timestamp || b instanceof admin.firestore.Timestamp) {
    return a instanceof admin.firestore.Timestamp && b instanceof admin.firestore.Timestamp && a.isEqual(b);
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length &&
      a.every((x, i) => deepEqual(x, b[i]));
  }
  if (isPlainObject(a) && isPlainObject(b)) {
    const ka = Object.keys(a);
    const kb = Object.keys(b);
    return ka.length === kb.length && ka.every((k) => deepEqual(a[k], b[k]));
  }
  return false;
}

/** `{collection}/{docId}.{field}` — the AD-38 before/after key. */
export function changeKey(collection: string, docId: string, field: string): string {
  return `${collection}/${docId}.${field}`;
}

function validateFields(collection: string, fields: unknown): Record<string, unknown> {
  const spec = FIELD_SPECS[collection];
  if (!spec) reject("invalid-argument", "Unknown governed collection");
  if (!isPlainObject(fields)) reject("invalid-argument", "fields must be an object");
  const keys = Object.keys(fields);
  if (keys.length === 0) reject("invalid-argument", "fields must not be empty");
  for (const key of keys) {
    const check = spec[key];
    if (!check) reject("invalid-argument", `Field not allowed on ${collection}: ${key}`);
    // Each spec states its own nullability (null = remove the field); a
    // null for a non-nullable field is rejected here.
    if (!check(fields[key])) {
      reject("invalid-argument", `Invalid value for ${collection}.${key}`);
    }
  }
  return fields;
}

function validateEntries(raw: unknown): GovernedEntryIntent[] {
  if (raw === undefined) return [];
  if (!Array.isArray(raw)) reject("invalid-argument", "entries must be an array");
  return raw.map((e): GovernedEntryIntent => {
    if (!isPlainObject(e)) reject("invalid-argument", "entry must be an object");
    if (!isGovernedEntity(e.entity)) reject("invalid-argument", "Unknown entity");
    const entity = e.entity;
    if (e.id !== undefined && (typeof e.id !== "string" || !ULID_RE.test(e.id))) {
      reject("invalid-argument", "entry id must be a ULID");
    }
    if (e.entityId !== undefined && !isDocIdSafe(e.entityId)) {
      reject("invalid-argument", "entityId must be a non-empty id");
    }
    if (e.entityId === undefined && !MAIN_TRACK_ENTITIES.has(entity)) {
      reject("invalid-argument", "entityId is required for this entity");
    }
    if (!Array.isArray(e.docs) || e.docs.length === 0) {
      reject("invalid-argument", "entry docs must be a non-empty array");
    }
    const collection = ENTITY_COLLECTION[entity];
    const docs = e.docs.map((d: unknown): GovernedDocPatch => {
      if (!isPlainObject(d)) reject("invalid-argument", "doc patch must be an object");
      if (d.collection !== collection) {
        reject("invalid-argument", `Entity ${entity} owns only ${collection}`);
      }
      if (!isDocIdSafe(d.docId)) reject("invalid-argument", "docId must be a valid document id");
      if (d.mode !== undefined && d.mode !== "create" && d.mode !== "upsert" && d.mode !== "update") {
        reject("invalid-argument", "mode must be create, upsert or update");
      }
      return {
        collection,
        docId: d.docId,
        fields: validateFields(collection, d.fields),
        mode: (d.mode as DocMode | undefined) ?? "upsert",
      };
    });
    return { id: e.id as string | undefined, entity, entityId: e.entityId as string | undefined, docs };
  });
}

function validateEvents(raw: unknown): LearningEventIntent[] {
  if (raw === undefined) return [];
  if (!Array.isArray(raw)) reject("invalid-argument", "events must be an array");
  return raw.map((ev): LearningEventIntent => {
    if (!isPlainObject(ev)) reject("invalid-argument", "event must be an object");
    if (typeof ev.id !== "string" || !ULID_RE.test(ev.id)) {
      reject("invalid-argument", "event id must be a ULID");
    }
    const fields = ev.fields;
    if (!isPlainObject(fields)) reject("invalid-argument", "event fields must be an object");
    const spec = fields.kind === "learn" ? EVENT_LEARN_FIELDS
      : fields.kind === "void" ? EVENT_VOID_FIELDS
        : reject("invalid-argument", "event kind must be learn or void");
    for (const [key, value] of Object.entries(fields)) {
      const check = spec[key];
      if (!check) reject("invalid-argument", `Field not allowed on a ${fields.kind} event: ${key}`);
      if (!check(value)) reject("invalid-argument", `Invalid value for learning_events.${key}`);
    }
    if (fields.kind === "learn") {
      for (const req of ["curriculum_id", "ref", "source", "date_state"]) {
        if (fields[req] === undefined) reject("invalid-argument", `learn event requires ${req}`);
      }
      const beforeTracking = fields.date_state === "before_tracking";
      if (!beforeTracking && fields.level !== undefined) {
        reject("invalid-argument", "level is only allowed on before_tracking events");
      }
      if (!beforeTracking && !date(fields.learned_on)) {
        reject("invalid-argument", "dated and catch_up events require learned_on");
      }
      if (fields.stage !== undefined && fields.source !== "main") {
        reject("invalid-argument", "stage is only allowed on source = main");
      }
      if (typeof fields.original_recorded_at === "string" &&
        Date.parse(fields.original_recorded_at) > Date.now() + 10 * 60 * 1000) {
        reject("invalid-argument", "original_recorded_at is in the future");
      }
    } else if (fields.target_id === undefined) {
      reject("invalid-argument", "void event requires target_id");
    }
    return { id: ev.id, fields };
  });
}

// ── Final-state validation (AD-43 / AD-45 / AD-52 required fields) ────────────

function isLive(state: Record<string, unknown>): boolean {
  return state.ended_at === undefined || state.ended_at === null;
}

function validateFinalState(
  collection: string,
  docId: string,
  state: Record<string, unknown>,
  prior: Record<string, unknown> | null,
): void {
  // Checked before the tombstone early return: the lifecycle pair is the one
  // shape a tombstoned sub-track still has to hold.
  if (collection === "sub_tracks") validateSubTrackLifecycle(state, prior);
  if (!isLive(state)) return; // a tombstoned doc needs no further shape
  for (const f of REQUIRED_LIVE_FIELDS[collection] ?? []) {
    if (state[f] === undefined || state[f] === null) {
      reject("invalid-argument", `A live ${collection} doc requires ${f}`);
    }
  }
  switch (collection) {
    case "goals": {
      // AD-43: fixed ids {curriculumId}_deadline / {curriculumId}_pace.
      const m = /^(.+)_(deadline|pace)$/.exec(docId);
      if (!m) reject("invalid-argument", "goal id must be {curriculumId}_deadline or {curriculumId}_pace");
      if (state.curriculum_id !== m[1]) reject("invalid-argument", "goal curriculum_id must match its id");
      if (state.goal_type !== m[2]) reject("invalid-argument", "goal_type must match the goal id");
      if (m[2] === "deadline" && !date(state.target_date)) {
        reject("invalid-argument", "a deadline goal requires target_date");
      }
      if (m[2] === "pace" && !(posNum(state.pace_value) && str(64)(state.pace_unit) &&
        str(64)(state.pace_granularity))) {
        reject("invalid-argument", "a pace goal requires pace_value, pace_unit and pace_granularity");
      }
      break;
    }
    case "profile_programs":
      if (state.program_id !== undefined && state.program_id !== null && !date(state.tracking_start_date)) {
        reject("invalid-argument", "tracking_start_date is required when program_id is set");
      }
      break;
    case "sub_tracks": {
      // AD-52 required fields on a live sub-track (create, edit or re-add).
      for (const f of ["curriculum_id", "name", "type", "window_start", "rate_per_week",
        "weeks_per_year", "learns_on_shabbos", "ground"]) {
        if (state[f] === undefined || state[f] === null) {
          reject("invalid-argument", `A live sub_tracks doc requires ${f}`);
        }
      }
      const school = state.type === "school_year";
      if (school !== (state.academic_year !== undefined && state.academic_year !== null)) {
        reject("invalid-argument", "academic_year is required for, and only for, a school_year sub-track");
      }
      // AC-5 intent shape (Story 2.1); AD-45 limits are checked across docs
      // after the diff loop, against the transactional sibling set.
      const shape = subTrackIntentViolations(state);
      if (shape.length) rejectSubTrack("invalid-argument", shape);
      break;
    }
    default:
      break;
  }
}

/**
 * Rejects an AD-45 sub-track violation with its stable wire codes in
 * `details.sub_track_violations` (the same codes as the Dart
 * `SubTrackLimit.code`).
 */
function rejectSubTrack(code: "invalid-argument" | "failed-precondition", violations: SubTrackViolation[]): never {
  const codes = subTrackViolationCodes(violations);
  throw new HttpsError(code, `Sub-track rule violated: ${codes.join(", ")}`, { sub_track_violations: codes });
}

/**
 * AD-52 sub-track lifecycle: `ended_at` and `end_reason` are a coupled pair.
 * A live sub-track carries neither; an ended one carries both. Ending writes
 * both, re-adding clears both, and an ended sub-track's `end_reason` changes
 * only when `ended_at` does (a repeated end/delete of an ended sub-track is a
 * no-op upstream, so this only rejects a bare reason rewrite).
 */
function validateSubTrackLifecycle(
  state: Record<string, unknown>,
  prior: Record<string, unknown> | null,
): void {
  const ended = !isLive(state);
  const hasReason = state.end_reason !== undefined && state.end_reason !== null;
  if (ended && !hasReason) {
    reject("invalid-argument", "An ended sub_tracks doc requires end_reason");
  }
  if (!ended && hasReason) {
    reject("invalid-argument", "A live sub_tracks doc cannot carry end_reason");
  }
  if (ended && prior !== null && !isLive(prior) && !deepEqual(state.end_reason, prior.end_reason ?? null)) {
    reject("invalid-argument", "end_reason can change only together with ended_at");
  }
}

function hasCalendarProgram(state: Record<string, unknown> | null): boolean {
  if (!state || !isLive(state)) return false;
  return typeof state.program_id === "string" && state.program_id.length > 0;
}

// ── Actor / authorisation ─────────────────────────────────────────────────────

interface AuthLike {
  uid: string;
}

async function resolveActor(
  txn: FirebaseFirestore.Transaction,
  auth: AuthLike,
  req: GovernedWriteRequest,
): Promise<{ actor: Actor; grantRef: FirebaseFirestore.DocumentReference | null }> {
  if (auth.uid === req.ownerUid) {
    const role = req.actorRole ?? "parent";
    if (role !== "parent" && role !== "child") {
      reject("invalid-argument", "actorRole must be parent or child");
    }
    const account = await txn.get(db.collection("users").doc(auth.uid));
    const displayName = account.exists ? account.get("display_name") : undefined;
    return {
      actor: { uid: auth.uid, role, display_name: typeof displayName === "string" ? displayName : "" },
      grantRef: null,
    };
  }
  if (req.callerPolicy === "owner-only") {
    reject("permission-denied", "Only the profile owner may call this function");
  }
  if (typeof req.grantId !== "string" || !isDocIdSafe(req.grantId)) {
    reject("permission-denied", "No grant for this profile");
  }
  const grantRef = db.collection("tutor_grants").doc(req.grantId);
  const grantSnap = await txn.get(grantRef);
  const grant = grantSnap.data();
  if (!grant ||
    grant.state !== "active" ||
    grant.tutor_uid !== auth.uid ||
    grant.parent_uid !== req.ownerUid ||
    String(grant.child_profile_id) !== req.profileId) {
    reject("permission-denied", "No active grant for this profile");
  }
  if (grant.permissions?.can_edit_learning !== true) {
    reject("permission-denied", "Grant lacks can_edit_learning");
  }
  const name = grant.tutor_name_snapshot;
  return {
    actor: { uid: auth.uid, role: "tutor", display_name: typeof name === "string" ? name : "" },
    grantRef,
  };
}

// ── Idempotent replay ─────────────────────────────────────────────────────────

function timestampIso(v: unknown): string | null {
  return v instanceof admin.firestore.Timestamp ? v.toDate().toISOString() : null;
}

/** JSON with object keys sorted, so equal requests serialise identically. */
function canonicalJson(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(canonicalJson).join(",")}]`;
  if (isPlainObject(v)) {
    return `{${Object.keys(v).sort()
      .filter((k) => v[k] !== undefined)
      .map((k) => `${JSON.stringify(k)}:${canonicalJson(v[k])}`).join(",")}}`;
  }
  return JSON.stringify(v ?? null);
}

/**
 * The replay fingerprint: a hash of everything the client asked for — every
 * entry's id, entity and entity id, every doc's collection, id, mode and
 * fields, the plan identity, every event's id and fields, the revert target
 * and the callable's audit action. Two requests alias one action only when
 * this matches exactly.
 */
function requestFingerprint(
  req: GovernedWriteRequest,
  entries: GovernedEntryIntent[],
  events: LearningEventIntent[],
): string {
  const canonical = canonicalJson({
    v: 1,
    audit: req.auditAction ?? null,
    reverts: req.revertsActionId ?? null,
    plan: req.planKey ?? null,
    entries: entries.map((e) => ({
      id: e.id ?? null,
      entity: e.entity,
      entityId: e.entityId ?? null,
      docs: e.docs.map((d) => ({
        collection: d.collection, docId: d.docId, mode: d.mode ?? "upsert", fields: d.fields,
      })),
    })),
    events: events.map((ev) => ({ id: ev.id, fields: ev.fields })),
  });
  return crypto.createHash("sha256").update(canonical).digest("hex");
}

/** Server-only per-action receipt (AD-38 idempotency); never client-readable. */
export const RECEIPTS_COLLECTION = "governed_action_receipts";

/**
 * An existing learning event may be replayed only by its own actor with the
 * identical payload (events are immutable): every client field must match the
 * stored doc and the stored doc may carry no other client field.
 */
function assertEventReplay(
  snap: FirebaseFirestore.DocumentSnapshot,
  ev: LearningEventIntent,
  actor: Actor,
): void {
  const stored = snap.data() ?? {};
  const differs = () => reject("already-exists", "This event id was already used for a different event");
  if (stored.actor?.uid !== actor.uid || stored.actor?.role !== actor.role) differs();
  const storedKeys = Object.keys(stored).filter((k) => k !== "recorded_at" && k !== "actor");
  const mineKeys = Object.keys(ev.fields);
  if (storedKeys.length !== mineKeys.length || !mineKeys.every((k) => k in stored)) differs();
  for (const k of mineKeys) {
    const mine = ev.fields[k];
    const theirs = stored[k];
    if (k === "original_recorded_at") {
      const iso = timestampIso(theirs);
      if (iso === null || Date.parse(iso) !== Date.parse(String(mine))) differs();
    } else if (!deepEqual(mine, theirs)) {
      differs();
    }
  }
}

// ── The helper ────────────────────────────────────────────────────────────────

interface PlannedEntry {
  id: string;
  entity: GovernedEntity;
  entityId: string;
  writes: Array<{ ref: FirebaseFirestore.DocumentReference; data: Record<string, unknown> }>;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
}

/**
 * The shared governed write. See the module header for the contract.
 *
 * @param auth  the callable's `request.auth` (undefined → unauthenticated).
 * @param req   owner/profile, the caller's grant (tutor) or role (owner), the
 *              client ULID, and the storage-shaped entries/events.
 */
export async function writeWithChangeLog(
  auth: AuthLike | undefined | null,
  req: GovernedWriteRequest,
): Promise<GovernedWriteResult> {
  if (!auth?.uid) reject("unauthenticated", "Must be signed in");
  if (!isDocIdSafe(req.ownerUid)) reject("invalid-argument", "ownerUid must be a non-empty string");
  if (!isDocIdSafe(req.profileId)) reject("invalid-argument", "profileId must be a non-empty string (ULID)");
  if (req.actionId !== undefined && req.actionId !== null &&
    (typeof req.actionId !== "string" || !ULID_RE.test(req.actionId))) {
    reject("invalid-argument", "actionId must be a ULID");
  }
  if (req.revertsActionId !== undefined && req.revertsActionId !== null &&
    (typeof req.revertsActionId !== "string" || !ULID_RE.test(req.revertsActionId))) {
    reject("invalid-argument", "revertsActionId must be a ULID");
  }
  const staticEntries = validateEntries(req.entries);
  const staticEvents = validateEvents(req.events);
  if (staticEntries.length === 0 && staticEvents.length === 0 && !req.plan) {
    reject("invalid-argument", "Nothing to write");
  }

  // The replay key is the ACTION id the client supplied: the request actionId
  // (Story 1.8 owner-port action id, B13) or, without one, the first entry's
  // client ULID (which then is the action id). Every change_log entry of the
  // action carries it as `action_id`, whichever entry ids were assigned and
  // whichever entries turned out to be no-ops, so a retry always finds the
  // stored action. Null when the client supplied neither: the server
  // generates an id and there is no cross-call replay protection.
  const clientActionId: string | null = req.actionId ?? staticEntries[0]?.id ?? null;
  const actionId: string = clientActionId ?? newUlid();
  if (req.plan && (typeof req.planKey !== "string" || req.planKey.length === 0)) {
    reject("invalid-argument", "A planned write needs a planKey");
  }
  const fingerprint = requestFingerprint(req, staticEntries, staticEvents);

  const profileRef = db.collection("users").doc(req.ownerUid)
    .collection("learner_profiles").doc(req.profileId);

  const receiptRef = profileRef.collection(RECEIPTS_COLLECTION).doc(actionId);

  type Outcome =
    | { kind: "replay"; changeIds: string[]; eventIds: string[]; noop: boolean }
    | {
      kind: "written"; changeIds: string[]; eventIds: string[];
      newEventIds: string[]; replayedEventIds: string[];
    };

  const outcome: Outcome = await db.runTransaction(async (txn): Promise<Outcome> => {
    // ── 1. Authorise (re-read every call, so revocation stops the next one) ──
    const { actor, grantRef } = await resolveActor(txn, auth, req);
    const profileSnap = await txn.get(profileRef);
    if (!profileSnap.exists) reject("not-found", "Learner profile not found");

    // ── 2. Idempotent replay on the client action id ─────────────────────────
    // The receipt is the durable record of the action — written even when
    // the action changed nothing — so a retry is recognised whatever the
    // state has become since, and is never re-planned against new state.
    if (clientActionId) {
      const receipt = await txn.get(receiptRef);
      if (receipt.exists) {
        const r = receipt.data()!;
        if (r.actor?.uid !== actor.uid || r.actor?.role !== actor.role || r.fingerprint !== fingerprint) {
          reject("already-exists", "This change id was already used for a different change");
        }
        return {
          kind: "replay",
          changeIds: Array.isArray(r.change_ids) ? r.change_ids.map(String) : [],
          eventIds: Array.isArray(r.event_ids) ? r.event_ids.map(String) : [],
          noop: r.noop === true,
        };
      }
      // No receipt: the id must not already belong to an action written
      // elsewhere (e.g. an owner-path batch carrying this action_id) …
      const members = await txn.get(
        profileRef.collection("change_log").where("action_id", "==", actionId).limit(1));
      if (!members.empty) {
        reject("already-exists", "This change id was already used for a different change");
      }
      // … and none of its client ULIDs may already name an entry of a
      // different action (never overwritten).
      const claimed = [...new Set([actionId, ...staticEntries.flatMap((e) => (e.id ? [e.id] : []))])];
      const claimedSnaps = await txn.getAll(
        ...claimed.map((id) => profileRef.collection("change_log").doc(id)));
      if (claimedSnaps.some((snap) => snap.exists)) {
        reject("already-exists", "This change id was already used for a different change");
      }
    }

    // ── 3. In-transaction expansion (reads only) ─────────────────────────────
    let entries = staticEntries;
    let events = staticEvents;
    if (req.plan) {
      const planned = await req.plan({ txn, profileRef });
      entries = [...entries, ...validateEntries(planned.entries)];
      events = [...events, ...validateEvents(planned.events)];
    }
    const docCount = entries.reduce((n, e) => n + e.docs.length, 0);
    const pointsCount = events.filter((ev) => earnsPointsEntry(ev.fields)).length;
    if (docCount + entries.length + events.length + pointsCount > MAX_WRITES_PER_CALL) {
      reject("invalid-argument", "Too many writes for one call");
    }

    // ── 4. Read every target doc, void target and calendar program ───────────
    const docRef = (collection: string, docId: string) =>
      collection === "learner_profiles" ? profileRef : profileRef.collection(collection).doc(docId);
    const seenDocs = new Set<string>();
    const seenEntities = new Set<string>();
    for (const e of entries) {
      if (e.entity === "learnerSettings" && (e.entityId !== req.profileId ||
        e.docs.some((d) => d.docId !== req.profileId))) {
        reject("invalid-argument", "learnerSettings must target this profile");
      }
      for (const d of e.docs) {
        const k = `${d.collection}/${d.docId}`;
        if (seenDocs.has(k)) reject("invalid-argument", "A doc may appear only once per call");
        seenDocs.add(k);
      }
    }
    const allDocs = entries.flatMap((e) => e.docs);
    const snaps = allDocs.length ? await txn.getAll(...allDocs.map((d) => docRef(d.collection, d.docId))) : [];
    const current = new Map<string, Record<string, unknown> | null>();
    allDocs.forEach((d, i) => {
      current.set(`${d.collection}/${d.docId}`, snaps[i].exists ? snaps[i].data()! : null);
    });

    const eventRefs = events.map((ev) => profileRef.collection("learning_events").doc(ev.id));
    const voidTargets = events
      .filter((ev) => ev.fields.kind === "void")
      .map((ev) => String(ev.fields.target_id));
    const eventSnaps = eventRefs.length ? await txn.getAll(...eventRefs) : [];
    const targetSnaps = voidTargets.length
      ? await txn.getAll(...voidTargets.map((t) => profileRef.collection("learning_events").doc(t)))
      : [];

    // ── 5. Compute field-level diffs and validate final states ───────────────
    const planned: PlannedEntry[] = [];
    const finalStates = new Map<string, Record<string, unknown>>();
    const goalCurricula: string[] = [];
    for (const e of entries) {
      const before: Record<string, unknown> = {};
      const after: Record<string, unknown> = {};
      const writes: PlannedEntry["writes"] = [];
      let entityId = e.entityId;
      for (const d of e.docs) {
        const key = `${d.collection}/${d.docId}`;
        const cur = current.get(key) ?? null;
        if (d.mode === "create" && cur !== null) {
          reject("already-exists", "Create target already exists");
        }
        if (d.mode === "update" && cur === null) reject("not-found", "Update target does not exist");
        const patch = { ...d.fields };
        const tombstoneOnly = Object.keys(patch).every((f) => f === "ended_at" || f === "end_reason") &&
          patch.ended_at === TOMBSTONE;
        if (cur === null && tombstoneOnly) continue; // nothing to remove
        // Already ended (end, delete, undo or track removal): a repeated
        // tombstone is a no-op and never rewrites the stored end_reason.
        if (cur !== null && !isLive(cur) && tombstoneOnly) continue;
        if (cur === null && patch.ended_at === TOMBSTONE) {
          reject("invalid-argument", "Cannot create a tombstoned doc");
        }
        // AD-38: mainTrack* docs carry a required, immutable curriculum_id.
        if (MAIN_TRACK_ENTITIES.has(e.entity) || e.entity === "goal" || e.entity === "subTrack") {
          const stored = cur?.curriculum_id;
          if (stored !== undefined && patch.curriculum_id !== undefined && patch.curriculum_id !== stored) {
            reject("invalid-argument", "curriculum_id is immutable");
          }
          if (cur === null && patch.curriculum_id === undefined) {
            const derived = e.entity === "goal" ? /^(.+)_(deadline|pace)$/.exec(d.docId)?.[1]
              : MAIN_TRACK_ENTITIES.has(e.entity) ? entityId : undefined;
            if (!derived) reject("invalid-argument", "curriculum_id is required on create");
            patch.curriculum_id = derived;
          }
        }
        const finalState: Record<string, unknown> = { ...(cur ?? {}) };
        const data: Record<string, unknown> = {};
        for (const [field, value] of Object.entries(patch)) {
          const old = cur?.[field] ?? null;
          if (field === "ended_at" && value === TOMBSTONE) {
            if (old !== null) continue; // already ended: never re-tombstone
            data[field] = admin.firestore.FieldValue.serverTimestamp();
            finalState[field] = "__pending__";
          } else {
            if (deepEqual(old, value)) continue;
            data[field] = value === null ? admin.firestore.FieldValue.delete() : value;
            if (value === null) delete finalState[field];
            else finalState[field] = value;
          }
          before[changeKey(d.collection, d.docId, field)] = old;
          after[changeKey(d.collection, d.docId, field)] =
            value === TOMBSTONE && field === "ended_at" ? admin.firestore.FieldValue.serverTimestamp() : value;
        }
        if (MAIN_TRACK_ENTITIES.has(e.entity)) {
          const cid = finalState.curriculum_id;
          if (typeof cid !== "string") reject("invalid-argument", "curriculum_id is required");
          if (entityId === undefined) entityId = cid;
          if (cid !== entityId) reject("invalid-argument", "entity_id must be the docs' curriculum_id");
          if ((e.entity === "mainTrack" || e.entity === "mainTrackProgram") && d.docId !== entityId) {
            reject("invalid-argument", "This entity's doc id must be its curriculum id");
          }
        } else if ((e.entity === "goal" || e.entity === "subTrack") && d.docId !== entityId) {
          reject("invalid-argument", "entity_id must be the doc id");
        }
        validateFinalState(d.collection, d.docId, finalState, cur);
        finalStates.set(key, finalState);
        if (e.entity === "goal" && isLive(finalState)) goalCurricula.push(String(finalState.curriculum_id));
        if (Object.keys(data).length > 0) writes.push({ ref: docRef(d.collection, d.docId), data });
      }
      if (entityId === undefined) {
        // Every doc was a no-op tombstone of an absent doc.
        continue;
      }
      const entityKey = `${e.entity}/${entityId}`;
      if (seenEntities.has(entityKey)) reject("invalid-argument", "One entry per entity per action");
      seenEntities.add(entityKey);
      if (writes.length === 0) continue; // nothing changed for this entity
      planned.push({ id: e.id ?? "", entity: e.entity, entityId, writes, before, after });
    }

    // AD-43 / AD-45: goals are rejected on a calendar-program curriculum,
    // judged on the transactional program state after this call's patches.
    const uniqueGoalCurricula = [...new Set(goalCurricula)];
    if (uniqueGoalCurricula.length) {
      const programSnaps = await txn.getAll(
        ...uniqueGoalCurricula.map((c) => profileRef.collection("profile_programs").doc(c)));
      uniqueGoalCurricula.forEach((c, i) => {
        const state = finalStates.get(`profile_programs/${c}`) ??
          (programSnaps[i].exists ? programSnaps[i].data()! : null);
        if (hasCalendarProgram(state)) {
          reject("failed-precondition", "Goals are not allowed on a calendar-program curriculum");
        }
      });
    }

    // AD-45 (Story 2.1): sub-track limits and the calendar-program exclusion
    // in both directions, judged per profile and curriculum on the
    // transactional state after this call's patches. Single-field equality
    // queries only — no index is added (AD-54).
    await validateSubTrackRules(txn, profileRef, profileSnap.get("time_zone"), current, finalStates);

    // AD-31: a void's target must be a learn event (an absent target is fine).
    const requestKinds = new Map(events.map((ev) => [ev.id, ev.fields.kind]));
    voidTargets.forEach((t, i) => {
      const kind = targetSnaps[i].exists ? targetSnaps[i].get("kind") : requestKinds.get(t);
      if (kind !== undefined && kind !== "learn") {
        reject("invalid-argument", "A void must target a learn event");
      }
    });

    // Learning events are idempotent on their own ULID doc id: an existing
    // event by the same actor is a replay, part of this action's result.
    const newEvents: LearningEventIntent[] = [];
    const replayedEventIds: string[] = [];
    events.forEach((ev, i) => {
      const snap = eventSnaps[i];
      if (!snap.exists) {
        newEvents.push(ev);
        return;
      }
      assertEventReplay(snap, ev, actor);
      replayedEventIds.push(ev.id);
    });

    // AD-50: the amount for each new points-earning event, read in this
    // transaction (stage ?? the curriculum's first live stage_order, then its
    // point_configs override or the default ladder).
    const pointsEvents = newEvents.filter((ev) => earnsPointsEntry(ev.fields));
    const pointsAmount = await resolvePointsAmounts(txn, profileRef, pointsEvents);

    // ── 6. Assign entry ids (first written entry carries the action id) ──────
    planned.forEach((p, i) => {
      if (!p.id) p.id = i === 0 ? actionId : newUlid();
    });
    const ids = planned.map((p) => p.id);
    if (new Set(ids).size !== ids.length) reject("invalid-argument", "Duplicate change ids");

    // ── 7. Write: docs + entries + events + receipt, all in this transaction ─
    const serverNow = admin.firestore.FieldValue.serverTimestamp();
    const changeIds = [...ids].sort();
    if (clientActionId) {
      // Immutable: txn.create fails (and the transaction retries into the
      // replay branch above) if a concurrent call claimed the id first.
      txn.create(receiptRef, {
        actor: { uid: actor.uid, role: actor.role },
        fingerprint,
        change_ids: changeIds,
        event_ids: events.map((ev) => ev.id),
        noop: changeIds.length === 0 && newEvents.length === 0 && replayedEventIds.length === 0,
        at: serverNow,
      });
    }
    for (const p of planned) {
      for (const w of p.writes) {
        const data = { ...w.data, last_change_id: p.id };
        txn.set(w.ref, data, { mergeFields: Object.keys(data) });
      }
      const entry: Record<string, unknown> = {
        entity: p.entity,
        entity_id: p.entityId,
        action_id: actionId,
        before: p.before,
        after: p.after,
        at: serverNow,
        actor,
      };
      if (req.revertsActionId) entry.reverts_action_id = req.revertsActionId;
      txn.create(profileRef.collection("change_log").doc(p.id), entry);
    }
    for (const ev of newEvents) {
      const data: Record<string, unknown> = { ...ev.fields, recorded_at: serverNow, actor };
      if (typeof ev.fields.original_recorded_at === "string") {
        data.original_recorded_at = admin.firestore.Timestamp.fromDate(new Date(ev.fields.original_recorded_at));
      }
      txn.create(profileRef.collection("learning_events").doc(ev.id), data);
    }
    for (const ev of pointsEvents) {
      // The existing points_ledger entry shape plus `event_id`; created_at is
      // the same commit-time stamp as the event's recorded_at.
      txn.create(profileRef.collection("points_ledger").doc(pointsDocId(ev.id)), {
        ulid: pointsDocId(ev.id),
        entry_kind: "completion",
        delta: pointsAmount.get(ev.id)!,
        created_at: serverNow,
        source: "live",
        event_id: ev.id,
      });
    }
    // Security audit only (AD-38 History): who wrote what, when — the change
    // itself lives in change_log, so no before/after values are copied here.
    if (grantRef && planned.length > 0) {
      txn.set(grantRef.collection("audit_log").doc(actionId), {
        tutor_uid: actor.uid,
        tutor_name_snapshot: actor.display_name,
        action: req.auditAction ?? "governed_write",
        target: `profile/${req.profileId}/${planned[0].entity}/${planned[0].entityId}`,
        before_value: null,
        after_value: null,
        timestamp: new Date().toISOString(),
      });
    }
    return {
      kind: "written",
      // Sorted, exactly as the receipt stores them for a replay.
      changeIds,
      eventIds: events.map((ev) => ev.id),
      newEventIds: newEvents.map((e) => e.id),
      replayedEventIds,
    };
  });

  const wroteNothing = outcome.kind === "written" &&
    outcome.changeIds.length === 0 && outcome.newEventIds.length === 0;
  // A retry whose action is already stored — its change_log entries, or (for
  // an events-only action) its learning events — returns the stored result.
  const replayed = outcome.kind === "replay" ||
    (wroteNothing && outcome.replayedEventIds.length > 0);
  const noop = outcome.kind === "replay" ? outcome.noop : wroteNothing && !replayed;
  const eventIds = outcome.eventIds;

  // Read back the server-stamped times (serverTimestamp resolves at commit).
  const firstChange = outcome.changeIds[0];
  const firstEvent = eventIds[0];
  const [changeSnap, eventSnap] = await Promise.all([
    firstChange ? profileRef.collection("change_log").doc(firstChange).get() : Promise.resolve(null),
    firstEvent ? profileRef.collection("learning_events").doc(firstEvent).get() : Promise.resolve(null),
  ]);
  return {
    success: true,
    action_id: actionId,
    change_ids: outcome.changeIds,
    event_ids: eventIds,
    at: changeSnap ? timestampIso(changeSnap.get("at")) : null,
    recorded_at: eventSnap ? timestampIso(eventSnap.get("recorded_at")) : null,
    replayed,
    noop,
  };
}

/**
 * The AD-45 cross-document checks for every sub-track and calendar program
 * this call writes. `current` holds each target doc as stored before the
 * call, `finalStates` its state after the call's patches. Reads only
 * (transaction-safe).
 */
async function validateSubTrackRules(
  txn: admin.firestore.Transaction,
  profileRef: admin.firestore.DocumentReference,
  timeZone: unknown,
  current: Map<string, Record<string, unknown> | null>,
  finalStates: Map<string, Record<string, unknown>>,
): Promise<void> {
  const prefix = (k: string, c: string) => k.startsWith(`${c}/`) ? k.slice(c.length + 1) : null;
  const tracks: SubTrackRow[] = [];
  const programs: Array<{ curriculumId: string; programId: string }> = [];
  for (const [key, state] of finalStates) {
    const trackId = prefix(key, "sub_tracks");
    if (trackId !== null) tracks.push({ id: trackId, data: state });
    const programDoc = prefix(key, "profile_programs");
    if (programDoc !== null && hasCalendarProgram(state)) {
      const before = current.get(key) ?? null;
      const newlySet = !hasCalendarProgram(before) || before?.program_id !== state.program_id;
      if (newlySet) programs.push({ curriculumId: String(state.curriculum_id ?? programDoc), programId: String(state.program_id) });
    }
  }
  const candidates = tracks.filter((t) => isLive(t.data));
  const curricula = [...new Set([
    ...candidates.map((t) => String(t.data.curriculum_id)),
    ...programs.map((p) => p.curriculumId),
  ])];
  if (curricula.length === 0) return;

  // Every sub-track of each affected curriculum, overlaid with this call's
  // final states (a sub-track ended in the same call no longer counts).
  const siblingsOf = new Map<string, SubTrackRow[]>();
  for (const c of curricula) {
    const snap = await txn.get(profileRef.collection("sub_tracks").where("curriculum_id", "==", c));
    const rows = new Map<string, Record<string, unknown>>(snap.docs.map((d) => [d.id, d.data()]));
    for (const t of tracks) if (t.data.curriculum_id === c) rows.set(t.id, t.data);
    siblingsOf.set(c, [...rows].map(([id, data]) => ({ id, data })));
  }

  for (const p of programs) {
    const violations = calendarProgramSetViolations({
      curriculumId: p.curriculumId, programId: p.programId, subTracks: siblingsOf.get(p.curriculumId) ?? [],
    });
    if (violations.length) rejectSubTrack("failed-precondition", violations);
  }

  if (candidates.length === 0) return;
  const today = civilDateIn(timeZone, new Date());
  const programIds = new Map<string, string | null>();
  const createdCurricula = [...new Set(candidates
    .filter((t) => (current.get(`sub_tracks/${t.id}`) ?? null) === null)
    .map((t) => String(t.data.curriculum_id)))];
  if (createdCurricula.length) {
    const programSnaps = await txn.getAll(
      ...createdCurricula.map((c) => profileRef.collection("profile_programs").doc(c)));
    createdCurricula.forEach((c, i) => {
      const state = finalStates.get(`profile_programs/${c}`) ??
        (programSnaps[i].exists ? programSnaps[i].data()! : null);
      programIds.set(c, hasCalendarProgram(state) ? String(state!.program_id) : null);
    });
  }
  for (const t of candidates) {
    const c = String(t.data.curriculum_id);
    const prior = current.get(`sub_tracks/${t.id}`) ?? null;
    const violations = subTrackLimitViolations({
      candidate: t,
      prior,
      siblings: siblingsOf.get(c) ?? [],
      today,
      calendarProgramId: programIds.get(c) ?? null,
    });
    if (violations.length) rejectSubTrack("failed-precondition", violations);
  }
}

/**
 * Resolves the AD-50 amount for each points-earning event:
 * `point_configs[curriculum, stage ?? firstStageOrder]`, where
 * firstStageOrder is the lowest live `stage_definitions.stage_order` of the
 * curriculum (1 when none is configured), falling back to the default ladder
 * when no override doc exists. Reads only (transaction-safe).
 */
async function resolvePointsAmounts(
  txn: FirebaseFirestore.Transaction,
  profileRef: FirebaseFirestore.DocumentReference,
  events: LearningEventIntent[],
): Promise<Map<string, number>> {
  const amounts = new Map<string, number>();
  if (events.length === 0) return amounts;
  const firstStage = new Map<string, number>();
  const needFirst = [...new Set(events
    .filter((ev) => ev.fields.stage === undefined)
    .map((ev) => String(ev.fields.curriculum_id)))];
  for (const c of needFirst) {
    const stages = await txn.get(profileRef.collection("stage_definitions").where("curriculum_id", "==", c));
    const orders = stages.docs
      .filter((d) => isLive(d.data()))
      .map((d) => d.get("stage_order"))
      .filter((o): o is number => typeof o === "number" && Number.isInteger(o));
    firstStage.set(c, orders.length ? Math.min(...orders) : 1);
  }
  const keyOf = (ev: LearningEventIntent) => {
    const c = String(ev.fields.curriculum_id);
    const stage = ev.fields.stage === undefined ? firstStage.get(c)! : (ev.fields.stage as number);
    return { c, stage, id: `${c}_${stage}` };
  };
  const configIds = [...new Set(events.map((ev) => keyOf(ev).id))];
  const configSnaps = await txn.getAll(
    ...configIds.map((id) => profileRef.collection("point_configs").doc(id)));
  const configured = new Map<string, number>();
  configSnaps.forEach((snap, i) => {
    const pts = snap.exists ? snap.get("points") : undefined;
    if (typeof pts === "number" && Number.isInteger(pts) && pts >= 1) configured.set(configIds[i], pts);
  });
  for (const ev of events) {
    const k = keyOf(ev);
    amounts.set(ev.id, configured.get(k.id) ?? defaultPointsForStage(k.stage));
  }
  return amounts;
}

// ── Named multi-entity action: remove track (AD-38 Track lifecycle) ───────────

/**
 * Remove track: one `mainTrack` entry setting `ended_at` on the
 * curriculum_tracks doc only, plus one `subTrack` tombstone entry
 * (`end_reason = track_deleted`) per non-ended sub-track of that curriculum,
 * all under one action_id. Other governed docs are left alone — readers treat
 * them as ended while the track has `ended_at`. Nothing is hard-deleted.
 * An already-ended or absent track is a no-op.
 */
/** The replay identity of {@link removeTrackPlan} for a curriculum. */
export function removeTrackPlanKey(curriculumId: string): string {
  return `removeTrack:${curriculumId}`;
}

export function removeTrackPlan(curriculumId: string): (ctx: PlanContext) => Promise<GovernedPlan> {
  return async ({ txn, profileRef }) => {
    const track = await txn.get(profileRef.collection("curriculum_tracks").doc(curriculumId));
    if (!track.exists || !isLive(track.data()!)) return { entries: [] };
    const subTracks = await txn.get(
      profileRef.collection("sub_tracks").where("curriculum_id", "==", curriculumId));
    const live = subTracks.docs.filter((d) => isLive(d.data())).sort((a, b) => a.id.localeCompare(b.id));
    return {
      entries: [
        {
          entity: "mainTrack",
          entityId: curriculumId,
          docs: [{ collection: "curriculum_tracks", docId: curriculumId, fields: { ended_at: TOMBSTONE } }],
        },
        ...live.map((d): GovernedEntryIntent => ({
          entity: "subTrack",
          entityId: d.id,
          docs: [{
            collection: "sub_tracks",
            docId: d.id,
            fields: { ended_at: TOMBSTONE, end_reason: "track_deleted" },
          }],
        })),
      ],
    };
  };
}

// ── Wire codec for owner governed actions (Story 1.8 OversizedGovernedWritePort) ──

export interface GovernedActionWire {
  profileId: string;
  actorRole?: "parent" | "child";
  actionId?: string;
  revertsActionId?: string;
  entries: Array<{
    id: string;
    entity: GovernedEntity;
    entityId: string;
    docs: Array<{ collection: string; docId: string; fields: Record<string, unknown>; mode?: DocMode }>;
  }>;
}

/**
 * Decodes the owner-action wire payload (the Story 1.8 owner intent/patch
 * shape). Structural only — field validation happens in writeWithChangeLog.
 * The contract fixture lives at test/fixtures/governed_write_contract/.
 */
export function decodeGovernedActionWire(data: unknown): GovernedActionWire {
  if (!isPlainObject(data)) reject("invalid-argument", "request must be an object");
  const allowed = new Set(["profileId", "actorRole", "actionId", "revertsActionId", "entries", "ownerUid"]);
  for (const k of Object.keys(data)) {
    if (!allowed.has(k)) reject("invalid-argument", `Unexpected request field: ${k}`);
  }
  if (!Array.isArray(data.entries) || data.entries.length === 0) {
    reject("invalid-argument", "entries must be a non-empty array");
  }
  for (const e of data.entries) {
    if (!isPlainObject(e) || typeof e.id !== "string" || !ULID_RE.test(e.id)) {
      reject("invalid-argument", "every entry needs a ULID id");
    }
    if (typeof e.entityId !== "string") reject("invalid-argument", "every entry needs an entityId");
  }
  return data as unknown as GovernedActionWire;
}
