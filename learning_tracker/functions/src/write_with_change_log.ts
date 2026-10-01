import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v1";
import { HttpsError } from "firebase-functions/v2/https";

import { db } from "./shared";

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
//   6. is idempotent on the client ULID: an existing entry with the same actor
//      and entity returns the stored result; a different actor/entity/payload
//      under the same ULID is rejected (already-exists).
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
 */
const FIELD_SPECS: Readonly<Record<string, Readonly<Record<string, Check>>>> = {
  sub_tracks: {
    curriculum_id: CURRICULUM_ID,
    name: str(200),
    type: oneOf("school_year", "ongoing"),
    academic_year: int,
    window_start: date,
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
    latitude: (v) => num(v) && Math.abs(v as number) <= 90,
    longitude: (v) => num(v) && Math.abs(v as number) <= 180,
    time_zone: str(64),
    in_israel: bool,
  },
};

const EVENT_LEARN_FIELDS: Readonly<Record<string, Check>> = {
  kind: oneOf("learn"),
  curriculum_id: CURRICULUM_ID,
  ref: str(500),
  level: either(str(64), int),
  source: (v) => v === "main" || (typeof v === "string" && ULID_RE.test(v)),
  date_state: oneOf("dated", "catch_up", "before_tracking"),
  learned_on: nullable(date),
  stage: int,
  original_recorded_at: (v) => typeof v === "string" && !Number.isNaN(Date.parse(v)),
};

const EVENT_VOID_FIELDS: Readonly<Record<string, Check>> = {
  kind: oneOf("void"),
  target_id: (v) => typeof v === "string" && ULID_RE.test(v),
  reverts_action_id: (v) => typeof v === "string" && ULID_RE.test(v),
};

// ── Request / result types ────────────────────────────────────────────────────

export type DocMode = "create" | "upsert" | "update";

export interface GovernedDocPatch {
  collection: string;
  docId: string;
  /** Storage-named fields to set; `null` = absent; `ended_at: true` = tombstone now. */
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
  /** Entities a stored entry under this ULID may belong to for an idempotent replay. */
  replayScope?: Array<{ entity: GovernedEntity; entityId?: string }>;
  /** owner-only rejects every non-owner caller (ownerOversizedGovernedWrite). */
  callerPolicy?: "owner-or-tutor" | "owner-only";
  /** Security-audit action label for tutor writes (tutor_grants/{id}/audit_log). */
  auditAction?: string;
}

export interface GovernedWriteResult {
  success: true;
  action_id: string;
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
    const value = fields[key];
    // null = "absent" for every optional field; required-ness is checked on
    // the final doc state below.
    if (value !== null && !check(value)) {
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
      if (!beforeTracking && (fields.level !== undefined || fields.learned_on !== undefined)) {
        reject("invalid-argument", "level/learned_on are only allowed on before_tracking events");
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
  created: boolean,
): void {
  if (!isLive(state)) return; // a tombstoned doc needs no further shape
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
    case "track_learning_order":
      if (created) {
        for (const f of ["level", "ref", "user_sort_order"]) {
          if (state[f] === undefined || state[f] === null) {
            reject("invalid-argument", `track_learning_order requires ${f}`);
          }
        }
      }
      break;
    case "curriculum_tracks":
      if (created && state.state === undefined) reject("invalid-argument", "a new track requires state");
      break;
    case "sub_tracks":
      if (created) {
        // AD-45 sub-track limits are not validated server-side yet (owned by
        // the sub-track stories); until then the helper never creates one.
        reject("failed-precondition", "sub-track creation is not supported by this callable");
      }
      break;
    default:
      break;
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

function replayMatches(
  stored: FirebaseFirestore.DocumentData,
  actor: Actor,
  scope: Array<{ entity: GovernedEntity; entityId?: string }>,
  staticEntries: GovernedEntryIntent[],
): boolean {
  if (stored.actor?.uid !== actor.uid || stored.actor?.role !== actor.role) return false;
  const inScope = scope.some((s) =>
    s.entity === stored.entity && (s.entityId === undefined || s.entityId === stored.entity_id));
  if (!inScope) return false;
  // Payload check: every stored after-value whose doc/field the replay also
  // patches must carry the same value (server-stamped tombstones excepted).
  const patched = new Map<string, unknown>();
  for (const e of staticEntries) {
    for (const d of e.docs) {
      for (const [f, v] of Object.entries(d.fields)) patched.set(changeKey(d.collection, d.docId, f), v);
    }
  }
  if (patched.size === 0) return true;
  for (const [key, value] of Object.entries((stored.after ?? {}) as Record<string, unknown>)) {
    if (!patched.has(key)) continue;
    const mine = patched.get(key);
    if (key.endsWith(".ended_at")) {
      if ((mine === null) !== (value === null)) return false;
      continue;
    }
    if (!deepEqual(mine, value)) return false;
  }
  return true;
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

  const clientUlid: string | null = staticEntries[0]?.id ?? req.actionId ?? null;
  const actionId: string = req.actionId ?? staticEntries[0]?.id ?? newUlid();
  const replayScope = req.replayScope ??
    staticEntries.map((e) => ({ entity: e.entity, entityId: e.entityId }));

  const profileRef = db.collection("users").doc(req.ownerUid)
    .collection("learner_profiles").doc(req.profileId);

  type Outcome =
    | { kind: "replay"; actionId: string; changeIds: string[]; at: string | null }
    | { kind: "written"; changeIds: string[]; eventIds: string[] };

  const outcome: Outcome = await db.runTransaction(async (txn): Promise<Outcome> => {
    // ── 1. Authorise (re-read every call, so revocation stops the next one) ──
    const { actor, grantRef } = await resolveActor(txn, auth, req);
    const profileSnap = await txn.get(profileRef);
    if (!profileSnap.exists) reject("not-found", "Learner profile not found");

    // ── 2. Idempotent replay on the client ULID ──────────────────────────────
    if (clientUlid) {
      const storedSnap = await txn.get(profileRef.collection("change_log").doc(clientUlid));
      if (storedSnap.exists) {
        const stored = storedSnap.data()!;
        if (!replayMatches(stored, actor, replayScope, staticEntries)) {
          reject("already-exists", "This change id was already used for a different change");
        }
        const members = await txn.get(
          profileRef.collection("change_log").where("action_id", "==", stored.action_id));
        return {
          kind: "replay",
          actionId: String(stored.action_id),
          changeIds: members.docs.map((d) => d.id).sort(),
          at: timestampIso(stored.at),
        };
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
    if (docCount + entries.length + events.length > MAX_WRITES_PER_CALL) {
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
        validateFinalState(d.collection, d.docId, finalState, cur === null);
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

    // AD-31: a void's target must be a learn event (an absent target is fine).
    const requestKinds = new Map(events.map((ev) => [ev.id, ev.fields.kind]));
    voidTargets.forEach((t, i) => {
      const kind = targetSnaps[i].exists ? targetSnaps[i].get("kind") : requestKinds.get(t);
      if (kind !== undefined && kind !== "learn") {
        reject("invalid-argument", "A void must target a learn event");
      }
    });

    // Learning events are idempotent on their own ULID doc id.
    const newEvents: LearningEventIntent[] = [];
    events.forEach((ev, i) => {
      const snap = eventSnaps[i];
      if (!snap.exists) {
        newEvents.push(ev);
        return;
      }
      if (snap.get("actor.uid") !== actor.uid || snap.get("kind") !== ev.fields.kind) {
        reject("already-exists", "This event id was already used for a different event");
      }
    });

    // ── 6. Assign entry ids (first written entry carries the action id) ──────
    planned.forEach((p, i) => {
      if (!p.id) p.id = i === 0 ? actionId : newUlid();
    });
    const ids = planned.map((p) => p.id);
    if (new Set(ids).size !== ids.length) reject("invalid-argument", "Duplicate change ids");

    // ── 7. Write: docs + entries + events, all in this transaction ───────────
    const serverNow = admin.firestore.FieldValue.serverTimestamp();
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
    return { kind: "written", changeIds: ids, eventIds: newEvents.map((e) => e.id) };
  });

  if (outcome.kind === "replay") {
    return {
      success: true,
      action_id: outcome.actionId,
      change_ids: outcome.changeIds,
      event_ids: [],
      at: outcome.at,
      recorded_at: null,
      replayed: true,
      noop: false,
    };
  }

  // Read back the server-stamped times (serverTimestamp resolves at commit).
  const firstChange = outcome.changeIds[0];
  const firstEvent = outcome.eventIds[0] ?? staticEvents[0]?.id;
  const [changeSnap, eventSnap] = await Promise.all([
    firstChange ? profileRef.collection("change_log").doc(firstChange).get() : Promise.resolve(null),
    firstEvent ? profileRef.collection("learning_events").doc(firstEvent).get() : Promise.resolve(null),
  ]);
  return {
    success: true,
    action_id: actionId,
    change_ids: outcome.changeIds,
    event_ids: outcome.eventIds,
    at: changeSnap ? timestampIso(changeSnap.get("at")) : null,
    recorded_at: eventSnap ? timestampIso(eventSnap.get("recorded_at")) : null,
    replayed: false,
    noop: outcome.changeIds.length === 0 && outcome.eventIds.length === 0,
  };
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
