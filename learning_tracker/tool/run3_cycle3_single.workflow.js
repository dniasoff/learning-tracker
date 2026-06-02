export const meta = {
  name: 'run3-cycle3-single-account',
  description: 'Cycle 3 (single-account, clean): pm clear → dniasoff only → child+track+goal → verify the non-tutor fixes incl. the FIX#7 header re-fix, no multi-account/tutor noise. Bugs → /tmp/run3-cycle-bug-log.md.',
  phases: [{ title: 'Setup' }, { title: 'Verify' }],
}

const DEV = '100.72.6.10:5555'
const PKG = 'com.jcom.torah.learning_tracker'
function base() {
  return `You drive Daniel's REAL Android phone over ADB-over-Tailscale (adb id \`${DEV}\`, package \`${PKG}\`, 1080x2340). Reconnect \`adb connect ${DEV}\` if needed. Wake: \`adb -s ${DEV} shell input keyevent KEYCODE_WAKEUP\`; if a SECURE lockscreen blocks you, STOP + report "device locked". NEVER airplane-mode/wifi-off/uninstall. Google sign-in = native picker (dniasoff@gmail.com is on the device, tap it, no password). PINs: parent=1111.
METHOD: screenshot \`adb -s ${DEV} shell screencap -p /sdcard/s.png && adb -s ${DEV} pull /sdcard/s.png /tmp/s.png && adb -s ${DEV} shell rm /sdcard/s.png\` then Read /tmp/s.png; bounds \`adb -s ${DEV} shell uiautomator dump /sdcard/ui.xml && adb -s ${DEV} shell cat /sdcard/ui.xml\` → tap center; input tap/swipe/text. If an action fails 3× or the API errors, note + move on.
Append defects to /tmp/run3-cycle-bug-log.md (\`cat >>\`): \`[CYCLE 3][AREA][SEV] title — repro — expected vs actual — file\`. Only real defects.`
}

phase('Setup')
log('Cycle 3 (single-account) — wipe + dniasoff + child + track + goal')
await agent(
  `${base()}
# SETUP (single account — NO second account, NO tutoring this cycle).
1. \`adb -s ${DEV} shell pm clear ${PKG}\`; launch (\`adb -s ${DEV} shell monkey -p ${PKG} -c android.intent.category.LAUNCHER 1\`); wait ~60-90s for content DB re-seed.
2. Sign in as dniasoff@gmail.com (Google native picker). Go through onboarding: CONFIRM the onboarding WIZARD appears (with a Skip option) — do NOT skip; create a CHILD profile named "Talmid3"; set parent PIN 1111 if asked; ADD A TRACK (e.g. Mishnayos; finish the wizard). Confirm you land in the app (Dashboard), NOT bounced to splash/sign-in.
3. As the child/owner, create a GOAL on the track (deadline or pace goal).
REPORT: did onboarding show the wizard? child+track+goal created? did add-track keep you in-app (no splash bounce)? Note anything that blocked you.`,
  { label: 'C3 setup: wipe + dniasoff + child + track + goal', phase: 'Setup', model: 'sonnet' },
)

phase('Verify')
log('Cycle 3 — verify A: onboarding/header/picker/no-track-type/PIN')
await agent(
  `${base()}
# VERIFY (cycle 3, batch A — single account, NO tutoring). Verify each; log FAILures only.
- FIX#1 add-track no-crash: confirm setup stayed in-app (no splash/sign-out). If setup reported a bounce, log [APP][P0].
- FIX#5 onboarding wizard on fresh sign-up: confirm setup saw the onboarding wizard (with Skip), NOT straight-to-Settings.
- FIX#7 HEADER CONTRAST (the key re-fix): open (a) a TRACK DETAIL screen (Parent Mode PIN 1111 → Manage Tracks → tap a track) and (b) PARENT SETTINGS. The top switcher header (profile name + mode badge) must be clearly READABLE — opaque light background, dark text, good contrast. It must NOT be dark-on-dark / washed-out / invisible. Screenshot both; report the readability explicitly.
- FIX#8 skip-to-settings: (a) the "Who is learning?" full picker AND (b) the profile-switcher bottom SHEET (tap the top header switcher) must each show a "Skip to Settings" affordance that routes to Settings. Check both.
- FIX#9 no track-type: nowhere shows "personal"/"Personal"/"אישי"/"Custom Track" (task cards, track screens, breakdowns, settings).
- Parent PIN: entering Parent Mode prompts a fresh PIN keypad and 1111 works.
Report PASS/FAIL per item with evidence (screenshots for FIX#7).`,
  { label: 'C3 verify-A: onboarding/header/picker/no-track-type', phase: 'Verify', model: 'sonnet' },
)

log('Cycle 3 — verify B: sync/goals (single-account clean)/invite/reader/gamification')
await agent(
  `${base()}
# VERIFY (cycle 3, batch B — single account). Verify each; log FAILures only.
- FIX#2 goals sync (single account → should be CLEAN, no multi-account permission-denied): after creating the goal, check Settings → Backup & Sync. With ONE account (dniasoff is the live Firebase user), it must reach "Last synced"/"synced" with NO stuck rows. Give it ~30-60s + a background→foreground. (If it still shows permission-denied/stuck even single-account, that's a real rules/sync bug — log [SYNC][P1] with the exact logcat error.)
- FIX#4 no copy-link invite: Manage Tutors → Invite — only email input + Send, no copy/share-link.
- REGRESSION reader/seed: Genesis 1:1 clean English (no footnote gluing) + a Mishnah/Tehillim clean Hebrew+nikud.
- REGRESSION gamification: child rewards/achievements unlock when points ≥ threshold (no "0/N while met"); dashboard stat tiles resolve (not stuck on "…").
Report PASS/FAIL per item with evidence.
NOTE: tutor-mode items (#3/#10/#11/#12) are SKIPPED this cycle — they're blocked by the multi-account single-Firebase-slot issue (separate escalation); do NOT attempt the 2-account tutor flow.`,
  { label: 'C3 verify-B: sync/goals/invite/reader/gamification', phase: 'Verify', model: 'sonnet' },
)

log('Cycle 3 complete. Bugs in /tmp/run3-cycle-bug-log.md')
return { cycle: 3, singleAccount: true, done: true }
