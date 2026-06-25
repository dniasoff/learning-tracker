export const meta = {
  name: 'device-e2e-run3-fixes',
  description: 'Fix 21 confirmed run-3 defects (excludes #10 RTL-segmented [contradicted] and #20 dead-route [product decision]): l10n agent first, then parallel widget-fix agents on distinct files',
  phases: [
    { title: 'l10n', detail: 'ARB additions/edits (copy, points, offline warning, siyumim method, PIN subtitle) + gen-l10n' },
    { title: 'widgets', detail: 'parallel fixes on distinct widget files' },
  ],
}

const REPO = '/home/daniel/repos/learning-tracker';
const LIB = REPO + '/learning_tracker/lib';
const F = LIB + '/features';

const RULES = [
  `## Rules`,
  `- Work in ${REPO}. SURGICAL, minimal fixes matching surrounding style. Respect layering lints (DNI-386/387).`,
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
  `You are a senior Flutter + l10n engineer. Apply ALL run-3 localization (ARB) changes, then regenerate. You OWN ${LIB}/l10n/app_en.arb, app_he.arb, and the generated app_localizations*.dart. No other agent touches l10n.`,
  RULES,
  `Make each change in BOTH app_en.arb and app_he.arb (keep synced, match existing style/@metadata; provide correct Hebrew for new strings). After all edits run \`flutter gen-l10n\` from learning_tracker/ and \`dart analyze\` the l10n dir.`,
  ``,
  `1. (#12) FIX \`signInForgotPassword\` — the sign-in password field is labelled "Secret Key", so change the link from "Forgot password?" to match, e.g. en "Forgot your Secret Key?", he equivalent.`,
  `2. (#22) FIX \`redeemScreenCostLabel\` — capitalize "Points" to match \`dashboardPointsValue\` (e.g. en "{points} Points"). Verify the current value first; keep the placeholder.`,
  `3. (#23) The RecentActivity "Points Earned" card subtitle currently uses \`chartTotalTorahPoints\` ("TOTAL TORAH POINTS") which implies an all-time total but the value is range-scoped. ADD a new key (e.g. \`chartPointsEarnedSubtitle\`) with range-accurate wording (en e.g. "POINTS EARNED" or "POINTS THIS PERIOD", he equivalent). (The widget agent will wire it.)`,
  `4. (#13) ADD a new sign-in offline-state hint string (e.g. \`signInOfflineHint\`) — accurate copy for a user on the Sign-In screen while offline (sign-in needs a connection), replacing the misleading "Local account only" banner there. (Widget agent wires it.)`,
  `5. (#17) \`bulkMarkWizardSubtitle\` currently hardcodes "siyumim" in English, ignoring the Hebrew-terms toggle. Change it from a getter to a METHOD taking a \`siyumimTerm\` String placeholder (e.g. "...{siyumimTerm}...") in both ARB files (add the placeholder metadata). (The bulk-mark widget agent will pass \`domainTermLabels(ref).siyumim\`.)`,
  `6. (#19) ADD a new PIN-dialog subtitle string for the PROFILE-SWITCH context (e.g. \`pinDialogSubtitleSwitchProfile\` "Enter the PIN to switch profiles") so the dialog can show context-appropriate copy instead of always "access parent settings". (Widget agent wires it as an optional param.)`,
  `7. (#8) The All-Time stat label leaks the English word "done" when Hebrew domain terms are active. Investigate the relevant key used at recent_activity_screen.dart ~462-469; if a domain-term-aware string/placeholder is needed, add/adjust it so the widget can pass a localized term. (Coordinate: the widget agent will pass domainTermLabels(ref).<term>.)`,
  ``,
  `RETURN schema: cluster="l10n", filesChanged, summary (LIST the exact new/changed keys + their final signatures so widget agents can wire them), analyzeClean, notes.`,
].join('\n');

const CLUSTERS = [
  { key: 'streak-calendar', files: [`${F}/progress/presentation/widgets/streak_calendar.dart`],
    fix: `#1 (P1): on TABLET the streak "today" circle is massively oversized (~174px, fills the column) because the cell sizes to the Expanded slot width. In _DayRow.build, cap the day cell with a ConstrainedBox(constraints: BoxConstraints(maxWidth: 44, maxHeight: 44)) (or similar) inside the Expanded so the circle stays a fixed small size on wide tablet layouts while still centering. Verify it still looks right on phone.` },
  { key: 'study-days', files: [`${F}/tracks/setup/presentation/steps/step_study_days.dart`],
    fix: `#2 (P2): on a small screen (Pixel 2) the Friday (last) row of the study-days list is hidden under the sticky "Continue" button with no scroll affordance. In _StudyDaysEditableState.build (the Expanded ListView.builder ~123-158), ensure the last item isn't fully obscured — add bottom padding to the ListView equal to the sticky button height (so the last row can scroll above it), or otherwise give a clear scroll affordance / peek. Keep it correct on large screens.` },
  { key: 'sign-in', files: [`${F}/account/presentation/screens/sign_in_screen.dart`],
    fix: `#3 (P2): on tablet the sign-in card is left-anchored leaving the right ~64% blank. Wrap the ConstrainedBox(maxWidth: 430) (~line 267) in a Center widget — mirror the existing AN-10 fix in signup_screen.dart (~line 534). #13 (P3): the "Local account only" offline warning shown on the Sign-In screen is misleading. In _effectiveSignInMode (~137-151) / the mode card, use an accurate offline hint (the l10n agent added \`signInOfflineHint\`) for the offline state instead of the local-account-only banner.` },
  { key: 'text-display', files: [`${F}/content_browsing/presentation/screens/text_display_screen.dart`],
    fix: `#4 (P2): during Next/Previous content loading the AppBar title (~line 57) shows the raw Sefaria ref (\`chainAsync.asData?.value ?? sefariaRef.replaceAll('_',' ')\`). Use \`chainAsync.when(...)\` so the LOADING state shows a placeholder (e.g. '…' or a localized loading string) and the raw ref is only a last-resort error fallback — don't flash the underscored raw ref during loading.` },
  { key: 'goal-setup', files: [`${F}/scheduler/presentation/screens/goal_setup_screen.dart`],
    fix: `#5 (P2): the "No deadline" segment label wraps to 2 lines in the 3-segment SegmentedButton (~630-658) — add \`showSelectedIcon: false\` to reclaim width (and/or shorten copy). #6 (P2, data bug): in Pace mode an EMPTY pace field silently commits a stale value. In the pace onChanged (~444-449) and the submit onPressed guard (~677-679), treat empty/invalid pace as invalid: disable submit (or validate in _submit) so a blank pace can't commit a stale number. #18 (P3): in Deadline mode the Update button stays enabled when a PAST date is selected — also disable when _goalType=='deadline' && _targetDate != null && _targetDate!.isBefore(now); and pass a firstDate: now constraint to the Hebrew date picker (~line 256) to match the English picker.` },
  { key: 'switcher-id', files: [`${F}/app/router/app_shell.dart`],
    fix: `#7 (P2) + #21 (P3): the ProfileSwitcherBar (~line 458) shows the raw synthetic offline account id/email (e.g. "offline_1a95...@offline.local") instead of a human-readable label — including at cold start when no profile is selected. Add \`&& !authUser.email.endsWith('@offline.local')\` to the email-display condition (mirror the run-2 offline-email suppression), and ensure the no-profile/cold-start branch never renders the synthetic id (show a neutral label or nothing).` },
  { key: 'recent-activity', files: [`${F}/progress/presentation/screens/recent_activity_screen.dart`],
    fix: `#8 (P2): an English "done" leaks into the All-Time stat label (~462-469) when Hebrew domain terms are active — pass the localized domain term (domainTermLabels(ref).<appropriate term>) instead of the hardcoded English, using whatever key the l10n agent set up. #23 (P3): the "Points Earned" card subtitle (~line 156) uses \`chartTotalTorahPoints\` ("TOTAL TORAH POINTS") implying an all-time total though the value is range-scoped — switch it to the new range-accurate key the l10n agent added (e.g. \`chartPointsEarnedSubtitle\`).` },
  { key: 'invite-tutor', files: [`${F}/tutoring/presentation/screens/invite_tutor_screen.dart`],
    fix: `#9 (P2): LOCAL-ONLY (offline) users get a generic "retry" error on invite that can never succeed (inviting a tutor requires a cloud account). In _sendInvite / _friendlyInviteError, add a LOCAL-ONLY precondition: if the account is local-born/offline, show a clear, accurate message (e.g. "Tutoring requires a cloud account — upgrade to invite a tutor") and don't present a futile retry. Detect offline/local-born the same way other screens do (e.g. the @offline.local / isLocalOnly predicate).` },
  { key: 'hierarchy-panel', files: [`${F}/content_browsing/presentation/widgets/hierarchy_selection_panel.dart`],
    fix: `#11 + #14 (P3): the "Mark Completed" primary action button text wraps to two lines (bottom action Row ~318-342; OutlinedButton ~326 and FilledButton ~337). Add \`maxLines: 1, overflow: TextOverflow.ellipsis\` to the button Text children, and/or reduce the row's horizontal padding/gap so both buttons fit on one line on small screens.` },
  { key: 'intro-contrast', files: [`${F}/onboarding/presentation/widgets/intro_mishna_page.dart`],
    fix: `#15 (P3): the onboarding carousel progress indicator (IntroMishnaProgressBar ~151-191) is nearly invisible (fill 0xFFB8C0CC on a light bg). Raise its contrast — change the fill to the same green as page 1 (0xFF1DB97D) or another sufficiently-contrasting token so the progress affordance is visible.` },
  { key: 'intro-gap', files: [`${F}/onboarding/presentation/screens/app_intro_screen.dart`],
    fix: `#16 (P3): on tablet, the SETUP PROGRESS bar sits with a large empty gap below it (the hero height cap leaves dead space). In _buildDailyPlanBottomAnchored, relax the fixed maxHero ceiling for tall/tablet viewports (e.g. clamp to a fraction of maxHeight rather than a hard 320), or add a Spacer to distribute the blank space so the layout isn't bottom-gapped on tablet. Keep phone layout intact.` },
  { key: 'bulk-mark', files: [`${F}/onboarding/presentation/screens/bulk_mark_screen.dart`],
    fix: `#17 (P3): the wizard subtitle (~line 488) renders "siyumim" in English ignoring the Hebrew-terms toggle. The l10n agent changed \`bulkMarkWizardSubtitle\` into a method taking a \`siyumimTerm\` placeholder — update the call site to pass \`domainTermLabels(ref).siyumim\` (read how domainTermLabels is obtained elsewhere; it needs ref).` },
  { key: 'pin-subtitle', files: [`${F}/profiles/presentation/widgets/parent_pin_keypad_dialog.dart`],
    fix: `#19 (P3): the PIN dialog subtitle always says "...access parent settings" even when the action is switching profiles. Add an OPTIONAL subtitle parameter to showParentPinVerificationDialog (default = the existing parent-settings copy) so callers can pass context-appropriate copy; for the profile-switch caller, pass the new l10n string \`pinDialogSubtitleSwitchProfile\` (added by the l10n agent). Only edit THIS file (the dialog); if the switch call site is elsewhere, note it in your return (a follow-up agent isn't available, so if the call site is in this file's API surface, wire it; otherwise just add the optional param + default and report the call-site location).` },
];

function fixPrompt(c) {
  return [
    `You are a senior Flutter engineer applying a surgical run-3 audit fix. Cluster: "${c.key}".`,
    RULES,
    `- The l10n agent already added/updated ARB keys and ran gen-l10n, so referenced l10n keys exist.`,
    `- Edit ONLY: ${c.files.join(', ')}`,
    ``, `## Fix(es)`, c.fix, ``,
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
  l10n: l10n ? { summary: l10n.summary, clean: l10n.analyzeClean, notes: l10n.notes } : null,
  clusters: results.map(r => ({ key: r.cluster, files: r.filesChanged, clean: r.analyzeClean, summary: r.summary, notes: r.notes })),
  filesChanged: changed,
  analyzeIssues: issues.map(r => ({ cluster: r.cluster, notes: r.notes })),
  excluded: ['#10 RTL segmented controls (contradicted between runs; reverse-order fix would break LTR — manual review)', '#20 dead CurriculumSettings route (product decision: wire vs remove)'],
};
