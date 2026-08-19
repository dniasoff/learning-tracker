export const meta = {
  name: 'device-e2e-full-suite-run13',
  description: 'Comprehensive 3-device parallel on-device E2E re-audit (run 13) — first pass since Root Cause A/B (unwired cloud sign-in + AuthGuard misroute) and 6 P2/P3 polish fixes landed; seeds via REAL cloud sign-up (offline-account creation was removed), walks every screen across 16 feature areas (EN + Hebrew/RTL), adversarially verifies every finding, synthesizes a gate report',
  phases: [
    { title: 'Seed', detail: 'cloud sign-up (admin-verified email) + profile/track/completions/PIN/reward per device + audit onboarding/wizard' },
    { title: 'Audit', detail: '3 parallel device-chains walk every screen in their area partition' },
    { title: 'Verify', detail: 'adversarially verify each candidate finding against code + screenshot' },
    { title: 'Synthesize', detail: 'consolidate verified findings into a gate report' },
  ],
}

// Inlined from tool/device_e2e/_full_suite_lib.mjs -- Workflow scripts get no
// filesystem/import access, so the shared library is pasted in verbatim
// (functions/logic unchanged from run12 except where noted RUN13) rather
// than imported.

const REPO = '/home/daniel/repos/learning-tracker';
const DEVE2E = REPO + '/tool/device_e2e';
const PKG = 'com.jcom.torah.learning_tracker';
const PROJECT = 'torah-study-tracker';

const DEV = {
  '5554': { serial: 'emulator-5554', label: 'Pixel 2, API 28 (small/old)' },
  '5560': { serial: 'emulator-5560', label: 'Pixel 7, API 34 (modern)' },
  '5562': { serial: 'emulator-5562', label: 'tablet, API 36' },
};

// RUN13: cloud sign-up + admin-verify Python helper, appended to every seed
// prompt. Mirrors tool/device_e2e/journey_01_signup_profile.py's proven
// pattern (that script targets a physical phone over Tailscale and must NOT
// be run directly here — this is the same logic adapted inline for an
// emulator-driving agent). gcloud must already be authenticated in this
// environment (gcloud auth print-access-token must succeed without a login
// prompt).
function cloudSignupRecipe(port) {
  return [
    `## CLOUD SIGNUP RECIPE (Root Cause A is now fixed — this creates a REAL account in the live "${PROJECT}" Firebase project)`,
    `You already computed EMAIL and DISPLAY_NAME in the step above — use those exact values below, do not invent new ones.`,
    `From the Sign In screen ("Welcome Back"): tap "Register Here" -> Create Account screen.`,
    `Fill: Scholar Name = DISPLAY_NAME, Email = EMAIL, Password = "TestPass1234!". Tap "Sign Up".`,
    `Wait for "Verification email sent" (up to 20s). You cannot read the inbox — instead ADMIN-VERIFY the email server-side, then sign in normally. Run this Python inline (same host machine, not on-device — extend the same Python session where you set EMAIL, so the variable is already in scope):`,
    '```python',
    'import json, subprocess, urllib.request',
    `PROJECT = "${PROJECT}"`,
    'def gtoken():',
    '    return subprocess.run(["gcloud", "auth", "print-access-token"], capture_output=True, text=True, timeout=30).stdout.strip()',
    'def admin_verify_email(email):',
    '    tok = gtoken()',
    '    base = f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}"',
    '    hdr = {"Authorization": f"Bearer {tok}", "x-goog-user-project": PROJECT, "Content-Type": "application/json"}',
    '    req = urllib.request.Request(f"{base}/accounts:lookup", data=json.dumps({"email": [email]}).encode(), headers=hdr)',
    '    uid = json.load(urllib.request.urlopen(req, timeout=20))["users"][0]["localId"]',
    '    req2 = urllib.request.Request(f"{base}/accounts:update", data=json.dumps({"localId": uid, "emailVerified": True}).encode(), headers=hdr)',
    '    urllib.request.urlopen(req2, timeout=20)',
    '    return uid',
    'uid = admin_verify_email(EMAIL)',
    'print(uid)',
    '```',
    `Record the printed uid (you will need it later to spot-check Firestore via d.firestore_get). After verifying, the app should already be back on (or return to) the Sign In screen — fill Email/Password with the SAME EMAIL/password above and tap "Sign In". This should now succeed (Root Cause A fix) and proceed to onboarding.`,
    `If sign-up fails claiming the email is already in use (a retry from a prior partial run), recompute EMAIL with a fresh unix-time suffix and retry from "Register Here".`,
    `Do NOT create a second account later in this session — reuse this one for everything else in your seed spec.`,
  ].join('\n');
}

function driveGuide(port) {
  const d = DEV[port];
  return [
    `## Device + driver (HARD RULES)`,
    `- Operate ONLY on serial \`${d.serial}\` (${d.label}). NEVER run \`adb connect\`, never use an IP (e.g. 100.x), never touch another serial or any physical device. Do NOT run journey_01_signup_profile.py (it targets a physical phone) — but you MAY read it for reference.`,
    `- Driver: \`\`\`python`,
    `import sys, time; sys.path.insert(0, "${DEVE2E}")`,
    `from driver import Device`,
    `d = Device("${d.serial}", artifact_dir="/tmp/device_e2e/${port}")`,
    `\`\`\``,
    `API: d.launch(clear=False), d.screenshot("name")->path, d.find/wait/present(text=/desc=/hint=/contains=), d.tap_text/tap_desc/tap_contains, d.tap(text=...), d.back(), d.type_into(hint=...,text=...), d.shell(cmd), d.tap_xy(x,y), d._dump() -> [{text,desc,rid,hint,cls,bounds,center}]. d.firestore_get(path) reads live Firestore via the same admin token (see driver.py).`,
    `- Flutter labels arrive as content-desc (text=""); text=/tap_text match either. Enumerate: \`print([(n['text'] or n['desc']) for n in d._dump() if (n['text'] or n['desc'])])\`.`,
    `- After each navigation: \`time.sleep(1.5)\` settle, THEN screenshot, THEN **Read the PNG** and judge with vision. Your visual judgment is the point.`,
    `- The device needs real network for cloud sign-in/sign-up to work (Root Cause A's fix depends on it) — if wifi/data got disabled by a prior session, run \`d.shell("svc wifi enable"); d.shell("svc data enable")\` first and confirm connectivity before signing in.`,
    ``,
    `## Robustness / recovery`,
    `- ANR ("isn't responding"): tap "Wait", \`time.sleep(8)\`, retry; if it persists, \`d.shell("am force-stop ${PKG}")\` then relaunch.`,
    `- Element not found after ~3 polls: screenshot, log it as a finding ("could not reach X"), \`d.back()\` or relaunch, continue. NEVER loop the same failing tap > 3 times. Pace yourself (avoid rapid-fire taps — they ANR this emulator).`,
    `- **Merged-semantics caution**: after a meaningful tap, CONFIRM the intended state actually changed (dump/screenshot). If it didn't, Flutter likely merged the semantics node and your tap hit the WRONG widget — re-tap by visual pixel position. Do NOT log "broken" until you've confirmed your tap hit the target.`,
    ``,
    `## Judgment calibration (avoid known false positives — carried forward from runs 1-12, updated after each run)`,
    `- A vertically-CENTERED empty state (icon + "No X yet" + a CTA) is BY DESIGN = PASS.`,
    `- Hebrew curriculum names (משניות, תלמוד בבלי, חומש, נ"ך, משנה ברורה, תנ"ך, תלמוד ירושלמי) are CORRECT for this Torah-study app, NOT untranslated keys.`,
    `- In RTL: a FAB at bottom-LEFT is CORRECT (Material endFloat). A trailing drill-down chevron moving to the LEFT edge is CORRECT. LinearProgressIndicator is direction-aware. Do NOT flag these.`,
    `- RTL SegmentedButton auto-mirrors correctly via Directionality — a selected segment appearing on the LEFT in RTL is BY DESIGN, not a bug. Only flag a segmented control if it is INCONSISTENT with its sibling controls, or if the primary/first option lands on the TRAILING (left) edge instead of the leading (right) edge in RTL.`,
    `- There is intentionally NO in-app UI-language switcher (the app follows device locale). The Settings "English/Hebrew" control is a Hebrew-TERMS/pronunciation setting, not app language.`,
    `- There is intentionally NO "Create Offline Account" path anymore (removed 2026-08-11, owner decision) — do NOT flag its absence as a bug; cloud sign-up is the only account-creation path now, by design.`,
    `- DO flag genuine defects: text overflow / clipping / RenderFlex cutoff, truncated labels, RAW l10n keys (literal "tabBarDashboard"/"streakSubtitle"), overlapping/misaligned widgets, controls pushed off-screen, broken/missing icons, unreadable contrast, nonsensical numbers, unlabeled buttons, English text leaking into a Hebrew UI, real RTL mis-mirroring.`,
  ].join('\n');
}

function findingItem() {
  return {
    type: 'object', additionalProperties: false,
    required: ['severity', 'screen', 'title', 'what', 'repro', 'screenshot'],
    properties: {
      severity: { type: 'string', enum: ['P0', 'P1', 'P2', 'P3'] },
      screen: { type: 'string' }, title: { type: 'string' },
      what: { type: 'string' }, repro: { type: 'string' },
      screenshot: { type: 'string' }, suspectedCode: { type: 'string' },
    },
  };
}
const SEED_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['device', 'seeded', 'summary', 'findings'],
  properties: {
    device: { type: 'string' },
    seeded: {
      type: 'object', additionalProperties: true,
      properties: {
        cloudAccount: { type: 'boolean' }, uid: { type: 'string' }, adultProfile: { type: 'boolean' },
        childProfile: { type: 'boolean' }, track: { type: 'boolean' },
        completions: { type: 'integer' }, parentPin: { type: 'boolean' }, reward: { type: 'boolean' },
      },
    },
    summary: { type: 'string' },
    findings: { type: 'array', items: findingItem() },
  },
};
const FINDINGS_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['device', 'area', 'screensAudited', 'findings'],
  properties: {
    device: { type: 'string' }, area: { type: 'string' },
    screensAudited: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['name', 'result'],
        properties: { name: { type: 'string' }, result: { type: 'string', enum: ['PASS', 'ISSUES', 'UNREACHABLE'] }, note: { type: 'string' } },
      },
    },
    findings: { type: 'array', items: findingItem() },
    coverageNotes: { type: 'string' },
  },
};
const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['verdict', 'reasoning'],
  properties: {
    verdict: { type: 'string', enum: ['real', 'false_positive', 'needs_device', 'by_design'] },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    reasoning: { type: 'string' },
    fixLocation: { type: 'string' },
  },
};

const AREAS_5560 = [
  { key: 'dashboard', title: 'Dashboard (populated)', screens: 'DashboardScreen', how: 'Enter the adult profile -> Dashboard tab. Audit greeting+date, stat row (streak/siyumim/lifetime), STATS card (overdue/due circles), Today\'s Missions + Start Learning, Active-tracks carousel with current focus. Tap a mission/Start Learning to confirm it opens learning.' },
  { key: 'learning', title: 'Learning + Completion', screens: 'LearningScreen, daily tasks, mark-complete, text display', how: 'LEARN tab -> Daily Tasks list -> open a task -> learning detail (Hebrew text RTL, Hebrew-Text/English-Translation chips, Mark complete + Next daily task). Mark one complete; confirm it advances. Audit breadcrumbs, text rendering, buttons.' },
  { key: 'content', title: 'Content Browsing', screens: 'CurriculumList, ContentHierarchy, ContentSearch, TextDisplay', how: 'LEARN -> Browse -> curriculum -> drill seder->masechta->perek->text (ContentHierarchy/TextDisplay). Tap the Search icon -> ContentSearch; try a query (Hebrew e.g. ברכות, and English e.g. "berachot"). Audit hierarchy nav, breadcrumbs, paging, text display, search empty-state guidance.' },
  { key: 'tracks', title: 'Tracks management', screens: 'TrackManagementHub, TrackDetail, EditTrack, TrackLearningOrder', how: 'Settings -> Manage Tracks (hub) -> tap the track (TrackDetail: stats, progress, action rows) -> Edit Track -> Learning Order / reorder. Also try ADD TRACK to re-walk the 7-step wizard briefly (back out before creating a duplicate). Audit forms, stats, reorder UI.' },
  { key: 'scheduler', title: 'Scheduler + Goals', screens: 'Scheduler, StudyDayConfig, GoalSetup', how: 'From the track (Edit) or dashboard reach Study Days config (7-day toggles, study/review-only) and Goal setup (Edit Goal: target slider, deadline/pace/no-deadline, pace stepper, projected finish). Audit toggles, forms, projected dates.' },
];
const AREAS_5554 = [
  { key: 'profiles_childmode', title: 'Profiles + Child mode + PIN', screens: 'ProfilePicker, ManageLearners, child dashboard/settings, PinFlow (setup/verify), ParentSettings, ParentTrackManagement', how: 'Profile Picker (audit cards/avatars). Settings -> Manage Profiles (ManageLearners: initials avatars, edit/delete menus, FAB). Switch to the CHILD profile -> child Dashboard + child Settings (child-appropriate copy). In the child, Settings -> "Parent Mode / Switch to admin" -> if no PIN, the SETUP screen: set PIN 1234 then confirm -> EXPECT it reaches the Parent Settings hub. Then Parent Settings hub rows + Parent Track Management. Relaunch + re-enter -> the VERIFY PIN dialog -> enter 1234 -> hub.' },
  { key: 'settings', title: 'Settings subtree', screens: 'Settings, CurriculumSettings, LifetimeMarking, LifetimeCurriculumMarking', how: 'Settings root: scroll the FULL list (Shabbos MODE, Calendar Preference, Hebrew Terms, Nikud, Pronunciation, Manage Tracks/Profiles, Backup & Sync, Diagnostics, version). Open Curriculum Settings; open Lifetime Marking / Lifetime Curriculum Marking. Audit every section for clipped/overflowing text on this SMALL screen, raw keys, broken toggles.' },
  { key: 'auth_account', title: 'Auth / Account', screens: 'AccountPicker, SignIn, Signup, EmptyLogin, SignOut/re-signin', how: 'This device already completed a REAL cloud sign-up during seeding (Root Cause A is fixed) — do NOT sign up a second account here. Instead: audit the Sign In / Signup screen LAYOUT again from a clean angle (navigate to them via back-navigation or the account switcher without submitting), reach Account Picker if reachable, and if safe, sign OUT then sign back IN with the already-seeded credentials to confirm the round-trip still works post-seed (this exercises the actual fixed code path, unlike run12 which could not risk it while broken). Overflow focus (small screen).' },
  { key: 'infra', title: 'Infra cross-cutting', screens: 'CityPicker, SacredTime/Shabbos, Notifications, DeviceRestore, SyncStatus', how: 'Settings -> Shabbos MODE -> "Choose city" (CityPicker: search + list). Sacred-time/Shabbos lock overlay if triggerable (note if not). Notifications settings. Sync Status indicator/banner — this is a good place to confirm cloud sync is actually flowing now that sign-in works (look for a synced/online state, not a permanent offline banner). Device Restore (note if it needs a real backup). Audit reachable surfaces; clearly mark device-only/unreachable ones.' },
];
const AREAS_5562 = [
  { key: 'gamification', title: 'Gamification + Rewards', screens: 'GamificationHub, PointConfig, RewardConfig, ParentPendingRedemptions, ChildRedemption', how: 'Enter the adult/child as seeded. Parent Mode (PIN 2580 if set) -> Gamification Hub, Point Configuration, Reward Configuration (avatar/name/points + live PREVIEW), Pending Prizes/Redemptions. Then switch to the CHILD profile -> Child Redemption (redeem points for a reward) if points exist. Audit configs, preview cards, points math, tablet width usage.' },
  { key: 'progress', title: 'Progress', screens: 'Progress, RecentActivity, LifetimeKnowledge, CurriculumProgress, SiyumimMilestones', how: 'PROGRESS tab -> stat row + nav cards. Open Recent Activity (streak calendar + bar chart + filter chips), Lifetime Knowledge (tree/filters), Curriculum Progress, Siyumim & Milestones. Audit charts, stats, empty vs populated, tablet two-column/width usage.' },
  { key: 'tutoring', title: 'Tutoring (HIGH RISK)', screens: 'InviteTutor, ManageTutors, ManageGrants, TutorAuditLog, TutorPin, AcceptInvite/DeclineInvite', how: 'Find Tutoring entry (Settings or parent area): Invite Tutor (generate invite), Manage Tutors, Manage Grants (grant/revoke), Tutor Audit Log, Tutor PIN setup/reset. Accept/Decline Invite require a real invite from another account -> if unreachable, mark UNREACHABLE with a note. Audit all reachable management screens carefully (this area is highest-risk per the catalogue, and was entirely UNREACHED in run12 due to Root Cause A — this is its first real audit pass).' },
  { key: 'hebrew_rtl', title: 'Hebrew / RTL (tablet) — run LAST', screens: 'representative set in Hebrew', how: 'Switch the app to Hebrew via device per-app locale: `d.shell("cmd locale set-app-locales ' + PKG + ' --locales he")` (try "iw" if "he" no-ops), force-stop + relaunch, confirm RTL/Hebrew. Re-audit on the tablet in RTL: Profile Picker, Dashboard, LEARN, PROGRESS, Settings (scroll), Add Track wizard step 1-2, Gamification hub, and this time ALSO Sign In / Account screens in Hebrew (unreachable-in-practice in run12, now testable). Judge RTL correctness using the calibration (endFloat/trailing-chevron/direction-aware progress = CORRECT). FLAG: English leaking into the Hebrew UI (quote it), broken RTL alignment/mirroring, clipped/tofu Hebrew, awkward tablet layout. When done, reset locale: `d.shell("cmd locale set-app-locales ' + PKG + ' --locales en")`.' },
];

// RUN13: cloud sign-up specs replace run12's "Create Offline Account" specs
// (that flow was removed 2026-08-11; run12's own report flagged this seed
// recipe as unexecutable — see docs/test-artifacts/device-audit-run12/_REPORT.md
// "Rejected / Reclassified" section, follow-up #1). Each device computes its
// OWN unique email at Python runtime (via time.time()) since Workflow scripts
// cannot use Date.now(). displayName differs per device to keep accounts
// distinguishable in the live project during manual cleanup afterward.
function seedSpec5560() {
  return [
    `Generate the account credentials FIRST, in the same Python session you'll reuse below: \`import time; EMAIL = f"e2e-run13-5560-{int(time.time())}@example.com"; DISPLAY_NAME = "Abba"\`.`,
    cloudSignupRecipe('5560'),
    `After signing in, reach the profile-creation onboarding step -> name "Abba" -> Create Profile -> Skip for now -> reach Dashboard WITH bottom nav.`,
    `Then ADD TRACK: משניות -> Self-paced -> select all sedarim -> finish the wizard. Then LEARN -> mark 2-3 daily tasks complete. (Adult-only populated state for the core learning loop.)`,
  ].join('\n');
}
function seedSpec5554() {
  return [
    `Generate the account credentials FIRST, in the same Python session you'll reuse below: \`import time; EMAIL = f"e2e-run13-5554-{int(time.time())}@example.com"; DISPLAY_NAME = "Parent"\`.`,
    cloudSignupRecipe('5554'),
    `After signing in, reach the profile-creation onboarding step -> name "Parent" -> Create Profile -> Skip for now -> reach Dashboard.`,
    `Then add a CHILD profile via Profile Picker -> Add Profile -> name "Kid" -> Child Mode -> Create Profile. A track is optional but add one (משניות, self-paced, select-all) if easy. (Goal: an adult + a child profile so child-mode/PIN/profiles can be audited.)`,
  ].join('\n');
}
function seedSpec5562() {
  return [
    `Generate the account credentials FIRST, in the same Python session you'll reuse below: \`import time; EMAIL = f"e2e-run13-5562-{int(time.time())}@example.com"; DISPLAY_NAME = "Saba"\`.`,
    cloudSignupRecipe('5562'),
    `After signing in, reach the profile-creation onboarding step -> name "Saba" -> Create Profile -> Skip for now -> reach Dashboard.`,
    `Also add a CHILD profile "Yedid". Add a track (משניות, self-paced, select-all) and mark 2 completions. Then set a PARENT PIN: enter the child -> Settings -> "Parent Mode / Switch to admin" -> SETUP -> set PIN 2580, confirm 2580 -> EXPECT the Parent Settings hub. In the hub, open Reward Configuration and create one reward (name "Ice Cream", some points), Save. (Rich state for gamification + parent-area audit.)`,
  ].join('\n');
}
const SEED_SPECS = { '5560': seedSpec5560(), '5554': seedSpec5554(), '5562': seedSpec5562() };

function seedPrompt(port, spec) {
  return [
    `You are an on-device E2E setup+audit agent (Sonnet) for the Learning Tracker Android app.`,
    driveGuide(port),
    ``,
    `## TASK: seed this device to a known POPULATED state via a REAL cloud account, auditing onboarding/wizard screens as you go.`,
    `Start from first-run: \`d.launch(clear=True)\` (pm clear + launch). This clears any prior local state but does NOT delete the cloud account you create below.`,
    spec,
    ``,
    `As you walk onboarding + the Add-Track wizard, screenshot + Read + audit each screen and collect findings (same calibration as above). The wizard scope step: tap "Select all in this list" to select all sedarim (the "I want to learn everything!" hero card also selects-all-and-advances — both are valid).`,
    `Mishnayos curriculum = "משניות". Self-paced = "Self-paced (no program)". To mark completions: LEARN -> open a daily task -> "Mark complete".`,
    ``,
    `RETURN the structured object: device="${port}", seeded={cloudAccount: true/false, uid: "<the printed uid>", adultProfile, childProfile, track, completions, parentPin, reward — whichever apply}, summary (one line, include the email used), findings[] (onboarding/wizard/signup/signin issues, calibrated).`,
  ].join('\n');
}
function auditPrompt(port, area) {
  return [
    `You are an on-device E2E UX/correctness auditor (Sonnet) for the Learning Tracker Android app.`,
    driveGuide(port),
    ``,
    `## TASK: exhaustively audit the "${area.title}" area. Walk EVERY screen listed; screenshot + Read + judge each.`,
    `Screens: ${area.screens}`,
    `How to reach / what to check: ${area.how}`,
    ``,
    `The device is already seeded (a REAL cloud account + profile + track/completions exist; some devices also have a parent PIN / reward — discover the actual state by navigating). Start by relaunching (\`d.launch()\`) and orienting from the Profile Picker or Dashboard. Do NOT pm clear. Do NOT sign up a second account.`,
    `For each screen: navigate (dump UI to find real labels), settle 1.5s, screenshot, Read the PNG, judge. Record screens that look GOOD too (so we know they were checked).`,
    ``,
    `RETURN the structured object: device="${port}", area="${area.key}", screensAudited[] (name + PASS/ISSUES/UNREACHABLE), findings[] (calibrated — only genuine defects), coverageNotes (what you could not reach + why).`,
  ].join('\n');
}
function verifyPrompt(f) {
  return [
    `You are an adversarial verifier for an on-device audit finding. Decide if it is a REAL defect, a FALSE POSITIVE, BY_DESIGN, or NEEDS_DEVICE. Be skeptical — earlier runs had many false positives from auditors misreading intentional design, RTL conventions, and Flutter merged-semantics tap artifacts.`,
    ``,
    `## Finding`,
    `- Device: ${f.device}   Area: ${f.area}   Screen: ${f.screen}`,
    `- Severity (claimed): ${f.severity}`,
    `- Title: ${f.title}`,
    `- What: ${f.what}`,
    `- Repro: ${f.repro}`,
    `- Screenshot: ${f.screenshot}`,
    `- Suspected code: ${f.suspectedCode || '(none given)'}`,
    ``,
    `## How to verify`,
    `- READ the screenshot (Read the PNG) and judge whether it actually shows a defect.`,
    `- READ the relevant code in ${REPO}/learning_tracker/lib (grep for the strings/widgets involved) to confirm the behavior is a bug vs intentional.`,
    `- Apply these known-design facts (do NOT count as bugs): centered empty states; Hebrew curriculum names; RTL endFloat FAB at bottom-left; trailing chevrons moving to the left in RTL; direction-aware LinearProgressIndicator; NO in-app language switcher (follows device locale); Shabbos defaulting ON as a study day is intentional (documented); the "I want to learn everything" CTA advances with the whole curriculum (tap-center artifacts from merged semantics are NOT a functional bug); NO "Create Offline Account" path (removed 2026-08-11, cloud sign-up only, by design).`,
    `- If it is a real localization gap in SEED DATA (e.g. English program subtitles in Hebrew), mark REAL but note it is a data/translation task.`,
    ``,
    `RETURN: verdict (real|false_positive|by_design|needs_device), confidence, reasoning (cite the code/screenshot evidence), fixLocation (file:area if real).`,
  ].join('\n');
}

// ───────────────────────── run ─────────────────────────
const runNum = 13;
const reportIntro = `Run: comprehensive 3-device parallel on-device E2E re-audit (run 13 — first pass since Root Cause A/B landed). Run 12 (docs/test-artifacts/device-audit-run12/_REPORT.md) found cloud sign-in completely unwired, blocking 65 of 72 assigned screens (only 7/72, 10%, were reachable) behind a universal sign-in wall, plus an AuthGuard misroute stranding zero-account devices. Both root causes are now fixed and deployed (commits 2a458b96, de53f1b6, tagged v1.0.71-internal, live on Google Play), along with 6 follow-on P2/P3 polish fixes from the same report (commits 515f8da1, 965e2712, 8fd16843): Back-button exit bug, sign-in watchdog/email-verification-dialog conflict, generic-error diagnostics, signup snackbar overlap, signup scroll affordance, and a password-visibility icon inconsistency. The ONE remaining known item from run12 (#3, a Firebase Console verification-email sender-name typo "Trarcker") is out of scope for this run — it needs manual Console action, not code, and does not block anything. This run's job: seed real cloud accounts (offline-account creation was permanently removed 2026-08-11) and finally audit the ~90% of the app that run12 could not reach.`;
const OUT = `${REPO}/docs/test-artifacts/device-audit-run${runNum}`;

phase('Seed');
const seedResults = (await parallel(['5560', '5554', '5562'].map(p =>
  () => agent(seedPrompt(p, SEED_SPECS[p]), { label: `seed:${p}`, phase: 'Seed', schema: SEED_SCHEMA, model: 'sonnet' })
))).filter(Boolean);
log(`Seed complete: ${seedResults.map(r => `${r.device}[${r.summary}]`).join(' | ')}`);

phase('Audit');
async function deviceChain(port, portAreas) {
  const out = [];
  for (const area of portAreas) {
    const r = await agent(auditPrompt(port, area), { label: `audit:${port}:${area.key}`, phase: 'Audit', schema: FINDINGS_SCHEMA, model: 'sonnet' });
    if (r) out.push(r);
  }
  return out;
}
const auditByDevice = await parallel([
  () => deviceChain('5560', AREAS_5560),
  () => deviceChain('5554', AREAS_5554),
  () => deviceChain('5562', AREAS_5562),
]);
const areaResults = auditByDevice.filter(Boolean).flat().filter(Boolean);
const seedFindings = seedResults.flatMap(r => (r.findings || []).map(f => ({ ...f, device: r.device, area: 'onboarding/seed' })));
const auditFindings = areaResults.flatMap(r => (r.findings || []).map(f => ({ ...f, device: r.device, area: r.area })));
const allFindings = [...seedFindings, ...auditFindings];
log(`Audit complete: ${areaResults.length} area reports, ${allFindings.length} candidate findings`);

phase('Verify');
const verified = (await parallel(allFindings.map(f =>
  () => agent(verifyPrompt(f), { label: `verify:${f.area}:${(f.screen || '').slice(0, 18)}`, phase: 'Verify', schema: VERDICT_SCHEMA, model: 'sonnet' })
    .then(v => ({ ...f, verdict: v }))
))).filter(Boolean);
const real = verified.filter(f => f.verdict && f.verdict.verdict === 'real');
const rejected = verified.filter(f => f.verdict && (f.verdict.verdict === 'false_positive' || f.verdict.verdict === 'by_design'));
const needsDevice = verified.filter(f => f.verdict && f.verdict.verdict === 'needs_device');
log(`Verify complete: ${real.length} REAL, ${rejected.length} rejected, ${needsDevice.length} needs-device`);

phase('Synthesize');
const coverage = areaResults.map(r => `${r.device}/${r.area}: ${(r.screensAudited || []).length} screens (${(r.screensAudited || []).filter(s => s.result === 'PASS').length} pass)`).join('; ');
const realList = real.map(f => `[${f.verdict.confidence || '?'}][${f.severity}] ${f.device}/${f.area} ${f.screen} — ${f.title}\n    what: ${f.what}\n    fix: ${f.verdict.fixLocation || '?'} | ${f.verdict.reasoning}`).join('\n');
const rejList = rejected.map(f => `[${f.verdict.verdict}] ${f.screen} — ${f.title}: ${f.verdict.reasoning}`).join('\n');
const synth = await agent([
  `You are the lead test architect. Write a concise markdown gate report to the file ${OUT}/_REPORT.md (use the Write tool) and return a 10-line executive summary.`,
  ``,
  reportIntro,
  `Coverage: ${coverage}`,
  ``,
  `CONFIRMED REAL findings (${real.length}):`,
  realList || '(none)',
  ``,
  `REJECTED as false-positive/by-design (${rejected.length}):`,
  rejList || '(none)',
  ``,
  `Needs-device/unverifiable (${needsDevice.length}): ${needsDevice.map(f => f.screen + ':' + f.title).join('; ') || '(none)'}`,
  ``,
  `In _REPORT.md: a verdict line (PASS/CONCERNS/FAIL with reasoning), a table of confirmed real findings (severity, device, screen, what, fix location) grouped by severity, a short "rejected false positives" section, coverage summary (compare explicitly against run12's 7/72 — how many more screens did this run actually reach?), and a "recommended fixes" list ordered by severity. Be precise and honest; do not inflate.`,
].join('\n'), { label: 'synthesize', phase: 'Synthesize', model: 'sonnet' });

return {
  seeded: seedResults.map(r => ({ device: r.device, seeded: r.seeded })),
  coverage,
  confirmedReal: real.length,
  rejected: rejected.length,
  needsDevice: needsDevice.length,
  confirmed: real.map(f => ({ severity: f.severity, device: f.device, area: f.area, screen: f.screen, title: f.title, fix: f.verdict.fixLocation })),
  report: synth,
};
