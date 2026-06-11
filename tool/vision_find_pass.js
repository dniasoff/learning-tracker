export const meta = {
  name: 'vision-find-pass',
  description: 'Reusable vision deep-pass over a batch of screens (passed via args). Each agent navigates to its screen, drives the permutation matrix, captures+downscales+VISUALLY JUDGES a screenshot per state against a human rubric, checks term correctness against the domain oracle, and runs adversarial probes. Read-only FINDING pass with screenshot evidence. Runs screens in rounds of 3 (one per device).',
  phases: [{ title: 'DeepPass', detail: 'vision+oracle+exploration audit of the batch screens' }],
}

const ADB = '/home/daniel/bin/adb'
// EDIT THIS BLOCK PER BATCH (args wiring unavailable for scriptPath runs)
const BATCH = 'R2'
const SCREENS = [
  { slug: 'r2_gamification', serial: 'emulator-5556', nav: 'My Achievements / gamification. Switch to a CHILD profile (Shloime) first (Parent-PIN may gate adult→child back). Reach the achievements/badges surface (dashboard child view or a trophy/achievements entry). Verify achievement tiles, locked vs unlocked states, points/streak/level displays, any progress bars. Then open Settings → App Language → עברית and re-audit in Hebrew RTL: achievement names localized, no mixed script, count pluralization correct (1 vs many). font 1.0 + 1.3.', controls: 'achievement tiles, locked/unlocked badges, points/streak/level chips, any claim/celebration dialog' },
  { slug: 'r2_curriculum_settings', serial: 'emulator-5554', nav: 'Settings → curriculum / learning preferences (the Nusach Ashkenazi↔Sephardi control + Hebrew-Terms toggle + Nikud). Toggle Nusach and CONFIRM the transliteration actually changes live (Bereishis↔Bereshit, Shabbos↔Shabbat, -os↔-ot); toggle Hebrew-Terms ON and confirm domain terms switch to Hebrew script and back. Then App Language → עברית: verify RTL + the controls are fully localized, no half-translation. font 1.3.', controls: 'nusach segmented control, hebrew-terms toggle, nikud toggle, any sample/preview label' },
  { slug: 'r2_content_search', serial: 'emulator-5558', nav: 'Content browsing → search (a search icon / ContentSearchScreen). Enter junk, empty, very long, and Hebrew-script queries; verify results render with NO crash, correct nusach terms, and no raw exception/placeholder. Probe rapid typing + clear. Then App Language → עברית and re-check RTL + localized empty/no-results copy. font 1.3, en+he. (Ashkenazi search aliases are KNOWN-DEFERRED — do not re-flag.)', controls: 'search field, result rows, empty/no-results state, clear button, filters' },
  { slug: 'r2_learning', serial: 'emulator-5556', nav: 'Dashboard → a track → "Start learning" (the learning/study screen showing the daf/mishna/pasuk content). Verify Hebrew text renders correctly (with/without nikud per the Nikud pref), the masechta/section name is nusach-correct and not mixed-script, and the mark-complete / next affordance works and re-reads state. Then App Language → עברית: RTL chrome. font 1.3.', controls: 'content text body, nikud rendering, section/masechta header, mark-complete / next button, progress indicator' },
  { slug: 'r2_scheduler', serial: 'emulator-5554', nav: 'The daily-plan / scheduler surface (today\'s tasks list — reachable from the dashboard "Today" / a Learn tab). Verify the task list, due vs overdue vs review states, date rendering honoring the Hebrew-date preference, and count pluralization. Mutate (complete a task) and re-read the same counter for staleness. Then App Language → עברית: RTL + localized states/dates. font 1.3.', controls: 'task rows, due/overdue/review chips, date labels, complete affordance, empty state' },
  { slug: 'r2_content_hierarchy', serial: 'emulator-5558', nav: 'Content browsing → pick a curriculum → drill into the seder/masechta/perek hierarchy. Verify breadcrumb correctness at each level, that the SAME masechta renders in ONE nusach spelling throughout (no Berakhos/Berakhot mix), Hebrew-terms consistency, and no mixed script. Then App Language → עברית: RTL breadcrumb + headers. font 1.3, en+he.', controls: 'curriculum tiles, hierarchy rows, breadcrumb trail, back navigation, any select/expand control' },
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

const KNOWN = `REDO / VERIFICATION PASS (R1v2): the app was just rebuilt + redeployed with the R1-remediation fixes. The
in-app UI-language switcher now EXISTS: Settings → "App Language" segmented tile (English / עברית) at the TOP of the
preferences card. Tapping עברית must flip the ENTIRE UI to Hebrew RTL — exercise it and verify RTL chrome on this
screen. If it does NOT flip the UI, that is a P0 regression of the keystone fix.
ALSO drive: Hebrew-TERMS toggle, Nusach (Ashkenazi/Sephardi), large text (1.3), data states, exploration probes.
KNOWN-DEFERRED — do NOT report these as findings (they are intended/product-decisions or pending external work):
 - add-track wizard step-count denominator branches (6 → 7 → 4) by path — this is INTENDED, pinned by TS-11 tests
   (program reveals a step then auto-skips scope/study-days/goal). Do NOT re-flag the changing denominator.
 - Kodshim renders with slightly different Hebrew spelling (קודשים vs קדשים) between a Bavli vs Mishnayos track —
   originates in content-DB displayNameHe data; asset-regen pending. Do NOT re-flag.
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
// run in rounds of 3 (3 devices), sequential rounds to avoid device contention
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
