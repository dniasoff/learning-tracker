export const meta = {
  name: 'fix-stale-tests',
  description: 'Bring 42 failing tests green across ~18 files — mostly tests made stale by runs 1-5 intentional UI/behavior changes; update tests to match current behavior, fix prod only if a real regression',
  phases: [{ title: 'FixTests', detail: 'parallel agents, one per failing test file, each runs its file to green' }],
}

const REPO = '/home/daniel/repos/learning-tracker';
const TEST = REPO + '/learning_tracker/test';

const COMMON = [
  `## Context`,
  `This repo just had 5 rounds of on-device-audit fixes (runs 1-5) that changed UI/behavior INTENTIONALLY (all on-device verified). Many widget/unit tests now fail because they assert the OLD behavior. Your job: make the assigned failing test(s) GREEN.`,
  ``,
  `## How to decide test-update vs prod-fix`,
  `- DEFAULT: update the TEST to match the CURRENT (intentional) behavior. The production change was deliberate and verified — do NOT revert it.`,
  `- ONLY if the failure reveals a genuine REGRESSION (the app is actually broken, not just the test stale) should you touch production code — and then explain clearly in notes.`,
  `- Known intentional changes that made tests stale (match tests to these):`,
  `  * PIN flow: \`maybePop(result)\` was changed to \`pop(result)\` (so the parent-mode guard's push<bool> resolves). Tests asserting "maybePop invoked" should assert pop / the navigation result instead.`,
  `  * Goal-type SegmentedButton: leading icons (Icons.calendar_today on 'deadline', Icons.speed on 'pace', Icons.all_inclusive on 'none') were REMOVED (text-only segments). Tests that tap find.byIcon(Icons.speed)/etc to switch goal-type mode must tap the segment by its localized LABEL instead (goalTypePace="Pace"/"קצב", goalTypeDeadline, goalTypeNoDeadline). NOTE: Icons.calendar_today still exists in the deadline DATE-PICKER row, so presence-in-deadline-mode assertions are fine; only the goal-type-toggle icon taps broke.`,
  `  * Profile mode labels: manage-learners now uses l10n keys \`profileTypeChild\`/\`profileTypeAdult\` (values "Child"/"Adult") instead of \`childMode\`/\`adultMode\` ("Child mode"/"Adult mode"). Update expected subtitle text.`,
  `  * TextDisplay AppBar title: during loading shows '…' (was the raw sefariaRef). The raw ref only shows on error now.`,
  `  * InviteTutor: copy-link affordance removed; account-level "cloud account required" error now shown as an account-level message (not the email field's errorText); success path pops back / shows snackbar. Match current widget tree.`,
  `  * bulkMarkWizardSubtitle is now a METHOD taking a siyumimTerm String (was a getter). The B1 tier-credit subtitle text now interpolates the (possibly Hebrew) term.`,
  `  * Account picker: the "Add another account" section moved into the list (max-accounts message still present — check current placement).`,
  `  * RewardConfig/redeem: "{points} Points" capitalization; reward "Redeem" button text. RecentActivity: "Points Earned" subtitle key changed (chartPointsEarnedSubtitle), bar-chart axis honours Hebrew-date pref, "Last 30 Days" no longer wraps.`,
  `  * Sign-in offline: the offline state may now show an inline offline hint instead of the "coral local-warning mode card" — match the current behavior (check what SignInScreen renders when offline now).`,
  ``,
  `## Rules`,
  `- Work in ${REPO}. Edit ONLY your assigned test file(s) (and production code ONLY for a genuine regression). Do NOT git commit. Do NOT run \`git reset\`/\`git checkout\` (other uncommitted work — the make-audit fix — is in the tree; never discard it).`,
  `- Toolchain (from learning_tracker/): \`export PATH="/home/daniel/flutter/bin:$PATH"; mkdir -p ~/.local/lib/sqliteshim; ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0.8.6 ~/.local/lib/sqliteshim/libsqlite3.so; export LD_LIBRARY_PATH="$HOME/.local/lib/sqliteshim:$LD_LIBRARY_PATH"\`.`,
  `- VERIFY: run \`flutter test <your file(s)>\` and iterate until it reports All tests passed (0 failures). For golden tests, regenerate with \`flutter test --update-goldens <file>\` ONLY if the golden diff is an expected consequence of the intentional UI changes (inspect first; note what changed).`,
  `- Run \`dart analyze\` on any file you edit.`,
].join('\n');

const SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['file', 'green', 'changedProd', 'summary'],
  properties: {
    file: { type: 'string' },
    green: { type: 'boolean' },
    changedProd: { type: 'boolean' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    regressionFound: { type: 'string' },
  },
};

// Each entry: test file(s) + the specific failing tests + cause hint
const FILES = [
  { f: 'features/scheduler/widgets/goal_setup_screen_test.dart', why: '4 "pace input label + helper are not truncated" tests tap find.byIcon(Icons.speed) to switch to pace mode — that icon was removed. Tap the "Pace" segment by localized label (goalTypePace) instead.' },
  { f: 'features/profiles/pin_flow_and_setup_dialog_l1_test.dart', why: '4 tests (B3, B6, C6, G1) assert "maybePop invoked". The flow now uses pop(result). Update mocks/assertions to expect pop / the popped result.' },
  { f: 'features/profiles/presentation/screens/manage_learners_screen_l1_test.dart', why: '2 tests expect "childMode"/"adultMode" subtitle l10n; now uses profileTypeChild/profileTypeAdult ("Child"/"Adult"). Update expected text.' },
  { f: 'features/content_browsing/presentation/screens/text_display_screen_test.dart', why: '"shows sefariaRef in AppBar title" — title now shows "…" during loading; raw ref only on error. Update the test to drive the loaded state, or assert the loading placeholder, per intent.' },
  { f: 'features/tutoring/invite_tutor_screen_l1_test.dart', why: '8 tests (success snackbar/no-link, child-name, null grantId, pops back, friendly errors, precondition inline error, error clears, no copy-link). Invite error/success handling changed (account-level error message; copy-link removed). Match current widget tree.' },
  { f: 'features/onboarding/presentation/screens/bulk_mark_screen_test.dart', why: '"B1 tier-credit subtitle" — bulkMarkWizardSubtitle is now a method taking siyumimTerm; subtitle text interpolates the term. Update expected text.' },
  { f: 'features/onboarding/presentation/screens/onboarding_bulk_l1_test.dart', why: 'B1 tier-credit subtitle present — same bulkMarkWizardSubtitle method change as above.' },
  { f: 'features/gamification/presentation/screens/child_redemption_screen_l1_test.dart', why: '"affordable reward button text is Redeem and is enabled" — likely affected by redeemScreenCostLabel "{points} Points" capitalization or layout. Inspect current tree; update expectation.' },
  { f: 'features/account/presentation/screens/account_picker_screen_l1_test.dart', why: '"max-accounts message shown when account count == kMaxDeviceAccounts" — add-account section moved into the list (run-4 #11). Update finder/placement.' },
  { f: 'features/tutor_pin_dialog_and_goal_setup_l1_test.dart', why: '2 tests G4/G5 (description preserved in GoalEntity; targetPercent reflects slider) — goal form interaction likely used a removed goal-type icon to reach pace/deadline. Tap segments by label.' },
  { f: 'features/auth/presentation/screens/sign_in_screen_test.dart', why: '"offline: shows the coral local-warning mode card" — offline sign-in now may show an inline offline hint (run-5 #13). Inspect what SignInScreen renders offline now and update.' },
  { f: 'features/tracks/setup/presentation/screens/track_detail_screen_test.dart', why: '"tapping the goal tile and submitting persists a goal" — goal submit flow; likely the removed goal-type icon or goal-setup change. Drive via labels; ensure a valid goal can submit (note: deadline mode now needs a date / pace needs a non-empty value).' },
  { f: 'features/progress/recent_activity_and_hierarchy_panel_l1_test.dart', why: '"A7 child mode — Points Earned section visible" — Points Earned subtitle key changed (chartPointsEarnedSubtitle) / hierarchy panel RTL/checkbox change. Update expectation.' },
  { f: 'features/progress/presentation/screens/recent_activity_screen_test.dart', why: '"switching time-range pill triggers a fresh chart fetch" — chart/time-range changes (Last 30 Days no longer wraps; bar-chart hebrew). Update finder/expectation.' },
  { f: 'golden/store_screenshots_test.dart', why: '4 golden screenshots (Dashboard child, Add Track, Scheduler, Gamification) drifted due to intentional UI changes across runs. Inspect the diffs; if they reflect the intended changes, regenerate with --update-goldens. Note exactly what visually changed.' },
  { f: 'e2e/journeys/scheduler_p1_test.dart', why: '3 tests (E2E-510 neutral message/hide chazara; E2E-511 read-only tiles; E2E-512 zero-study-day warning) in StudyDayConfig. Study-days screen got a scroll affordance/title change; check if a finder broke. Also may tap a removed goal icon. Fix finders.' },
  { f: 'e2e/journeys/scheduler_p0_test.dart', why: 'E2E-509 StudyDayConfig shows day-toggle grid for chazara track — study-days change; fix finder.' },
  { f: 'e2e/journeys/tutoring_p0_test.dart', why: 'E2E-1001 entering valid tutor email + Send calls inviteTutorUseCase — invite flow change (same as invite_tutor unit tests). Match current behavior.' },
  { f: 'e2e/journeys/progress_p0_test.dart', why: '2 tests E2E-804 (navigate to RecentActivity, time-range chips + curriculum filter; Last 30 Days chip switches range) — chart/time-range label changes. Fix finders (e.g. "Last 30 Days" text no longer has a newline).' },
  { f: 'e2e/journeys/progress_p1_test.dart', why: 'E2E-810 RecentActivity renders from Drift cache offline, no spinner hang — likely the same recent-activity changes. Fix finder/expectation.' },
];

phase('FixTests');
function prompt(e) {
  return [
    `You are a senior Flutter test engineer. Make the failing test(s) in \`test/${e.f}\` GREEN.`,
    COMMON,
    ``, `## Your file: test/${e.f}`,
    `## Failing test(s) + likely cause: ${e.why}`,
    ``,
    `Read the failing test(s) and the production widget/code they exercise, update the test(s) to match current intentional behavior (or fix a genuine regression), then \`flutter test test/${e.f}\` until ALL pass. Report.`,
    `RETURN schema: file="${e.f}", green (true only if the whole file passes), changedProd, filesChanged, summary, regressionFound (describe if you found a real bug, else "").`,
  ].join('\n');
}

const results = (await parallel(FILES.map(e =>
  () => agent(prompt(e), { label: `test:${e.f.split('/').pop()}`, phase: 'FixTests', schema: SCHEMA, model: 'sonnet' })
))).filter(Boolean);

const green = results.filter(r => r.green);
const notGreen = results.filter(r => !r.green);
const prodChanges = results.filter(r => r.changedProd);
const regressions = results.filter(r => r.regressionFound && r.regressionFound.trim());
log(`Done: ${green.length}/${results.length} files green; ${prodChanges.length} touched prod; ${regressions.length} flagged regressions`);
return {
  green: green.map(r => r.file),
  notGreen: notGreen.map(r => ({ file: r.file, summary: r.summary })),
  prodChanges: prodChanges.map(r => ({ file: r.file, files: r.filesChanged, summary: r.summary })),
  regressions: regressions.map(r => ({ file: r.file, regression: r.regressionFound })),
  allFilesChanged: results.flatMap(r => r.filesChanged || []),
};
