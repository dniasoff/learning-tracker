export const meta = {
  name: 'run3-test-cycle',
  description: 'One full wipe→setup→verify cycle on the device: pm clear, recreate both accounts + child + track + tutor grant, then verify all 12 owner-fixes + regression. Sequential (one device). Bugs → /tmp/run3-cycle-bug-log.md. Pass {cycle:N} as args.',
  phases: [
    { title: 'Setup (wipe+recreate)' },
    { title: 'Verify' },
  ],
}

const CYCLE = (typeof args === 'object' && args && args.cycle) ? args.cycle : 1

const DEV = '100.72.6.10:5555'
const PKG = 'com.jcom.torah.learning_tracker'

function base() {
  return `You drive Daniel's REAL Android phone over ADB-over-Tailscale (adb id \`${DEV}\`, package \`${PKG}\`, screen 1080x2340). Reconnect with \`adb connect ${DEV}\` if "device not found". Wake: \`adb -s ${DEV} shell input keyevent KEYCODE_WAKEUP\`; if a SECURE lockscreen blocks you (dumpsys window: mDreamingLockscreen=true and you cannot swipe past), STOP and report "device locked — needs human".
GUARDRAILS: NEVER toggle airplane mode / disable wifi (it severs your ADB link). NEVER \`adb uninstall\`. Google sign-in uses the NATIVE account picker (both dniasoff@gmail.com and familyniasoff@gmail.com are on the device — just tap the email, no password). PINs: parent/portal=1111, tutor=2222.
METHOD: screenshot \`adb -s ${DEV} shell screencap -p /sdcard/s.png && adb -s ${DEV} pull /sdcard/s.png /tmp/s.png && adb -s ${DEV} shell rm /sdcard/s.png\` then Read /tmp/s.png; bounds \`adb -s ${DEV} shell uiautomator dump /sdcard/ui.xml && adb -s ${DEV} shell cat /sdcard/ui.xml\` → tap center; \`adb -s ${DEV} shell input tap X Y\`/swipe/text. Logs: \`adb -s ${DEV} logcat -d | grep -i flutter | tail -60\`.
If an action fails 3× or something is ambiguous, note it and move on — don't flail.`
}

function logfmt(area) {
  return `Append EVERY defect to /tmp/run3-cycle-bug-log.md (append with \`cat >>\`), one per line: \`[CYCLE ${CYCLE}][${area}][SEV] title — repro — expected vs actual — suspected file\`. SEV P0..P3. Only log real defects (NOT expected behavior).`
}

const S = { model: 'sonnet', phase: 'Verify' }

// ── SETUP ──────────────────────────────────────────────────────────────────
phase('Setup (wipe+recreate)')
log(`Cycle ${CYCLE} — Step 1/5: wipe + recreate accounts + child + track + tutor grant`)
const setup = await agent(
  `${base()}

# GOAL (cycle ${CYCLE} setup) — establish a clean, fully-populated state for testing.
1. WIPE (authorized): \`adb -s ${DEV} shell pm clear ${PKG}\`. Launch (\`adb -s ${DEV} shell monkey -p ${PKG} -c android.intent.category.LAUNCHER 1\`); wait ~60-90s for the content DB to re-seed (watch logcat or just wait + screenshot).
2. SIGN IN as dniasoff@gmail.com via Google (native picker). Complete onboarding: when it offers the onboarding/learning wizard, CREATE A CHILD PROFILE (name it "Talmid${CYCLE}"); set parent PIN 1111 if asked. ADD A TRACK for the child (pick any curriculum, e.g. Mishnayos; finish the Add-Track wizard). Confirm you land in the app (Dashboard) — NOT bounced to splash/sign-in.
3. As dniasoff (the child's owner): create a TUTOR INVITE for the child profile (Parent Settings → Manage Tutors → invite; invite familyniasoff@gmail.com).
4. Switch to / add familyniasoff@gmail.com (Google native picker); ACCEPT the tutor invite; when prompted, SET the tutor PIN to 2222. Confirm the grant is active (TALMID row shows the child).
5. Switch back to dniasoff for the verify phase to start from the owner.
REPORT the exact end state: child profile name, track added (yes/no), parent PIN set, tutor grant created (yes/no + evidence), tutor PIN set. Flag anything that blocked you (this gates the verify steps). ${logfmt('SETUP')}`,
  { label: `C${CYCLE} setup: wipe+recreate+child+track+grant`, phase: 'Setup (wipe+recreate)', model: 'sonnet' },
)

// ── VERIFY ─────────────────────────────────────────────────────────────────
phase('Verify')
log(`Cycle ${CYCLE} — Step 2/5: verify account/onboarding/PIN/header/picker/no-personal`)
await agent(
  `${base()}

# VERIFY (cycle ${CYCLE}, batch A — fresh-state + account fixes). The app was just set up (dniasoff signed in, child "Talmid${CYCLE}" with a track, familyniasoff tutors the child). Verify each fix; log FAILures only.
- FIX#1 add-track no-crash: (already exercised in setup) — confirm creating the child + Add Track did NOT bounce to the first-launch splash / sign-out. If setup reported a bounce, log it [APP][P0].
- FIX#5 fresh sign-up → onboarding: this was a fresh sign-up — confirm it went through the onboarding WIZARD (with a Skip option), NOT straight to Settings.
- FIX#6 tutor PIN reset on wipe: confirm setup had to SET tutor PIN 2222 fresh (a pre-wipe PIN must NOT have been silently accepted). If the old PIN worked without a set step, log it.
- FIX#7 header coloring: open several screens incl. Parent Settings + the profile picker; the top switcher header must be readable (light bg, good contrast) — NOT dark-on-dark/washed-out.
- FIX#8 profile picker skip: on the "Who is learning?" picker, confirm a "Skip to Settings" affordance exists and routes to Settings.
- FIX#9 NO track-type: nowhere should show "personal"/"Personal"/"אישי"/"Custom Track" as a track-type label (task cards, track screens, breakdowns, settings). Spot-check the Learn tab task cards + track/scheduler screens.
${logfmt('VERIFY-A')}
Report PASS/FAIL per item with brief evidence.`,
  S,
)

log(`Cycle ${CYCLE} — Step 3/5: verify tutor parent-powers + projection + banner + scoping`)
await agent(
  `${base()}

# VERIFY (cycle ${CYCLE}, batch B — tutor mode). Switch to familyniasoff. CRITICAL entry: open the profile switcher and tap the **TALMID PROFILES** row for the child "Talmid${CYCLE}" (NOT familyniasoff's OWN profile) → enter tutor PIN 2222. If no grant / no TALMID row exists (setup failed), log [TUTORING][P1] and skip.
**FIRST, confirm you actually entered the TALMID session:** the dashboard greeting AND the amber banner must show the CHILD's name "Talmid${CYCLE}". If they instead show familyniasoff's OWN profile name (e.g. a leftover profile), the talmid entry FAILED — log [TUTORING][P1] "tutor session resolves to tutor's own profile, not the talmid mirror" with what name/data you see, and note the rest of batch B is on the wrong profile. Only proceed to the checks below once the CHILD's name is confirmed showing. Verify; log FAILures only.
- FIX#3 tutor sees child's schedule: the child's track in tutor view must show the SAME projection as the child sees — a real CURRENT FOCUS + DUE TODAY count + non-zero progress/lifetime — NOT "No projection"/0 due/0%. Compare against the child's own view (switch to dniasoff/child to see the real numbers if needed).
- FIX#10 tutor manage rewards/points/goals: in the tutor's Settings → the management hub must expose Points, Rewards, and Goals management (not tracks-only) and they must be reachable.
- FIX#11 banner names child: the amber "Tutor mode" banner must read "Tutor mode · Talmid${CYCLE}" (the child's name), not a bare "Tutor mode".
- FIX#12 talmid Settings scope: in the tutor session, Settings must HIDE the tutor's own DEVICE/account items (App Permissions, Sacred Time/location, Send Diagnostic Logs) and show only student-scope items.
- live-mark barred / lifetime+bulk allowed: confirm the child's Learn live "mark complete" is disabled for the tutor, but lifetime + bulk marking ARE available.
${logfmt('VERIFY-B')}
Report PASS/FAIL per item with evidence.`,
  S,
)

log(`Cycle ${CYCLE} — Step 4/5: verify sync/goals + invite + reader/seed + gamification regression`)
await agent(
  `${base()}

# VERIFY (cycle ${CYCLE}, batch C — sync/goals/invite + regression). Verify; log FAILures only.
- FIX#2 goals sync not stuck: as the child/owner, create a GOAL on the track (a deadline/pace goal). Then check Settings → Backup & Sync: it must reach "synced"/"Last synced", NOT "Sync paused — N stuck". Give it ~30-60s + a background→foreground to let the outbox drain. (The goal push must no longer be permission-denied.)
- FIX#4 no copy-link invite: open the tutor invite screen (Manage Tutors → invite) — there must be NO "copy link"/share-link method, only the email invite.
- REGRESSION reader/seed: open the reader on Genesis 1:1 (Chumash) — clean English, no footnote gluing; spot-check a Mishnah/Tehillim for clean Hebrew+nikud.
- REGRESSION gamification: for the child, the rewards/achievements unlock correctly when points ≥ threshold (no "0/N" while a threshold is met); dashboard stat tiles resolve (not stuck on "…").
${logfmt('VERIFY-C')}
Report PASS/FAIL per item with evidence.`,
  S,
)

log(`Cycle ${CYCLE} — complete. Bugs in /tmp/run3-cycle-bug-log.md`)
return { cycle: CYCLE, done: true }
