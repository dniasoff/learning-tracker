export const meta = {
  name: 'device-e2e-run6-fixes',
  description: 'Fix 22 confirmed run-6 defects: l10n agent first (BiDi/plural/copy + new keys), then parallel widget agents on distinct files (same-file findings clustered)',
  phases: [
    { title: 'l10n', detail: 'ARB BiDi isolates, ICU plural, copy fixes + new keys (pin subtitles, backspace) + gen-l10n' },
    { title: 'widgets', detail: 'parallel fixes on distinct files' },
  ],
}

const REPO = '/home/daniel/repos/learning-tracker';
const LIB = REPO + '/learning_tracker/lib';
const F = LIB + '/features';

const RULES = [
  `## Rules`,
  `- Work in ${REPO}. SURGICAL minimal fixes matching surrounding style. Respect layering lints (DNI-386/387). \`make audit\` must stay green.`,
  `- Edit ONLY your assigned files. Do NOT commit/build-apk/deploy. Do NOT run \`git reset\`/\`git checkout\`.`,
  `- After editing run \`dart analyze <changed files>\` (env: \`export PATH="/home/daniel/flutter/bin:$PATH"; export LD_LIBRARY_PATH="$HOME/.local/lib/sqliteshim:$LD_LIBRARY_PATH"\` from learning_tracker/). Must be clean.`,
  `- If, after reading, you judge a finding BY-DESIGN / not a real bug, make NO change and explain in notes.`,
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
  `You are a senior Flutter + l10n engineer. Apply ALL run-6 ARB changes in BOTH ${LIB}/l10n/app_en.arb and app_he.arb (keep synced, match style/@metadata, correct Hebrew), then \`flutter gen-l10n\` from learning_tracker/ and \`dart analyze\` the l10n dir. No other agent touches l10n.`,
  RULES,
  ``,
  `1. (#12 BiDi) introRewardsSubtitle: the {scholarTier} placeholder (a Hebrew term) absorbs the trailing "!" into its RTL run, so "!" renders on the wrong side. Wrap the placeholder with Unicode LTR-isolate marks U+2066 (⁦) ... U+2069 (⁩): e.g. "...a ⁦{scholarTier}⁩!". (Apply the same isolate technique to any other intro string that interpolates a Hebrew term inside an English sentence ending in punctuation, if obvious.)`,
  `2. (#15 BiDi) searchFieldHint mixes LTR "Search" with an RTL Hebrew curriculum name placeholder — wrap the curriculum-name placeholder in the same U+2066…U+2069 isolate so the layout/punctuation is correct in both locales.`,
  `3. (#17 plural) The Deadline pace projection shows "1 days". Convert the relevant days string (app_en.arb ~line 1739; he ~1572 — find the exact key, e.g. something like goalDeadlineInDays / "{n} days") to an ICU plural: \`{count, plural, =1{1 day} other{{count} days}}\`. Add proper Hebrew plural categories (one/two/many/other as Hebrew requires). Update the placeholder metadata (count: int).`,
  `4. (#19) The "Add another account" button label value starts with a literal "+1   " prefix (app_en.arb ~1091; he too) — strip the "+1   " so the label is just "Add another account" / Hebrew equivalent.`,
  `5. (#22) rewardConfigRewardCreatedBody and rewardConfigRewardUpdatedBody claim the child sees the reward "under Achievements", but that's not where it appears. Remove or correct the navigation claim to match reality (the widget agent will tell you where rewards actually appear if unsure — for now, drop the specific "under Achievements" location claim, keep it generic e.g. "Your child can now redeem this reward.").`,
  `6. (#5 new keys) ADD context-specific PIN-dialog subtitle keys so Edit/Delete/Switch each read correctly: \`pinDialogSubtitleEditProfile\` (en "Enter the PIN to edit this profile."), \`pinDialogSubtitleDeleteProfile\` (en "Enter the PIN to delete this profile."), with Hebrew equivalents. (pinDialogSubtitleSwitchProfile already exists from run-4.)`,
  `7. (#18 new key) ADD \`pinBackspace\` (en "Delete", he "מחק" — or "Backspace"/"מחק ספרה") for the PIN keypad backspace button's accessibility label.`,
  `8. (#2 verify) Confirm an \`addProfile\` key exists (en "Add Profile") for the Manage-Profiles FAB tooltip; if missing, add it.`,
  ``,
  `RETURN schema: cluster="l10n", filesChanged, summary (LIST exact new/changed keys + final signatures), analyzeClean, notes.`,
].join('\n');

const CLUSTERS = [
  { key: 'pin-keypad', files: [`${F}/profiles/presentation/widgets/parent_pin_keypad_dialog.dart`],
    fix: `#10 (P2, RTL bug): the numeric PIN keypad columns are RTL-MIRRORED (renders 3-2-1 instead of 1-2-3) in Hebrew. Numbers must read LTR regardless of locale. In _PinKeypad.build(), wrap the keypad grid Column (the number rows) in \`Directionality(textDirection: TextDirection.ltr, child: ...)\` so digits stay 1-2-3 / 4-5-6 / 7-8-9 left-to-right. Verify it doesn't affect anything that should stay RTL. #18 (P3): the backspace IconButton/Icon (Icons.backspace_outlined, ~line 599) has no a11y label — add \`semanticLabel: AppLocalizations.of(context)!.pinBackspace\` (key added by l10n agent).` },
  { key: 'text-display', files: [`${F}/content_browsing/presentation/screens/text_display_screen.dart`],
    fix: `#16 (P3): the TextDisplay AppBar breadcrumb omits the ROOT curriculum name, so shared seder names are ambiguous (e.g. ברכות exists in multiple curricula). In the app-bar title block (~lines 77-87), prepend the curriculum display name to the chain title (or add a small curriculum chip). The curriculum is resolvable from the ContentItem already resolved in renderedDisplayForRefProvider — add a companion provider (e.g. curriculumRootForRefProvider) or reuse the existing resolution to surface the root name. Keep it clean. #14 (P3): Next/Previous chapter paging shows a blocking "Loading text…" spinner ~8s. After resolving adjAsync (~line 63), add a FIRE-AND-FORGET background prefetch: when adj?.next / adj?.prev is non-null, \`ref.read(textContentProvider(<next/prev ref>).future)\` to warm the SQLite read before the user taps the chevron (don't await; keep provider auto-dispose). Verify no crash if the prefetch fails.` },
  { key: 'signin', files: [`${F}/account/presentation/screens/sign_in_screen.dart`],
    fix: `#7 (P2): on a small screen with the IME keyboard open, the Sign In button + controls are still hidden below the keyboard. The ConstrainedBox (~lines 257-263) minHeight must account for the keyboard: subtract \`MediaQuery.of(context).viewInsets.bottom\` from the available height so the SingleChildScrollView can scroll the CTA into view when the keyboard is up. (Run-3 set minHeight to screen height; refine it to subtract viewInsets so content remains scrollable with the keyboard open.) Verify the CTA is reachable both with and without the keyboard. #11 (P3): a brand-new first-time user sees "Welcome Back!" — add an optional \`isFirstRun\` flag to SignInScreen (~line 294) and show a first-run-appropriate heading (e.g. l10n.signInWelcome if it exists, else a sensible existing greeting) instead of signInWelcomeBack; pass isFirstRun:true from the onboarding entry (AppIntroScreen ~line 126, SignInRoute). If wiring the route arg is too broad, at minimum guard the heading by whether any account/credential has existed before (check what state distinguishes first-run here) and explain in notes.` },
  { key: 'reward-config', files: [`${F}/gamification/presentation/screens/reward_configuration_screen.dart`, `${F}/gamification/presentation/providers/reward_config_controller.dart`],
    fix: `#1 (P2): configured rewards aren't visible on the primary Reward Configuration screen (hidden behind the overflow menu). In reward_configuration_screen.dart build(), when rewards exist, show an inline rewards summary/list (a count + the existing ManageRewardsList, or a compact list) ABOVE the "Configure New Reward" form so parents see existing rewards without discovering the overflow menu. #21 (P3): in reward_config_controller.dart saveReward(), duplicate-named rewards are saved with no disambiguation — before svc.upsertMilestone(), fetch the current curriculum's milestones and if a same-name reward exists, either block with a clear error or disambiguate. Implement the minimal safe guard (prefer surfacing a duplicate-name validation error to the UI over silent creation).` },
  { key: 'content-search', files: [`${F}/content_browsing/data/repositories/content_repository_impl.dart`],
    fix: `#3 (P2, real relevance bug): search "floods" with all descendants of the first matching book because normalizedEn is built from the FULL-PATH displayNameEn, so an ancestor path word (e.g. "Numbers") matches every descendant. In search() (~lines 145-177), restrict the English match text to the item's OWN leaf segment name (not the full ancestor path) so ancestor path words don't infect every descendant. Preserve matching on the item's own name in both Hebrew and English. Test mentally against: searching a book name should return that book / its direct relevant matches, not bury other books' matches.` },
  { key: 'reorder-blank', files: [`${F}/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart`],
    fix: `#4 (P2): reorder list items render BLANK on first arrival (labels invisible until scrolled) because the ListTile title uses an async \`CurriculumLabel.local(item.sefariaRef)\` that hasn't resolved yet. Replace it with a SYNCHRONOUS label: LearningOrderItem already carries displayNameHe/displayNameEn — render item.displayNameHe or item.displayNameEn based on the effective Hebrew-terms setting (read effectiveUseHebrewTermsProvider or the same provider used elsewhere). So labels show immediately.` },
  { key: 'pin-subtitle-context', files: [`${F}/profiles/presentation/widgets/profile_switcher_sheet.dart`],
    fix: `#5 (P2): the PIN dialog subtitle always says "Enter the PIN to switch profiles." even when the action is Edit or Delete. _guardEscalating is shared across switch/edit/delete. Add a subtitle parameter to _guardEscalating (or pass a context enum) and at each call site pass the correct l10n string: pinDialogSubtitleSwitchProfile (switch), pinDialogSubtitleEditProfile (edit), pinDialogSubtitleDeleteProfile (delete) — the edit/delete keys were added by the l10n agent. Wire each call site to its action.` },
  { key: 'upgrade-keyboard', files: [`${F}/settings/presentation/screens/upgrade_to_cloud_screen.dart`],
    fix: `#6 (P2): the CTA button is hidden below the IME keyboard when the email field is focused. Make the form scrollable so the submit button can be brought above the keyboard (mirror the sign_in fix): ensure the body is a SingleChildScrollView whose content min-height accounts for MediaQuery.viewInsets.bottom, OR pin the CTA above the keyboard. Verify the submit button is reachable with the keyboard open on a small screen. (Run-3 added IME submit actions here; this is the layout/reachability gap.)` },
  { key: 'progress-tree-rtl', files: [`${F}/progress/presentation/widgets/curriculum_breakdown_list.dart`],
    fix: `#8 (P2, RTL): in seder-level tree rows the content is right-aligned (RTL) but the progress dot is stranded on the far LEFT, disconnected from its row. In CurriculumBreakdownTreeNode.build() (the row layout), make the progress indicator/dot adjacent to its content under RTL — ensure the Row honours Directionality so the dot sits with the label, not stranded at the opposite edge. Keep LTR correct.` },
  { key: 'tutoring-errors', files: [`${F}/tutoring/presentation/screens/accept_invite_screen.dart`, `${F}/tutoring/presentation/screens/decline_invite_screen.dart`],
    fix: `#9 (P2): a raw Firebase gRPC error code "UNAVAILABLE" is shown to the user as the error body. In the TutorGrantFailure handling in accept_invite_screen.dart (~line 194-198) and decline_invite_screen.dart (same pattern), map raw gRPC/Firebase codes (UNAVAILABLE, etc.) to a friendly localized message (e.g. a "couldn't reach the server, try again" string — reuse an existing friendly-error l10n key if present, like the friendly sign-in fallback used by invite_tutor) instead of surfacing the raw code. Don't leak raw codes.` },
  { key: 'manage-learners-fab', files: [`${F}/profiles/presentation/screens/manage_learners_screen.dart`],
    fix: `#2 (P2 a11y): the Add Profile FAB is absent from the semantics tree. At the FloatingActionButton (~line 30), add \`tooltip: AppLocalizations.of(context)!.addProfile\` so it has an accessible label (key confirmed/added by l10n agent).` },
  { key: 'profile-pills', files: [`${F}/onboarding/presentation/steps/onboarding_profile_creation_step.dart`],
    fix: `#13 (P3): the Nikud/Calendar/Hebrew-Terms segment pills show no visible SELECTED state. In the local pill() builder inside pillPair (~line 161), give the selected pill a high-contrast brand fill — change \`color: selected ? theme.colorScheme.surface : AppTheme.brandOutline\` so selected uses a brand fill (e.g. AppTheme.brandBlue) with white text, matching PreferenceSegmentedTile's selected style. Ensure unselected stays clearly distinct.` },
  { key: 'city-picker', files: [`${F}/sacred_time/presentation/screens/city_picker_screen.dart`],
    fix: `#20 (P3): numeric GeoNames admin1 codes are shown verbatim in city search results + the Shabbos location subtitle (e.g. a raw code instead of a region name). In _subtitleFor (~line 159) and _formatCityLabel (~line ...), suppress/replace numeric-only admin1 codes (e.g. if the admin1 value is all digits, omit it or fall back to country) so users don't see raw codes. Keep real region names.` },
];

function fixPrompt(c) {
  return [
    `You are a senior Flutter engineer applying surgical run-6 audit fix(es). Cluster: "${c.key}".`, RULES,
    `- The l10n agent already applied ARB changes + gen-l10n; referenced l10n keys exist.`,
    `- Edit ONLY: ${c.files.join(', ')}`, ``, `## Fix(es)`, c.fix, ``,
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
};
