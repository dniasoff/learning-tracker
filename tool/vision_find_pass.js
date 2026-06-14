export const meta = {
  name: 'vision-find-pass',
  description: 'Reusable vision deep-pass over a batch of screens (passed via args). Each agent navigates to its screen, drives the permutation matrix, captures+downscales+VISUALLY JUDGES a screenshot per state against a human rubric, checks term correctness against the domain oracle, and runs adversarial probes. Read-only FINDING pass with screenshot evidence. Runs screens in rounds of 3 (one per device).',
  phases: [{ title: 'DeepPass', detail: 'vision+oracle+exploration audit of the batch screens' }],
}

const ADB = '/home/daniel/bin/adb'
// EDIT THIS BLOCK PER BATCH (args wiring unavailable for scriptPath runs)
const BATCH = 'DSWEEP'
// ===== FULL REGRESSION SWEEP after the deferred-item fix wave (build 4e075e8a) =====
// HOST-CONTENTION LESSON: run only 2 devices concurrently (5556 EN cloud, 5558
// native Hebrew). Rounds of 2 (see the i += 2 loop below). 5554 is dead.
const SCREENS_FR1_ARCHIVED = [
  // ===== FINAL FULL RESWEEP — cross-cutting regression hunt over the most-fixed surfaces on build 5b3eeede =====
  // Device states: 5554=API34 English, cloud "Loop Test A" (RedeemKid/PinKid/Daniel + Talmid LoopChild);
  //                5556=API36 tablet English, same cloud account; 5558=API29 NATIVE HEBREW, child LoopChild dashboard.
  // ROUND 1
  { slug: 'fr_settings_root', serial: 'emulator-5554', nav: 'Settings root (Adult/Parent mode → Settings tab → SettingsScreen). This is the keystone of the device-language change: VERIFY there is NO "App Language" tile (intentional). Audit EVERY tile: Calendar Preference, Nusach, Hebrew Terms toggle, Notifications, Display/font, Backup & Sync card, Manage Tracks/Goals, Tutors, About. All fully localized, none clipped at font 1.3, icons render (no blank discs). Then `cmd locale set-app-locales com.jcom.torah.learning_tracker --locales he`, relaunch, re-audit the whole list in Hebrew RTL (mirrored chrome, translated tiles, domain terms in Hebrew script), then RESET `--locales \'\'`.', controls: 'every settings tile, Backup&Sync card, Hebrew-terms toggle, Nusach picker, font 1.3, en+he' },
  { slug: 'fr_lifetime_collision', serial: 'emulator-5556', nav: 'Lifetime Knowledge (Adult/Parent → pick a child with data e.g. RedeemKid/PinKid → Progress → Lifetime Knowledge). PRIMARY GOAL: confirm the bare-daf collision fix held — percentages/counts must be SANE (marking one unit credits ONLY its own scope, not an inflated cross-scope total). Drill the tree: folder rows, node states full/partial/none, provenance labels (live/bulk/lifetime). Nusach-correct names (one spelling). font 1.3, no clip.', controls: 'curriculum cards, learned %/counts, drill tree, node states, provenance labels' },
  { slug: 'fr_child_gamification_he', serial: 'emulator-5558', nav: 'NATIVE-HEBREW child dashboard + gamification (device is already Hebrew; LoopChild child mode is showing). Audit the child Dashboard (points/known-total/siyumim/streak stat cards, the points balance hero, the bottom nav) AND open My Achievements via the streak/flame chip. Everything Hebrew RTL, domain terms (נקודות/חזרה/סיומים/רצף) in Hebrew SCRIPT, mirrored layout, no clipping, no English leak, no stale/lingering state. Check count pluralization and that 0-states read correctly in Hebrew.', controls: 'stat cards, points hero, bottom nav, My Achievements, badges, RTL, font 1.3' },
  // ROUND 2
  { slug: 'fr_upgrade_cloud_backup', serial: 'emulator-5554', nav: 'Backup & Sync section + Upgrade to Cloud (Settings → Backup & Sync card → review the card itself incl. "Last synced" relative-time string → then "Upgrade to Cloud" button → UpgradeToCloudScreen). This whole cluster was just localized — verify NO raw error tokens, NO untranslated keys, relative-time ("X minutes ago") localized. Audit value-prop copy, sign-in/Google buttons, benefit list/icons, error states. Then test Hebrew via `cmd locale set-app-locales com.jcom.torah.learning_tracker --locales he`, relaunch, re-audit (no English leak, RTL), RESET `--locales \'\'`. font 1.3.', controls: 'Backup&Sync card, last-synced relative time, value-prop, sign-in buttons, benefit list, error states, en+he' },
  { slug: 'fr_manage_tracks_redeem', serial: 'emulator-5556', nav: 'TWO screens on this device. (A) Track Management Hub (Settings → Manage Tracks): active/archived list, add-track CTA, per-track edit/archive/delete, status chips, counts pluralization, nusach-correct names, safe delete confirm. (B) Then Rewards/Redeem (child context → Rewards / "Redeem" → RedeemScreen): verify the screen TITLE is correct (the Hebrew title was fixed to מימוש פרסים — test by `cmd locale set-app-locales com.jcom.torah.learning_tracker --locales he` then reset), points balance, reward cards, redeem-guard when insufficient points. font 1.3, no clip.', controls: 'track rows, add/edit/archive/delete, status chips; redeem title, reward cards, points balance, redeem guard, en+he' },
  { slug: 'fr_lifetime_marking_he', serial: 'emulator-5558', nav: 'NATIVE-HEBREW Lifetime Knowledge + Lifetime Marking (need Adult/Parent mode — switch from child via the mode chip + Parent PIN 2580; if it stays child-locked, audit whatever Progress view IS reachable and say so). Audit Lifetime Knowledge tree in Hebrew (collision fix → sane counts; Hebrew-script domain terms; counts gematriya where designed) AND the Lifetime Marking screen (the scope-id collision fix touched its question ids): select units across levels, verify marking writes/credits the right scope, no duplicate/ghost selection, Hebrew labels correct. font 1.3.', controls: 'lifetime tree, learned counts, drill levels, lifetime-marking selection, scope credit, RTL, gematriya' },
  // ROUND 3
  { slug: 'fr_profile_account_picker', serial: 'emulator-5554', nav: 'Profile picker / "Who is learning?" (the multi-profile chooser shown on this cloud account: RedeemKid/PinKid child cards, Daniel adult card, Add Profile, and the TALMID PROFILES section with LoopChild). Verify: the account picker subtitle/copy reads "Select an account" (NOT "Select a learner") where it picks an ACCOUNT; Child/Adult mode badges correct; Talmid section renders with the right owner/tutor labels (no "CloudUser" placeholder leak). Then `cmd locale ... --locales he`, relaunch, re-audit Hebrew RTL, RESET. font 1.3, no clip.', controls: 'profile cards, mode badges, Add Profile, Talmid section, account-picker copy, en+he' },
  { slug: 'fr_tutor_cluster', serial: 'emulator-5556', nav: 'Tutor owner/parent surfaces (Adult/Parent mode → Tutors / Manage Tutors → ManageTutorsScreen). Audit the per-child grants list (LoopChild grant to test-loop-a should read ACTIVE, owner display name NOT "CloudUser"), pull-to-refresh works, Invite Tutor form (email field shows inline validation on a malformed address), and the Tutor Audit Log filter chips (leading chip not RTL-clipped — test via `cmd locale ... --locales he` then reset). No stale "Pending". font 1.3, no clip.', controls: 'grants list, active/owner-name, pull-to-refresh, invite-email inline validation, audit-log filter chips, en+he' },
  { slug: 'fr_text_reader_he', serial: 'emulator-5558', nav: 'NATIVE-HEBREW Text Display / reader (LoopChild → a track → Start Learning / Today\'s task → the daf/mishna/pasuk text reader, TextDisplayScreen). If LoopChild has no active track, add a self-paced Mishnayos track first or use any reachable track. Audit: Hebrew text body (nikud per pref), the AppBar breadcrumb chain (nusach-correct, NOT clipped, RTL), prev/next arrows (mirrored), and the bottom mark-complete / next-task buttons NOT clipped by the nav-bar inset (recently SafeArea-fixed). font 1.3.', controls: 'text body, nikud, AppBar breadcrumb, prev/next arrows, mark-complete/next buttons, RTL safe-area' },
]

const SCREENS = [
  // ===== DSWEEP: broad regression pass after the deferred-item fixes =====
  // 2 devices only (host-contention lesson). Rounds of 2 (i += 2 loop). Each
  // agent ALSO double-checks the FR1 fixes still hold (no regression).
  // ROUND 1
  { slug: 'ds_track_detail_en', serial: 'emulator-5556', nav: 'Track detail + add-track ESTIMATE consistency (English). Adult/Parent mode → Manage Tracks. If no track exists, ADD one: Talmud Bavli, self-paced, full scope, goal pace = 7 per week using the COARSE unit (דף/daf, NOT amud). On the wizard pace step (step 6) NOTE the "Estimated finish" date. Create the track, open its Track Detail, and read the "Est. finish" row. PRIMARY CHECK (deferred fix #1): the two dates must now AGREE (same year, ~2033 — NOT an ~8-year-later ~2041). Report both dates. Also audit the detail card: Items remaining, Goal row, progress labels, no clipping at font 1.3.', controls: 'add-track wizard pace step estimate, track-detail Est. finish, items remaining, goal row, font 1.3' },
  { slug: 'ds_dashboard_he', serial: 'emulator-5558', nav: 'NATIVE-HEBREW child dashboard regression (LoopChild). Audit the dashboard: stat cards (נקודות/ידע כולל/סיומים/רצף), points hero, statistics, today-missions, bottom nav — all Hebrew RTL, domain terms Hebrew SCRIPT, no English leak, no clipping, correct pluralization. Then open My Achievements via the red flame chip (top-left header) and confirm the progress-hero badge does NOT overlap the header (FR1 RTL fix) and the activity-calendar weekday headers are Hebrew letters (NOT Mon/Tue/Wed). font 1.0 + 1.3.', controls: 'stat cards, points hero, bottom nav, My Achievements badge, activity-calendar weekday headers, RTL, font 1.3' },
  // ROUND 2
  { slug: 'ds_track_mgmt_delete_en', serial: 'emulator-5556', nav: 'Track management + DELETE behaviour (English) — deferred fix #2. In Manage Tracks: with the profile having 2+ active tracks, open a track → Delete Track → CONFIRM the Archive/Delete dialog appears (Archive keep history / Delete and wipe / Cancel) and works. Then get the profile down to its LAST/SOLE active track and tap Delete Track → it must show "At least one curriculum must remain active" explanation IMMEDIATELY (no Archive/Delete dialog offered — the old "offered then refused" bug). Report both behaviours. font 1.3.', controls: 'Delete Track dialog (multi-track), sole-track guard explanation, archive/wipe options, no offered-then-refused' },
  { slug: 'ds_parent_pin_he', serial: 'emulator-5558', nav: 'NATIVE-HEBREW parent-PIN error (deferred fix #3). Trigger the Parent PIN entry/verify (e.g. switch child→parent via the mode chip, or Settings parent gate). Enter a WRONG 4-digit PIN. PRIMARY CHECK: the error must render in HEBREW (קוד שגוי) — NOT the raw English "Incorrect PIN". Also try the change-PIN confirm-mismatch path if reachable (should show הקודים אינם תואמים, not "PINs do not match"). Report exactly what error text appears. Then enter the correct PIN 2580 to proceed. No English leak in the PIN UI.', controls: 'parent PIN keypad, wrong-PIN error (Hebrew), mismatch error, no English error leak' },
  // ROUND 3
  { slug: 'ds_settings_he', serial: 'emulator-5556', nav: 'Settings root regression (English + Hebrew via cmd-locale). Adult/Parent → Settings. Verify NO "App Language" tile (intentional), every tile localized + icons render, Backup&Sync card. Then `cmd locale set-app-locales com.jcom.torah.learning_tracker --locales he`, relaunch, re-audit Hebrew RTL (translated tiles, domain terms Hebrew script), RESET `--locales \'\'`. font 1.3, no clipping.', controls: 'all settings tiles, no app-language tile, Backup&Sync, en+he, font 1.3' },
  { slug: 'ds_font_scale_he', serial: 'emulator-5558', nav: 'FONT-SCALE verification (deferred item #4) on the NATIVE-HEBREW device + Lifetime screens. FIRST capture a Lifetime Knowledge screen (Parent mode PIN 2580 → Progress → ידע כולל, drill the tree) at font_scale 1.0. THEN set `settings put system font_scale 1.3`, force-stop + relaunch the app, re-capture the SAME screen. PRIMARY CHECK: the text must be VISIBLY LARGER at 1.3 than at 1.0 (confirming the app honors OS font scaling; the FR1 "1.3 not honored" note was suspected to be a test-env artifact). Report whether text grew, with both screenshots. Also confirm Hebrew tree labels render Hebrew script (regression of the FR1 Hebrew-label fix). RESET `settings put system font_scale 1.0` when done.', controls: 'lifetime tree at 1.0 vs 1.3 (does text grow?), Hebrew labels, font-scale honored' },
]

const RUBRIC = `VISION RUBRIC — for EVERY screenshot, judge it like a human and report each YES as a finding:
 - Text clipped / ellipsized / cut off; word broken mid-word (e.g. "IceCre/am")?
 - RenderFlex overflow stripes or content off any edge?
 - Text with too-low contrast to read; icon rendered as a blank disc with no glyph?
 - Overlapping / mis-aligned elements; tap targets colliding?
 - Element half-off-screen, mispositioned, wrong size?
 - Leftover/lingering/wrong state (filled PIN dots after submit, stuck spinner, stale banner, placeholder)?
 - A value that is NONSENSE (a name where a date belongs, an internal id like "level N", a raw exception string)?
 - Wrong account/profile/mode for the context; a parent-only surface under a child badge; half-translated UI?
 - Pluralization wrong for count=1 ("1 study days", "1 Items learned", "1 Masechta")?`

const ORACLE = `DOMAIN ORACLE (check rendered curriculum/term labels — "present" != "correct"):
 - Ashkenazi transliteration uses -os/-oh (Berakhos, Mishnayos, Shabbos); Sephardi uses -ot (Berakhot, Mishnayot).
 - The SAME masechta must not render in two different nuschaos on one screen.
 - English-mode (transliteration) labels must NOT contain Hebrew-script characters (U+0590–U+05FF) unless intended.
 - Hebrew-terms toggle ON shows Hebrew script for domain terms (מסכת etc.); flipping it must change the rendered term.
 - Track-created toast / labels must use transliteration, never the English translation ("Genesis" is wrong; it's Bereishis/Bereshit).
 - In Hebrew-script mode, counts should be gematriya, not Arabic digits, where the design calls for it.`

const KNOWN = `REDO / VERIFICATION PASS: the app follows the DEVICE language. There is INTENTIONALLY NO in-app language
switcher (a product decision) — do NOT flag the absence of an "App Language" tile in Settings; that is correct.
(The "Calendar Preference" English/Hebrew tile selects the DATE system, not the UI language — also correct.)
TO TEST HEBREW RTL: set the device/per-app locale to Hebrew, do NOT look for an in-app toggle.
  · Fast (API 33+ devices, e.g. emulator-5554): \`timeout 30 ${ADB} -s SERIAL shell cmd locale set-app-locales
    com.jcom.torah.learning_tracker --locales he\`, relaunch the app, verify Hebrew RTL; RESET with \`--locales ''\`.
  · If \`cmd locale\` is unavailable (API < 33), skip the Hebrew-locale check and say so (do NOT flag it).
When the device IS Hebrew: the whole UI must be Hebrew RTL (mirrored chrome, translated nav) AND domain terms
(מסכת/חזרה/סיומים) must render in Hebrew SCRIPT. Brand/proper nouns (Firebase, Torah Study Tracker) stay Latin.
ALSO drive: Hebrew-TERMS toggle, Nusach (Ashkenazi/Sephardi), large text (1.3), data states, exploration probes.
KNOWN-DEFERRED — do NOT report these as findings (they are intended/product-decisions or pending external work):
 - NO in-app App Language switcher exists (UI follows the device language) — intentional, do NOT flag.
 - local-vs-cloud onboarding choice is gated by network reachability (network present → cloud), no manual toggle —
   INTENDED (Daniel confirmed). Do NOT flag.
 - add-track wizard step-count denominator branches (6 → 7 → 4) by path — this is INTENDED, pinned by TS-11 tests
   (program reveals a step then auto-skips scope/study-days/goal). Do NOT re-flag the changing denominator.
 - Kodshim renders with slightly different Hebrew spelling (קודשים vs קדשים) between a Bavli vs Mishnayos track —
   originates in content-DB displayNameHe data; asset-regen pending. Do NOT re-flag.
 - curriculum-settings scope count "11 Masechta" uses the singular level-noun for >1 — DEFERRED (needs a per-nusach
   plural-forms table Masechtos/Sefarim/Perakim). Do NOT re-flag.
 - the Notification-Settings tile icon uses a saturated red disc vs the pastel palette — known minor, do NOT re-flag.
 - transient ghost/flash frames during font-scale re-layout or first paint (e.g. a Hebrew label flashing before it
   resolves to transliteration) are transient and NOT defects — do NOT report transient single-frame artifacts.
 - mixed-script rows (Hebrew domain term beside English chrome) IN ENGLISH MODE — documented design split (product).
 - daily "TODAY DUE" is a rolling queue that stays constant; daf completion clears both amudim — product-decisions.
 - points-but-no-rewards "doing great" empty state; single-member siyum aggregate; filtered-streak headline — product-decisions.
 - Manage Goals == Manage Tracks destination; prev-chevron disabled after complete; auth copy voice — product-decisions.
 - city subtitle still shows raw GeoNames code "NN" (the build SCRIPT is fixed; the cities.sqlite ASSET regen is
 - add-track wizard step-count denominator branches (6 → 7 → 4) by path — this is INTENDED, pinned by TS-11 tests
   (program reveals a step then auto-skips scope/study-days/goal). Do NOT re-flag the changing denominator.
 - Kodshim renders with slightly different Hebrew spelling (קודשים vs קדשים) between a Bavli vs Mishnayos track —
   originates in content-DB displayNameHe data; asset-regen pending. Do NOT re-flag.
 - curriculum-settings scope count "11 Masechta" uses the singular level-noun for >1 — DEFERRED (needs a per-nusach
   plural-forms table Masechtos/Sefarim/Perakim). Do NOT re-flag.
 - when the UI language is Hebrew, the Hebrew-Terms toggle is intentionally hidden (terms already render in Hebrew) —
   product-decision pending Daniel. Do NOT re-flag the "missing toggle".
 - the Notification-Settings tile icon uses a saturated red disc vs the pastel palette — known minor, do NOT re-flag.
 - transient ghost/flash frames during font-scale re-layout or first paint (e.g. a Hebrew label flashing before it
   resolves to transliteration) are transient and NOT defects — do NOT report transient single-frame artifacts.
 - mixed-script rows (Hebrew domain term beside English chrome) — documented design split (product-decision).
 - daily "TODAY DUE" is a rolling queue that stays constant; daf completion clears both amudim — product-decisions.
 - points-but-no-rewards "doing great" empty state; single-member siyum aggregate; filtered-streak headline — product-decisions.
 - Manage Goals == Manage Tracks destination; prev-chevron disabled after complete; auth copy voice — product-decisions.
 - city subtitle still shows raw GeoNames code "NN" (the build SCRIPT is fixed; the cities.sqlite ASSET regen is
   pending a GeoNames source download — known, do not re-flag).
 - a11y labels still missing on Point-Config steppers / Add-Learner FAB / Invite-Tutor email; content-search Ashkenazi
   aliases — known leftovers, do not re-flag.
REPORT ONLY: (a) confirmation the screen is now visually/semantically clean, (b) any NEW issue or REGRESSION the
63 fixes introduced, (c) any prior CONFIRMED bug that is STILL present (a fix that did not take on-device).`

const VISION_HOW = `HOW TO SEE (the whole point): 1) \`timeout 30 ${ADB} -s SERIAL exec-out screencap -p > /tmp/audit/SLUG_full.png\`
2) downscale (REQUIRED): \`convert /tmp/audit/SLUG_full.png -resize 1024x1024\\> -strip /tmp/audit/SLUG.png\`
3) Read the DOWNSCALED /tmp/audit/SLUG.png (never the _full) to SEE it, then apply the rubric. Unique SLUG per state.
Keep the /tmp/audit PNG paths as evidence in your report. (mkdir -p /tmp/audit first.)`

const PROBES = `ADVERSARIAL PROBES (run those that apply): junk/empty/huge input into fields; rapid back-to-back taps (no settle)
on buttons / PIN keypad; start a flow then background (\`input keyevent KEYCODE_HOME\`) and resume; for any
counter/list/balance — perform a state-changing action and RE-READ the SAME element (staleness); Back-button mid-flow
(does it discard data?). Reset font_scale to 1.0 when done.`

const FINDING_SCHEMA = {
  type: 'object',
  required: ['screen', 'device', 'permutationsCovered', 'findings', 'controlsExercised', 'summary'],
  properties: {
    screen: { type: 'string' }, device: { type: 'string' },
    permutationsCovered: { type: 'array', items: { type: 'string' } },
    controlsExercised: { type: 'array', items: { type: 'string' } },
    findings: { type: 'array', items: { type: 'object',
      required: ['title', 'sense', 'severity', 'permutation', 'evidence', 'detail'],
      properties: {
        title: { type: 'string' },
        sense: { type: 'string', enum: ['vision', 'domain-oracle', 'exploration', 'logic'] },
        severity: { type: 'string', enum: ['P0', 'P1', 'P2'] },
        permutation: { type: 'string' },
        evidence: { type: 'string' }, detail: { type: 'string' } } } },
    summary: { type: 'string' },
    blocked: { type: 'string', description: 'if the screen could not be reached, why' },
  },
}

const briefFor = (s) => `You are a VISION-EQUIPPED screen auditor on device ${s.serial}. Audit ONE screen EXHAUSTIVELY: ${s.slug}.
NAVIGATE: ${s.nav}
CONTROLS to exercise (every one): ${s.controls}
This is a read-only FINDING pass — do NOT edit code. Find what a text-only loop misses, with EYES.
mkdir -p /tmp/audit. Wrap every adb call in \`timeout 30\`. Foreground the app first; relaunch if focus leaves it.
If you cannot reach the screen (needs a state you can't construct), set blocked and report what's needed.
${VISION_HOW}
${RUBRIC}
${ORACLE}
${KNOWN}
${PROBES}
METHOD: for each applicable permutation (data state × nusach × hebrew-terms toggle × font 1.0/1.3), set the levers,
capture → downscale → Read the downscaled PNG → apply the rubric → record findings with the screenshot path as
evidence; also run the oracle check and the probes. A clean screen is suspicious — look harder (transient frames,
large text, populated vs empty). Return ONLY the structured report.`

phase('DeepPass')
const reports = []
// run in rounds of 2 (only 2 healthy devices — host-contention lesson), one
// agent per device per round, sequential rounds to keep host load manageable.
for (let i = 0; i < SCREENS.length; i += 2) {
  const round = SCREENS.slice(i, i + 2)
  const r = await parallel(round.map(s => () =>
    agent(briefFor(s), { label: `b${BATCH}:${s.slug}`, phase: 'DeepPass', schema: FINDING_SCHEMA })))
  reports.push(...r.filter(Boolean))
  log(`Batch ${BATCH}: round ${i / 2 + 1} done (${round.map(s => s.slug).join(', ')}).`)
}

const allFindings = reports.flatMap(r => (r.findings || []).map(f => ({ screen: r.screen, ...f })))
const bySev = {}, bySense = {}
for (const f of allFindings) { bySev[f.severity] = (bySev[f.severity] || 0) + 1; bySense[f.sense] = (bySense[f.sense] || 0) + 1 }
log(`Batch ${BATCH}: ${reports.length} screens, ${allFindings.length} findings. Severity ${JSON.stringify(bySev)}, sense ${JSON.stringify(bySense)}.`)
return { batch: BATCH, screens: reports.length, totalFindings: allFindings.length, bySeverity: bySev, bySense, reports }
