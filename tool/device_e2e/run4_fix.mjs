export const meta = {
  name: 'device-e2e-run4-fixes',
  description: 'Fix 11 confirmed run-4 defects (defers #1 cold-start bootstrap — high blast radius): l10n agent first (1 new key), then parallel widget-fix agents on distinct files',
  phases: [
    { title: 'l10n', detail: 'add tasksNoOverdueTasksSubtitle + gen-l10n' },
    { title: 'widgets', detail: 'parallel fixes on distinct files' },
  ],
}

const REPO = '/home/daniel/repos/learning-tracker';
const LIB = REPO + '/learning_tracker/lib';
const F = LIB + '/features';

const RULES = [
  `## Rules`,
  `- Work in ${REPO}. SURGICAL minimal fixes matching surrounding style. Respect layering lints (DNI-386/387).`,
  `- Edit ONLY your assigned files. Do NOT commit, build an APK, or deploy.`,
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
  `You are a senior Flutter + l10n engineer. Add ONE new ARB key in BOTH ${LIB}/l10n/app_en.arb and app_he.arb, then regenerate. No other agent touches l10n.`,
  RULES,
  `ADD \`tasksNoOverdueTasksSubtitle\` — en "No overdue tasks." , he "אין משימות באיחור." (match the file's JSON style + any @metadata next to the existing \`tasksNoTasksRemainingTitle\` / scheduler empty-state keys ~line 2452). Then from learning_tracker/ run \`flutter gen-l10n\` and \`dart analyze\` the l10n dir. The scheduler widget agent will use l10n.tasksNoOverdueTasksSubtitle.`,
  `RETURN schema: cluster="l10n", filesChanged, summary (the exact new key + values), analyzeClean, notes.`,
].join('\n');

const CLUSTERS = [
  { key: 'scheduler-overdue', files: [`${F}/scheduler/presentation/screens/scheduler_screen.dart`],
    fix: `#2 (P2): the OVERDUE section's empty state (~lines 65-74) reuses \`tasksNoTasksRemainingTitle\`/subtitle which falsely says "no tasks remaining for today" even when there are future/today tasks (it just means no OVERDUE tasks). Make the EmptyState message/subtitle switch on the \`section\`: for \`SchedulerTaskSection.overdue\` use an overdue-specific subtitle — \`l10n.tasksNoOverdueTasksSubtitle\` (added by the l10n agent) — instead of the generic "no tasks remaining" copy. Keep other sections unchanged.` },
  { key: 'content-index', files: [`${LIB}/core/content/content_index.dart`],
    fix: `#3 (P2): a חומש (Chumash) text's breadcrumb shows the WRONG curriculum root ('תורה' instead of 'חומש') because ContentIndex._byRef collides on sefariaRef across curricula (the same ref exists in multiple curricula, and the last one wins). In ContentIndex.fromCurricula, make the lookup curriculum-aware: either key _byRef by (curriculumId, sefariaRef), OR add a \`lookup(ref, {CurriculumId? preferredCurriculum})\` that prefers a match in the given curriculum and only falls back to any match when there's no preferred match. Apply the minimal change that resolves the right curriculum's ContentItem; keep existing callers working (preferredCurriculum optional).` },
  { key: 'point-config-empty', files: [`${F}/gamification/presentation/screens/point_config_screen.dart`],
    fix: `#4 (P2): the empty state (~269-279) is bare Center/Padding/Text — no icon, no CTA. Replace it with the shared EmptyState widget (find it in the codebase, e.g. core/widgets — grep "class EmptyState"): an icon (e.g. Icons.tune_rounded), the existing heading string, a subtitle (use the existing body l10n string the screen already has), and an action button (e.g. OutlinedButton) that navigates to Manage Tracks. Match how other screens use EmptyState.` },
  { key: 'bar-chart-hebrew', files: [`${F}/progress/presentation/widgets/limudim_chazaros_bar_chart.dart`],
    fix: `#5 (P2): the bar chart weekday axis ignores the Hebrew date preference — it shows English weekday labels while the streak calendar above shows Hebrew. At ~line 58, the \`isHebrew\` assignment should ALSO honour the Hebrew-date provider: OR in \`ref.watch(useHebrewDateProvider)\` (read how useHebrewDateProvider is used by the streak calendar / elsewhere for the exact provider + import). Make the axis labels follow the same Hebrew-date setting.` },
  { key: 'manage-tutors-contrast', files: [`${F}/tutoring/presentation/screens/manage_tutors_screen.dart`],
    fix: `#6 (P2): the "No tutors invited." empty-state text (~line 241) uses \`theme.colorScheme.outline\` (a border token, ~1.12:1 contrast — unreadable). Change it to \`theme.colorScheme.onSurfaceVariant\` (the standard secondary-text token) for legible contrast.` },
  { key: 'add-profile-dismiss', files: [`${F}/profiles/presentation/widgets/add_profile_dialog.dart`],
    fix: `#7 (P3): Android Back (and barrier tap) dismisses the Add Profile dialog, silently discarding the typed name. On the showDialog call (~line 30) add \`barrierDismissible: false\`, and wrap the dialog content (StatefulBuilder/ParentModeDialogFrame) in a \`PopScope(canPop: false, ...)\` so Back doesn't bypass the explicit Cancel/X affordances. Keep the explicit Cancel/X working.` },
  { key: 'content-labels-hebrew', files: [`${LIB}/core/labels/curriculum_label_renderer.dart`, `${LIB}/core/labels/curriculum_label_providers.dart`],
    fix: `#8 (P3): ContentSearch result SUBTITLES show English organizational ancestor labels ('Torah','Genesis','Seder Zeraim') even in Hebrew content context. In curriculum_label_renderer.dart \`renderParentForItem\`, the ancestor segments need hebrewNamesPerSegment (mirroring \`renderedDisplayForRef\` in curriculum_label_providers.dart which already resolves Hebrew names). Move/extend the async allItems lookup into \`renderedParentForRef\` (curriculum_label_providers.dart) so it can pass hebrewNamesPerSegment to renderParentForItem. This is a moderate refactor — do it cleanly mirroring the existing renderedDisplayForRef pattern; if you genuinely cannot do it safely, make the smallest correct improvement and explain in notes.` },
  { key: 'pin-subtitle-wire', files: [`${F}/profiles/presentation/widgets/profile_switcher_sheet.dart`],
    fix: `#9 (P3): completes run-3 #19. The profile-switch PIN prompt still says "...access parent settings". At ~line 356 (the showParentPinVerificationDialog call inside _guardEscalating), pass \`subtitle: AppLocalizations.of(context)!.pinDialogSubtitleSwitchProfile\` (the optional param + l10n key already exist from run 3) so the dialog shows switch-profile-appropriate copy.` },
  { key: 'profile-mode-label', files: [`${F}/profiles/presentation/screens/manage_learners_screen.dart`],
    fix: `#10 (P3): Manage Profiles shows "Adult mode"/"Child mode" while the profile-picker sheet shows "Adult"/"Child" — inconsistent. At ~lines 84-86, use the SAME keys the picker uses: \`profileTypeChild\`/\`profileTypeAdult\` (instead of \`childMode\`/\`adultMode\`). Only swap the key references (do NOT remove the old ARB keys — that's out of scope and would touch l10n).` },
  { key: 'account-picker-gap', files: [`${F}/account/presentation/screens/account_picker_screen.dart`],
    fix: `#11 (P3): on a single-account device there's an excessive whitespace gap between the account list and the bottom-pinned "Add another account" CTA. In AccountPickerScreen.build, move \`_BottomAddAccountSection\` to follow the account tiles as content (e.g. into the ListView children after the tiles) and remove the Column/Expanded wrapper that pins it to the screen bottom, so the CTA sits just below the list instead of far below it.` },
  { key: 'reward-preview-placeholder', files: [`${F}/gamification/presentation/screens/reward_configuration_screen.dart`],
    fix: `#12 (P3): the RewardConfig PREVIEW card renders the placeholder reward NAME in brand-navy (looks like real content/a link). In _RewardPreview (~491-570), when the name is empty/placeholder, render the placeholder text (~line 548) in a muted style (e.g. grey, normal weight, italic) instead of the brand-navy real-content style. Derive isPlaceholder from an empty-name check (or add a bool param).` },
];

function fixPrompt(c) {
  return [
    `You are a senior Flutter engineer applying a surgical run-4 audit fix. Cluster: "${c.key}".`, RULES,
    `- The l10n agent already added \`tasksNoOverdueTasksSubtitle\` and ran gen-l10n.`,
    `- Edit ONLY: ${c.files.join(', ')}`, ``, `## Fix`, c.fix, ``,
    `Read the file(s), confirm exact lines, apply the minimal fix, \`dart analyze\` your files.`,
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
  deferred: ['#1 cold-start splash 15s after pm clear — main.dart/bootstrap.dart async-runApp change; high blast radius (app launch), first-run-only cost; deferred for careful manual work'],
};
