export const meta = {
  name: 'r2-fix-wave',
  description: 'Fix the real R2 redo findings: scheduler daily-task banner Hebrew localization + bottom-clip button + count=1 pluralization (tierCounter* and masechta) in ARB; content_hierarchy breadcrumb RTL chevron direction + current-crumb clip + system-back drill-path. 2 worktree workers, disjoint roots (scheduler+l10n vs content_browsing).',
  phases: [{ title: 'Fix', detail: '2 workers fix the R2 cluster in parallel worktrees' }],
}

const COMMON = `
DOMAIN RULES (Torah-study app):
 - HEBREW/RTL: the 'he' UI locale must be FULLY Hebrew — no English chrome leaking in. New strings → NEW key in BOTH
   lib/l10n/app_en.arb AND lib/l10n/app_he.arb, referenced via l10n.
 - PLURALIZATION: use ICU plural so count==1 is singular. English: {count, plural, =1{1 item} other{{count} items}}.
   Hebrew has dual — use {count, plural, one{...} two{...} other{...}} with grammatical forms (e.g. one{פריט אחד}
   two{שני פריטים} other{{count} פריטים}). Keep ALL existing placeholders (e.g. {siyumimTerm}) intact.
 - Transliteration not translation; .displayNameEn/He only in core/labels (lint DNI-386).
LAYERING (lints — see learning_tracker/CLAUDE.md): no cross-feature deep imports (only a feature's barrel); core
 cannot import features. DomainTermLabels / curriculum label renderer live in core/labels and are importable anywhere.
WORKFLOW (do exactly this):
 1. cd into YOUR worktree's learning_tracker dir (path below).
 2. Edit ONLY your OWNED roots (below). If a fix needs a file outside your roots, DO NOT touch it — record it in
    "skipped" with the path and what's needed.
 3. Add/extend a focused widget or unit test that goes RED before your fix and GREEN after, where practical.
 4. After edits: \`flutter gen-l10n\` (if you changed ARB) then \`dart analyze <your roots> lib/l10n\` → fix until
    "No issues found!". Run your new/affected tests: \`flutter test <files>\` → green.
 5. Stage EXPLICITLY (not \`-A\`): your code + test files (+ lib/l10n/app_en.arb + app_he.arb IF you own l10n). Do NOT
    git add lib/l10n/app_localizations*.dart (integration regenerates them once on dev).
 6. \`git commit -m "fix(<area>): R2 — <summary>"\` on YOUR branch (already checked out).
 No Drift/Freezed/Riverpod annotation changes expected; .g.dart already present. You CANNOT deploy; an on-device
 VISION redo verifies later.`

const WORKERS = [
  {
    label: 'sched-i18n',
    branch: 'r1-tracks2',
    wt: '/home/daniel/repos/lt-r1-tracks2/learning_tracker',
    owns: `lib/features/scheduler/** + lib/l10n/*.arb. DO NOT touch lib/features/content_browsing, gamification, or
      progress (the tierCounter pluralization is an ARB-ONLY change — the render sites in progress/gamification keep
      the same getter + args and need no code edit).`,
    findings: `SCHEDULER + L10N PLURALS — fix all:
 1. [P1] DAILY-TASK GOAL BANNER leaks English under Hebrew UI. lib/features/scheduler/presentation/screens/scheduler_screen.dart
    line ~293 hardcodes "TODAY'S GOAL"; the "N today tasks" count text is also hardcoded English. Localize BOTH (new
    ARB keys en+he; the count text must pluralize for count==1). Verify the banner is fully Hebrew in the he locale.
 2. [P2] The secondary "Next daily task" button on the scheduler/daily-task screen hugs the screen bottom edge / is
    clipped by the system nav-bar inset (bounds run under the gesture inset). Wrap the bottom area in SafeArea (or add
    MediaQuery viewPadding.bottom padding) so the button is never clipped by the nav bar. Verify at font 1.0 and 1.3.
 3. [P2] COUNT=1 PLURALIZATION (ARB-only, lib/l10n/app_en.arb + app_he.arb). Convert these to ICU plural so count==1
    is singular, keeping their existing placeholders:
      · tierCounterStreakDays  ("{count}-day streak"  / he "רצף של {count} ימים")
      · tierCounterSiyumimEarned ("{count} {siyumimTerm} earned" / he with {siyumimTerm}) — keep {siyumimTerm}
      · tierCounterLifetimeItems ("{count} items in lifetime" / he "{count} פריטים")
      · tierCounterPoints ("{count} pts" / he "{count} נקודות")
    Also find and fix the curriculum-settings masechta-count label that renders "11 Masechta" / "7 Masechta" with a
    singular noun for plural counts (grep the ARB for a "{count} Masechta"-style key, or a masechta/section count
    string used on the curriculum settings scope summary) — pluralize it (English plural "Masechtos/Masechtas" per
    the curriculum's nusach is out of scope; at minimum make count==1 vs >1 grammatical). The call sites are unchanged
    (same getter + count arg), so this is an ARB-only edit + \`flutter gen-l10n\`.`,
  },
  {
    label: 'content',
    branch: 'r1-locale',
    wt: '/home/daniel/repos/lt-r1-locale/learning_tracker',
    owns: `lib/features/content_browsing/** only. Do NOT edit lib/l10n (no new strings needed for these layout/nav
      fixes; if you genuinely need a new string, record it in skipped).`,
    findings: `CONTENT HIERARCHY breadcrumb + back-nav — fix all:
 4. [P2] BREADCRUMB CHEVRON DIRECTION in RTL: in lib/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart
    the separator chevrons point in OPPOSITE directions within one RTL trail — the root-chip separator vs the inner
    separators disagree. Use a direction-aware separator (Icons.chevron_right that auto-mirrors in RTL, or
    Directionality-aware logic) so ALL separators point the same way for the reading direction (LTR: ›  RTL: ‹).
 5. [P2] BREADCRUMB CURRENT CRUMB CLIPPED mid-word at font scale 1.3 (worse in RTL — e.g. 'Berakhos' truncates). Make
    the active/current crumb wrap or ellipsize cleanly (Flexible + ellipsis, or allow the trail to scroll) so it is
    never cut mid-word at 1.3 in LTR or RTL.
 6. [P2] SYSTEM BACK discards the ENTIRE drill path: in the content hierarchy, the AppBar back-arrow steps up ONE
    level but the Android system Back button pops the whole route (losing the drill path), an inconsistent and
    surprising UX. Make the system Back button step up ONE hierarchy level (matching the AppBar back), only popping
    the route when already at the top level. Use PopScope/WillPopScope (or the navigation controller) on the content
    hierarchy screen. Verify: drill 3 levels deep, press system Back → goes up one level (not all the way out).`,
  },
]

const FIX_SCHEMA = {
  type: 'object',
  required: ['worker', 'branch', 'committed', 'analyzeClean', 'testsGreen', 'findingsFixed', 'filesTouched', 'summary'],
  properties: {
    worker: { type: 'string' }, branch: { type: 'string' }, committed: { type: 'boolean' },
    commitSha: { type: 'string' }, analyzeClean: { type: 'boolean' }, testsGreen: { type: 'boolean' },
    findingsFixed: { type: 'array', items: { type: 'object', required: ['finding', 'file', 'change'],
      properties: { finding: { type: 'string' }, file: { type: 'string' }, change: { type: 'string' }, test: { type: 'string' } } } },
    filesTouched: { type: 'array', items: { type: 'string' } },
    skipped: { type: 'array', items: { type: 'object', properties: { finding: { type: 'string' }, reason: { type: 'string' }, file: { type: 'string' } } } },
    summary: { type: 'string' },
  },
}

const briefFor = (w) => `You are a careful Flutter fix-worker for the "${w.label}" slice of the Learning Tracker app.
YOUR WORKTREE: ${w.wt}   (you are on branch ${w.branch})
YOUR OWNED ROOTS (edit ONLY these):
${w.owns}
${COMMON}

${w.findings}

Be thorough and correct — a buggy "fix" is worse than none. Confirm the rendered result satisfies a human (fully
Hebrew in he, no clipping at 1.3, count==1 grammatical, chevrons consistent). Add a red→green test where practical,
analyze clean, run tests, commit. Return ONLY the structured report.`

phase('Fix')
const reports = await parallel(
  WORKERS.map((w) => () => agent(briefFor(w), { label: `fix:${w.label}`, phase: 'Fix', schema: FIX_SCHEMA })),
)
const ok = reports.filter(Boolean)
const fixedCount = ok.reduce((n, r) => n + (r.findingsFixed?.length || 0), 0)
const committed = ok.filter((r) => r.committed).map((r) => `${r.branch}@${(r.commitSha || '?').slice(0, 8)}`)
log(`R2 fix wave: ${ok.length}/${WORKERS.length} workers; ${fixedCount} findings fixed. Committed: ${committed.join(', ')}`)
return { workers: ok.length, fixedCount, committed, reports: ok }
