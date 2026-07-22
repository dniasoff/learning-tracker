---
title: "Reassurance Campaign — Mission Control & Running Log"
purpose: "Durable, reboot-surviving state for the Release Reassurance campaign. If you are a fresh session (or just rebooted), READ THIS FILE FIRST, then §RESUME."
companion: "docs/test-artifacts/reassurance-plan.md (the strategy)"
last_updated: 2026-07-22
---

# Reassurance Campaign — Mission Control

> **This file is the source of truth for campaign state.** It lives in the repo
> (survives reboots — `/tmp` does not). The strategy is in
> [`reassurance-plan.md`](reassurance-plan.md); this file tracks *execution*:
> what's done, what's in flight, what's next, and **how to recover the machine
> after a reboot**.
>
> **Golden rule:** background workflows/monitors and all emulators die on reboot
> and leave NO completion marker. Never assume an in-flight item finished — verify
> via its output path / branch (see registry), and relaunch if absent.

---

## 🔴 IF YOU JUST REBOOTED / ARE A FRESH SESSION — START HERE (§RESUME)

1. **Read** this file top-to-bottom + `reassurance-plan.md`.
2. **Recover the environment** (§ENV RECOVERY) — emulators are dead after a reboot.
3. **Reconcile in-flight work** (§WORKFLOW REGISTRY) — check each run's output
   path/branch; if incomplete, relaunch (run IDs + scripts are recorded).
4. **Read the Scorecard** (§STATE) to see which surface to advance next.
5. **Continue** per the plan's §5 sequencing. Append every action to §LOG.

---

## ⚙️ ENV RECOVERY (run after any reboot)

Environment is **native Linux + KVM** (Android Studio installed a full Linux SDK;
the old WSL→Windows `adb.exe` interop is GONE). `adb` = native ELF at
`/home/daniel/Android/Sdk/platform-tools/adb`. `driver.py` works unmodified.

```bash
# 1. Relaunch the 6 AVDs (native, headless, KVM). Run from /home/daniel (or /mnt/c).
EMU=/home/daniel/Android/Sdk/emulator/emulator
cd /home/daniel
launch(){ nohup "$EMU" -avd "$1" -port "$2" -no-window -no-audio -no-snapshot-save -no-boot-anim -gpu swiftshader_indirect >/tmp/emu_$2.log 2>&1 & }
launch lt_api28_pixel2 5554   # Android 9  (small/old — overflow)
launch lt_api29_pixel3 5556   # Android 10
launch lt_api31_pixel5 5558   # Android 12
launch lt_api34_pixel7 5560   # Android 14
launch lt_api33_pixel6 5562   # Android 13 (fresh matrix cell)
launch lt_api36_tablet 5564   # Android 16 (tablet — RTL/wide)

# 2. Wait for boot (each ~10-40s with KVM):
A=/home/daniel/Android/Sdk/platform-tools/adb
for p in 5554 5556 5558 5560 5562 5564; do
  until [ "$($A -s emulator-$p get-state 2>/dev/null|tr -d '\r')" = device ] && \
        [ "$($A -s emulator-$p shell getprop sys.boot_completed 2>/dev/null|tr -d '\r')" = 1 ]; do sleep 4; done
done; $A devices

# 3. Rebuild + install the current-dev APK on all 6 (fresh AVDs start blank):
cd /home/daniel/repos/learning-tracker/learning_tracker
export PATH="/home/daniel/flutter/bin:$PATH"; flutter build apk --debug
APK=build/app/outputs/flutter-apk/app-debug.apk
for p in 5554 5556 5558 5560 5562 5564; do $A -s emulator-$p install -r -d "$APK" & done; wait
```

**Local flutter/dart env** (needed for tests/build), run from `learning_tracker/`:
```bash
export PATH="/home/daniel/flutter/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib/sqliteshim:$LD_LIBRARY_PATH"   # Drift tests
```

**Known operational facts (learned this campaign):**
- 6 concurrent emulators driven through one adb server **flap** under load (not
  OOM — box has 123 GB, ~100 free). Tolerate transient `get-state` blips; retry.
  For heavy on-device fan-out, prefer **3–4 concurrent** devices.
- **Offline-account onboarding is network-gated by design** (NOT a regression).
  To seed the offline flow you MUST cut the network first:
  `adb -s <serial> shell svc wifi disable; svc data disable; settings put global airplane_mode_on 1`
  then: launch → Skip intro → "Register Here" → **"Create Offline Account"** →
  profile (name + "Adult Mode", dismiss keyboard w/ keyevent 4 before "Create
  Profile") → "What brings you here?" → "Track my own learning" → 7-step Add-Track
  wizard (Mishnayos → Self-paced → "Select all in this list" → "Continue with N
  selected" → chazara "1 + 7 days" → … → Create). Parent PIN default `2580`.

---

## 📊 STATE — Reassurance Scorecard (live)

🔴 unguarded · 🟠 partial · 🟢 reassured (systemic guard + red-demo + in the gate)

| Surface | State | Owner / branch | Evidence when GREEN |
|---|:--:|---|---|
| R1 Child-data integrity | 🟢 | dev `ca4bd912` (+merge); red-demo `red-demos/R1-collision-scope-id.md` | **REASSURED** — property/collision sweep (20 tests, all 9 curricula) + factory consolidation; red-demoed (naive keying → 18/20 fail w/ authentic over-count); `make ci` green (10,197 pass). |
| R2 Device-reality (RTL/overflow, API 9–16) | 🟠 (2 fixes merged, ci gating) | dev `487c46e8` | wizard CTA truncation (FittedBox) + RTL chevron double-flip — both merged + red-demoed, ci gating. **Hebrew-Terms toggle finding = FALSE POSITIVE** (hiding it under he-UI is INTENTIONAL — Daniel's commit c8569b6c "issue-7bcd: hide Hebrew Terms tile when locale is Hebrew", enforced by test E2E-922); fix reverted, branch `reassurance/f-hebrew-terms-toggle` kept unmerged. Remaining for 🟢: en+he golden matrix + RTL harness. |
| **R8 Memory/perf on low-end devices (NEW, from run-8)** | 🟠 (Part A landed) | dev (merged, ci gating) | **Part A DONE + red-demoed:** items-learned aggregates now materialize ONLY curricula with completions (1-track user: 1 not 9) — fixes the common Learn-tab crash. Added `countLeavesForCurriculum` (transient, non-caching) + equivalence test. **Part B DEFERRED (correctly):** the header "X / 70,033" denominator = `\|union(all leaf refs)\|` (70,033) ≠ per-curriculum count-sum (93,395; Chumash/Nach ⊂ Tanach) — a naive count-sum would change the total, so the union-aware count path is a separate follow-up. Until Part B, the Dashboard/Lifetime-Knowledge denominator still loads all 9 → residual OOM risk there. |
| R3 Parent-PIN / privacy | 🟠 (keypad fix merged, ci gating) | dev `487c46e8` | PIN keypad tap-drop FIXED + red-demoed (onTap→onTapDown, drift-immune; was dropping fast taps → false "PINs do not match"). Remaining for 🟢: on-device nav-guard timing + de-tautologized guards + privacy invariants (Phase 3). |
| R4 Sync / cloud / rules | 🟠 | Phase 2 (not started) | rules matrix + on-device real-Firestore round-trip + convert path |
| R5 Reactivity | 🔴 | Phase 1 A1.6 (not started) | `expectRebuildsOn` contract adopted, red-demoed |
| R6 Gate & flake trust | 🟠 | Phase 4 (not started) | flake policy + risk-tier coverage + device-in-CI, red-demoed |
| R7 Full-journey acceptance | 🔴 | run-8 + A1.1 | top-20 journeys traced on-device + acceptance de-tautologized |

**Phase status:** Phase 0 (baseline) IN PROGRESS · Phase 1 (layer gaps) STARTED (R1) ·
Phases 2–5 NOT STARTED.

---

## 🔧 WORKFLOW REGISTRY (in-flight & completed)

> Workflows do NOT survive a process/machine restart. On resume, check the
> "Verify complete via" column; if the output/branch is absent, relaunch with the
> recorded scriptPath (+ `resumeFromRunId` for same-session cache).

| Run ID | Task ID | What | Output / branch | Status | Verify complete via |
|---|---|---|---|---|---|
| `wf_200850b5-faa` | wczsy20x3 | Run-8 on-device 6-device audit (Phase 0/A0.1) | `docs/test-artifacts/device-audit-run8/_REPORT.md` + `findings_<port>.md` | IN FLIGHT | `_REPORT.md` exists |
| `wf_3055001f-e0f` | w9va7ojn4 | Phase 1/R1 collision fixture + factory consolidation | branches merged to dev; red-demo `docs/test-artifacts/red-demos/R1-collision-scope-id.md` | ✅ DONE (verified) | committed on dev; `make ci` gate `b2um978z3` in flight |

| `wf_47388ca2-54d` | wnk1k4la0 | Run-8 findings fix wave (5 built) | 4 MERGED to dev `487c46e8` (wizard-cta, rtl-chevron, pin-keypad, bulk-mark-rollup); Hebrew-Terms DROPPED (false positive) | ✅ DONE; `make ci` gate in flight (READ LOG) | `git log --grep=run-8 --oneline` |

Workflow scripts (for relaunch) are auto-persisted under
`~/.claude/projects/<proj>/*/workflows/scripts/` (name-matched: `ondevice-audit-run8-*.js`,
`reassurance-p1-r1-childdata-*.js`).

---

## 🗂 ARTIFACT INDEX

| Artifact | Path |
|---|---|
| Strategy (the plan) | `docs/test-artifacts/reassurance-plan.md` |
| This mission-control log | `docs/test-artifacts/reassurance-log.md` |
| Framework validation report (gate: CONCERNS) | `docs/test-artifacts/framework-validation-report.md` |
| TEA test-architecture audit (41 findings) | `docs/test-artifacts/test-reviews/tea-audit-2026-07-09/_TEA-AUDIT.md` |
| Run-8 on-device audit (in progress) | `docs/test-artifacts/device-audit-run8/` |
| On-device driver + recipe | `tool/device_e2e/driver.py`, `README.md` |
| Baseline anchor | dev HEAD `f8b42240` |

---

## 📝 RUNNING LOG (append-only, newest at bottom)

- **2026-07-22 ~04:00** — Env changed: Android Studio installed → native Linux+KVM
  toolchain; 6 AVDs (added `lt_api33_pixel6`). Booted all 6 headless; native path
  proven (boot ~10s, screenshot integrity OK). `testing-guide.md` on-device section
  now STALE for this box (documents old WSL→Windows path) — flagged for refresh.
- **2026-07-22 ~04:20** — Framework validation completed (workflow, 16 agents):
  **gate CONCERNS** (1 PASS, 7 WARN, 0 FAIL). TEA reconciliation on dev: **9 CLOSED,
  12 PARTIAL, 20 OPEN** of 41. Report written. Verified headline (67 files assert on
  lib/ source text — tautology). Root at HEAD f8b42240.
- **2026-07-22 ~04:30** — Rebuilt fresh APK from HEAD, installed on all 6. Probed
  onboarding: **offline flow intact but network-gated** (must cut network to reach
  "Create Offline Account"). Captured full offline seed recipe (see ENV RECOVERY).
  Confirmed run-7 fixes live on dev (chazara "…schedule חזרה?" grammar).
- **2026-07-22 ~04:45** — Authored `reassurance-plan.md` (7 surfaces, 6 phases,
  Scorecard, red-demo discipline). Launched execution:
  run-8 (`wf_200850b5-faa`, Phase 0/A0.1) + R1 fixture (`wf_3055001f-e0f`, Phase 1).
- **2026-07-22 ~04:50** — Created this mission-control log. run-8 at 1/6 device
  results; R1 in design phase (no branches yet). 6 devices online. dev HEAD f8b42240.
- **2026-07-22 ~05:10** — **R1 (child-data integrity) built + red-demoed.** Workflow
  `wf_3055001f-e0f` delivered 2 worktree branches, both adversarially verified MERGE.
  Integrated: merged `r1-factory-consolidation` (canonical `ContentItemFixtures.leaf`
  + new `LedgerFixtures`, 8 consumers migrated, 79 tests green) + brought A's 2 new
  files (`collision_fixtures.dart` + property sweep, 20 tests). Ran red-demo ON dev:
  naive bare keying → 18/20 fail with authentic over-count (`bavli|B|2` wrongly
  credited); fix restored → 20/20 green. Recorded `red-demos/R1-collision-scope-id.md`.
  Committed. `make ci` gate `b2um978z3` running (bg) — on green, push + R1 → 🟢.
- **2026-07-22 ~05:30** — **R1 → 🟢 (first surface reassured).** `make ci` green
  (10,197 pass / 128 skip) with the collision sweep + factory consolidation. Pushed.
- **2026-07-22 ~05:30** — **Run-8 (Phase 0/A0.1) COMPLETE — on-device gate FAIL.**
  6/6 devices seeded profile+track (offline recipe), **140 screens** audited (API
  28→36). 23 raw → verify dropped 2 P1 false-positives → **P0=1, P2=8, P3=12**.
  Report: `device-audit-run8/_REPORT.md`. **Headline: a CONFIRMED P0 the 10,370-test
  suite never saw** — Learn/aggregates eager-load all 9 curricula → OOM on low-mem
  (API 29). Verified in code (`items_learned_providers.dart:220/259` Future.wait over
  CurriculumId.values). Logged as new surface **R8**. Confound: emulators ran
  `-gpu swiftshader_indirect` (my ENV-RECOVERY default) → ~199 host RenderThread
  segfaults muddied crash attribution; verify correctly split app-side (5556) from
  host-GPU (5560). **ACTION for ENV-RECOVERY:** prefer `-gpu host` when a display is
  available; swiftshader is crash-noisy. Other run-8 reals folded into R2/R3 rows +
  a rollup-gap P2 (bulk-mark completions don't aggregate — touches R1's neighborhood,
  UNDER-count vs the over-count R1 guards).
- **NEXT:** fix R8 P0 (bounded/lazy curricula load + constrained-heap red-demo), then
  Phase-1 remaining (R2 golden+RTL, R5 reactivity, R7 de-tautologize).
- **2026-07-22 ~06:00** — **R8 Part A GREEN on dev (`a1b04eb5`).** Merged + red-demoed
  + pushed. INCIDENT + fix (recorded honestly): first push (`ff08f438`) went RED — I
  misread a backgrounded `make ci; echo EXIT=$?` wrapper's "exit 0" as ci passing; ci
  had 6 failures. Root cause was NOT a bug: the new R8 red-demo test tripped the TQ-6
  in-memory-db-close guardrail (used `late db; db = inMemoryDb()` + separate tearDown;
  the checker only recognizes `final x = inMemoryDb()` + in-scope `addTearDown`).
  Restructured to the sanctioned form → `make audit` clean (67/67) → audit self-tests
  green → pushed `a1b04eb5`. **LESSON (now standing rule): after any backgrounded
  `make ci`, READ THE LOG for "All tests passed"/"Some tests failed" — NEVER trust the
  task-notification exit code (it's the wrapper). Verify BEFORE pushing.**
- **2026-07-22 ~06:20** — **Run-8 findings wave: 4 fixes merged, 1 dropped as false
  positive.** Kept (dev `487c46e8`, red-demoed): wizard step-7 CTA truncation (FittedBox);
  RTL chevron double-flip (both chevron icons already matchTextDirection → use plain
  chevron_right at 3 sites); PIN keypad onTap→onTapDown (drift-immune); bulk-mark rollup
  (Recent Activity All-Time UTC-vs-local-midnight clamp; PROVED Lifetime-Knowledge header
  already rolls up → no risky change, R1 untouched). **DROPPED — Hebrew-Terms toggle: the
  first `make ci` (5-merge) failed ONLY on E2E-922; investigation showed hiding the tile
  under he-UI is INTENTIONAL (Daniel's c8569b6c, test E2E-922) — a run-8 auditor false
  positive. Reset to last-green, re-merged the 4.** LESSON: on-device "common-sense"
  findings must be checked against deliberate design/tests before fixing — added to the
  campaign's fix protocol. (Second near-miss avoided by READING THE CI LOG, not the
  wrapper exit code.) → make ci gating the 4; push only on green-in-log.
- **2026-07-22 ~10:15** — **ALL reassurance work LANDED + CI GREEN on dev `a68c97d5`.**
  My 10 held commits (4 run-8 device fixes + hygiene) went up as the parent of the
  concurrent `theme/royal-blue-brightness-aware-palette` migration (another agent);
  GitHub CI for `a68c97d5` = **success** (1h16m) — that combined-state run is the gate
  I was holding for, and it's stronger than mine alone would have been.
  **Cross-agent note:** the theme agent's `faef5006` fixed a subtle re-break of MY test —
  `dart format` had split `addTearDown(database.close)` across lines, and the TQ-6 checker
  only matches it on a SINGLE line, so `bulk_mark_all_time_rollup_test.dart:108` re-flagged.
  **LESSON: keep `addTearDown(<var>.close)` on one line; `dart format` can split it and
  re-trip TQ-6.** Also: app version bumped to 1.0.66; goldens regenerated for the palette.
- *(next entries appended as waves land.)*

---

## ▶️ RESUME PROTOCOL (detailed)

1. `git -C /home/daniel/repos/learning-tracker fetch && git log --oneline -5` — is
   dev past `f8b42240`? If so, any `reassurance/*` work may already be merged; check
   `git branch -a | grep reassurance` and `git log --grep=reassurance --oneline`.
2. For each IN-FLIGHT workflow in the registry: check its "Verify complete via". If
   done → read its output, update the Scorecard + LOG. If not → relaunch the script
   (scripts under `~/.claude/.../workflows/scripts/`).
3. If continuing on-device work: run §ENV RECOVERY, then re-seed devices via the
   offline recipe.
4. Advance the next surface per plan §5 order: R1 → R3 → R2 → R4 → R5 → R6 → R7,
   each: build in worktree → red-demo → adversarial verify → merge → `make ci` green
   → flip Scorecard cell → append LOG.
5. Campaign is DONE when every Scorecard cell is 🟢 or a documented, accepted waiver;
   produce the Phase-5 sign-off (`release-trace.md` + `nfr-evidence.md`).
