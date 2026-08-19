---
title: "Device Audit Run 17 — Learning and Content Browsing"
description: "On-device audit of device 5560 after App Check token-cap diagnosis and recovery."
date: 2026-08-20
---

# Device Audit Run 17 — Learning and Content Browsing

## Executive answers

- **Sign-in on `emulator-5560`: YES.** After the reset-generated default and named App Check tokens were registered and verified through the Firebase App Check API, the existing cloud account signed in and reached the app shell.
- **Mark Complete persistence: UNTESTABLE.** Tapping the first Daily Task caused the emulator/ADB transport to disappear before the learning-detail screen opened and could be captured.
- **Final coverage:** Learning + Completion **1/4**; Content Browsing **0/4**; **1/8 total**.

## Scope

- **Device:** `emulator-5560` (Pixel 7, API 34)
- **Package:** `com.jcom.torah.learning_tracker`
- **HEAD:** `561c7a3a` (`docs(device-audit): run15 and run16 reports -- Learning/Content still 0/8`)
- **Build:** debug APK built from the above HEAD; APK mtime `2026-08-20 00:11:30 +0200`
- **Areas:** Learning + Completion; Content Browsing
- **Assigned:** 8 screens total (4 per area)

## Seed and sign-in evidence

The app shell was reached with the existing verified cloud account and the seeded local profile/track:

- **Profile:** `Run17` (adult mode)
- **Active track:** `פרק יומי`
- **Daily tasks shown:** 8

The app-data reset generated a new default debug token `48299905-9666-4ec1-9ad3-27b95e9e1a89`. It was registered as `run17-apk-default`; the registration response returned a Firebase debug-token resource, and a subsequent registry listing confirmed the entry. The named per-account FirebaseApp then generated `7f03e5d2-03ed-45ba-ba7d-49459519ba77`. It was registered as `run17-apk-named`, and the registry listing was queried again to confirm both `run17-apk-default` and `run17-apk-named` entries.

The first sign-in attempt after the reset reached Firebase Auth and named-app authentication but returned Firestore `PERMISSION_DENIED` because the named token had not yet been registered. After registering that exact token, force-stopping/relaunching, and signing in again, the app reached the dashboard/app shell. The shell visibly showed `Run17`, the active track, and 8 due tasks.

## Verdict

**PARTIALLY BLOCKED — sign-in and the Daily Tasks list passed, but opening a task took down the assigned emulator transport before Learning detail or any Content Browsing screen could be audited.**

The first Daily Tasks screenshot was visually inspected: it showed a readable Hebrew RTL list with eight real tasks (`שביעית › פרק א › משנה א` through the visible subsequent items), consistent row cards, and the LEARN navigation selected.

Tapping the first task was attempted twice from the same list state. Immediately after the tap, `adb` reported `device 'emulator-5560' not found`; the emulator process was no longer present. No post-failure app logcat or detail screenshot was available, so this report does not attribute the transport disappearance to application code.

## Coverage

### Area 1 — Learning + Completion

| Screen | Result | Note |
|---|---|---|
| LearningScreen / Daily Tasks | PASSED | App shell reached; Daily Tasks displayed 8 real Hebrew tasks and was visually inspected. |
| Learning detail / Hebrew text display | UNREACHABLE | Emulator/ADB transport disappeared immediately after opening the first task. |
| Hebrew-Text / English-Translation chips and task controls | UNREACHABLE | Detail screen was not captured. |
| Mark complete + next daily task persistence | UNTESTED | No detail screen; persistence could not be exercised. |

**Coverage: 1/4 passed.**

### Area 2 — Content Browsing

| Screen | Result | Note |
|---|---|---|
| CurriculumList | UNREACHABLE | Emulator transport was unavailable before Browse could be opened. |
| ContentHierarchy | UNREACHABLE | Curriculum/seder/masechta/perek navigation not reached. |
| ContentSearch | UNREACHABLE | Hebrew and English queries were not attempted. |
| TextDisplay | UNREACHABLE | No content text page was reached. |

**Coverage: 0/4 passed.**

**Total coverage: 1/8 passed (12.5%).**

## Historical App Check infrastructure clarification

Runs 14–16 were blocked by App Check debug-token registry exhaustion, not by the app defects initially reported from their sign-in symptoms. The registry's hard 20-token cap caused fresh named-app tokens to remain unregistered even when the run notes said both tokens had been registered; once a stale entry was pruned and the exact named token was registered, sign-in reached the app shell. Run17 verified the registration responses and queried the registry entries directly before relying on the session.

## Findings

| Device / Screen | Finding | Suggested fix location | Severity |
|---|---|---|---|
| `emulator-5560` / Daily Tasks → first task | The emulator/ADB transport disappeared immediately after tapping the first real Daily Task. This was reproduced twice. No post-failure logcat or crash dump was available, so the cause is unresolved and is not attributed here to app code. | Device/emulator crash diagnostics first; then inspect the Learning-detail route transition if the device-level failure reproduces with a stable emulator | P1 |

## Out of scope / not run

No Flutter tests, `dart analyze`, `make audit`, `build_runner`, or source-file changes were made for this audit. The APK was not rebuilt after the initial run17 build because HEAD did not move.
