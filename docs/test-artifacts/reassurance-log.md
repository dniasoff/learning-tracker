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
| R1 Child-data integrity | 🔴→(building) | wf `wf_3055001f-e0f` → `reassurance/r1-*` | property/collision fixture sweep + red-demo + factory consolidation |
| R2 Device-reality (RTL/overflow, API 9–16) | 🔴 | run-8 (baseline) → then A1.4/A1.5 | en+he golden matrix + RTL harness + multi-device on-device run |
| R3 Parent-PIN / privacy | 🔴 | Phase 3 (not started) | on-device nav-guard timing + de-tautologized guards + invariants |
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
| `wf_3055001f-e0f` | w9va7ojn4 | Phase 1/R1 collision fixture + factory consolidation | branches `reassurance/r1-collision-fixture`, `reassurance/r1-factory-consolidation` | IN FLIGHT | `git branch \| grep reassurance/r1` |

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
- *(next entries appended as waves land — record: what completed, evidence path,
  Scorecard cell moved, any branch merged + make-ci result.)*

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
