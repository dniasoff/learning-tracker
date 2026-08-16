# Self-resuming exhaustive test-and-fix loop — KICKOFF (2026-06-09)

Paste the block below into a fresh Claude Code session at the repo root, on **Opus**, with
**multiple debug devices of different types attached** (see SETUP). It becomes the autonomous
**orchestrator**: it shards the work across the devices and dispatches **Sonnet sub-agents** that do
all the hands-on work — driving the **real app** on each device, walking **every screen × every
control × every permutation**, finding and fixing defects with a regression test. The orchestrator
integrates their fixes (**one make ci → commit → push**) and **schedules its own next iteration** so it
runs for days without you re-pasting. You can interrupt at any time; it resumes from the durable state.

> Why this exists / why past "exhaustive" runs didn't deliver (read once, then it's encoded below):
> 1. **They tested fakes, not the app.** Unit/widget tests with in-memory fakes structurally cannot
>    see the bugs found by opening the app (delete, projection, sync, permissions, navigation, RTL).
>    → This loop's unit of work is *driving a real screen on the emulator*, never a fake.
> 2. **They were one-shots.** "Resumable by re-pasting" meant a human had to relaunch; in practice it
>    ran once and stopped. → This loop **self-schedules** the next iteration every cycle (ScheduleWakeup).
> 3. **"Fixed" without a red→green test** → bugs returned. → Every fix here ships a test that *failed
>    before and passes after*, against the realistic on-device scenario.

It builds on (does NOT replace) the existing machinery — same scoreboard, same bug log:
- Plan: `docs/planning/exhaustive-test-and-fix-plan-2026-05-29.md`
- Scoreboard: `docs/planning/test-coverage-matrix.md`  ← the resumable state (tick cells as covered)
- Bug log: `docs/planning/test-fix-bug-log.md`  ← one line per bug: symptom → cause → fix → test
- Driver detail: `docs/planning/on-device-exhaustive-test-plan-2026-05-31.md`

---

```
You are the SELF-RESUMING EXHAUSTIVE TEST-AND-FIX ORCHESTRATOR for the Learning Tracker app
(Flutter, working dir learning_tracker/, branch dev — the project's main branch; no feature branches).
You run on Opus. You ORCHESTRATE — you do NOT drive devices or edit code yourself. All hands-on work
(driving the app on devices, detecting defects, root-causing, fixing code, writing regression tests) is
done by Sonnet sub-agents you dispatch. Your job: plan, shard the work across devices, dispatch Sonnet
workers, integrate their results (merge fixes, run one make ci, commit + push), update the durable
state, and schedule the next iteration. Run for DAYS until DONE.

MISSION (what the fleet collectively achieves)
Verify ABSOLUTELY EVERYTHING — every screen, every button, every switch, every menu option, every text
string, every frame/state — across every permutation (child / adult / tutor / parent-mode × 1-vs-many
profiles × many tracks × chazara on/off × empty / populated / overdue / all-caught-up × en / he-RTL ×
online / offline), on MULTIPLE debug devices of DIFFERENT types (small phone / large phone / tablet /
different Android versions) so size-, locale-, and OS-specific defects surface. Every defect → root-
cause fix → red-then-green regression test → committed + pushed to dev. Surface area (measured
2026-06-09): 47 @RoutePage screens · ~425 interactive elements · 987 user-facing strings. 47 screens ×
the permutations × device types = many thousands of states. That is the job.

ORCHESTRATION ARCHITECTURE (read this twice)
- YOU (Opus orchestrator): own the coverage matrix/cursor and the durable state. Each iteration, shard
  the next batch of uncovered (screen × permutation) cells across the attached devices, dispatch one
  Sonnet WORKER per device (in parallel), collect their reports, INTEGRATE (merge their fixes, resolve
  overlaps, run ONE consolidated `make ci`, commit + push), update the matrix/bug-log/progress, then
  schedule the next iteration. You NEVER tap a device or write a production diff yourself.
- SONNET WORKERS (do all the work): spawn via the Agent tool with model: 'sonnet' and
  isolation: 'worktree'. Each worker gets {one device serial, a disjoint coverage slice, a disjoint set
  of files/features it may modify}. It drives the app on its device, detects defects per the checklist,
  root-causes, fixes ITS files, writes a failing→passing regression test, runs make ci on its slice, and
  reports back {cells driven + on-device proof (screenshot/console), defects with root cause, the diff,
  bug-log lines}. You integrate the worktrees serially.
- CONFLICT AVOIDANCE: shard so no two concurrent workers own the same files/feature (split by feature
  area AND by device). If two workers' fixes overlap, integrate one, re-run, then rebase/re-apply the
  other. One consolidated `make ci` gate before you commit — never commit red.

THE ONE RULE THAT MAKES THIS WORK
Every iteration MUST result in (a) at least one new (screen × permutation × device) cell driven by a
worker AND/OR at least one fix integrated + committed, then (b) checkpoint state, then (c) schedule the
next iteration. NEVER end an iteration having only "planned", "analysed", or written a report. Real
on-device progress or a committed fix, every single time.

DURABLE STATE (resume from these every iteration — they ARE the memory)
- docs/planning/test-coverage-matrix.md   — the scoreboard. One row per screen; cells = the
  permutations above + L4 (on-device sweep) + the device serial/type it was driven on. Tick a cell only
  when a worker has DRIVEN it on a real device and asserted behaviour (not "renders"). This is your
  cursor: the next uncovered cell is the next job to shard out.
- docs/planning/test-fix-bug-log.md       — append one line per defect: symptom → root cause → fix
  (file:line) → regression test (path) → commit sha.
- docs/planning/loop-progress.md          — create on first run; each iteration append: timestamp,
  cells covered this iter, bugs found/fixed, what's next, and any blockers. This is the human-readable
  heartbeat.

SELF-RESUME MECHANISM (this is the part that was missing before)
At the END of every iteration, after checkpointing, call ScheduleWakeup with delaySeconds 60–120 and
prompt set to the EXACT text of this kickoff (so the next firing re-enters this driver). That makes the
loop re-fire automatically and grind for days. Keep scheduling until the DONE condition is met; on DONE,
write the final report and DO NOT schedule again. If an iteration is blocked (emulator gone, etc.),
still schedule the next one with a short note in loop-progress.md so the loop self-heals.

SETUP (first iteration only — detect from loop-progress.md whether already done)
1. Devices (MULTIPLE, different types): run `adb devices -l` and record EVERY attached serial plus its
   form factor / size / Android version (the app package id is com.jcom.torah.learning_tracker). The
   fleet should span device types — e.g. a small phone, a large phone, and a tablet, ideally on
   different Android versions — so layout/overflow, RTL, and OS-specific defects surface. If NONE is
   attached, STOP and ask the user to connect devices / start emulators (do not proceed blind). If only
   one is attached, proceed with one worker and note in loop-progress.md that more device types are
   wanted. Prefer emulators (stable, no incoming calls / notification shade, run-as writable so workers
   can flip prefs to reach first-run states, free to wipe/reinstall). For a physical phone, note some
   OEMs (e.g. Samsung) mount the app data dir read-only under run-as (read prefs OK, can't flip them —
   reach first-run states by reinstall); wireless-debug ports rotate, so ask the user if a saved serial
   refuses. Maintain the live serial→type map in loop-progress.md; you assign one device per worker each
   iteration. Each worker addresses its device with `adb -s <serial> ...`.
2. Build + install the debug app:  cd learning_tracker &&
   PATH=/home/daniel/flutter/bin:$PATH JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
   ANDROID_HOME=/home/daniel/Android/Sdk ANDROID_SDK_ROOT=/home/daniel/Android/Sdk
   flutter build apk --debug   (NEVER pipe through |tail — it hides Gradle's exit code; check EXIT=$?).
   Install with `adb install -r build/app/outputs/flutter-apk/app-debug.apk` — `-r` over a same-signed
   debug build PRESERVES data + sign-in + the App Check token (no wipe, no re-register). Only a
   signature change forces a wiping uninstall.
3. Sync MUST work or sync bugs are invisible. Two options:
   (a) Firebase emulator (preferred — no App Check, no real backend): stand up firestore+auth emulators
       and point the app at them (milestone-2 wiring under lib bootstrap), OR
   (b) Real backend: after any fresh install the App Check debug token regenerates and ALL Firestore
       ops return permission-denied until re-registered. Read the new secret from the app prefs:
         adb shell run-as com.jcom.torah.learning_tracker cat 'shared_prefs/com.google.firebase.appcheck.debug.store.*.xml'
       then register it:
         curl -sS -X POST "https://firebaseappcheck.googleapis.com/v1/projects/346569574648/apps/1:346569574648:android:3519edaeb5ce5df9d6130d/debugTokens" \
           -H "Authorization: Bearer $(gcloud auth print-access-token)" \
           -H "x-goog-user-project: torah-study-tracker" -H "Content-Type: application/json" \
           -d '{"displayName":"loop-<date>","token":"<secret>"}'
       Restart the app; sync drains. (See memory reference_phone_testing_adb.)
4. KEEPALIVE so wireless ADB / the device doesn't drop on idle:  tool/adb-keepalive.sh <serial> 20 &
5. Seed the permutation fixtures (below). Build them through the REAL app UI or via the app's own
   services (TrackCreationService etc.) so they're valid by construction — never hand-write rows that
   the scheduler would reject.

PERMUTATION FIXTURES (create once; reuse across iterations)
- Profiles: one child, one adult, plus a 2nd and 3rd profile (multi-profile picker states).
- Tutor: an adult granted access to a child (tutor sees the child's PARENT/management view, learn
  view-only, live-mark barred — memory feedback_tutor_parent_view); plus a pending invite and a
  revoked grant (D18 resurrection guard).
- Tracks per profile: at least one chazara-enabled (stageOrder>1) and one single-stage; a pace goal
  and a deadline goal and a calendar program (perek/amud/tehillim); one back-dated start (→ overdue);
  one all-caught-up; one empty (no goal — must show a sane state, not a crash).
- Language: run each screen in en AND he (RTL). Offline: toggle airplane and re-walk.

ITERATION ALGORITHM (one cycle — you ORCHESTRATE; workers do the hands-on steps)
1. Read the matrix + bug log + loop-progress.md + the serial→type map. Confirm devices via
   `adb devices`; if some dropped, note it and proceed with what's attached.
2. SHARD: pick the next uncovered (screen × permutation) cells, worst-coverage features first
   (Tutoring → Sync/offline → Tracks → Gamification+Profiles → Account+Onboarding+Nav/guards →
   Settings+Scheduler+Notifications+Dashboard+Learning → Backend CFs+rules → Visual/i18n/a11y).
   Split into one DISJOINT slice per attached device — disjoint in BOTH the screens/permutations
   covered AND the files/features a worker may modify (so parallel fixes can't collide). Spread
   device types across the riskier visual/RTL cells.
3. DISPATCH one Sonnet worker per device IN PARALLEL — Agent tool, model: 'sonnet',
   isolation: 'worktree'. Give each worker its {device serial, coverage slice, owned files/features}
   and the WORKER BRIEF (below). Workers run concurrently.
4. COLLECT each worker's report: cells driven (+ screenshot/console proof), defects (symptom → root
   cause), the diff/worktree it produced, regression-test path(s), bug-log lines.
5. INTEGRATE (you, serially — this is the only place code lands on dev): merge each worker's worktree
   in turn; if two overlap, apply one, re-run, rebase/re-apply the other. After all merges run ONE
   consolidated `make ci` (+ `make format-check`; `make audit` if imports changed). After
   Drift/Freezed/Riverpod signature changes: dart run build_runner build --delete-conflicting-outputs.
   If red, dispatch a focused Sonnet fix-it worker (or have the owning worker repair) until green —
   NEVER commit red. Then commit each fix to dev (clear message; end:
   Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>) and push.
6. Update state: tick the matrix cells the workers proved, append each defect to the bug log, append
   the iteration summary (per device: cells, bugs found/fixed) to loop-progress.md.
7. Schedule the next iteration (ScheduleWakeup, see SELF-RESUME). Done.

WORKER BRIEF (hand this to each Sonnet worker, parameterised by its device + slice)
"You are a Sonnet test-and-fix worker on device <serial> (<type>). Cover ONLY this slice:
<screens × permutations>. You may modify ONLY these files/features: <list>. Work in your worktree.
For each cell: ensure the app is installed/foreground on <serial> (use `adb -s <serial>`); navigate to
the screen in the right permutation; exercise EVERY interactive element (tap/toggle/select/long-press/
swipe); after each action capture screencap + `uiautomator dump` + console — tap by the UI tree's
content-desc/bounds, never eyeballed coordinates. Apply the DETECTION CHECKLIST. For each defect:
reproduce, find root cause, write a regression test that FAILS on current code, fix the root cause in
your owned files (no TODOs/tech-debt), confirm the test passes, run make ci on your slice. REPORT back:
cells driven with proof, defects (symptom→root cause→fix file:line→test path), and your diff. Do NOT
push or commit to dev — the orchestrator integrates. If a defect needs files outside your ownership,
report it as a finding for the orchestrator to route."

DETECTION CHECKLIST (what counts as a defect on every screen)
- Crash / red error screen / exception in console.
- RenderFlex/overflow or clipped/cut-off content (any device size; use the overflow harness mindset).
- Any user-facing English string that isn't localized; wrong he/RTL layout; "Gregorian" instead of
  "English"; locale-wrong date format (US = May 11, 2026; UK/IL = 11 May 2026).
- A button/switch/tile that does nothing, or whose action silently fails (e.g. delete that dismisses
  but doesn't delete — the FK-ordering class; "No projection" when a goal+stages exist).
- A network spinner with no timeout, or UI gated on network (must be offline-first: Drift-first reads,
  queued writes, sync informational only).
- permission-denied / stuck outbox / "Sync paused — N stuck" on the owner's own data.
- Product-rule violations: any "track type" label; "parent" profile type (only child/adult); chazara
  UI on a track without chazara; tutor rendered in child-mode instead of the child's parent view;
  the persistent role/profile switcher missing from any context.
- Wrong/stale counters (points, streak, due/overdue) after an action; back/nav dead-ends.

ANTI-STALL HARD RULES (these are the failures that burned us — do not repeat)
- Workers NEVER substitute "I wrote/ran unit tests" for driving the screen on the real device. The
  on-device walk is mandatory for every cell; unit/widget tests are the regression guard, not the
  coverage claim.
- NEVER end an iteration having only planned/analysed/reported. Every iteration ends with worker-driven
  cells and/or an integrated+committed fix, PLUS a scheduled next iteration.
- NEVER mark a bug fixed without a regression test that failed before the fix.
- NEVER tick a cell without on-device screenshot/console proof noted in loop-progress.md.
- The orchestrator NEVER taps a device or writes a production diff itself; workers do. The orchestrator
  ONLY plans, dispatches, integrates, commits/pushes, and schedules.
- If the consolidated `make ci` is red, get it green before committing; never commit red.
- Keep commits small and described. Push as you go (the user authorized fix+commit+push).
- If no device is attached, ask the user — never fake on-device work.

MODELS (binding)
Orchestrator = Opus (this session). Workers = Sonnet (Agent tool, model: 'sonnet', isolation:
'worktree'). All device-driving, defect-detection, fixing, and test-writing happens in Sonnet workers;
the orchestrator does none of it by hand. For large iterations you may dispatch via the Workflow tool
(one worker per device, fanned out), but the integrate→make-ci→commit→push gate stays with the
orchestrator, serial.

DONE CONDITION
Every matrix cell that applies is ticked (driven on-device + asserted) AND two consecutive full passes
over the whole matrix find zero new defects. Then write a final summary to loop-progress.md (cells
covered, bugs fixed with shas, residual risks) and STOP scheduling. Until then, keep looping.

START NOW: read the three state files + the serial→type map; do SETUP if loop-progress.md says it's
not done; then run one full iteration — SHARD across the attached devices, DISPATCH one Sonnet worker
per device, COLLECT + INTEGRATE (one make ci, commit, push), update state — and schedule the next.
```

---

## How to launch

1. Attach **multiple debug devices of different types** (e.g. small phone + large phone + tablet,
   ideally different Android versions) — emulators preferred. Confirm with `adb devices -l`.
2. New Claude Code session on **Opus** at the repo root.
3. Paste the fenced block above. The Opus orchestrator shards across the devices, dispatches Sonnet
   workers, integrates, and self-resumes from there.

## How to watch / stop

- **Watch:** `docs/planning/loop-progress.md` (heartbeat — per-device cells + bugs each iteration), the
  bug log, and `git log --oneline dev`.
- **Stop:** interrupt the session, or it stops itself on DONE. Re-paste anytime to resume — state is
  in the matrix + bug log + progress file.

## What's genuinely new vs the 2026-05-29 kickoff

- **Opus orchestrates, Sonnet does all the work** — the orchestrator never taps a device or edits
  code; it shards, dispatches Sonnet workers (one per device, worktree-isolated), integrates, and
  schedules. Workers do the driving, detecting, fixing, and test-writing.
- **Multiple devices of different types in parallel** — size/RTL/OS-specific defects surface that a
  single device hides.
- **True self-resume** (ScheduleWakeup each iteration) — runs for days unattended instead of needing
  a human re-paste. This was the missing piece.
- **Real-app-first as the unit of work** — every cell is driven on a real device; unit tests are the
  regression guard, not the coverage claim.
- **Encoded environment runbook** (App Check re-register, install -r preserves data, keepalive, JDK21,
  codegen) so device/sync friction can't silently stall the loop.
