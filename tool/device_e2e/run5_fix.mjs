export const meta = {
  name: 'device-e2e-run5-fixes',
  description: 'Fix 15 confirmed run-5 defects (excludes #16 RTL-segmented — re-rejected, would break LTR): l10n agent first, then parallel widget-fix agents on distinct files',
  phases: [
    { title: 'l10n', detail: 'ARB edits (Study Days separator, review-term method, avatar step prefix, CurriculumSettings keys) + gen-l10n' },
    { title: 'widgets', detail: 'parallel fixes on distinct files' },
  ],
}

const REPO = '/home/daniel/repos/learning-tracker';
const LIB = REPO + '/learning_tracker/lib';
const F = LIB + '/features';

const RULES = [
  `## Rules`,
  `- Work in ${REPO}. SURGICAL minimal fixes matching surrounding style. Respect layering lints (DNI-386/387).`,
  `- Edit ONLY your assigned files. Do NOT commit/build-apk/deploy. Do NOT run \`git reset\`/\`git checkout\` (other uncommitted work is in the tree).`,
  `- After editing run \`dart analyze <changed files>\` (env: \`export PATH="/home/daniel/flutter/bin:$PATH"; export LD_LIBRARY_PATH="$HOME/.local/lib/sqliteshim:$LD_LIBRARY_PATH"\` from learning_tracker/) and fix errors you introduced.`,
].join('\n');

const SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['cluster', 'filesChanged', 'summary', 'analyzeClean'],
  properties: {
    cluster: { type: 'string' }, filesChanged: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' }, analyzeClean: { type: 'boolean' }, notes: { type: 'string' },
  },
};

const l10nPrompt = [
  `You are a senior Flutter + l10n engineer. Apply ALL run-5 ARB changes in BOTH ${LIB}/l10n/app_en.arb and app_he.arb (keep synced, match style/@metadata, correct Hebrew), then \`flutter gen-l10n\` from learning_tracker/ and \`dart analyze\` the l10n dir. No other agent touches l10n.`,
  RULES,
  ``,
  `1. (#9) Study Days screen title: change the "{curriculum} Study Days" string (app_en.arb ~line 2887; he ~2649) to use a bullet separator like the Reorder pattern: en "{curriculum} • Study Days", he equivalent with " • ". (Find the exact key — likely studyDaysScreenTitle or similar.)`,
  `2. (#10) The track-edit "Review (chazara)" section label currently bakes in the English term and is rendered inconsistently. Change \`trackEditSectionReview\` from a plain string/getter to a METHOD taking a \`term\` String placeholder, en e.g. "Review ({term})", he equivalent. (The tracks widget agent will pass domainTermLabels(ref).chazara.) Add the placeholder metadata.`,
  `3. (#14) \`rewardConfigChooseAvatarStep\` (app_en.arb ~809, he ~704) has an orphaned "1. " number prefix but there are no subsequent numbered steps — REMOVE the leading "1. " from the value in both ARB files.`,
  `4. (#11) CurriculumSettings has hardcoded English. ADD keys it needs: \`curriculumSettingsCustomSchedule\` (en "Custom schedule", he equivalent) and a parameterized program label key (e.g. \`curriculumSettingsProgramLabel\` — inspect ${F}/settings/presentation/screens/curriculum_settings_screen.dart lines ~84-88 to see exactly what English strings are hardcoded and add matching keys). The settings widget agent will wire them.`,
  ``,
  `RETURN schema: cluster="l10n", filesChanged, summary (LIST exact new/changed key names + signatures), analyzeClean, notes.`,
].join('\n');

const CLUSTERS = [
  { key: 'step-goal-deadline', files: [`${F}/tracks/setup/presentation/steps/step_goal.dart`],
    fix: `#2 (P2): the inactive Deadline preview defaults \`_deadline\` to TODAY (step_goal.dart initState ~line 86: \`DateTime(now.year, now.month, now.day)\`), so the preview computes "1 study day" → a degenerate ~655 items/day. Default it to a sensible forward date, e.g. \`.add(const Duration(days: 30))\` (30 days out), so the inactive preview shows a realistic items/day estimate. Keep it a date-floored value.` },
  { key: 'search-perek-nav', files: [`${F}/content_browsing/presentation/screens/content_search_screen.dart`],
    fix: `#1 (P2): tapping a chapter/perek FOLDER in search results opens a broken intermediate hierarchy screen instead of the text. In the onTap handler (~lines 163-181), perek-level items (at the curriculum's maxBrowseDepth, where maxBrowseDepth < full depth) should route DIRECTLY to TextDisplayRoute, like leaves do. Add a check equivalent to _isChapterLevelRef (item is at maxBrowseDepth) alongside item.isLeaf so perek-level results go to TextDisplayRoute, not ContentHierarchyRoute. (Look at how content_hierarchy_screen.dart decides chapter-level vs deeper.)` },
  { key: 'goal-deadline-passed', files: [`${F}/scheduler/presentation/screens/goal_setup_screen.dart`],
    fix: `#3 (P2): "Deadline has passed" wrongly shows for a FUTURE date (tomorrow) when the device clock is in the afternoon — because it uses raw \`_targetDate.difference(_now()).inDays\` (which truncates a <24h-but-next-day gap to 0/negative). At ~line 371, compare DATE FLOORS: \`DateUtils.extractLocalDate(_targetDate!.toLocal()).difference(DateUtils.extractLocalDate(_now())).inDays\`. Ensure tomorrow reads as +1 day (not passed). Check for the same raw .inDays pattern elsewhere in this file's deadline logic and fix consistently.` },
  { key: 'switcher-offline-email', files: [`${F}/profiles/presentation/widgets/profile_switcher_sheet.dart`],
    fix: `#4 (P2): the synthetic \`@offline.local\` email leaks as the "Switch account" subtitle. At ~line 143, change the subtitle condition from \`accountEmail == null\` to \`accountEmail == null || accountEmail.endsWith('@offline.local')\` so offline accounts show no synthetic email (mirror the run-2/run-4 offline-email suppression).` },
  { key: 'wizard-step-total', files: [`${F}/tracks/setup/presentation/screens/add_track_flow_screen.dart`],
    fix: `#5 (P3): the wizard step counter denominator jumps 6→7 after curriculum selection. NOTE: run-4 verify previously marked a similar "6→7" as BY-DESIGN (a test add_track_flow_ts11_test.dart mandates showing the full count once the program step activates). So be careful: the ONLY change wanted here is to avoid the denominator CHANGING mid-flow as jarring UX — make step 1 ALREADY show the full count (7) when the selected/about-to-be-selected curriculum has a program step, rather than showing 6 then 7. In computeWizardStepTotal (~53-64) and/or the displayTotal in build (~711-718): on step 1, if the curriculum has programs, include the program step in the denominator up front. DO NOT break add_track_flow_ts11_test.dart — read it first; if the test pins the 6-then-7 behavior, then this is BY-DESIGN and you should make NO change and report that in notes (verdict in summary).` },
  { key: 'scheduler-today-remaining', files: [`${F}/scheduler/presentation/providers/scheduler_providers.dart`],
    fix: `#6 (P3, real logic bug): the Dashboard shows "TODAY DUE: 3 / 3 remaining" immediately AFTER the user completes all 3 of today's tasks — today's just-completed completions aren't counted as done. In _buildProjectionTasks, the priorCompletionRefs filter (~line 851) uses \`!DateUtils.extractLocalDate(c.completedAt).isAfter(anchor)\` which EXCLUDES same-day completions incorrectly. Change to \`DateUtils.extractLocalDate(c.completedAt).isBefore(anchor)\` — VERIFY against the surrounding logic that this correctly counts today's completions as done for the remaining-count (read the function carefully; the goal is today's completed tasks reduce "remaining"). If the precise fix differs after reading, apply the correct one and explain.` },
  { key: 'study-days-affordance', files: [`${F}/tracks/setup/presentation/steps/step_study_days.dart`],
    fix: `#7 (P3): on Pixel 2 the שבת (last) row is clipped behind the sticky Continue button at the initial scroll position with no scroll affordance. NOTE: run-3 added bottom padding here already — verify what's present. Add a clear scroll affordance so users see more rows exist: e.g. a bottom-fade ShaderMask over the ListView, or an always-visible Scrollbar. Keep the existing bottom padding. Minimal + correct on all screen sizes.` },
  { key: 'hierarchy-rtl-checkbox', files: [`${F}/content_browsing/presentation/widgets/hierarchy_selection_panel.dart`],
    fix: `#8 (P3): in the Mark-Prior-Learning checklist (Step 7), Hebrew seder names are right-justified while their checkboxes are stranded at the far LEFT — checkbox not adjacent to its label. In the effectiveTileBuilder closure (~175-195), make the ListTile's Directionality match the content (RTL when Hebrew-script labels are shown) so leading/trailing place the checkbox adjacent to the label — OR restructure so the checkbox sits next to the label regardless of text direction. Verify it stays correct for English (LTR) too.` },
  { key: 'tracks-review-term', files: [`${F}/tracks/setup/presentation/screens/edit_track_screen.dart`],
    fix: `#10 (P3): the "Review (chazara)" section label is rendered inconsistently. The l10n agent changed \`trackEditSectionReview\` into a METHOD taking a \`term\` param. Update the call sites in edit_track_screen.dart (~lines 526 and 796) to call it with \`domainTermLabels(ref).chazara\` so the term honours the Hebrew-terms toggle consistently. (Read domainTermLabels usage elsewhere in the file for the exact accessor.)` },
  { key: 'curriculum-settings-l10n', files: [`${F}/settings/presentation/screens/curriculum_settings_screen.dart`],
    fix: `#11 (P3): hardcoded English strings (~lines 84-88, the data-branch title + labels) bypass l10n. Replace them with the l10n keys the l10n agent added (curriculumSettingsCustomSchedule, curriculumSettingsProgramLabel, etc.). Use AppLocalizations.of(context)!. Match how the rest of the screen/codebase localizes.` },
  { key: 'upgrade-pw-toggle', files: [`${F}/settings/presentation/screens/upgrade_to_cloud_screen.dart`],
    fix: `#12 (P3): the "Create a password" field has no show/hide visibility toggle. Add an \`_obscurePassword\` bool state (default true) and a suffixIcon IconButton that toggles it (Icons.visibility / visibility_off), wiring \`obscureText: _obscurePassword\`. Use the showPassword/hidePassword l10n keys (added in run-3) for the tooltip if present; otherwise mirror the sign-in form's password-toggle pattern.` },
  { key: 'reward-cta-inset', files: [`${F}/gamification/presentation/screens/reward_configuration_screen.dart`],
    fix: `#13 (P3): the Save Reward CTA's bottom edge sits under the system gesture-navigation pill at the default scroll position. Add bottom safe-area inset to the scroll content — e.g. include MediaQuery.of(context).viewPadding.bottom (or wrap in SafeArea / add to the SingleChildScrollView padding ~line 305) so the CTA clears the nav pill.` },
  { key: 'invite-tutor-banner', files: [`${F}/tutoring/presentation/screens/invite_tutor_screen.dart`],
    fix: `#15 (P3): the account-level "cloud account required" error is shown via the EMAIL FIELD's errorText, which misleadingly implies the email is malformed. Introduce a separate \`_accountError\` state (distinct from field validation) and render the account-level message as a banner/message ABOVE or below the form (not as the email field's errorText). Keep the run-4 behavior that local-only users get a clear "requires a cloud account" message — just present it as an account-level notice, not field validation.` },
];

function fixPrompt(c) {
  return [
    `You are a senior Flutter engineer applying a surgical run-5 audit fix. Cluster: "${c.key}".`, RULES,
    `- The l10n agent already applied ARB changes + gen-l10n, so referenced l10n keys exist.`,
    `- Edit ONLY: ${c.files.join(', ')}`, ``, `## Fix`, c.fix, ``,
    `Read the file(s), confirm exact lines, apply the minimal fix, \`dart analyze\` your files. If after reading you conclude the finding is actually BY-DESIGN / not a real bug, make NO change and say so in summary+notes.`,
    `RETURN schema: cluster="${c.key}", filesChanged, summary, analyzeClean, notes.`,
  ].join('\n');
}

phase('l10n');
const l10n = await agent(l10nPrompt, { label: 'fix:l10n', phase: 'l10n', schema: SCHEMA, model: 'sonnet' });
log(`l10n done: ${l10n ? l10n.summary : 'FAILED'}`);

phase('widgets');
const results = (await parallel(CLUSTERS.map(c =>
  () => agent(fixPrompt(c), { label: `fix:${c.key}`, phase: 'widgets', schema: SCHEMA, model: 'sonnet' })
))).filter(Boolean);
const changed = [l10n, ...results].filter(Boolean).flatMap(r => r.filesChanged || []);
const issues = [l10n, ...results].filter(Boolean).filter(r => !r.analyzeClean);
log(`widgets done: ${results.length}/${CLUSTERS.length}; ${changed.length} files; ${issues.length} analyze issues`);
return {
  l10n: l10n ? { summary: l10n.summary, clean: l10n.analyzeClean } : null,
  clusters: results.map(r => ({ key: r.cluster, files: r.filesChanged, clean: r.analyzeClean, summary: r.summary, notes: r.notes })),
  filesChanged: changed,
  analyzeIssues: issues.map(r => ({ cluster: r.cluster, notes: r.notes })),
  excluded: ['#16 RTL segmented stranded — re-rejected (deferred workflow + run-2 confirmed SegmentedButton mirrors correctly; swap-arrays fix would break LTR)'],
};
