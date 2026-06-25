export const meta = {
  name: 'device-e2e-run2-fixes',
  description: 'Fix all 23 confirmed run-2 defects: one l10n/ARB agent first (shared files + P1 Hebrew program descriptions + gen-l10n), then parallel widget-fix agents on distinct files',
  phases: [
    { title: 'l10n', detail: 'all ARB additions/edits + P1 program-description localization + flutter gen-l10n' },
    { title: 'widgets', detail: 'parallel fixes on distinct widget files, wiring the new l10n keys' },
  ],
}

const REPO = '/home/daniel/repos/learning-tracker';
const LIB = REPO + '/learning_tracker/lib';

const RULES = [
  `## Rules (all agents)`,
  `- Work in ${REPO}. Make SURGICAL, minimal fixes that match the surrounding code style.`,
  `- Respect the layering lints in learning_tracker/CLAUDE.md (DNI-386/387): no core->features imports, no cross-feature deep imports, Firebase only in core/sync|auth, etc.`,
  `- Edit ONLY the files assigned to you. Do NOT git commit, do NOT build an APK, do NOT deploy. (The coordinator builds + deploys + commits.)`,
  `- After editing, run \`dart analyze <your changed files>\` (toolchain: \`export PATH="/home/daniel/flutter/bin:$PATH"; export LD_LIBRARY_PATH="$HOME/.local/lib/sqliteshim:$LD_LIBRARY_PATH"\`, from learning_tracker/) and fix any errors YOU introduced. Note pre-existing unrelated issues but don't fix them.`,
].join('\n');

const SUMMARY_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['cluster', 'filesChanged', 'summary', 'analyzeClean'],
  properties: {
    cluster: { type: 'string' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    analyzeClean: { type: 'boolean' },
    notes: { type: 'string' },
  },
};

// ───────────────────────── Stage 1: l10n / ARB ─────────────────────────
const l10nPrompt = [
  `You are a senior Flutter + l10n engineer. Apply ALL the localization (ARB) changes for the run-2 fix batch, then regenerate localizations. You OWN: ${LIB}/l10n/app_en.arb, ${LIB}/l10n/app_he.arb, the generated app_localizations*.dart (via gen-l10n), and the P1 program-description files. No other agent touches l10n.`,
  RULES,
  ``,
  `## ARB changes (add new keys / fix existing) in BOTH app_en.arb and app_he.arb (keep them in sync; match the file's existing JSON style + any @metadata blocks):`,
  `1. NEW key \`goalClearDeadlineTooltip\` — en "Clear deadline date", he "נקה תאריך יעד". (used by goal_setup clear-date IconButton)`,
  `2. NEW keys \`showPassword\` / \`hidePassword\` — en "Show password" / "Hide password", he "הצג סיסמה" / "הסתר סיסמה". (used by password visibility toggles)`,
  `3. FIX \`notificationSettingsSubtitle\` — it currently over-promises "Push, email, and study sound alerts" but the screen only has push toggles. Change to describe ONLY push notifications: en e.g. "Push notification alerts", he e.g. "התראות דחיפה". (verify the exact current value first)`,
  `4. FIX \`chartLast30Days\` — remove the embedded \`\\n\` (it makes the tab wrap to 2 lines). en e.g. "Last 30 Days" (single line), he equivalent single line.`,
  ``,
  `## P1 (F-01) — Hebrew UI leaks English program-schedule descriptions`,
  `The Add-Track "Join a Program?" step shows program cards whose TITLES are localized but whose DESCRIPTIONS render the raw English \`description\` from seed data (${LIB}/core/database/seed/learning_program_seeds.dart). Render sites: ${LIB}/features/tracks/setup/presentation/widgets/program_selection_step.dart (the description Text in _FeaturedProgramCard and _CompactProgramCard).`,
  `FIX: mirror the EXISTING locale-aware pattern used for program TITLES. INVESTIGATE first: grep for how titles are localized (e.g. \`learningProgramLabelText\` or similar) and how programs are keyed (program id). Then provide a locale-aware DESCRIPTION lookup: add per-program description strings to the ARB (en = the existing English text, he = a correct Hebrew translation) keyed consistently (mirror the title keys), add a \`learningProgramDescriptionText(...)\`-style helper next to the title helper, and change the two render sites to use it instead of the raw \`program.description\`. Keep the English seed \`description\` as a safe fallback. Translate each program description to natural Hebrew (these are short: e.g. "Two mishnayos per day, no built-in review." -> "שתי משניות ביום, ללא חזרה מובנית.").`,
  ``,
  `## After all ARB edits: regenerate localizations`,
  `From learning_tracker/: \`export PATH="/home/daniel/flutter/bin:$PATH"; flutter gen-l10n\` (or the project's configured l10n command — check l10n.yaml / pubspec). Confirm app_localizations_en.dart + app_localizations_he.dart now contain the new getters. Then \`dart analyze\` the l10n + program_selection_step files.`,
  ``,
  `RETURN the schema object: cluster="l10n", filesChanged, summary (list new keys + the helper name so widget agents can use them), analyzeClean, notes.`,
].join('\n');

// ───────────────────────── Stage 2: parallel widget clusters ─────────────────────────
const F = LIB + '/features';
const CLUSTERS = [
  { key: 'wizard-label', files: [`${F}/tracks/setup/presentation/screens/add_track_flow_screen.dart`, `${F}/tracks/setup/presentation/controllers/add_track_controller.dart`],
    fix: `F-05/F-21/F-13(toast): the Add-Track completion toast/label names the LAST-selected seder (e.g. "Seder Taharos") instead of the curriculum when ALL sedarim were selected via "Select all in this list". In add_track_flow_screen.dart \`_getSmartDefault()\` (~lines 669-685) and add_track_controller.dart \`_smartLabel\` (~lines 332-340): when the number of selected top-level scope items equals the curriculum's total top-level count, skip the \`.last.value\` branch and use the curriculum label (\`curriculumLabelText(ref, curriculum: c)\` / the curriculum display name). i.e. "all selected" -> name the curriculum, not the last seder.` },
  { key: 'track-card-a11y', files: [`${F}/tracks/setup/presentation/widgets/learning_track_card.dart`, `${F}/tracks/setup/presentation/screens/track_detail_screen.dart`],
    fix: `F-09: the LinearProgressIndicator emits its raw fractional value ("0") into the semantics tree, so TalkBack announces "0, <name>". Wrap the LinearProgressIndicator in \`ExcludeSemantics\` (learning_track_card.dart ~162-172 AND track_detail_screen.dart ~436-443) since an adjacent Text already announces the percentage. F-10: also wrap the track card's outer Material/InkWell (learning_track_card.dart) in a \`Semantics(label: "<title>, <progress>", button: true, child: ...)\` so the merged content-desc is clean (no leaked ordinal "0,").` },
  { key: 'content-search', files: [`${F}/content_browsing/presentation/screens/content_search_screen.dart`, `${F}/content_browsing/presentation/widgets/content_item_tile.dart`],
    fix: `F-07: in content_search_screen.dart \`_buildBody\` onTap (~line 162), container/folder (non-leaf) results show a drill-down chevron but tapping no-ops because onTap only handles \`if (item.isLeaf)\`. Add an else branch for container items that navigates into the hierarchy (push ContentHierarchyRoute / equivalent pre-filtered to the container's level path), mirroring \`_handleItemTap\` in content_hierarchy_screen.dart. F-13: search results are ambiguous (many "משנה ו"). In content_item_tile.dart add a parent breadcrumb \`subtitle\` (e.g. CurriculumLabel.parent / breadcrumb) when shown in search context — add a \`showBreadcrumb\` flag to ContentItemTile defaulting false, and pass true from ContentSearchScreen.` },
  { key: 'goal-setup', files: [`${F}/scheduler/presentation/screens/goal_setup_screen.dart`],
    fix: `F-04 (data integrity): in Deadline mode the "Update Goal" button (~line 674) is enabled even when no target date is selected, submitting a null targetDate. Guard it: disable the button (onPressed: null) OR early-return/validate in _submit() when goalType=='deadline' && targetDate==null (show a message). F-15: the clear-date IconButton (~line 314) has no tooltip — add \`tooltip: AppLocalizations.of(context)!.goalClearDeadlineTooltip\` (the l10n key was added by the l10n agent).` },
  { key: 'mode-card', files: [`${F}/onboarding/presentation/steps/onboarding_profile_creation_step.dart`],
    fix: `F-06 + F-23 (tablet layout): in \`modeCard()\` (~lines 201-294), the ACTIVE badge anchors to the far right and the Child/Adult cards have a big dead-zone gap on tablet, because the Stack sits inside an Expanded and sizes to the full row slot rather than the card. Fix so the Stack/card fills its Expanded slot and the badge anchors to the card: add \`width: double.infinity\` to the inner card Container (so it fills the Expanded width) AND ensure the Stack wraps only the Material/card (move Stack inside, or wrap the card Container in a SizedBox.expand) so the badge positions relative to the card, not the screen.` },
  { key: 'auth', files: [`${F}/account/presentation/screens/sign_in_screen.dart`, `${F}/account/presentation/widgets/sign_in_form.dart`, `${F}/account/onboarding/presentation/screens/signup_screen.dart`, `${F}/account/presentation/screens/account_picker_screen.dart`, `${F}/settings/presentation/screens/upgrade_to_cloud_screen.dart`],
    fix: `F-02: sign_in_screen.dart (~254-261) uses a ConstrainedBox minHeight derived from LayoutBuilder constraints, so when the soft keyboard opens the content can't scroll and the Sign In CTA/checkbox/register link are unreachable. Use MediaQuery.of(context).size.height (minus padding) as minHeight so the SingleChildScrollView always has scrollable content. F-03: upgrade_to_cloud_screen.dart password TextFormFields (~550-594) — add \`textInputAction: TextInputAction.done\` + \`onFieldSubmitted: (_) => <submit>()\`, and \`textInputAction: TextInputAction.next\` on the email field; same keyboard-reachability concern as F-02 if present. F-17: password visibility toggle IconButtons (sign_in_form.dart ~92-100 and signup_screen.dart ~619-630) — add \`tooltip:\` using l10n.showPassword/l10n.hidePassword (added by l10n agent), toggling on the obscure state. F-18: sign_in_form.dart "Keep me signed in" Row (~129-145) — wrap in MergeSemantics (or add semanticLabel) so the checkbox is self-describing. F-19: account_picker_screen.dart _DashedOutlineButton (~189-209) — wrap in \`Semantics(button: true, child: ...)\`.` },
  { key: 'reward', files: [`${F}/gamification/presentation/screens/reward_configuration_screen.dart`],
    fix: `F-08: the points field (~line 391) shows only a placeholder with no label, unlike the adjacent name field (~362-369). Insert \`Text(l10n.rewardConfigPointsThresholdLabel)\` + a SizedBox(height: 8) before the points TextField, matching the name-field label pattern. (The key rewardConfigPointsThresholdLabel already exists.)` },
  { key: 'dashboard-a11y', files: [`${F}/dashboard/presentation/widgets/dashboard_body.dart`],
    fix: `F-11: the streak chip's raw count ("1") is merged into the greeting semantics with no context. Wrap the streak GestureDetector (~304-370) in a \`Semantics(label: <descriptive streak label>, child: ...)\` and add \`excludeSemantics: true\` so the bare Icon+number don't also announce. Build the label from the EXISTING localized streak text already shown in the widget (don't invent a new ARB key — reuse what's there, e.g. the same string used for the visible streak label).` },
  { key: 'reader-back', files: [`${F}/content_browsing/presentation/screens/text_display_screen.dart`],
    fix: `F-12: the reader AppBar back IconButton (~69-72) has an empty content-desc (automaticallyImplyLeading:false suppresses the auto label). Add \`tooltip: MaterialLocalizations.of(context).backButtonTooltip\`.` },
  { key: 'track-order-rtl', files: [`${F}/tracks/track_order/presentation/screens/track_learning_order_screen.dart`],
    fix: `F-14: in \`_buildSectionHeader\` (~141-155) the header Text (line ~148, e.g. "סדרים"/"מסכתות") is left-aligned (LTR default) while the Hebrew list items auto-detect RTL and right-align. Add textDirection inference to that Text, e.g. \`textDirection: RegExp(r'[\\u0590-\\u05FF]').hasMatch(label) ? TextDirection.rtl : null\` (match the DNI-341 pattern in CurriculumLabel._text — read it for the exact idiom).` },
  { key: 'parent-settings', files: [`${F}/profiles/presentation/screens/parent_settings_screen.dart`],
    fix: `F-16: the Sign Out row (~335-339) shows a duplicate logout icon — a leading Icons.logout_rounded AND a trailing Icons.logout_outlined. Change the \`trailing\` to \`const SizedBox.shrink()\` (matching how the Delete Account row handles it).` },
  { key: 'progress-tab', files: [`${F}/progress/presentation/screens/recent_activity_screen.dart`],
    fix: `F-22 (widget half): the "Last 30 Days" tab was wrapping to 2 lines. The ARB \`\\n\` was already removed by the l10n agent; here just remove the now-unnecessary \`maxLines: 2\` (~line 193) or change it to maxLines: 1 so the tab row stays single-line and aligned.` },
];

function fixPrompt(c) {
  return [
    `You are a senior Flutter engineer applying a surgical fix from an on-device audit. Cluster: "${c.key}".`,
    RULES,
    `- The l10n agent already added/updated ARB keys and ran gen-l10n, so any l10n keys referenced below already exist.`,
    `- You may ONLY edit these files: ${c.files.join(', ')}`,
    ``,
    `## Fix(es) to apply`,
    c.fix,
    ``,
    `Read the file(s), confirm the exact lines, apply the minimal fix, then \`dart analyze\` your changed files.`,
    `RETURN the schema object: cluster="${c.key}", filesChanged, summary, analyzeClean, notes (anything you couldn't do or that needs follow-up).`,
  ].join('\n');
}

// ───────────────────────── orchestration ─────────────────────────
phase('l10n');
const l10n = await agent(l10nPrompt, { label: 'fix:l10n', phase: 'l10n', schema: SUMMARY_SCHEMA, model: 'sonnet' });
log(`l10n done: ${l10n ? l10n.summary : 'FAILED'}`);

phase('widgets');
const widgetResults = (await parallel(CLUSTERS.map(c =>
  () => agent(fixPrompt(c), { label: `fix:${c.key}`, phase: 'widgets', schema: SUMMARY_SCHEMA, model: 'sonnet' })
))).filter(Boolean);

const allChanged = [l10n, ...widgetResults].filter(Boolean).flatMap(r => r.filesChanged || []);
const notClean = [l10n, ...widgetResults].filter(Boolean).filter(r => !r.analyzeClean);
log(`widgets done: ${widgetResults.length}/${CLUSTERS.length} clusters; ${allChanged.length} files changed; ${notClean.length} reported analyze issues`);

return {
  l10n: l10n ? { summary: l10n.summary, files: l10n.filesChanged, clean: l10n.analyzeClean, notes: l10n.notes } : null,
  clusters: widgetResults.map(r => ({ key: r.cluster, files: r.filesChanged, clean: r.analyzeClean, summary: r.summary, notes: r.notes })),
  filesChanged: allChanged,
  analyzeIssues: notClean.map(r => ({ cluster: r.cluster, notes: r.notes })),
};
