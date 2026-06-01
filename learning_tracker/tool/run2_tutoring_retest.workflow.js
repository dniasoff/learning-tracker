export const meta = {
  name: 'run2-tutoring-retest',
  description: 'Re-test Tutoring now that the App Check debug token is allowlisted: ensure child profile + points, run the cross-account tutor invite/accept, then test tutor view + grants + audit. Sequential (one device). Bugs → /tmp/run2-bug-log.md',
  phases: [
    { title: 'Setup' },
    { title: 'Tutoring' },
  ],
}

const PLAN = '/home/daniel/repos/learning-tracker/docs/planning/on-device-exhaustive-test-plan-2026-05-31.md'

function preamble(area, planRange) {
  return `You are a QA tester/operator driving Daniel's REAL Android phone over ADB-over-Tailscale. TEST + LOG bugs (and perform the SETUP described). Do NOT fix code.

# Device
- adb id: \`100.72.6.10:5555\` (reconnect \`adb connect 100.72.6.10:5555\` if "device not found"). Package \`com.jcom.torah.learning_tracker\`. Screen 1080x2340.
- Two cloud accounts signed in: dniasoff@gmail.com ("Daniel", adult) + familyniasoff@gmail.com ("Family", adult). Both Google accounts on device (sign-in = tap email in native picker, no password). PINs: parent/portal=1111, tutor=2222.
- App Check is now FIXED on this device (debug token allowlisted) — tutor Cloud Functions should authenticate. If you still see \`firebase_functions/unauthenticated\` or App Check "Too many attempts" in logcat, report it (it would mean the rate-limit hasn't cleared).
- START: \`adb -s 100.72.6.10:5555 shell input keyevent KEYCODE_WAKEUP\`; if lockscreen (dumpsys window: mDreamingLockscreen=true) STOP + report "device locked". Foreground: \`adb -s 100.72.6.10:5555 shell monkey -p com.jcom.torah.learning_tracker -c android.intent.category.LAUNCHER 1\`.

# GUARDRAILS
- NEVER toggle airplane mode / disable wifi (severs ADB). NEVER pm clear / adb uninstall. Account-switching + tutor PIN + creating a CHILD profile are ALLOWED. "SIGN IN AGAIN" on the non-live account after switching is EXPECTED. Do NOT delete the two MAIN cloud accounts. Cancel destructive confirmations you can't assess. If stuck / action fails 3x → note + move on; don't flail.

# Task
${area}
Plan ref: \`sed -n '${planRange}' ${PLAN}\`.

# Method
- Screenshot: \`adb -s 100.72.6.10:5555 shell screencap -p /sdcard/s.png && adb -s 100.72.6.10:5555 pull /sdcard/s.png /tmp/s.png && adb -s 100.72.6.10:5555 shell rm /sdcard/s.png\` → Read /tmp/s.png.
- Bounds: \`adb -s 100.72.6.10:5555 shell uiautomator dump /sdcard/ui.xml && adb -s 100.72.6.10:5555 shell cat /sdcard/ui.xml\` → tap center of bounds.
- \`adb -s 100.72.6.10:5555 shell input tap X Y\` / swipe / input text.
- Confirm CF-backed actions via \`adb -s 100.72.6.10:5555 logcat -d | grep -iE "flutter|appcheck|unauthenticated" | tail -40\`.

# Logging
Append defects to /tmp/run2-bug-log.md: \`[TUTORING][SEV] title — repro — expected vs actual — suspected file\`. Only defects.

# Report back
Concise: what you set up/exercised (PASS/FAIL each); CRITICAL handoff (e.g. "tutor grant Family→Daniel's child: CREATED yes/no + evidence"); bugs appended; whether App Check/CF auth worked this time. Factual.`
}

const units = [
  { phase: 'Setup', label: 'Setup 1/1 · ensure child+points + tutor invite/accept (F2)', range: '106,170',
    area: `[CLUSTER: SETUP/TUTORING] STEP A — on dniasoff/"Daniel": confirm a CHILD profile exists (a "Kid" child may already exist from a prior pass; if not, create one) and that it has some points (parent mode PIN 1111 → Adjust Points if needed). STEP B — Flow F2 tutor invite, NOW that App Check works: as Daniel, send a tutor invite for the child profile (capture invite code/link). Switch to familyniasoff/"Family" (re-auth prompt expected), ACCEPT the invite so Family becomes the child's tutor. CONFIRM the grant via UI (a TALMID/talmid row appears for Family) and/or logcat (inviteTutor + acceptInvite CF success, no unauthenticated). REPORT whether the grant was created (yes/no + exact evidence/error).` },

  { phase: 'Tutoring', label: 'Tutor 1/2 · tutor-mode view + PIN', range: '4210,4600',
    area: `[CLUSTER: TUTORING] (Requires the grant from Setup; if absent, report the blocker + skip.) On familyniasoff/"Family", open the profile switcher → the TALMID/tutored child should appear → enter the tutor session for Daniel's child (tutor PIN 2222). Verify: tutor sees the CHILD's parent/management surfaces (tracks/points/rewards/goals); Learn view is VIEW-ONLY; live-mark is barred for the tutor. Log deviations.` },
  { phase: 'Tutoring', label: 'Tutor 2/2 · grants management + audit log', range: '4210,4600',
    area: `[CLUSTER: TUTORING] (Requires the grant.) On dniasoff/"Daniel" (the child owner): Parent Settings/Manage Tutors should now show the ACTIVE grant (Family) — verify it lists Family with Active badge + Revoke + History. Open the audit log (history) and verify tutor actions are recorded. Test revoking a grant if safe (then note state). On Family, verify ManageGrants/TutorPinEntryGate reachable. Log defects.` },
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
log(`Tutoring re-test complete: ${done}/${units.length} steps. Bugs in /tmp/run2-bug-log.md`)
return { stepsRun: done, total: units.length }
