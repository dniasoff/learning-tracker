export const meta = {
  name: 'run2-tutoring-gamification',
  description: 'Guided coverage pass: set up a child profile + points + cross-account tutor grant, then test the points/rewards economy and tutoring (single device, sequential). Logs bugs to /tmp/run2-bug-log.md',
  phases: [
    { title: 'Setup' },
    { title: 'Gamification' },
    { title: 'Tutoring' },
  ],
}

// Single physical device => sequential (await each). No parallel() (device
// collision). No airplane-mode/wifi toggling (severs ADB-over-Tailscale).
// Account-switching IS allowed here (the tutor invite needs both accounts); the
// "SIGN IN AGAIN" re-auth prompt on the non-live account is EXPECTED.

const PLAN = '/home/daniel/repos/learning-tracker/docs/planning/on-device-exhaustive-test-plan-2026-05-31.md'

function preamble(area, planRange) {
  return `You are a QA tester/operator driving Daniel's REAL Android phone over ADB-over-Tailscale. TEST and LOG bugs (and perform the SETUP described) — you do NOT fix code.

# Device
- adb id: \`100.72.6.10:5555\`. If "device not found", \`adb connect 100.72.6.10:5555\` then retry.
- Package: \`com.jcom.torah.learning_tracker\`. Screen 1080x2340.
- Two cloud accounts signed in: dniasoff@gmail.com ("Daniel", adult) + familyniasoff@gmail.com ("Family", adult). Both Google accounts on device (sign-in = tap email in native picker, no password). PINs: parent/portal=1111, tutor=2222.
- START: \`adb -s 100.72.6.10:5555 shell input keyevent KEYCODE_WAKEUP\`; if lockscreen (dumpsys window: mDreamingLockscreen=true) STOP and report "device locked". Foreground: \`adb -s 100.72.6.10:5555 shell monkey -p com.jcom.torah.learning_tracker -c android.intent.category.LAUNCHER 1\`.

# GUARDRAILS
- NEVER toggle airplane mode / disable wifi / disable network (severs ADB). NEVER \`pm clear\` / \`adb uninstall\`.
- Account-switching + the tutor PIN + creating a CHILD profile are all ALLOWED here. The "SIGN IN AGAIN" badge on the non-live account after switching is EXPECTED — not a bug. Do NOT delete either of the two MAIN cloud accounts (dniasoff/familyniasoff); you MAY create/delete child learner PROFILES.
- Do NOT trigger native/JS dialogs you can't dismiss. If stuck / an action fails 3x / something ambiguous → note it and move on; do NOT flail.

# Your task
${area}
Relevant plan section: \`sed -n '${planRange}' ${PLAN}\`.

# Method
1. Screenshot: \`adb -s 100.72.6.10:5555 shell screencap -p /sdcard/s.png && adb -s 100.72.6.10:5555 pull /sdcard/s.png /tmp/s.png && adb -s 100.72.6.10:5555 shell rm /sdcard/s.png\` then Read /tmp/s.png.
2. Bounds: \`adb -s 100.72.6.10:5555 shell uiautomator dump /sdcard/ui.xml && adb -s 100.72.6.10:5555 shell cat /sdcard/ui.xml\` → parse bounds, tap center.
3. \`adb -s 100.72.6.10:5555 shell input tap X Y\` / swipe / \`input text\`. Verify; screenshot.
4. App logs (talker): \`adb -s 100.72.6.10:5555 logcat -d | grep -i flutter | tail -40\` — useful to confirm CF-backed actions (invites, grants) succeeded server-side.

# Logging
Append EVERY defect to /tmp/run2-bug-log.md, one per line:
\`[CLUSTER][SEV] title — repro — expected vs actual — suspected file/root cause\` (CLUSTER tag given in your task). SEV P0..P3. Only defects.

# Report back
Concise: what you set up / exercised (PASS/FAIL each), any bugs appended (title+sev), and CRITICAL handoff state for later steps (e.g. "child profile 'Kid' created under Daniel with 50 pts"; "tutor grant: Family now tutors Daniel's child — YES/NO + why"). Factual.`
}

const units = [
  { phase: 'Setup', label: 'Setup 1/1 · child profile + points + tutor grant (F2)', range: '106,170',
    area: `[CLUSTER: SETUP/TUTORING] Establish prerequisites for the later tests. STEP A — under the dniasoff/"Daniel" account, create a CHILD learner profile (e.g. name "Kid"); enter parent mode (PIN 1111) and use Adjust Points to give it ~50 points (verify the just-fixed dialog: Apply is DISABLED on empty/0 amount, enabled on a valid amount — log a bug if not). STEP B — Flow F2 two-phase tutor invite: as Daniel (the child's owner) create/send a tutor invite for the "Kid" profile (capture the invite code/link if shown); then SWITCH to the familyniasoff/"Family" account (re-auth prompt is expected) and ACCEPT the invite via the accept-invite screen so Family becomes a tutor of Daniel's "Kid". Confirm the grant via app UI and/or logcat (look for invite/grant CF success). REPORT the exact handoff state: child profile name + points, and whether the tutor grant was successfully created (and if not, the exact blocker/error).` },

  { phase: 'Gamification', label: 'Game 1/3 · points config + earning', range: '2860,3571',
    area: `[CLUSTER: GAMIFICATION] Using the "Kid" CHILD profile under Daniel (switch back to dniasoff if needed): verify the top-bar role label reads "CHILD MODE" (just-fixed). Test the point configuration screen (per-curriculum points, steppers, save), and that completing/marking content for the child earns points (balance increases). Log defects.` },
  { phase: 'Gamification', label: 'Game 2/3 · rewards + redemption (F8)', range: '2860,3571',
    area: `[CLUSTER: GAMIFICATION] Flow F8 — full rewards economy for the "Kid" profile: configure a reward (cost ≤ the child's points), then redeem it; verify points are SPENT correctly and the redemption appears. Verify the Fulfil/Decline action is single-tap-guarded (no double-fire). Log defects.` },
  { phase: 'Gamification', label: 'Game 3/3 · milestones + streak', range: '2860,3571',
    area: `[CLUSTER: GAMIFICATION] Test achievement tiers/milestones, the streak card, and progress summary widgets for the child profile. Verify counts render and taps navigate. Log defects.` },

  { phase: 'Tutoring', label: 'Tutor 1/2 · tutor-mode view + PIN', range: '4210,4600',
    area: `[CLUSTER: TUTORING] (Requires the tutor grant from Setup. If no grant was created, note that and SKIP, logging the setup failure as the blocker.) On the familyniasoff/"Family" account, enter tutor mode for Daniel's "Kid" (tutor PIN 2222). Verify: the tutor sees the CHILD's parent/management surfaces (tracks/points/rewards/goals); the Learn view is VIEW-ONLY; live-mark is barred for the tutor. Log any deviation.` },
  { phase: 'Tutoring', label: 'Tutor 2/2 · grants + audit log', range: '4210,4600',
    area: `[CLUSTER: TUTORING] (Requires the grant.) Test the tutor grants management surface (list/active grants) and the audit log (tutor actions are recorded). Verify revoking/managing a grant works. If no grant exists, note and skip. Log defects.` },
]

let done = 0
for (const u of units) {
  phase(u.phase)
  log(`Step ${done + 1}/${units.length} — ${u.label}`)
  try {
    await agent(preamble(u.area, u.range), { label: u.label, phase: u.phase, model: 'sonnet' })
  } catch (e) {
    log(`Step ${done + 1} (${u.label}) errored: ${String(e).slice(0, 120)}`)
  }
  done++
}
log(`Coverage pass complete: ${done}/${units.length} steps. Bugs in /tmp/run2-bug-log.md`)
return { stepsRun: done, total: units.length }
