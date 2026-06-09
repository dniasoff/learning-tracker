# Self-resuming exhaustive test-and-fix loop — KICKOFF (2026-06-09)

Paste the block below into a fresh Claude Code session at the repo root, on **Opus**, with an
**Android emulator running** (see SETUP). It becomes the autonomous driver: it drives the **real app**
on the emulator, walks **every screen × every control × every permutation**, **fixes + commits +
pushes** each defect with a regression test, and **schedules its own next iteration** so it runs for
days without you re-pasting. You can interrupt at any time; it resumes from the durable state.

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
You are the SELF-RESUMING EXHAUSTIVE TEST-AND-FIX DRIVER for the Learning Tracker app
(Flutter, working dir learning_tracker/, branch dev — the project's main branch; no feature branches).

MISSION
Drive the REAL app on the Android emulator and verify ABSOLUTELY EVERYTHING — every screen, every
button, every switch, every menu option, every text string, every frame/state — across every
permutation (child / adult / tutor / parent-mode × 1-vs-many profiles × many tracks × chazara on/off ×
empty / populated / overdue / all-caught-up × en / he-RTL × online / offline). Fix every defect found,
root-cause, with a regression test, commit + push to dev, then continue. Run for DAYS until DONE.
Surface area (measured 2026-06-09): 47 @RoutePage screens · ~425 interactive elements · 987 user-facing
strings. 47 screens × the permutations = thousands of states. That is the job.

THE ONE RULE THAT MAKES THIS WORK
Every iteration MUST (a) drive at least one new (screen × permutation) cell on the emulator AND/OR fix
at least one logged bug, then (b) checkpoint state, then (c) schedule the next iteration. NEVER end an
iteration having only "planned", "analysed", or written a report. Tangible on-device progress or a
committed fix, every single time.

DURABLE STATE (resume from these every iteration — they ARE the memory)
- docs/planning/test-coverage-matrix.md   — the scoreboard. One row per screen; cells = the
  permutations above + L4 (on-device sweep). Tick a cell only when you have DRIVEN it on the emulator
  and asserted behaviour (not "renders"). This is your cursor: the next uncovered cell is the next job.
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
1. Emulator: confirm a device with `adb devices`. Prefer the emulator (stable, no calls/notification
   shade, run-as is writable so you can flip prefs to reach first-run states, free to wipe/reinstall).
   If the physical phone is the target instead, it lives at 100.72.6.10:5555 (stable port) — see
   reference_phone_testing_adb; ask for the port only if 5555 refuses.
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

ITERATION ALGORITHM (one cycle)
1. Read the matrix + bug log + loop-progress.md. Reconnect adb if needed; confirm app is foreground.
2. Pick the next uncovered (screen × permutation) batch, worst-coverage features first:
   Tutoring → Sync/offline → Tracks → Gamification+Profiles → Account+Onboarding+Nav/guards →
   Settings+Scheduler+Notifications+Dashboard+Learning → Backend CFs+rules → Visual/i18n/a11y.
3. DRIVE it on the emulator: navigate to the screen in the right permutation; for EACH interactive
   element exercise it (tap/toggle/select/long-press/swipe); after each action capture
   screencap + `uiautomator dump` + console (read_console / logcat). Use the UI tree's content-desc +
   bounds to tap precisely — never eyeball coordinates.
4. ASSERT the detection checklist (below). Anything failing is a defect.
5. For EACH defect: reproduce → find root cause in code → write a regression test that FAILS on current
   code → fix root cause (no TODOs, no tech debt) → test passes → `make ci` green (also run
   `make format-check`; `make audit` if you touched imports) → commit to dev with a clear message
   (end: Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>) → push → append to bug log.
   Prefer an on-device/integration_test regression where the bug is on-device-only; unit/widget where
   the logic is host-testable. After Drift/Freezed/Riverpod signature changes:
   dart run build_runner build --delete-conflicting-outputs.
6. Tick the matrix cells you drove; append the iteration line to loop-progress.md.
7. Schedule the next iteration (ScheduleWakeup, see SELF-RESUME). Done.

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
- NEVER substitute "I wrote/ran unit tests" for driving the screen on the emulator. The emulator walk
  is mandatory for every cell.
- NEVER write a plan/report and end. Every iteration ends with covered cells or a committed fix +
  a scheduled next iteration.
- NEVER mark a bug fixed without a regression test that failed before the fix.
- NEVER claim a cell covered without an on-device screenshot/console proof noted in loop-progress.md.
- If `make ci` is red, fix it before moving on; never commit red.
- Keep commits small and described. Push as you go (the user authorized fix+commit+push).

MODELS / FAN-OUT (optional, for speed)
You may use background Workflows to fan out the WALK (one Sonnet agent per screen to capture
screenshots + UI dumps + flag suspects) and to WRITE/verify test files. But every production-code diff,
every fix decision, and every on-device verification stays with YOU (Opus). Sonnet agents report
suspected bugs as findings; you reproduce, fix, and write the regression test.

DONE CONDITION
Every matrix cell that applies is ticked (driven on-device + asserted) AND two consecutive full passes
over the whole matrix find zero new defects. Then write a final summary to loop-progress.md (cells
covered, bugs fixed with shas, residual risks) and STOP scheduling. Until then, keep looping.

START NOW: read the three state files; do SETUP if loop-progress.md says it's not done; then run one
full iteration and schedule the next.
```

---

## How to launch

1. Start the emulator (or connect the phone at `100.72.6.10:5555`).
2. New Claude Code session on **Opus** at the repo root.
3. Paste the fenced block above. It self-resumes from there.

## How to watch / stop

- **Watch:** `docs/planning/loop-progress.md` (heartbeat), the bug log, and `git log --oneline dev`.
- **Stop:** interrupt the session, or it stops itself on DONE. Re-paste anytime to resume — state is
  in the matrix + bug log + progress file.

## What's genuinely new vs the 2026-05-29 kickoff

- **True self-resume** (ScheduleWakeup each iteration) — runs for days unattended instead of needing
  a human re-paste. This was the missing piece.
- **Real-app-first as the unit of work** — every cell is driven on the emulator; unit tests are the
  regression guard, not the coverage claim.
- **Emulator-preferred** (stable, wipe-friendly, run-as-writable) with the phone as fallback.
- **Encoded environment runbook** (App Check re-register, install -r preserves data, keepalive, JDK21,
  codegen) so device/sync friction can't silently stall the loop.
