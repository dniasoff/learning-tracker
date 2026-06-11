export const meta = {
  name: 'r3-fix-wave',
  description: 'Fix the real R3 redo findings across progress (curriculum-progress duplicated labels, chazaros nusach, layout; recent-activity streak-calendar Hebrew-date, plural, empty-state), gamification (reward-config plural + empty-state copy), and settings (lifetime-marking indeterminate ancestors, breadcrumb clip, toggle label, selection colors, denominator). 3 worktree workers, disjoint roots.',
  phases: [{ title: 'Fix', detail: '3 workers fix the R3 cluster in parallel worktrees' }],
}

const COMMON = `
DOMAIN RULES (Torah-study app):
 - NUSACH VARIANT: in English/transliteration mode, named terms follow the Pronunciation pref — Ashkenazi uses -os
   (Berakhos, chazaros), Sephardi uses -ot (Berakhot, chazarot). Route variant-aware terms through the existing
   transliteration/label helpers; do NOT hardcode the -os form.
 - HEBREW SCRIPT now FOLLOWS THE DEVICE LOCALE: domain terms render Hebrew script when the device language is Hebrew
   (via domainTermLabels(ref).isHebrew, which already checks the locale). Do NOT re-implement that. If a screen reads
   useHebrewTermsProvider DIRECTLY for display, switch it to domainTermLabels(ref).isHebrew so it follows the locale.
 - PLURALIZATION: ICU plural so count==1 is singular. EN {count, plural, =1{...} other{...}}; HE one/two/other.
 - HEBREW-DATE: date/calendar UI must honor the Calendar Preference (Hebrew vs Gregorian) — never hardcode Gregorian.
LAYERING (lints, see learning_tracker/CLAUDE.md): no cross-feature deep imports (only a feature barrel); core can't
 import features; .displayNameEn/He only in core/labels. domainTermLabels / curriculum label renderer are in
 core/labels and importable anywhere.
WORKFLOW: 1) cd YOUR worktree's learning_tracker. 2) Edit ONLY your OWNED roots (below) + lib/l10n/*.arb additively;
 anything outside → record in "skipped". 3) Add a red→green test where practical. 4) flutter gen-l10n (if ARB
 changed) then dart analyze <roots> lib/l10n → "No issues found!"; run your new/affected tests → green. 5) Stage
 EXPLICITLY (code + tests + app_en.arb + app_he.arb); do NOT git add app_localizations*.dart. 6) commit on YOUR
 branch. No annotation changes expected (.g.dart present). You cannot deploy; an on-device redo verifies later.`

const WORKERS = [
  {
    label: 'progress',
    branch: 'r1-tracks2',
    wt: '/home/daniel/repos/lt-r1-tracks2/learning_tracker',
    owns: `lib/features/progress/** + lib/l10n/*.arb.`,
    findings: `PROGRESS — fix all:
 1. [P1] curriculum_progress_screen.dart: the EXPANDED breakdown sub-stat labels are DUPLICATED — each SRS stage is
    rendered TWICE in the expanded breakdown. Find the breakdown builder and dedupe so each stage label appears once.
 2. [P2] The review-unit word "chazaros" does NOT respect Sephardi nusach (always Ashkenazi -os) on the progress
    breakdown. Route it through the variant-aware transliteration helper so Sephardi renders "chazarot". (English
    mode only; in Hebrew UI it follows the locale via domainTermLabels and is already correct.)
 3. [P2] curriculum_progress: the "Track progress: 0%" headline is cramped into a narrow column and wraps to 3 lines
    beside a single-line value. Fix the layout (give the headline room / Flexible / reflow) so it reads cleanly.
 4. [P1] recent_activity streak calendar (widgets/streak_calendar.dart): it IGNORES the Calendar Preference
    (Hebrew-date) setting and uses hardcoded English/Gregorian month/day labels. Make the streak calendar honor the
    Hebrew-date preference (render Hebrew months/dates when the pref is on), like the rest of the app's dates.
 5. [P2] recent_activity: "1 Active days" (English) / "1 ימים פעילים" (Hebrew) is a static plural — use ICU plural so
    count==1 is singular ("1 Active day" / "יום פעיל אחד").
 6. [P2] recent_activity: the empty-filter state shows zeroed charts with NO explicit empty-state copy (bare/blank
    charts). Add a localized empty-state message when the filtered activity set is empty.
 NOTE: the 'Siyumim'/'Limud & Chazaros' rendering-in-Latin-under-Hebrew-UI findings are ALREADY fixed centrally
 (domain terms now follow the device locale). Only act if a progress widget reads useHebrewTermsProvider DIRECTLY —
 then switch it to domainTermLabels(ref).isHebrew. Do not otherwise touch term script.`,
  },
  {
    label: 'gamif',
    branch: 'r1-locale',
    wt: '/home/daniel/repos/lt-r1-locale/learning_tracker',
    owns: `lib/features/gamification/** + lib/l10n/*.arb.`,
    findings: `GAMIFICATION (reward configuration) — fix both:
 1. [P2] reward_configuration_screen.dart: the reward preview shows "1 Points" — pluralization not handled for
    count==1, in English AND Hebrew. Use ICU plural ("1 Point" / "N Points"; Hebrew "נקודה אחת" / "{count} נקודות").
 2. [P2] The empty-state "Manage rewards" copy says "Tap below to add one", but the add affordance (FAB / sheet)
    overlaps or covers where that instruction points, so the guidance is wrong. Fix it so the copy correctly directs
    the user to the actual add control (adjust copy and/or layout so they don't overlap).`,
  },
  {
    label: 'lifetime',
    branch: 'r1-content2',
    wt: '/home/daniel/repos/lt-r1-content2/learning_tracker',
    owns: `lib/features/settings/presentation/screens/lifetime_marking_screen.dart and lib/features/settings/** +
      lib/l10n/*.arb. (Note: lifetime_marking_screen.dart was just updated to read domainTermLabels(ref).isHebrew for
      term script — KEEP that; do not revert to useHebrewTermsProvider.)`,
    findings: `LIFETIME MARKING (bulk lifetime-marking UI) — fix all:
 1. [P1] Partial/indeterminate selection is NOT propagated to ANCESTOR checkboxes: when only some children under a
    parent are selected, the parent renders as fully-checked or unchecked instead of an INDETERMINATE (tristate)
    state. Implement tristate ancestor checkboxes (Checkbox(tristate: true) with value null for partial) so a parent
    reflects all/some/none of its descendants.
 2. [P2] The breadcrumb current/leaf node is HARD-CLIPPED (no ellipsis) in both LTR and RTL, worse at font 1.3. Add
    ellipsis/wrap so the leaf crumb is never cut mid-word.
 3. [P2] The toggle button stays "Deselect all in this list" when Selected:0 after a Clear selection — it must flip
    to "Select all" when nothing is selected. Fix the toggle-label logic to follow the actual selection count.
 4. [P2] Sibling dafim under the SAME wholesale-selected parent render in two DIFFERENT selection colors — the
    selected-state color is inconsistent across siblings. Make the selected color consistent for all selected items.
 5. [P2 needs-investigation] After marking a SINGLE daf, lifetime progress shows 1.3% — suspicious denominator
    (1 daf of Bavli ≈ 2711 dapim should be ~0.04%, not 1.3%). Investigate the lifetime-progress percentage
    denominator; if it is wrong (e.g. per-masechta vs whole-Shas, or double-counting amudim), fix it; if 1.3% is in
    fact correct for the selected scope, leave it and explain in your report.`,
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
YOUR OWNED ROOTS (edit ONLY these + the shared ARB files additively):
${w.owns}
${COMMON}

${w.findings}

Be thorough and correct — a buggy "fix" is worse than none. Confirm the rendered result satisfies a human (no
duplicated labels, no clipping, correct plural/nusach, indeterminate parents). Add a red→green test where practical,
analyze clean, run tests, commit. Return ONLY the structured report.`

phase('Fix')
const reports = await parallel(
  WORKERS.map((w) => () => agent(briefFor(w), { label: `fix:${w.label}`, phase: 'Fix', schema: FIX_SCHEMA })),
)
const ok = reports.filter(Boolean)
const fixedCount = ok.reduce((n, r) => n + (r.findingsFixed?.length || 0), 0)
const committed = ok.filter((r) => r.committed).map((r) => `${r.branch}@${(r.commitSha || '?').slice(0, 8)}`)
log(`R3 fix wave: ${ok.length}/${WORKERS.length} workers; ${fixedCount} findings fixed. Committed: ${committed.join(', ')}`)
return { workers: ok.length, fixedCount, committed, reports: ok }
