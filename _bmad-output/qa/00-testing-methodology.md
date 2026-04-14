# Manual Testing Methodology

**Project:** Learning Tracker (Torah learning tracker, Flutter/Dart Android app)
**Created:** 2026-04-13
**Purpose:** Guide a developer through systematic manual testing of ~80+ implemented stories

---

## Table of Contents

1. [Purpose and Overview](#1-purpose-and-overview)
2. [Environment Setup](#2-environment-setup)
3. [App State Management](#3-app-state-management)
4. [Bug Filing via Claude Code and Linear](#4-bug-filing-via-claude-code-and-linear)
5. [Bug Report Template](#5-bug-report-template)
6. [Severity Classification](#6-severity-classification)
7. [Progress Tracking](#7-progress-tracking)
8. [Testing Tips](#8-testing-tips)
9. [Document Index](#9-document-index)

---

## 1. Purpose and Overview

### Why We Are Doing This

Learning Tracker has ~80+ stories implemented without manual testing. The automated test suite (unit, widget, integration) catches logic errors, but it cannot answer two questions that only a human tester can:

1. **Does it work?** Does the feature function correctly on a real device, with real data, in real-world conditions (poor network, low memory, interrupted flows)?
2. **Does it make sense as a product?** Is the flow intuitive? Does the screen feel right for a 12-year-old doing his daily learning? Would an adult find it respectful of his time? Would a parent trust it?

Your job is to answer both questions. When something is broken, file a bug. When something works but feels wrong, file an enhancement. Both are valuable.

### What You Will Test

You will work through **18 test documents**, one per feature area of the app. Each document contains numbered scenarios with unique IDs (e.g., `AUTH-03`, `LEARN-12`). Scenarios are tagged by priority so you can focus on what matters most first.

The features span the full app: authentication, onboarding, content browsing, learning completion, review scheduling, gamification, parent and tutor modes, notifications, sync, settings, and more.

### Your Mindset

You are not just checking boxes. You are the first real user of this app. Notice what delights you. Notice what confuses you. Notice what makes you reach for the back button. All of it matters.

---

## 2. Environment Setup

### 2.1 Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| Flutter SDK | Build and run the app | [flutter.dev/get-started](https://flutter.dev/docs/get-started/install) |
| Android Studio | Emulator management, ADB | [developer.android.com/studio](https://developer.android.com/studio) |
| ADB (comes with Android Studio) | Physical device connection | Included with Android Studio |

Verify your setup:

```bash
flutter doctor
```

All checks should pass for Android development (Flutter, Android toolchain, Android Studio).

### 2.2 Android Emulator Setup

You need **two emulators** for thorough testing:

| Emulator | API Level | Purpose |
|----------|-----------|---------|
| **Minimum target** | API 21 (Android 5.0) | Catches compatibility issues, older layouts |
| **Modern target** | API 34 (Android 14) | Matches most current devices, tests latest features |

**Creating an emulator:**

1. Open Android Studio > Tools > Device Manager
2. Click "Create Device"
3. Choose a Pixel device (Pixel 6 is a good default)
4. Select the system image for your target API level
5. Name it clearly (e.g., `Pixel6_API34`, `Pixel6_API21`)
6. Finish and launch

**Configuring network toggling (for offline testing):**

In the emulator, use the extended controls (three-dot menu at the bottom of the emulator toolbar):

- Settings > Cellular > Network type: Set to "None" to simulate offline
- Or toggle airplane mode from the Android notification shade

### 2.3 Physical Device Setup

1. On the Android device: Settings > About phone > tap "Build number" 7 times to enable Developer Options
2. Settings > Developer Options > enable "USB debugging"
3. Connect via USB cable
4. Accept the "Allow USB debugging?" prompt on the device
5. Verify connection:

```bash
adb devices
```

You should see your device listed.

### 2.4 Building and Running the App

```bash
cd learning_tracker

# First time, or after code changes that affect generated files:
dart run build_runner build --delete-conflicting-outputs

# Run on connected device or emulator:
flutter run
```

If you have multiple devices connected, specify which one:

```bash
flutter devices                    # List available devices
flutter run -d <device-id>         # Run on specific device
```

### 2.5 Two Testing Modes

| Mode | Best For | How |
|------|----------|-----|
| **Emulator** | Repeatable screenshots, network toggling, state resets, testing multiple API levels | `flutter run -d emulator-5554` |
| **Physical device** | Performance feel, real notification behavior, actual touch responsiveness, real network conditions | `flutter run -d <device-id>` |

Start with the emulator for systematic scenario execution. Switch to physical device for performance-sensitive features (dashboard loading, animations, notification delivery).

---

## 3. App State Management

Learning Tracker uses two separate SQLite databases. Understanding them is essential for controlling test state.

### 3.1 The Two Databases

| Database | Type | Contains | Reset Behavior |
|----------|------|----------|----------------|
| **ContentDatabase** | Read-only, bundled in APK | Curriculum content (~52K items), calendar data (~30K rows), Sefaria-sourced text | Restored from bundled seed on reinstall |
| **UserDatabase** | Read-write, user-generated | Completions, tracks, stages, settings, profiles, sync queue, streaks, XP | Cleared on "Clear Data" or uninstall |

### 3.2 Full Reset

Use this between unrelated test documents or when you need a completely fresh start.

**Option A — Clear Data (faster):**

1. On the device/emulator: Settings > Apps > Learning Tracker > Storage > Clear Data
2. Relaunch the app (you will see the onboarding flow)

**Option B — Uninstall and reinstall:**

```bash
adb uninstall com.dniasoff.learning_tracker   # Adjust package name if different
flutter run
```

This also re-extracts the ContentDatabase from the bundled seed, so use this if you suspect content DB corruption.

### 3.3 Partial Reset

Some scenarios require specific prior state (e.g., "user has 50 completions"). Rather than full reset:

- Use the app's **Settings > Data Export** to save state before a destructive test
- Use **Settings > Data Import** to restore it afterward

### 3.4 When to Reset vs. Continue

| Situation | Action |
|-----------|--------|
| Starting a new test document | Full reset |
| Moving between scenarios within the same document | Continue (unless the scenario says otherwise) |
| A scenario explicitly says "fresh install" | Full reset |
| You suspect corrupted state is causing a false failure | Full reset, then retry |
| A scenario says "requires N completions" | Build up state from prior scenarios, or use import |

---

## 4. Bug Filing via Claude Code and Linear

The project uses **Linear** for issue tracking. Bugs are filed through **Claude Code** using the Linear MCP integration.

### 4.1 Project Details

| Field | Value |
|-------|-------|
| Team key | `DNI` |
| Project | `learning-tracker` |

### 4.2 How to File a Bug

Open Claude Code and describe the bug. Example prompt:

```
Create a Linear issue in team DNI with title '[BUG] [Auth] Cloud-born signup
crashes on slow network' and description with the following:

Test Scenario ID: AUTH-03
Severity: S1-Critical
Device: Emulator API 34
Steps: 1) Enable slow network in emulator 2) Launch app 3) Choose "Create Account"
4) Enter email and password 5) Tap "Sign Up"
Expected: Account created with loading indicator
Actual: App crashes with unhandled exception
```

Claude Code will use the `mcp__linear__save_issue` tool to create the issue in Linear.

### 4.3 Bug Title Format

```
[BUG] [Feature Area] Brief description
```

Examples:
- `[BUG] [Scheduler] Daily tasks not recalculated after timezone change`
- `[BUG] [Gamification] XP counter shows negative value after undo`
- `[BUG] [Content Browsing] Hebrew text truncated on small screens`

### 4.4 Traceability

Always include the **test scenario ID** (e.g., `AUTH-03`) in the bug description. This connects the bug back to the exact test that found it, making reproduction and verification straightforward.

---

## 5. Bug Report Template

Use this structure for every bug, whether filing via Claude Code or documenting for later filing:

```
**Test Scenario ID:** [e.g., LEARN-12]
**Severity:** [S1-Critical / S2-Major / S3-Minor / S4-Enhancement]
**Device:** [Emulator API XX / Physical Device Model]
**App Version:** [from Settings screen or pubspec.yaml]

**Steps to Reproduce:**
1. ...
2. ...
3. ...

**Expected Behavior:**
...

**Actual Behavior:**
...

**Screenshots/Recording:**
[Attach or describe]

**Additional Context:**
[Any relevant state, e.g., "offline mode", "child account", "3 tracks active"]
```

### Tips for Good Bug Reports

- **Be specific in steps.** "Tap the button" is vague. "Tap the blue 'Mark Complete' button at the bottom of the Berachos 1:1 detail screen" is reproducible.
- **Include the starting state.** Did you just do a fresh install? Are you logged in as a child or adult? How many tracks are active?
- **Separate observation from interpretation.** "Actual: Screen goes blank" (observation) is better than "Actual: App crashed" (interpretation that may be wrong).
- **Attach screenshots.** A picture of the broken state is worth a thousand words. On emulator, use the camera icon in the toolbar. On physical device: `adb exec-out screencap -p > bug-screenshot.png`

---

## 6. Severity Classification

| Severity | Label | Description | Examples | Action |
|----------|-------|-------------|----------|--------|
| **S1** | Critical | App crash, data loss, data corruption, security vulnerability | Crash on launch; PIN bypass lets anyone access child account; completions silently deleted; unhandled exception on common flow | File immediately. Stop testing the affected area. Note it as a blocker for dependent scenarios. |
| **S2** | Major | Feature completely broken or displays wrong data | Completion not recorded after tapping "Mark Complete"; scheduler shows items from wrong curriculum; sync silently fails without error | File immediately. Continue testing other scenarios in the document. |
| **S3** | Minor | UI glitch, cosmetic issue, minor layout problem | Text truncated on small screen; wrong icon color; animation jank; alignment off by a few pixels | File after finishing the current test document. |
| **S4** | Enhancement | Feature works correctly but UX could be better | "It would be easier if this button were larger"; "This confirmation dialog seems unnecessary"; "The success animation is too slow" | Note it. File in batch at the end of the testing session. |

### When in Doubt

- If users would lose data or trust: **S1**
- If users cannot complete a task: **S2**
- If users notice something wrong but can work around it: **S3**
- If you are suggesting an improvement: **S4**

---

## 7. Progress Tracking

### 7.1 Tracking Sheet

Create a simple tracking table (spreadsheet or markdown) with these columns:

| Scenario ID | Description | Priority | Status | Date | Notes | Linear Issue |
|-------------|-------------|----------|--------|------|-------|--------------|
| AUTH-01 | Cloud-born signup happy path | P0 | Pass | 04/14 | | |
| AUTH-02 | Local-born signup happy path | P0 | Pass | 04/14 | | |
| AUTH-03 | Signup with no network | P0 | Fail | 04/14 | Crash on submit | DNI-245 |
| AUTH-04 | Duplicate email handling | P1 | Skip | | Blocked by AUTH-03 | |

**Status values:**
- **Pass** — Scenario works as expected
- **Fail** — Bug found, Linear issue filed
- **Blocked** — Cannot test due to a blocker (note which scenario blocks it)
- **Skip** — Intentionally skipped (explain why in Notes)

### 7.2 Priority System

Each scenario is tagged with a priority level:

| Priority | What It Covers | When to Test |
|----------|----------------|--------------|
| **P0** | Happy paths, data integrity, security | First pass (weeks 1-2) |
| **P1** | Edge cases, cross-feature interactions | Second pass (week 3) |
| **P2** | Rare combinations, performance, stress | Third pass (as time permits) |

### 7.3 Recommended Approach

**Three-pass strategy:**

| Pass | Focus | Scenarios | Estimated Time |
|------|-------|-----------|----------------|
| **P0 first pass** | Happy paths, data integrity, security | ~150 scenarios | ~2 weeks |
| **P1 second pass** | Edge cases, cross-feature interactions | ~150 scenarios | ~1 week |
| **P2 third pass** | Rare combinations, performance | ~150 scenarios | As time permits |

**Daily cadence:**
- One test document per day
- ~2-3 hours per document
- File bugs as you go (do not batch them)
- At end of day, update the tracking sheet

**Total effort:** ~3-4 weeks for one developer across all 18 documents.

---

## 8. Testing Tips

### 8.1 Always Note Your Context

Every scenario result should record:

- **Account type:** Cloud-born or local-born
- **User mode:** Child or adult
- **Active curricula:** Which curricula have tracks set up (e.g., Mishnayos + Bavli)
- **Network state:** Online, offline, or transitioning

These variables dramatically affect behavior. A bug that only appears for local-born child accounts in offline mode is still a real bug.

### 8.2 Curriculum Testing Strategy

Test with at least **two curricula** to catch hierarchy-specific bugs:

| Curriculum | Why It Matters |
|------------|---------------|
| **Mishnayos** | 4-level hierarchy (seder > masechta > perek > mishna). Tests deep nesting, large item counts (4,192 items). |
| **Gemara Bavli** | Daf-based structure (masechta > daf > amud). Tests 2-level leaf items, ~2,711 dapim. Different content structure than Mishnayos. |

If time permits, also test **Chumash** (5,845 items, largest dataset) for performance.

### 8.3 Offline Testing

For scenarios that require offline behavior:

- **Emulator:** Extended controls > Cellular > Network type > None
- **Physical device:** Swipe down notification shade > Airplane mode

When testing offline-to-online transitions:
1. Perform actions offline
2. Re-enable network
3. Wait for sync indicator
4. Verify data integrity

### 8.4 Screenshot Discipline

- Take screenshots **before** filing bugs, not after (the state may change)
- Emulator: Click the camera icon in the emulator toolbar
- Physical device: `adb exec-out screencap -p > screenshot.png`
- Screen recording (physical device): `adb shell screenrecord /sdcard/recording.mp4` (Ctrl+C to stop, then `adb pull /sdcard/recording.mp4`)

### 8.5 Blocker Awareness

If a **P0 scenario fails**, immediately:
1. File the bug as S1 or S2
2. Note it as a blocker in the tracking sheet
3. Check if other scenarios in the document depend on it
4. Mark dependent scenarios as "Blocked" with a reference to the blocker
5. Continue testing non-dependent scenarios

### 8.6 The "Fresh Eyes" Rule

If you have been testing the same feature for over an hour and everything starts looking fine, take a break. Fresh eyes catch more bugs than tired ones.

### 8.7 Common Gotchas

- **Hebrew text rendering:** Check that Hebrew text displays right-to-left correctly, especially in mixed Hebrew/English contexts.
- **Timezone sensitivity:** The app uses Hebrew calendar dates. Test near day boundaries (sunset time) if your scenarios involve date-sensitive logic.
- **First launch vs. subsequent launch:** Some bugs only appear on first launch (seed DB extraction, onboarding) or only on subsequent launches (cached state, stale data).
- **Background/foreground transitions:** Minimize the app, wait a moment, and bring it back. Does state survive? Does the sync resume?

---

## 9. Document Index

The 18 test documents correspond to the 18 feature areas of the app. Work through them in the order listed below — earlier documents set up state that later documents may depend on.

| # | File | Feature Area | Description | Approx. Scenarios |
|---|------|-------------|-------------|-------------------|
| 01 | `01-auth.md` | Authentication | Cloud-born and local-born signup/signin, PIN, session management | ~25 |
| 02 | `02-onboarding.md` | Onboarding | First launch flow, seed DB extraction, welcome screens, connectivity detection | ~20 |
| 03 | `03-profiles.md` | Profiles | Child/adult profiles, profile switching, profile settings | ~20 |
| 04 | `04-content-browsing.md` | Content Browsing | Curriculum hierarchy navigation, search, Hebrew/English display, content detail | ~30 |
| 05 | `05-track-setup.md` | Track Setup | Personal/school/tutor track creation, configuration, removal | ~25 |
| 06 | `06-stages.md` | Stages | Stage definitions (learn + chazara), custom timing, stage progression | ~20 |
| 07 | `07-learning.md` | Learning | Mark completion, undo, bulk completion, stage transitions | ~30 |
| 08 | `08-learning-order.md` | Learning Order | Drag-and-drop reordering, custom sequences, order persistence | ~20 |
| 09 | `09-scheduler.md` | Scheduler | Daily task generation, pace calculation, catch-up, cross-curriculum composition | ~30 |
| 10 | `10-progress.md` | Progress | Completion history, statistics, streaks, progress visualization | ~25 |
| 11 | `11-dashboard.md` | Dashboard | Main dashboard, curriculum cards, daily summary, pace indicators | ~25 |
| 12 | `12-gamification.md` | Gamification | XP, levels, badges, streaks, mystery rewards (child mode) | ~25 |
| 13 | `13-parent-mode.md` | Parent Mode | Parent PIN access, reward management, progress monitoring, track configuration | ~25 |
| 14 | `14-tutor-mode.md` | Tutor Mode | Tutor read-only access, session logging, progress visibility | ~20 |
| 15 | `15-test-tracking.md` | Test Tracking | Dirshu and other test program tracking, score recording | ~20 |
| 16 | `16-notifications.md` | Notifications | Daily reminders, streak warnings, schedule-based notifications | ~20 |
| 17 | `17-sync.md` | Sync | Firestore sync, conflict resolution, offline queue, sync indicators | ~30 |
| 18 | `18-settings.md` | Settings | App settings, data export/import, account management, tier display | ~25 |

**Total: ~455 scenarios across 18 documents**

### Recommended Testing Order

The order above is intentional:

1. **Documents 01-03** (Auth, Onboarding, Profiles) establish the user and account — everything else depends on these working.
2. **Documents 04-06** (Content, Tracks, Stages) set up the learning infrastructure.
3. **Documents 07-10** (Learning, Order, Scheduler, Progress) cover the core daily workflow.
4. **Documents 11-12** (Dashboard, Gamification) test the surfaces users see most.
5. **Documents 13-15** (Parent, Tutor, Test Tracking) cover secondary user modes.
6. **Documents 16-18** (Notifications, Sync, Settings) cover supporting infrastructure.

If a critical bug in an earlier document blocks later testing, prioritize getting that bug fixed before moving on.

---

## Quick Start Checklist

Before you begin testing, confirm:

- [ ] Flutter SDK installed and `flutter doctor` passes
- [ ] At least one emulator created (API 34 recommended to start)
- [ ] App builds and launches: `cd learning_tracker && flutter run`
- [ ] You have access to Linear (team DNI)
- [ ] You have Claude Code available for bug filing
- [ ] You have created your progress tracking sheet
- [ ] You have read this document fully

Then open `01-auth.md` and begin with the P0 scenarios.

Good luck. Every bug you find is a bug your users will never see.
