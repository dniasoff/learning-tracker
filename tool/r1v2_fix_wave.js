export const meta = {
  name: 'r1v2-fix-wave',
  description: 'Fix the remaining R1v2 redo findings (Hebrew weekday abbreviations in the study-days step, scope-breadcrumb redundancy in Hebrew-Terms mode, "≈0 items" goal estimate, edited-track-name not surfacing, Edit-Goal pace-helper truncation, dashboard Today\'s-Missions clip at 1.3) across 2 worktree-isolated workers with disjoint roots (tracks vs scheduler+dashboard). Red->green tests, analyze clean, commit per branch.',
  phases: [{ title: 'Fix', detail: '2 workers fix the R1v2 cluster in parallel worktrees' }],
}

const COMMON = `
DOMAIN RULES (Torah-study app):
 - HEBREW/RTL: the 'he' UI locale must be FULLY Hebrew — no English/Latin chrome leaking in, and no MIXED script
   within one list (e.g. Latin 'S/M/T' day initials next to a Hebrew 'שבת'). New strings get a NEW key in BOTH
   lib/l10n/app_en.arb AND lib/l10n/app_he.arb, referenced via l10n.
 - Transliteration not translation; .displayNameEn/He only in core/labels (lint DNI-386). Saturday's weekday label
   routes through the nusach/terms resolver (DomainTermLabels.shabbos in core/labels) → Shabbos/Shabbat/שבת.
LAYERING (lints — see learning_tracker/CLAUDE.md): no cross-feature deep imports (only a feature's barrel); core
 cannot import features; Firebase only in core/sync|auth. DomainTermLabels and the curriculum label renderer live in
 core/labels and ARE importable anywhere.
WORKFLOW (do exactly this):
 1. cd into YOUR worktree's learning_tracker dir (path below).
 2. Edit ONLY your OWNED roots (below) + lib/l10n/*.arb (ADDITIVELY — append new keys, never reorder/delete). If a
    fix needs a file outside your roots, DO NOT touch it — record it in "skipped" with the path and what's needed.
 3. Add/extend a focused widget or unit test that goes RED before your fix and GREEN after, where practical.
 4. After edits: \`flutter gen-l10n\` then \`dart analyze <your roots> lib/l10n\` → fix until "No issues found!".
    Run your new/affected tests: \`flutter test <those test files>\` → all green.
 5. Stage EXPLICITLY (not \`-A\`): your code files + your test files + lib/l10n/app_en.arb + lib/l10n/app_he.arb.
    Do NOT git add lib/l10n/app_localizations*.dart (integration regenerates them once on dev).
 6. \`git commit -m "fix(<area>): R1v2 — <summary>"\` on YOUR branch (already checked out).
 No Drift/Freezed/Riverpod annotation changes are expected; .g.dart already present (run build_runner only if you
 truly changed an annotated symbol). You CANNOT deploy; an on-device VISION redo verifies later.`

const WORKERS = [
  {
    label: 'tracks',
    branch: 'r1-tracks2',
    wt: '/home/daniel/repos/lt-r1-tracks2/learning_tracker',
    owns: `lib/features/tracks/** + lib/l10n/*.arb. DO NOT touch lib/features/scheduler, lib/features/dashboard,
      or core/labels (read-only reference only).`,
    findings: `TRACKS — fix all four:
 1. [P2] STUDY-DAYS STEP mixed/Latin weekday labels (lib/features/tracks/setup/presentation/steps/step_study_days.dart).
    kStepStudyDayLabels is hardcoded English ['Sun','Mon',...]; the day-circle AVATAR initial is the first letter of
    that English label (so 'S'/'M'/'T'), and Saturday's avatar uses the shabbos label's first glyph ('ש') — so in
    the Hebrew UI you get Latin initials, and even in English you get a lone Hebrew 'שבת' among Latin letters (mixed
    script). FIX: localize the day labels AND the avatar initials so the whole row is consistent in each locale —
    Sun–Fri from the SHARED scheduler day-abbreviation l10n keys (l10n.schedulerDayAbbrevSun … schedulerDayAbbrevFri,
    already in the ARB), Saturday from DomainTermLabels.shabbos(variant:) (core/labels). The avatar initial must be
    the first grapheme of the LOCALIZED label. Verify EN (Sun..Fri + Shabbos/Shabbat) and HE (Hebrew abbrevs + שבת) —
    no Latin/Hebrew mixing in either.
 2. [P2] SCOPE BREADCRUMB redundancy STILL present in Hebrew-Terms mode (steps/scope_views.dart). The top-level fix
    uses l10n.scopeChooseLevelPrompt(labelForLevel(1)), but the redundancy ("Chumash → … selection", or the
    curriculum repeated, or an untranslated "selection" literal) reappears when Hebrew-Terms is ON and/or in the
    drill-down ScopeHierarchyView breadcrumb trail. Investigate BOTH render paths and ensure NO breadcrumb segment
    duplicates the curriculum name and there is no untranslated literal, with Hebrew-Terms both ON and OFF.
 3. [P2] GOAL STEP "(≈0 items)" nonsense (steps/step_goal.dart). _projectedFinishLabel guards totalScopeItems<=0, but
    the "(≈{totalItems} items)" parenthetical still renders "≈0 items" before the scope count resolves (or when 0).
    Guard the parenthetical so it is OMITTED (or shows a neutral placeholder) until the scope count is a positive
    number — never display "≈0 items".
 4. [P1] EDITED TRACK NAME does not surface. After Edit Track changes the Name, the track title/header/list still
    shows the CURRICULUM name, ignoring the user's custom name. Investigate where a track's title renders (likely it
    uses the curriculum label and ignores CurriculumTrack.name/displayName). Make the user-entered track name surface
    as the track title wherever a track is shown (detail header, track cards/list), falling back to the curriculum
    label when no custom name is set. Keep it within lib/features/tracks; if the title rendering genuinely lives
    outside tracks (e.g. core/labels), record it precisely in skipped.`,
  },
  {
    label: 'sched-dash',
    branch: 'r1-locale',
    wt: '/home/daniel/repos/lt-r1-locale/learning_tracker',
    owns: `lib/features/scheduler/** + lib/features/dashboard/** + lib/l10n/*.arb. DO NOT touch lib/features/tracks.`,
    findings: `SCHEDULER + DASHBOARD — fix both:
 5. [P2] EDIT-GOAL pace-input label/helper TRUNCATION (lib/features/scheduler/presentation/screens/goal_setup_screen.dart).
    The pace TextFormField's labelText ('<unit> <per>') and helperText ('How many <unit> …?') are truncated/ellipsized
    in BOTH languages even at default font, and worse at font scale 1.3. Fix the layout so the label and helper have
    room to wrap and are never clipped at default or 1.3 (e.g. allow multi-line helper / give the field width / use a
    Flexible/Expanded so a sibling control isn't squeezing it). Verify en + he at font 1.0 and 1.3.
 6. [P2] DASHBOARD "Today's Missions" heading clips to "Today's Mi…" at font scale 1.3
    (lib/features/dashboard/presentation/widgets/dashboard_body.dart). The heading shares a horizontal Row with the
    pink "N remaining" pill and ellipsizes at 1.3 despite ample vertical space. Make the heading wrap or flex
    (Expanded/Flexible on the heading, and/or let the pill yield width) so the full heading shows at font 1.3.`,
  },
]

const FIX_SCHEMA = {
  type: 'object',
  required: ['worker', 'branch', 'committed', 'analyzeClean', 'testsGreen', 'findingsFixed', 'filesTouched', 'summary'],
  properties: {
    worker: { type: 'string' },
    branch: { type: 'string' },
    committed: { type: 'boolean' },
    commitSha: { type: 'string' },
    analyzeClean: { type: 'boolean' },
    testsGreen: { type: 'boolean' },
    findingsFixed: {
      type: 'array',
      items: {
        type: 'object',
        required: ['finding', 'file', 'change'],
        properties: { finding: { type: 'string' }, file: { type: 'string' }, change: { type: 'string' }, test: { type: 'string' } },
      },
    },
    filesTouched: { type: 'array', items: { type: 'string' } },
    skipped: { type: 'array', items: { type: 'object', properties: { finding: { type: 'string' }, reason: { type: 'string' }, file: { type: 'string' } } } },
    summary: { type: 'string' },
  },
}

const briefFor = (w) => `You are a careful Flutter fix-worker for the "${w.label}" slice of the Learning Tracker app.
YOUR WORKTREE: ${w.wt}   (you are on branch ${w.branch})
YOUR OWNED ROOTS (edit ONLY these + the shared ARB files additively):
${w.owns}
${COMMON}

${w.findings}

Be thorough and correct — a buggy "fix" is worse than none. For each finding: read the code, make the minimal
correct change matching surrounding idiom, confirm the rendered result satisfies a human (text not clipped, fully
Hebrew in he, no mixed script, no "≈0 items"), add a red→green test where practical, analyze clean, run the tests,
commit. Return ONLY the structured report.`

phase('Fix')
const reports = await parallel(
  WORKERS.map((w) => () => agent(briefFor(w), { label: `fix:${w.label}`, phase: 'Fix', schema: FIX_SCHEMA })),
)
const ok = reports.filter(Boolean)
const fixedCount = ok.reduce((n, r) => n + (r.findingsFixed?.length || 0), 0)
const committed = ok.filter((r) => r.committed).map((r) => `${r.branch}@${(r.commitSha || '?').slice(0, 8)}`)
log(`R1v2 fix wave: ${ok.length}/${WORKERS.length} workers; ${fixedCount} findings fixed. Committed: ${committed.join(', ')}`)
return { workers: ok.length, fixedCount, committed, reports: ok }
