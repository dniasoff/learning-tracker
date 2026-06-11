export const meta = {
  name: 'vision-find-pass',
  description: 'Reusable vision deep-pass over a batch of screens (passed via args). Each agent navigates to its screen, drives the permutation matrix, captures+downscales+VISUALLY JUDGES a screenshot per state against a human rubric, checks term correctness against the domain oracle, and runs adversarial probes. Read-only FINDING pass with screenshot evidence. Runs screens in rounds of 3 (one per device).',
  phases: [{ title: 'DeepPass', detail: 'vision+oracle+exploration audit of the batch screens' }],
}

const ADB = '/home/daniel/bin/adb'
// EDIT THIS BLOCK PER BATCH (args wiring unavailable for scriptPath runs)
const BATCH = 'R3'
const SCREENS = [
  { slug: 'r3_gamification', serial: 'emulator-5556', nav: 'My Achievements (CHILD-ONLY; entry is the dashboard streak/flame chip, which only renders on a POPULATED child dashboard). SEED FIRST: switch to the child profile "Yossi" (adult→child needs no PIN). If Yossi\'s dashboard is the empty-state with no streak chip, try to populate it: add a track for Yossi if the child UI allows (look for an Add-Track CTA), open it, "Start learning", and MARK ONE task complete — that should create points/streak so the flame chip appears. If the child cannot add a track (parent-gated) and no entry appears, set blocked with EXACTLY what is needed. Once on My Achievements, audit: achievement tiles, locked vs unlocked, points/streak/level chips, any claim/celebration dialog. Then App Language → עברית: names localized, no mixed script, count pluralization (1 vs many). font 1.0+1.3.', controls: 'achievement tiles, locked/unlocked badges, points/streak/level chips, claim/celebration dialog' },
  { slug: 'r3_reward_configuration', serial: 'emulator-5554', nav: 'Parent reward configuration (you are signed in as the ADULT "Auditor", so parent surfaces need no PIN). Settings → Parental/Manage area → Reward Configuration. Verify the reward list, add/edit a reward (title, point cost, icon), point-cost steppers, delete, and empty state. Check count pluralization ("1 point" vs "N points"). Then App Language → עברית: fully Hebrew, RTL, no half-translation. font 1.3.', controls: 'reward rows, add-reward FAB, edit dialog, point-cost stepper, delete, save' },
  { slug: 'r3_curriculum_progress', serial: 'emulator-5558', nav: 'A single curriculum\'s progress detail (Progress tab → tap a curriculum card, e.g. Mishnayos). Verify progress bars/percentages, lifetime vs period stats, nusach-correct curriculum/masechta names (one spelling), and count pluralization. Then App Language → עברית: RTL + localized months/labels, no mixed script. font 1.0+1.3, en+he.', controls: 'progress bars, stat cards, breakdown rows, period toggle, back' },
  { slug: 'r3_recent_activity', serial: 'emulator-5556', nav: 'Recent Activity feed (Progress → Recent Activity / activity timeline). Verify activity rows, relative/absolute dates honoring the Hebrew-date preference, "1 item"/"N items" pluralization, nusach-correct names, and empty state. Then App Language → עברית: RTL + localized dates. font 1.3.', controls: 'activity rows, date labels, type icons, empty state, any filter' },
  { slug: 'r3_siyumim_milestones', serial: 'emulator-5554', nav: 'Siyumim / milestones (Progress → Siyumim, or a milestones/timeline surface). Verify milestone cards, completion dates, nusach-correct masechta/seder names (no double-Seder, one spelling), and singular/plural ("1 Siyum"). Then App Language → עברית: RTL + localized. font 1.3, en+he.', controls: 'siyum/milestone cards, dates, masechta names, progress-to-next, empty state' },
  { slug: 'r3_lifetime_marking', serial: 'emulator-5558', nav: 'Lifetime Marking (Settings → "Add what you learned" / Lifetime Marking). Verify the bulk lifetime-marking UI: curriculum hierarchy with checkboxes, select/deselect, partial states, the save/confirm path, and Hebrew-terms correctness. Probe rapid toggling. Then App Language → עברית: RTL + fully Hebrew. font 1.3.', controls: 'curriculum hierarchy rows, checkboxes, select-all, save/confirm, search/filter' },
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
