export const meta = {
  name: 'r1-fix-wave',
  description: 'Fix the remaining R1 vision-redo findings across 4 worktree-isolated feature workers (add-track wizard, track-detail/edit, scheduler study-days, gamification). Each worker owns a disjoint file set (+ shared ARB additively), fixes its findings, regenerates l10n, analyzes clean, and commits to its branch. Read-back report for serial integration on dev.',
  phases: [{ title: 'Fix', detail: '4 feature workers fix R1 findings in parallel worktrees' }],
}

const COMMON = `
DOMAIN RULES (this is a Torah-study app; term correctness matters):
 - TRANSLITERATION, never English translation. A curriculum/track named in English mode uses transliteration
   (Bereishis / Bereshit) — the English MEANING ("Genesis") is WRONG. Route names through the
   CurriculumLabelRenderer in lib/core/labels; NEVER read .displayNameEn/.displayNameHe directly (lint DNI-386).
 - PLURALIZATION: count==1 must be singular ("1 study day", "1 DAY", "1 Item"); count!=1 plural. Prefer an ICU
   plural ARB key over a hardcoded "\$n days".
 - HEBREW/RTL: the 'he' locale must be FULLY translated — no English chrome leaking into Hebrew. Any missing
   string gets a NEW key added to BOTH lib/l10n/app_en.arb AND lib/l10n/app_he.arb, then referenced via l10n.

LAYERING (enforced by custom lints — see learning_tracker/CLAUDE.md):
 - no core/ -> features/ imports; no cross-feature deep imports (only the feature barrel); Firebase only in
   core/sync|auth; raw Talker only in core/logging; .displayNameEn/He only in core/labels + generated files.

WORKFLOW (do exactly this):
 1. cd into YOUR worktree's learning_tracker dir (path given below).
 2. Edit ONLY your OWNED files (listed below) plus lib/l10n/app_en.arb + lib/l10n/app_he.arb (ADDITIVELY — append
    new keys, never reorder or delete existing keys). If a fix needs a file you do NOT own, DO NOT touch it —
    record it in "skipped" with the file path and what's needed. This prevents cross-worker merge conflicts.
 3. After edits: run \`flutter gen-l10n\` (regenerates app_localizations). Then
    \`dart analyze <your owned dirs/files> lib/l10n\` and fix until it prints "No issues found!".
 4. Stage EXPLICITLY (not \`-A\`): \`git add <your code files> lib/l10n/app_en.arb lib/l10n/app_he.arb\`.
    Do NOT \`git add\` the generated lib/l10n/app_localizations*.dart — integration regenerates those once on dev,
    so leaving them unstaged avoids generated-file merge conflicts.
 5. \`git commit -m "fix(<area>): R1 remediation — <short summary>"\` on YOUR branch (you are already on it).
 6. You CANNOT deploy; an on-device VISION redo verifies later. Your job: correct code + analyze-clean + committed.
 No Drift/Freezed/Riverpod annotation changes are expected (UI/string/layout/validation fixes), so build_runner is
 NOT needed — the .g.dart files are already present. If you genuinely changed an annotated symbol, run
 \`dart run build_runner build --delete-conflicting-outputs\` before analyze.`

const WORKERS = [
  {
    label: 'addtrack',
    branch: 'r1-tracks2',
    wt: '/home/daniel/repos/lt-r1-tracks2/learning_tracker',
    owns: `lib/features/tracks/setup/presentation/steps/*  (scope_views.dart, step_starting_position*.dart,
      step_goal.dart, step_study_days.dart, etc.), lib/features/tracks/setup/presentation/screens/add_track_flow_screen.dart,
      lib/features/tracks/setup/presentation/controllers/*, lib/features/tracks/setup/presentation/providers/add_track_providers.dart,
      lib/features/tracks/setup/domain/services/track_creation_service.dart, lib/l10n/*.arb.
      DO NOT TOUCH track_detail_screen.dart or edit_track_screen.dart (another worker owns those).`,
    findings: `ADD-TRACK WIZARD — fix all of these:
 1. [P1] Track-created toast/snackbar shows the English translation "Genesis" instead of the transliteration
    (should be Bereishis / Bereshit). Find where the success snackbar text is built on track creation
    (add_track_flow_screen.dart ~the ScaffoldMessenger near line 740, and/or track_creation_service.dart) and
    route the curriculum/track name through CurriculumLabelRenderer (transliteration). Verify mentally for en + he.
 2. [P1] Step-count denominator is NOT stable — the "Step X of N" header jumps 6 -> 7 -> 4 across program-branch
    transitions. Make N reflect the actual step count of the chosen path and stop it flickering mid-wizard.
    Investigate add_track_flow_screen.dart + controllers/add_track_controller.dart (the step list/total).
 3. [P2] The Custom-Cycle review stepper renders "1 DAYS" — wrong plural for count==1 (should be "1 DAY").
    Locate the composed string (likely a chazara/cycle review row) and make count==1 singular.
 4. [P2] The pace/deadline scope subtitle reads "across 1 study days" — wrong plural (should be "across 1 study day").
    Fix the singular case (likely steps/step_goal.dart or goal_helpers.dart or scope_views.dart).
 5. [P2] Scope-step breadcrumb RenderFlex overflow ("RIGHT OVERFLOWED BY 11 PIXELS", yellow/black stripe) at text
    scale 1.3 (steps/scope_views.dart). Make the breadcrumb wrap / ellipsize / Flexible so it never overflows at 1.3.
 6. [P2] The scope breadcrumb is malformed/redundant: "Chumash -> Sefer selection" repeats the curriculum and shows
    a generic "Sefer selection" placeholder that never reflects the actually-selected section. Make it show the real
    selected section name; remove the redundant curriculum repeat.
 7. [P2] Back within the wizard loses the scope-section selection (TS-10 partial regression). Preserve the wizard
    state across Back (the scope/section selection must survive navigating back then forward). Investigate the
    controller / flow-state retention.
 8. [P1] RenderFlex "BOTTOM OVERFLOWED BY 59 PIXELS" on the Starting Position step at text scale 1.3
    (steps/step_starting_position.dart and/or step_starting_position_calendar.dart). Make the step scroll / constrain
    so there is no overflow at 1.3.`,
  },
  {
    label: 'trackdetail',
    branch: 'r1-locale',
    wt: '/home/daniel/repos/lt-r1-locale/learning_tracker',
    owns: `lib/features/tracks/setup/presentation/screens/track_detail_screen.dart,
      lib/features/tracks/setup/presentation/screens/edit_track_screen.dart, lib/l10n/*.arb.
      DO NOT TOUCH the wizard steps/, add_track_flow_screen.dart, scheduler/, or core/labels.`,
    findings: `TRACK DETAIL + EDIT TRACK — fix all of these:
 1. [P1] TS-8: the track-detail card mixes Hebrew + Gregorian dates on the SAME card; "Est. finish" ignores the
    Hebrew-calendar preference. track_detail_screen.dart ~line 475-478 builds the projected/Est-finish date with a
    plain DateFormat. Make Est. finish honor the SAME hebrew-date preference the rest of the card uses (when the
    Hebrew-date pref is on, render it in the Hebrew calendar too) so one card never mixes calendars for date fields.
 2. [P2] The Delete-Track confirmation dialog has an INVERTED safety hierarchy: the destructive Delete is the only
    prominent button. Make Cancel the prominent/default action and Delete the de-emphasized destructive one (text or
    outlined, error color) — the safe default should be visually dominant.
 3. [P1] Hebrew "Edit Goal" is HALF-TRANSLATED — multiple English chrome strings leak into the he locale. Localize
    EVERY Edit-Goal string (add keys to app_en.arb + app_he.arb, reference via l10n).
 4. [P2] The Edit Goal field label + helper are truncated/ellipsized even at default font with space available. Fix
    the layout (allow wrap / give vertical room) so label and helper are not clipped.
 5. [P2] Edit Track accepts an EMPTY (or whitespace-only) Track Name and proceeds to the save-confirm dialog. Add
    validation: an empty/whitespace name blocks the proceed/save with an inline error message.
 6. [P2 needs-investigation] The same seder "Kodshim" renders in two different Hebrew spellings across screens of one
    track. If the spelling is produced WITHIN your owned files, normalize to the canonical spelling. If it originates
    in core/labels or content data (NOT your files), DO NOT touch it — record it precisely in "skipped".`,
  },
  {
    label: 'scheduler-studydays',
    branch: 'r1-content2',
    wt: '/home/daniel/repos/lt-r1-content2/learning_tracker',
    owns: `lib/features/scheduler/* (esp. presentation/screens/study_day_config_screen.dart and its providers),
      lib/l10n/*.arb. DO NOT TOUCH the wizard's tracks/setup/presentation/steps/step_study_days.dart (another worker
      owns the wizard) — only the standalone scheduler Study-Days config screen is yours.`,
    findings: `SCHEDULER STUDY-DAYS CONFIG — fix all of these:
 1. [P1] The Hebrew "Study Days" config screen is HALF-TRANSLATED: the title, the full instructional subtitle, the
    weekday abbreviations, and the footer all remain English under the he locale (study_day_config_screen.dart).
    Localize ALL of them (keys in app_en.arb + app_he.arb). Weekday abbreviations in Hebrew should be proper Hebrew
    short day names (e.g. א׳, ב׳, ג׳ … or ראשון/שני short forms), not English Mon/Tue.
 2. [P2] The screen allows selecting 0 study days per week (everything review) with NO warning. Add a guard: when
    zero study days are selected, show an inline warning (and optionally prevent saving / require confirmation).`,
  },
  {
    label: 'gamif',
    branch: 'r1-gamif2',
    wt: '/home/daniel/repos/lt-r1-gamif2/learning_tracker',
    owns: `lib/features/gamification/* (reward tiles, redeem screen), lib/l10n/*.arb.`,
    findings: `GAMIFICATION / REDEEM — fix all of these:
 1. [P2] A reward title with no spaces (e.g. a user reward named "IceCream") breaks mid-word as "IceCre / am" at text
    scale 1.3, because the wider disabled redeem button squeezes the title column. Fix the reward-tile layout so a
    long unspaced title degrades gracefully — give the title column adequate room (Flexible/Expanded) and use
    softWrap with TextOverflow.ellipsis (or maxLines) rather than an ugly mid-grapheme break. Verify at scale 1.3
    for both the affordable (enabled) and unaffordable (disabled-button) states.
 2. [P2] The Hebrew redeem-screen title (key redeemScreenTitle in app_he.arb, currently "פרס הפרסים") MISTRANSLATES
    "Redeem Prizes" — it reads "the prize of prizes". Correct it to proper Hebrew for redeeming/exchanging prizes,
    e.g. "מימוש פרסים". Also check the he value of dashboardRedeemPrizes (app_he.arb) and fix it the same way if it
    has the same error. (en stays "Redeem Prizes".)`,
  },
]

const FIX_SCHEMA = {
  type: 'object',
  required: ['worker', 'branch', 'committed', 'analyzeClean', 'findingsFixed', 'filesTouched', 'summary'],
  properties: {
    worker: { type: 'string' },
    branch: { type: 'string' },
    committed: { type: 'boolean' },
    commitSha: { type: 'string' },
    analyzeClean: { type: 'boolean' },
    findingsFixed: {
      type: 'array',
      items: {
        type: 'object',
        required: ['finding', 'file', 'change'],
        properties: {
          finding: { type: 'string' },
          file: { type: 'string' },
          change: { type: 'string' },
        },
      },
    },
    filesTouched: { type: 'array', items: { type: 'string' } },
    skipped: {
      type: 'array',
      items: {
        type: 'object',
        properties: { finding: { type: 'string' }, reason: { type: 'string' }, file: { type: 'string' } },
      },
    },
    summary: { type: 'string' },
  },
}

const briefFor = (w) => `You are a careful Flutter fix-worker for the "${w.label}" slice of the Learning Tracker app.
YOUR WORKTREE: ${w.wt}   (you are on branch ${w.branch})
YOUR OWNED FILES (edit ONLY these, + the shared ARB files additively):
${w.owns}
${COMMON}

${w.findings}

Be thorough and correct — a buggy "fix" is worse than none. For each finding: read the relevant code, make the
minimal correct change that matches surrounding idiom, and confirm the rendered result would satisfy a human looking
at the screen (text not clipped, plural correct, fully Hebrew in he, transliteration not translation). Then analyze
clean and commit. Return ONLY the structured report (what you fixed, files touched, anything skipped and why).`

phase('Fix')
const reports = await parallel(
  WORKERS.map((w) => () => agent(briefFor(w), { label: `fix:${w.label}`, phase: 'Fix', schema: FIX_SCHEMA })),
)
const ok = reports.filter(Boolean)
const fixedCount = ok.reduce((n, r) => n + (r.findingsFixed?.length || 0), 0)
const skippedCount = ok.reduce((n, r) => n + (r.skipped?.length || 0), 0)
const committed = ok.filter((r) => r.committed).map((r) => `${r.branch}@${r.commitSha || '?'}`)
log(`R1 fix wave: ${ok.length}/${WORKERS.length} workers reported; ${fixedCount} findings fixed, ${skippedCount} skipped. Committed: ${committed.join(', ')}`)
return { workers: ok.length, fixedCount, skippedCount, committed, reports: ok }
