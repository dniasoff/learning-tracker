export const meta = {
  name: 'run3-tutor-extensive',
  description: 'Extensive tutor re-test WITH auto-re-auth-on-switch: wipe, register App Check debug token, set up dniasoff(child+track+goal+points)+familyniasoff tutor grant, then deeply verify the tutor experience end-to-end. Sequential (one device). Bugs → /tmp/run3-cycle-bug-log.md.',
  phases: [{ title: 'Setup' }, { title: 'Verify tutor' }],
}

const DEV = '100.72.6.10:5555'
const PKG = 'com.jcom.torah.learning_tracker'
const APPID = '1:346569574648:android:3519edaeb5ce5df9d6130d'
function base() {
  return `You drive Daniel's REAL Android phone over ADB-over-Tailscale (adb id \`${DEV}\`, package \`${PKG}\`, 1080x2340). Reconnect \`adb connect ${DEV}\` if needed. Wake: \`adb -s ${DEV} shell input keyevent KEYCODE_WAKEUP\`; if a SECURE lockscreen blocks you, STOP + report "device locked". NEVER airplane-mode/wifi-off/uninstall. Google sign-in = native picker (dniasoff@gmail.com + familyniasoff@gmail.com are on the device — tap the email, no password). PINs: parent=1111, tutor=2222.
METHOD: screenshot \`adb -s ${DEV} shell screencap -p /sdcard/s.png && adb -s ${DEV} pull /sdcard/s.png /tmp/s.png && adb -s ${DEV} shell rm /sdcard/s.png\` then Read /tmp/s.png; bounds \`adb -s ${DEV} shell uiautomator dump /sdcard/ui.xml && adb -s ${DEV} shell cat /sdcard/ui.xml\` → tap center; input tap/swipe/text. Logs: \`adb -s ${DEV} logcat -d | grep -i flutter | tail -60\`. If an action fails 3× or the API errors, note + move on.
Append defects to /tmp/run3-cycle-bug-log.md (\`cat >>\`): \`[TUTOR-EXT][AREA][SEV] title — repro — expected vs actual — file\`. Only real defects.`
}

phase('Setup')
log('Tutor-ext setup: wipe → REGISTER App Check token → dniasoff(child+track+goal+points) → invite → switch(auto-re-auth)→familyniasoff accept')
await agent(
  `${base()}
# SETUP for an extensive tutor test. Do these IN ORDER; report the end state.
1. WIPE: \`adb -s ${DEV} shell pm clear ${PKG}\`. Launch: \`adb -s ${DEV} shell monkey -p ${PKG} -c android.intent.category.LAUNCHER 1\`. Wait ~60-90s for the content DB to re-seed.
2. **CRITICAL — register the App Check debug token (a pm clear regenerates it; without this, Firestore denies ALL writes and the whole test is meaningless):**
   - Get it: \`adb -s ${DEV} logcat -d | grep -oE "Enter this debug secret into the allow list[^:]*: [0-9a-f-]+"\` → extract the UUID (format 8-4-4-4-12).
   - Register it:
     \`TOK=<the-uuid>; curl -s -X POST "https://firebaseappcheck.googleapis.com/v1/projects/346569574648/apps/${APPID}/debugTokens" -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "x-goog-user-project: torah-study-tracker" -H "Content-Type: application/json" -d "{\\"displayName\\":\\"tutor-ext\\",\\"token\\":\\"$TOK\\"}"\`
   - Confirm the response has a "name" (success). Then force-stop + relaunch so the app picks up the now-valid token.
3. Sign in as **dniasoff@gmail.com** (Google native picker). Onboard: create a CHILD profile "Talmid", set parent PIN 1111, ADD A TRACK (Mishnayos), and set a GOAL on it. Enter Parent Mode (1111) → give the child some POINTS (Adjust Points, e.g. +50) and configure a REWARD (so there's reward/points data to view). Verify Backup&Sync reaches "Last synced" (dniasoff is the live Firebase user, so its data MUST sync now — if it shows stuck/permission-denied, the App Check token registration failed; redo step 2).
4. As dniasoff: Parent Settings → Manage Tutors → invite **familyniasoff@gmail.com** as a tutor for "Talmid".
5. SWITCH to familyniasoff: open the profile/account switcher → Switch Account → pick familyniasoff. **NEW BEHAVIOR: the app should now AUTO-RE-AUTHENTICATE Firebase to familyniasoff (a Google one-tap picker may appear — pick familyniasoff).** Confirm you end up as familyniasoff with sync working (no permission-denied). Then ACCEPT the tutor invite; set tutor PIN 2222.
REPORT the end state: App Check token registered (yes/no)? dniasoff data synced (yes/no)? child+track+goal+points+reward created? auto-re-auth on switch worked (did Firebase become familyniasoff — sync OK)? tutor grant active (yes/no + evidence)?`,
  { label: 'Setup: wipe+appcheck+dniasoff-data+tutor-grant', phase: 'Setup', model: 'sonnet' },
)

phase('Verify tutor')
log('Tutor-ext verify A: enter talmid session → child data / banner / projection / live-mark')
await agent(
  `${base()}
# VERIFY tutor experience (batch A). As familyniasoff, open the switcher and enter the TALMID session for "Talmid" (tap the TALMID PROFILES row, NOT familyniasoff's own profile; tutor PIN 2222). If no TALMID row appears, log [TUTOR-EXT][P1] "talmid row absent — grant not readable" + the logcat error, and skip.
**FIRST confirm correct entry:** the dashboard greeting AND the amber banner must show "Talmid" (the child). If they show familyniasoff's own profile instead, log [TUTOR-EXT][P1] "tutor session shows own profile not talmid" and note batch is on wrong profile.
Then verify (log FAILures only, with screenshots for the data ones):
- Banner reads "Tutor mode · Talmid".
- Dashboard/track carousel shows the CHILD's REAL data: a real CURRENT FOCUS (not "No projection"), a non-zero DUE TODAY, real Track progress / Lifetime % — and the POINTS you set (~50). Cross-check by switching to dniasoff/child briefly to compare the numbers.
- Live "mark complete" in the child's Learn/reader is DISABLED/absent for the tutor.
- Lifetime marking + bulk prior marking ARE available to the tutor.
Report PASS/FAIL each with evidence.`,
  { label: 'Verify A: talmid entry / child data / banner / live-mark', phase: 'Verify tutor', model: 'sonnet' },
)

log('Tutor-ext verify B: tutor management (tracks/points/rewards/goals) + settings scope + grants/audit + switch-back')
await agent(
  `${base()}
# VERIFY tutor experience (batch B). In the tutor (familyniasoff → Talmid) session. Log FAILures only.
- Tutor MANAGEMENT: Settings → the parent-management hub must let the tutor manage the child's TRACKS, POINTS, REWARDS, and GOALS — open each and confirm it's functional (e.g. adjust points, edit the reward, edit the track's goal via the track-detail Goal tile).
- Settings SCOPE: in the talmid session, Settings must HIDE the tutor's own device/account items (App Permissions, Sacred Time/location, Send Diagnostic Logs, the tutor's own account header) and show only student-scope items.
- GRANTS + AUDIT: from dniasoff (owner) Manage Tutors shows the ACTIVE grant (familyniasoff) with Revoke + History; the audit log records tutor actions. From familyniasoff, ManageGrants is reachable.
- SWITCH-BACK (auto-re-auth): switch from familyniasoff back to dniasoff — the app should auto-re-auth to dniasoff (one-tap), land on dniasoff's data, and sync (no permission-denied). Confirm the switch works both directions.
Report PASS/FAIL each with evidence.`,
  { label: 'Verify B: tutor management / settings scope / grants / switch-back', phase: 'Verify tutor', model: 'sonnet' },
)

log('Tutor-ext complete. Bugs in /tmp/run3-cycle-bug-log.md')
return { done: true }
