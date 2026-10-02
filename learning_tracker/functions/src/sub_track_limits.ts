// ══════════════════════════════════════════════════════════════════════════════
// AD-45 sub-track validation — the server half of the shared rule set.
// ══════════════════════════════════════════════════════════════════════════════
//
// Mirrors lib/domain/learner_state/sub_track_validator.dart code for code
// (Story 2.1 / DNI-492). Both run the fixture suite
// test/fixtures/sub_track_limits/*.json and must agree on every case
// (functions/test/cf_sub_track_limits.test.mjs here,
// test/domain/learner_state/sub_track_limits_test.dart in Dart).
//
// - Limits apply per learner profile AND curriculum. A sub-track counts while
//   it is not ended and its window has not passed (window_end null or
//   >= today, inclusive civil dates, AD-41): exactly "onHome or
//   future-start" (AD-34).
//     ≤ 5 counting ongoing sub-tracks;
//     ≤ 1 counting school-year sub-track per academic_year;
//     no two counting school-year windows overlapping (inclusive bounds).
// - Only NEW violations reject a write: a violation the stored row already
//   had (an excess reconciled from two offline devices, which the engine
//   tolerates) does not block an unrelated edit of that row.
// - Calendar programs: no sub-track create on a calendar-program curriculum;
//   no calendar program on a curriculum with a non-ended sub-track.
// - Intent shape (AC-5): no duplicate ground ref, window_start not after
//   window_end, positive rate_per_week and weeks_per_year. The
//   cross-curriculum ground check needs the ContentIndex and is Dart-only.
//
// Pure functions over plain AD-52 storage records — no Firestore access.

/** The AD-45 cap on counting ongoing sub-tracks per profile and curriculum. */
export const MAX_ONGOING_SUB_TRACKS = 5;

/** Stable wire codes, identical to Dart `SubTrackLimit.code`. */
export type SubTrackLimitCode =
  | "ongoing_limit"
  | "school_year_duplicate_academic_year"
  | "school_year_window_overlap"
  | "calendar_program_curriculum"
  | "calendar_program_has_sub_tracks"
  | "duplicate_ground"
  | "cross_curriculum_ground"
  | "window_reversed"
  | "non_positive_rate"
  | "non_positive_weeks";

export interface SubTrackViolation {
  code: SubTrackLimitCode;
  /** The conflicting sub-track id or ground ref, when there is one. */
  subject?: string;
}

/** One `sub_tracks/{id}` row in storage form, with its id. */
export interface SubTrackRow {
  id: string;
  data: Record<string, unknown>;
}

function isEnded(d: Record<string, unknown>): boolean {
  return d.ended_at !== undefined && d.ended_at !== null;
}

function windowEnd(d: Record<string, unknown>): string | null {
  return typeof d.window_end === "string" ? d.window_end : null;
}

/** Whether a row counts toward the AD-45 limits on `today`. */
export function countsTowardSubTrackLimits(d: Record<string, unknown>, today: string): boolean {
  if (isEnded(d)) return false;
  const end = windowEnd(d);
  return end === null || end >= today;
}

/** AC-5 shape violations (cross-curriculum ground is Dart-only). */
export function subTrackIntentViolations(d: Record<string, unknown>): SubTrackViolation[] {
  const out: SubTrackViolation[] = [];
  const seen = new Set<string>();
  for (const node of Array.isArray(d.ground) ? d.ground : []) {
    const ref = (node as Record<string, unknown> | null)?.ref;
    if (typeof ref !== "string") continue;
    if (seen.has(ref)) out.push({ code: "duplicate_ground", subject: ref });
    seen.add(ref);
  }
  const end = windowEnd(d);
  if (end !== null && typeof d.window_start === "string" && d.window_start > end) {
    out.push({ code: "window_reversed" });
  }
  if (!(typeof d.rate_per_week === "number" && d.rate_per_week > 0)) {
    out.push({ code: "non_positive_rate" });
  }
  if (!(typeof d.weeks_per_year === "number" && d.weeks_per_year > 0)) {
    out.push({ code: "non_positive_weeks" });
  }
  return out;
}

function violationKey(v: SubTrackViolation): string {
  return `${v.code}|${v.subject ?? ""}`;
}

function overlaps(a: Record<string, unknown>, b: Record<string, unknown>): boolean {
  const startsByEndOf = (x: Record<string, unknown>, y: Record<string, unknown>) => {
    const end = windowEnd(y);
    return end === null || String(x.window_start) <= end;
  };
  return startsByEndOf(a, b) && startsByEndOf(b, a);
}

function limitViolations(
  track: Record<string, unknown>,
  peers: SubTrackRow[],
  today: string,
): Map<string, SubTrackViolation> {
  const out = new Map<string, SubTrackViolation>();
  if (!countsTowardSubTrackLimits(track, today)) return out;
  const counting = peers.filter((p) => countsTowardSubTrackLimits(p.data, today) && p.data.type === track.type);
  const add = (v: SubTrackViolation) => out.set(violationKey(v), v);
  if (track.type === "ongoing") {
    if (counting.length + 1 > MAX_ONGOING_SUB_TRACKS) add({ code: "ongoing_limit" });
  } else if (track.type === "school_year") {
    for (const p of counting) {
      if (p.data.academic_year === track.academic_year) {
        add({ code: "school_year_duplicate_academic_year", subject: p.id });
      }
      if (overlaps(track, p.data)) add({ code: "school_year_window_overlap", subject: p.id });
    }
  }
  return out;
}

/**
 * The AD-45 limit and calendar-program violations that writing `candidate`
 * would introduce. `prior` is the stored row (null on create); `siblings`
 * every other sub-track of the profile (any curriculum; the candidate's id
 * is ignored); `calendarProgramId` the live program of the candidate's
 * curriculum, or null.
 */
export function subTrackLimitViolations(args: {
  candidate: SubTrackRow;
  prior: Record<string, unknown> | null;
  siblings: SubTrackRow[];
  today: string;
  calendarProgramId: string | null;
}): SubTrackViolation[] {
  const { candidate, prior, siblings, today, calendarProgramId } = args;
  const peers = siblings.filter(
    (s) => s.id !== candidate.id && s.data.curriculum_id === candidate.data.curriculum_id);
  const after = limitViolations(candidate.data, peers, today);
  const before = prior === null || prior.curriculum_id !== candidate.data.curriculum_id
    ? new Map<string, SubTrackViolation>()
    : limitViolations(prior, peers, today);
  const out: SubTrackViolation[] = [];
  if (prior === null && calendarProgramId !== null) out.push({ code: "calendar_program_curriculum" });
  for (const [k, v] of after) if (!before.has(k)) out.push(v);
  return out;
}

/**
 * Setting calendar program `programId` on `curriculumId` while a non-ended
 * sub-track of it exists. Clearing the program (null) is always allowed.
 */
export function calendarProgramSetViolations(args: {
  curriculumId: string;
  programId: string | null;
  subTracks: SubTrackRow[];
}): SubTrackViolation[] {
  if (args.programId === null) return [];
  return args.subTracks
    .filter((s) => s.data.curriculum_id === args.curriculumId && !isEnded(s.data))
    .map((s) => ({ code: "calendar_program_has_sub_tracks" as const, subject: s.id }));
}

/** Sorted, de-duplicated wire codes (the fixture / parity form). */
export function subTrackViolationCodes(violations: SubTrackViolation[]): string[] {
  return [...new Set(violations.map((v) => v.code))].sort();
}

/** The learner's civil date for `now` in IANA `timeZone` (AD-41); UTC when unset or invalid. */
export function civilDateIn(timeZone: unknown, now: Date): string {
  const fmt = (tz: string) => new Intl.DateTimeFormat("en-CA", {
    timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit",
  }).format(now);
  if (typeof timeZone === "string" && timeZone.length > 0) {
    try {
      return fmt(timeZone);
    } catch {
      // fall through to UTC
    }
  }
  return fmt("UTC");
}
