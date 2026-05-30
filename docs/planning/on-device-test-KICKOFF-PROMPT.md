# KICKOFF PROMPT — Exhaustive on-device test-and-fix sweep

> Paste everything below this line into a fresh agent. It is self-contained.

---

You are running an **exhaustive on-device test-and-fix sweep** of the Learning Tracker Flutter app on Daniel's
real Android phone, driven by ADB. Your job: **touch every screen, press every button, exercise every toggle /
field / gesture / state, run every end-to-end flow — confirm each works, and fix every defect you find** (root
cause + regression test), committing green to `dev`. This is the on-device verification that automated tests
cannot replace. Work autonomously; do not wait on Daniel.

## The plan you are executing
`docs/planning/on-device-exhaustive-test-plan-2026-05-31.md` — **126 screen-entries, 1,353 enumerated interactive
elements, 14 cross-cutting flows**, every one a numbered step with an explicit Expected result and a Pass/Fail/Notes
column. Read it. It is the source of truth for what to test. (It was generated from the actual screen source.)

## Device + build setup (do this first)
1. `adb connect 100.72.6.10:5555` → confirm `adb devices` shows `100.72.6.10:5555  device`. (Phone is on Tailscale;
   a keepalive script is at `tool/adb-keepalive.sh` if the link drops.)
2. `export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` (Gradle needs JDK 21).
3. Build the CURRENT code and install it **without wiping data**:
   - `cd learning_tracker && flutter build apk --debug`
   - `adb -s 100.72.6.10:5555 install -r build/app/outputs/flutter-apk/app-debug.apk`
   - The installed build is **debug-signed** (no `key.properties`), so `-r` preserves the user's profiles/tracks.
     **Never `adb uninstall`** (wipes data) without Daniel's explicit OK — use a throwaway/test profile to reach
     first-run states instead, or `pm clear` ONLY with explicit OK.
   - Confirm version updated: `adb -s 100.72.6.10:5555 shell dumpsys package com.jcom.torah.learning_tracker | grep -E "versionName|lastUpdateTime"`.
4. Launch: `adb -s 100.72.6.10:5555 shell monkey -p com.jcom.torah.learning_tracker 1`.

## The execution loop (per step in the plan)
- **Screenshot:** `adb -s 100.72.6.10:5555 exec-out screencap -p > /tmp/s.png`, then **Read `/tmp/s.png`** (it's an
  image — you can see the screen). Save evidence shots to `/tmp/ondevice/<screen>-<step>.png`.
- **Act on the element:** tap its on-screen coordinates → `adb ... shell input tap <x> <y>` (screen is 1080×2340).
  Swipe `input swipe x1 y1 x2 y2 <ms>`; type `input text 'foo'`; Back `input keyevent 4`.
- **Verify:** screenshot after; compare to the step's Expected result; mark **Pass/Fail/Notes** (with the shot
  filename) in the plan's table column.
- **Reach each State row:** offline → `adb ... shell svc wifi disable && svc data disable` (re-enable after);
  dark mode → `adb ... shell cmd uimode night yes`; Hebrew/RTL → device Settings → Languages. child/adult/tutor
  modes → use the top switcher / sign in as the relevant account.
- ⚠ **Do NOT trigger native Android dialogs you can't dismiss** (permission system dialogs are OK — grant/deny via
  tap). If the app hangs, screenshot + `adb logcat -d`.

## When a step FAILS (the point of the exercise)
1. Reproduce; capture the after-screenshot + `adb -s 100.72.6.10:5555 logcat -d` around the action.
2. Log it in **§D Defect log** of the plan (screen/flow, step, severity, symptom, repro).
3. **Fix the root cause** in `lib/` (per Daniel's standing mandate: fix everything, no tech debt, rewrite wrong
   sections if needed — see memory `project_two_day_autonomous_run`), **add a regression test**, run
   `make ci` (must stay green — note: `make ci` includes `dart format --set-exit-if-changed .`, so run
   `dart format .` before committing), rebuild+reinstall, and **re-verify on-device**.
4. Commit green to `dev` with a clear message (no feature branches — memory `feedback_no_feature_branches`).
   End commit messages with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
5. If a fix needs a product decision you can't infer, log it and keep going (don't block).

## Confirm these explicitly (high-value)
- **Product rules** (§2 of the plan): no track-type label; chazara only when enabled; tutor can't live-mark (sees
  child's parent-view, not child mode); persistent top switcher in every context; Settings account/profile
  separation; account switch with no sign-out; back-date→overdue; bulk/lifetime sentinel-date credit; Hebrew terms
  + locale dates; offline-first; adults have no points.
- **This run's fixes** (§3): the 5 route guards never lock out/hang; account-merge "discard local" doesn't crash;
  sacred-time in-Israel toggle sticks; scope-Save disabled on empty subset; redemption double-tap guard; deep-link
  doesn't crash. Confirm the deployed Cloud Functions take effect (tutor mutations, invite lifecycle, deletes).
- **The 2 push-route screens** (§0): `BulkMarkScreen`, `LearningProcessWizardScreen`.
- **Resolve dead/non-routed items** (§0): `ParentPortalBottomNav`, `ScopeSelectionScreen`, `TrackLearningOrderScreen`
  — delete if provably dead, or document/wire.

## Suggested order & checkpointing (it's a long sequential sweep — one device)
1. **Flows first** (§F1–F14) — they surface the most defects fastest and exercise many screens in context.
2. Then **cluster by cluster** (§1→§12), screen by screen, element by element.
3. The device is a single sequential resource — you cannot parallelize tapping. Checkpoint progress by committing
   the updated plan (Pass/Fail marks) + defect log periodically so the sweep is resumable.
4. Keep a running tally in §D and the §S sign-off checklist.

## Definition of done
Every step in §1–§12 walked + marked; every State row verified; all 14 flows passed; every Fail fixed +
regression-tested (or escalated); `make ci` green; on-device re-verified; §S sign-off checklist all ticked.
Report: screens covered, elements exercised, defects found+fixed (with commits), and anything escalated.

## Background / memory to read first
`docs/planning/exhaustive-test-and-fix-plan-2026-05-29.md`, `docs/planning/test-fix-bug-log.md`,
`docs/planning/test-coverage-matrix.md`, and the auto-memory under
`~/.claude/projects/-home-daniel-repos-learning-tracker/memory/` (esp. `project_two_day_autonomous_run`,
`reference_phone_testing_adb`, the product-rule + tutor + profile-switcher memories).
