export const meta = {
  name: 'run2-on-device-sweep',
  description: 'Sequential on-device test sweep (run 2, fresh dniasoff+familyniasoff accounts) — one Sonnet tester per group, single device so serial; logs bugs to /tmp/run2-bug-log.md',
  phases: [
    { title: 'Account/Auth' },
    { title: 'Profiles + PIN' },
    { title: 'Scheduler' },
    { title: 'Gamification' },
    { title: 'Settings' },
    { title: 'Tutoring' },
    { title: 'Cross-cutting flows' },
  ],
}

// Single physical device => every tester runs SEQUENTIALLY (await each). No
// parallel() — concurrent agents would collide on the one phone.
// No airplane-mode / wifi toggling (would sever ADB-over-Tailscale). Offline
// states are covered by unit tests, not here.

const PLAN = '/home/daniel/repos/learning-tracker/docs/planning/on-device-exhaustive-test-plan-2026-05-31.md'

function preamble(area, planRange, extra) {
  return `You are a QA tester driving Daniel's REAL Android phone over ADB-over-Tailscale. You TEST and LOG bugs — you do NOT fix code.

# Device
- adb id: \`100.72.6.10:5555\`. If "device not found", run \`adb connect 100.72.6.10:5555\` and retry. Reconnect as needed.
- Package: \`com.jcom.torah.learning_tracker\`. Screen 1080x2340.
- Two cloud accounts are signed in: dniasoff@gmail.com (profile "Daniel", adult) and familyniasoff@gmail.com (profile "Family", adult). Both Google accounts are on the device (sign-in = tap the email in the native picker, no password). PINs: parent/portal=1111, tutor=2222.
- START by getting to a known state: \`adb -s 100.72.6.10:5555 shell input keyevent KEYCODE_WAKEUP\`; if a lockscreen shows (dumpsys window: mDreamingLockscreen=true) STOP and report "device locked". Then foreground the app: \`adb -s 100.72.6.10:5555 shell monkey -p com.jcom.torah.learning_tracker -c android.intent.category.LAUNCHER 1\`.

# HARD GUARDRAILS
- NEVER toggle airplane mode / disable wifi / disable network (it would sever the ADB connection). NEVER \`pm clear\`, NEVER \`adb uninstall\`.
- Do NOT delete/remove either cloud account. Cancel any destructive "delete forever" confirmation (note "cancelled to preserve setup").
- Do NOT trigger native/JS dialogs you can't dismiss. If stuck or an adb action fails 3x or something is ambiguous/irreversible, note it and move on — do NOT flail.

# What to test
${area}
Read the relevant plan section first: \`sed -n '${planRange}' ${PLAN}\`. Follow its Test Steps + States-to-Verify for THIS area. Touch every reachable button/toggle/field/flow in scope.
${extra || ''}

# Method (per step)
1. Screenshot: \`adb -s 100.72.6.10:5555 shell screencap -p /sdcard/s.png && adb -s 100.72.6.10:5555 pull /sdcard/s.png /tmp/s.png && adb -s 100.72.6.10:5555 shell rm /sdcard/s.png\` then Read /tmp/s.png.
2. Bounds: \`adb -s 100.72.6.10:5555 shell uiautomator dump /sdcard/ui.xml && adb -s 100.72.6.10:5555 shell cat /sdcard/ui.xml\` → parse bounds="[x1,y1][x2,y2]", tap center.
3. Interact: \`adb -s 100.72.6.10:5555 shell input tap X Y\` / swipe / \`input text\`. Verify expected state; screenshot.

# Logging
Append EVERY defect to /tmp/run2-bug-log.md (it exists), one per line, exact format:
\`[${'$'}{CLUSTER}][SEV] title — repro — expected vs actual — suspected file/root cause\`
Use the CLUSTER tag given in your area. SEV = P0 crash/data-loss | P1 broken function | P2 wrong behavior | P3 cosmetic. Only log defects (not passes). Append with \`cat >> /tmp/run2-bug-log.md\`.

# Report back
Concise: screens/flows exercised with PASS/FAIL each; count + list of bugs appended (title+sev); anything unreachable and why. Factual.`
}

const S = { model: 'sonnet' }

// ── Test units (sequential). Tag in [BRACKETS] is the CLUSTER for the log. ──
const units = [
  // Account / Auth (602-909). Churn (sign-out/in, switch) is acceptable here.
  { phase: 'Account/Auth', label: 'A/A 1/3 · sign-in validation + error msgs', cluster: 'ACCOUNT/AUTH', range: '602,909',
    area: '[CLUSTER: Account/Auth] Verify the JUST-FIXED sign-in error messages: invalid email (no @) → "Please enter a valid email address"; wrong password → "Incorrect password" (not the generic "Sign-in failed"). Also exercise the SignInScreen fields/buttons generally. NOTE: you may sign out and back in via the Google picker as needed (this is expected for auth testing).' },
  { phase: 'Account/Auth', label: 'A/A 2/3 · account picker + add account', cluster: 'ACCOUNT/AUTH', range: '602,909',
    area: '[CLUSTER: Account/Auth] Test the AccountPicker / "Choose an Account" screen: both account tiles render correctly (cloud badges; the non-live account may show "SIGN IN AGAIN" — that is EXPECTED, do not treat as a bug), "Add another account (N slots remaining)" affordance, and tile taps route correctly. Do NOT remove either account.' },
  { phase: 'Account/Auth', label: 'A/A 3/3 · multi-account switch (F4)', cluster: 'ACCOUNT/AUTH', range: '120,124',
    area: '[CLUSTER: Account/Auth] Flow F4 — switch between the two accounts via the top profile/mode switcher → Switch Account → pick the other account. Verify the app context (name at top, data) changes to the selected account. The "SIGN IN AGAIN"/re-auth prompt on switching to the non-live account is EXPECTED behavior (the user accepted it) — only log a bug if switching CRASHES, loses data, or shows the WRONG account\'s data.' },

  // Profiles + PIN (910-2197)
  { phase: 'Profiles + PIN', label: 'P/PIN 1/3 · profile CRUD + switcher', cluster: 'PROFILES/PIN', range: '910,1400',
    area: '[CLUSTER: Profiles/PIN] Create a new learner profile (try a child profile), edit it, switch between profiles via the persistent top switcher (must be present in every context). Verify the switcher and profile management surfaces. You may DELETE a profile you JUST created (not the original "Daniel"/"Family") to test deletion, but cancel if it warns about data loss you can\'t assess.' },
  { phase: 'Profiles + PIN', label: 'P/PIN 2/3 · parent PIN gate (F7)', cluster: 'PROFILES/PIN', range: '910,1400',
    area: '[CLUSTER: Profiles/PIN] Flow F7 — parent-mode gated entry/exit. Set/enter the parent PIN (1111). Verify entering the parent/management area requires the PIN, wrong PIN is rejected, correct PIN enters, and exiting re-locks. Test PIN change if available.' },
  { phase: 'Profiles + PIN', label: 'P/PIN 3/3 · child vs adult gating', cluster: 'PROFILES/PIN', range: '910,1400',
    area: '[CLUSTER: Profiles/PIN] Verify child-mode vs adult-mode gating: child profiles see points/gamification; adult profiles have NO points (per product rule). Confirm child-only UI is gated and adult management surfaces differ appropriately.' },

  // Scheduler (2553-2859)
  { phase: 'Scheduler', label: 'Sched 1/2 · daily tasks + study days', cluster: 'SCHEDULER', range: '2553,2859',
    area: '[CLUSTER: Scheduler] Test the Scheduler screen: daily task list, marking tasks, study-day config (which days are study days), and that the task cards do NOT show a "personal" track-type label (just-fixed — verify it is gone).' },
  { phase: 'Scheduler', label: 'Sched 2/2 · back-dated enrolment / overdue (F10)', cluster: 'SCHEDULER', range: '2553,2859',
    area: '[CLUSTER: Scheduler] Flow F10 — enrol a track with a back-dated start (within the allowed [today-30, today] window). Verify it generates past-dated catch-up tasks that surface as OVERDUE. Check the start-date picker constrains to the allowed window.' },

  // Gamification / Rewards / Points (2860-3571)
  { phase: 'Gamification', label: 'Game 1/3 · points config + earning', cluster: 'GAMIFICATION', range: '2860,3571',
    area: '[CLUSTER: Gamification] (Use a CHILD profile — adults have no points.) Test point configuration screen (per-curriculum points, steppers), and that completing content earns points. Verify save affordances.' },
  { phase: 'Gamification', label: 'Game 2/3 · rewards + redemption (F8)', cluster: 'GAMIFICATION', range: '2860,3571',
    area: '[CLUSTER: Gamification] Flow F8 — full rewards economy: configure a reward, earn enough points, redeem it; verify the Fulfil/Decline action is single-tap-guarded (no double-fire) and points are spent correctly.' },
  { phase: 'Gamification', label: 'Game 3/3 · milestones + streak', cluster: 'GAMIFICATION', range: '2860,3571',
    area: '[CLUSTER: Gamification] Test achievement tiers / milestones, the streak card, and progress summary widgets. Verify counts render and tapping navigates correctly.' },

  // Settings + Curriculum / Lifetime / Scope (3572-4209)
  { phase: 'Settings', label: 'Set 1/2 · account/profile separation + curriculum', cluster: 'SETTINGS', range: '3572,4209',
    area: '[CLUSTER: Settings] Verify the Settings top header is an ACCOUNT-only sheet and profile management lives only in the PROFILE section (no duplicated actions). Test curriculum management (add/remove curricula, scope selection — Save must be disabled for an empty subset, no false "saved" toast).' },
  { phase: 'Settings', label: 'Set 2/2 · lifetime/bulk (F9) + sacred time', cluster: 'SETTINGS', range: '3572,4209',
    area: '[CLUSTER: Settings] Flow F9 — bulk prior-progress / lifetime marking (sentinel-date credit: credits siyumim/lifetime without polluting streak/recent activity). Also test the Sacred-time "in Israel" manual toggle STICKS (not reverted by a background reload).' },

  // Tutoring (4210-end) — needs a tutor grant between the two accounts.
  { phase: 'Tutoring', label: 'Tutor 1/2 · two-phase invite (F2)', cluster: 'TUTORING', range: '4210,4600',
    area: '[CLUSTER: Tutoring] Flow F2 — adult-as-tutor two-phase invite END-TO-END using BOTH accounts: from one account (e.g. Family) create/send a tutor invite for a child profile; switch to the other account (Daniel) and accept the invite (accept-invite screen). Switching accounts + re-auth prompts are EXPECTED. Verify the grant is created. If the CF-backed invite fails, capture the exact error.' },
  { phase: 'Tutoring', label: 'Tutor 2/2 · tutor view + PIN + audit', cluster: 'TUTORING', range: '4210,4600',
    area: '[CLUSTER: Tutoring] With a tutor grant active (from the previous step), enter tutor mode (tutor PIN 2222). Verify the tutor sees the CHILD\'s parent/management view (tracks/points/rewards/goals), the Learn view is view-only, live-mark is barred, and the audit log records actions. If no grant was created in the prior step, note that and skip.' },

  // Cross-cutting flows
  { phase: 'Cross-cutting flows', label: 'X 1/1 · F1/F6/F11/F13/F14', cluster: 'CROSS-CUTTING', range: '95,170',
    area: '[CLUSTER: Cross-cutting] Spot-check key cross-cutting flows: F1 canonical happy path (dashboard → learn → mark → progress); F6 the persistent profile/mode switcher is present & tappable in EVERY context (dashboard, learn, progress, settings, parent portal); F11 chazara UI appears ONLY for chazara-enabled tracks (none elsewhere); F13 Hebrew/RTL — switch device or app to Hebrew and verify RTL layout + Hebrew strings render without overflow; F14 guard redirects don\'t hang/lock navigation.' },
]

let done = 0
for (const u of units) {
  phase(u.phase)
  log(`Group ${done + 1}/${units.length} — ${u.label}`)
  try {
    const prompt = preamble(u.area.replace('${CLUSTER}', u.cluster), u.range)
      .replaceAll('${CLUSTER}', u.cluster)
    await agent(prompt, { label: u.label, phase: u.phase, model: 'sonnet' })
  } catch (e) {
    log(`Group ${done + 1} (${u.label}) errored: ${String(e).slice(0, 120)}`)
  }
  done++
}

log(`Sweep complete: ${done}/${units.length} groups run. Bugs in /tmp/run2-bug-log.md`)
return { groupsRun: done, total: units.length }
