export const meta = {
  name: 'vision-find-pass',
  description: 'Reusable vision deep-pass over a batch of screens (passed via args). Each agent navigates to its screen, drives the permutation matrix, captures+downscales+VISUALLY JUDGES a screenshot per state against a human rubric, checks term correctness against the domain oracle, and runs adversarial probes. Read-only FINDING pass with screenshot evidence. Runs screens in rounds of 3 (one per device).',
  phases: [{ title: 'DeepPass', detail: 'vision+oracle+exploration audit of the batch screens' }],
}

const ADB = '/home/daniel/bin/adb'
// EDIT THIS BLOCK PER BATCH (args wiring unavailable for scriptPath runs)
const BATCH = 'E2E-R4'
const SCREENS = [
  // ===== E2E ITERATION 4 — RE-VERIFY P0 read-time fix + re-run rate-limited screens + P1 re-verify =====
  // ROUND 1
  { slug: 'r4_p0_tanach_reverify_he', serial: 'emulator-5558', nav: 'NATIVE-HEBREW Lifetime Knowledge P0 RE-VERIFY (read-time synthetic-container filter just shipped; the stale tanach/level1/Torah ledger row may still exist on disk but must now be IGNORED). Parent mode (PIN 2580) → Progress → ידע כולל. VERIFY THE OVER-COUNT IS GONE: (1) תנ"ך (Tanach) total now ≈ standalone חומש (Chumash) total (~1533), NOT 5846; (2) expanding תנ"ך→תורה shows ONLY בראשית green, שמות/ויקרא/במדבר/דברים GREY (matching standalone Chumash); (3) Lifetime MARKING: the תורה parent renders INDETERMINATE/dash (partial), NOT a full green check, when only Bereishis is marked; (4) headline "פריטים נלמדו" dropped to ~1542 (no longer ~5852); (5) the CHILD home "ידע כולל" and the PARENT Progress card now AGREE (~1542 both), no 4× disagreement. Report exact numbers. font 1.3.', controls: 'Tanach total == Chumash ~1533, Torah tree only-Bereishis, marking parent partial, headline ~1542, child==parent' },
  { slug: 'r4_content_hierarchy_en', serial: 'emulator-5556', nav: 'ENGLISH content browsing/hierarchy (rate-limited last round — re-run). Browse the full content tree for a multi-level curriculum (Talmud Bavli: seder → masechta → daf → amud): breadcrumb chain + chevron separators (LTR), drill down/up, select/expand states. Open a leaf in the reader via free-browse. No clip, sane transliterated labels, breadcrumb not truncated. font 1.0 + 1.3.', controls: 'content tree drill, breadcrumb + separators, select/expand, free-browse reader, transliteration, font 1.3' },
  { slug: 'r4_city_picker_browse_en', serial: 'emulator-5560', nav: 'ENGLISH city-picker + content-search (rate-limited last round — re-run). (A) City picker (Settings → location/zmanim city): search a city, result rows (subtitle should be a place name, NOT a raw GeoNames code "NN"), selection. (B) Content Search: search a term, result rows (avoid context-free duplicated leaf rows), Ashkenazi alias handling. font 1.3.', controls: 'city search + subtitle (no raw code), selection; content search results + aliases, font 1.3' },
  // ROUND 2
  { slug: 'r4_reorder_markprior_he', serial: 'emulator-5558', nav: 'NATIVE-HEBREW i18n RE-VERIFY (two fixes shipped). (A) Track learning-order REORDER screen (Settings → Manage Tracks → a track → Learning Order / Reorder): the AppBar title must be fully Hebrew (e.g. "<תכנית> • סדר מחדש"), NO English "Reorder". (B) Mark-Prior-Completions picker (add a track → "mark prior learning", or the prior-learning entry): the screen TITLE and the selection HEADING must be Hebrew ("סימון לימוד קודם — …" / "בחרו תוכן שכבר למדתם"), no English. font 1.3, RTL.', controls: 'reorder title he (no "Reorder"), mark-prior title+heading he, RTL, font 1.3' },
  { slug: 'r4_point_config_en', serial: 'emulator-5556', nav: 'ENGLISH point-configuration (rate-limited last round — re-run). Parent mode → Settings → Points/Reward config → point-per-task configuration: per-stage point steppers (Learn vs Chazara), "set how many points" copy, pluralization (1 point), a11y on steppers; any reward-strategy/sacred-milestone point settings. Localized, no clip, font 1.3. (If a Google account mismatch blocks it, report blocked + what you saw.)', controls: 'point-per-task steppers, stage points, plurals (1 point), strategy settings, font 1.3' },
  { slug: 'r4_studydays_snackbar_en', serial: 'emulator-5560', nav: 'ENGLISH 0-study-days snackbar RE-VERIFY (clip fix shipped) + study-days config. Edit a track (Manage Tracks → track → Edit) and set ZERO study days, save → the warning SNACKBAR must show its FULL message (not clipped off-screen) at font scale 1.3. Also audit the Study Days config screen (weekday toggles, abbreviations, footer plural). font 1.0 + 1.3.', controls: 'zero-study-days snackbar full message @1.3, study-days toggles, footer plural' },
  // ROUND 3
  { slug: 'r4_learning_order_he', serial: 'emulator-5558', nav: 'NATIVE-HEBREW learning-order (rate-limited last round — re-run). The whole-curriculum / track learning-order screen (Parent mode, PIN 2580). Reorder items, "Reset to Default Order" (confirm the list refreshes — prior race fix), drag handles, Hebrew labels nusach-correct, RTL. font 1.3.', controls: 'learning-order list, reorder/drag, reset-to-default refresh, RTL labels, font 1.3' },
  { slug: 'r4_siyumim_progress_en', serial: 'emulator-5556', nav: 'ENGLISH Progress sub-screens NEW + carry-over. (A) Siyumim & Milestones screen (empty + any populated state). (B) Re-check the cross-surface Lifetime percent: the SAME track\'s lifetime % should be consistent between the Progress hub row and the track-detail/lifetime screens (iter-4 saw 0.2% vs 0.3%) — report whether they now agree or if they are genuinely different metrics. font 1.3.', controls: 'siyumim screen, lifetime percent cross-surface consistency, font 1.3' },
  { slug: 'r4_manage_profiles_en', serial: 'emulator-5560', nav: 'ENGLISH profiles management NEW coverage. Manage Learners/Profiles (Parent mode): learner list, add learner, edit learner (empty-name save → must show an inline error / feedback, not a silent no-op — a prior finding), mode badges, delete-with-confirm. Profile picker chrome. font 1.3.', controls: 'learner list, add/edit, empty-name error feedback, mode badges, delete confirm, font 1.3' },
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
// run in rounds of 3 (one agent per device per round, parallel), sequential
// rounds to keep host load manageable across the 3 emulators.
for (let i = 0; i < SCREENS.length; i += 3) {
  const round = SCREENS.slice(i, i + 3)
  const r = await parallel(round.map(s => () =>
    agent(briefFor(s), { label: `b${BATCH}:${s.slug}`, phase: 'DeepPass', schema: FINDING_SCHEMA })))
  reports.push(...r.filter(Boolean))
  log(`Batch ${BATCH}: round ${i / 3 + 1} done (${round.map(s => s.slug).join(', ')}).`)
}

const allFindings = reports.flatMap(r => (r.findings || []).map(f => ({ screen: r.screen, ...f })))
const bySev = {}, bySense = {}
for (const f of allFindings) { bySev[f.severity] = (bySev[f.severity] || 0) + 1; bySense[f.sense] = (bySense[f.sense] || 0) + 1 }
log(`Batch ${BATCH}: ${reports.length} screens, ${allFindings.length} findings. Severity ${JSON.stringify(bySev)}, sense ${JSON.stringify(bySense)}.`)
return { batch: BATCH, screens: reports.length, totalFindings: allFindings.length, bySeverity: bySev, bySense, reports }
