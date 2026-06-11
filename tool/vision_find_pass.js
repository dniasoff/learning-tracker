export const meta = {
  name: 'vision-find-pass',
  description: 'Reusable vision deep-pass over a batch of screens (passed via args). Each agent navigates to its screen, drives the permutation matrix, captures+downscales+VISUALLY JUDGES a screenshot per state against a human rubric, checks term correctness against the domain oracle, and runs adversarial probes. Read-only FINDING pass with screenshot evidence. Runs screens in rounds of 3 (one per device).',
  phases: [{ title: 'DeepPass', detail: 'vision+oracle+exploration audit of the batch screens' }],
}

const ADB = '/home/daniel/bin/adb'
// EDIT THIS BLOCK PER BATCH (args wiring unavailable for scriptPath runs)
const BATCH = 6
const SCREENS = [
  { slug: 'city_picker', serial: 'emulator-5556', nav: 'City picker (CityPicker) — Settings -> Sacred Time / location -> pick a city. Search a city (e.g. "Jerusalem", "New York"); junk/empty query; check the result list, selection, no-results state, font 1.3.', controls: 'search field, city result rows, select, clear, no-results' },
  { slug: 'curriculum_list', serial: 'emulator-5558', nav: 'Curriculum list (CurriculumList) — the full list of curricula (from Add-Track curriculum-select or a browse-all). Check EVERY curriculum name vs the oracle (nusach-aware, no -os/-ot mixing, no Hebrew-script leak in EN mode); scroll the whole list; Hebrew-terms ON/OFF; font 1.3.', controls: 'curriculum rows, search/filter if any, scroll, select' },
  { slug: 'upgrade_to_cloud', serial: 'emulator-5554', nav: 'Upgrade to cloud (UpgradeToCloud) — for a LOCAL account: Settings -> Backup & Sync / Upgrade. If the current account is cloud, sign out / create a local account first, else set blocked. Check the upgrade form, email/password, validation, the LOCAL-ONLY messaging, offline behavior.', controls: 'upgrade form fields, validation, upgrade button, collision handling' },
  { slug: 'decline_invite', serial: 'emulator-5556', nav: 'Decline invite (DeclineInvite) — a tutor declining a pending invite. Needs a pending invite for the signed-in tutor (test-loop-a@orvex.test). If no pending invite, set blocked with what is needed.', controls: 'decline button/confirm, reason field if any, back' },
  { slug: 'tutor_audit_log', serial: 'emulator-5558', nav: 'Tutor audit log (TutorAuditLog) — the grant history/audit log for an ACTIVE tutor grant, reached from Manage Tutors -> an active grant -> history. Needs an accepted grant. If none, set blocked. Check the log entries render with sensible dates + localized actions.', controls: 'audit log entries, date/action rendering, back, empty state' },
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

const KNOWN = `KNOWN ENV NOTE (do not re-derive or waste time): the app UI cannot currently switch to a Hebrew LOCALE
(MaterialApp locale:null bug, already logged) — the UI chrome stays English regardless of prefs. So do NOT try to
switch UI locale to he. DO exercise the Hebrew-TERMS toggle and the Nusach (Ashkenazi/Sephardi) control (those work
and drive curriculum term rendering), large text (font_scale 1.3), data states, and all visual + exploration probes.`

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
