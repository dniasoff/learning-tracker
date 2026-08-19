---
title: "Device Audit Run 18 — Learning and Content Browsing"
description: "On-device audit of Learning completion and curriculum browsing on the reprovisioned emulator."
date: 2026-08-20
---

# Device Audit Run 18 — Learning and Content Browsing

## Executive answers

- **Sign-in on `emulator-5560`: YES.** The preserved signed-in session reached the app shell with the `Run17` learner profile and active track.
- **Mark Complete persistence: YES.** Marking the first daily task complete survived an emulator restart: the dashboard showed a 1-day streak and 1 lifetime item, and the completed task was absent from the subsequent Daily Tasks list.
- **Final coverage:** Learning + Completion **4/4**; Content Browsing **4/4**; **8/8 total**.

## Scope

- **Device:** `emulator-5560` (Pixel 7, API 34)
- **Package:** `com.jcom.torah.learning_tracker`
- **HEAD:** `561c7a3a` (`docs(device-audit): run15 and run16 reports -- Learning/Content still 0/8`)
- **Build:** debug APK built from the above HEAD; APK mtime `2026-08-20 00:11:30 +0200`
- **Device provisioning:** AVD reprovisioned to 6 GB RAM and 1 GB heap before this run; app data was preserved and no `pm clear`, wipe, or reinstall was performed.
- **Areas:** Learning + Completion; Content Browsing
- **Assigned:** 8 screens total (4 per area)

## Seed and sign-in evidence

The existing cloud session remained usable after the no-wipe AVD relaunch. The app shell visibly showed:

- **Profile:** `Run17` (adult mode)
- **Active track:** `פרק יומי`
- **Daily tasks:** 8 before completion, then 7 after completion

No App Check token reset was performed in this run, so the default and named-app debug tokens from run17 remained in the preserved app data. Sign-in was not re-entered; the restored session opened directly to the authenticated app shell.

## Verdict

**PASS — all eight assigned screens were reached and visually inspected.** Learning detail displayed readable Hebrew RTL text, the Hebrew-Text and English-Translation controls, and completion controls. Mark Complete persisted across an emulator restart. Content Browsing displayed the curriculum hierarchy with breadcrumbs, Hebrew text, and the Search screen. The English query `berachot` produced the observed no-results state with guidance to try the Hebrew name (`ברכות`).

The exact RTL query string could not be injected through `adb shell input text` on this device (the command rejected the Unicode payload); therefore this report makes no claim about the result set for an exact typed `ברכות` query. The Search screen itself, its Hebrew-name guidance, and the English query path were observed.

## Coverage

### Area 1 — Learning + Completion

| Screen | Result | Note |
|---|---|---|
| LearningScreen / Daily Tasks | PASSED | Real Hebrew RTL daily-task cards were displayed; after completion the list dropped from 8 to 7 items. |
| Learning detail / Hebrew text display | PASSED | Breadcrumbs and readable Hebrew text were displayed for `שביעית › פרק א › משנה א`. |
| Hebrew-Text / English-Translation chips and task controls | PASSED | `Hebrew Text`, `English Translation`, `Mark complete`, and `Next daily task` were visible and actionable on the detail screen. |
| Mark complete + next daily task persistence | PASSED | After marking complete, restart/re-entry showed a 1-day streak, 1 lifetime item, and the completed task removed from Daily Tasks. |

**Coverage: 4/4 passed.**

### Area 2 — Content Browsing

| Screen | Result | Note |
|---|---|---|
| CurriculumList | PASSED | Browse Content opened to the `משניות` curriculum and displayed the seder list. |
| ContentHierarchy | PASSED | `מועד` → `שבת` → `פרק א` navigation worked; breadcrumbs were visible at each drilled level. |
| ContentSearch | PASSED | Search opened from the hierarchy. `berachot` produced a no-results state with Hebrew-name guidance; exact RTL input was not verifiable through the device input tool. |
| TextDisplay | PASSED | `משניות › מועד › שבת › פרק א` opened with readable Hebrew text and previous/next controls. |

**Coverage: 4/4 screens reached (8/8 total).**

## Findings

| Device / Screen | Finding | Suggested fix location | Severity |
|---|---|---|---|
| `emulator-5560` / Learning detail → Back after Mark Complete | The emulator process and ADB transport disappeared immediately after returning from the completed learning detail. The 6 GB / 1 GB AVD was restarted without wiping data and the persisted completion was then verified. No `dmesg`, `journalctl`, or logcat OOM evidence was available, so this is recorded as an unresolved device-level stability issue rather than attributed to app code. | Device/emulator diagnostics first; if reproducible on a stable host, inspect the Learning-detail back-navigation lifecycle | P1 |

## Historical App Check infrastructure clarification

Runs 14–16 were blocked by App Check debug-token registry exhaustion, not by the app defects initially reported from their sign-in symptoms. Run17 recovered the preserved session after registering the exact default and named-app tokens; run18 retained that working state without clearing app data.

## Out of scope / not run

No Flutter tests, `dart analyze`, `make audit`, `build_runner`, or source-file changes were made for this audit. The APK was not rebuilt during run18 because HEAD did not move and the existing APK mtime predates this audit but is newer than the fix build used for run17.
