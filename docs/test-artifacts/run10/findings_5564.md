# Run-10 — emulator-5564 (API 36, tablet): Hebrew/RTL + tablet layout

**Verdict: Hebrew/RTL rendering is correct. No RTL mirroring defects found.**
**Findings ledger: none (no P0/P1/P2/P3).** A clean, trusted run for this surface.

> Filed by the coordinator on the auditor's behalf — its harness returns findings as
> text rather than writing files. Content is the auditor's, verbatim in substance.

## Setup

- Device locale switched to **Hebrew** (Settings → Languages).
- Device defaulted to system dark mode (`cmd uimode night = yes`); set
  `cmd uimode night no` because the app follows the system theme and this run's scope
  was **light mode only** (a separate fix wave was rewriting dark-mode colours
  concurrently, so dark findings would have been stale). Every screenshot is light mode.
- Used the pre-seeded `RtlQA!` offline profile as-is.
- Build: v1.0.66 (see the build-identity caveat below — `versionName` cannot distinguish
  builds in this run).

## Coverage

Dashboard · Settings (profile, permissions, Shabbat mode, calendar/nikud toggles, Manage
Tracks, Manage Profiles, sync/backup, notifications) · Progress · Learn (daily tasks +
content-hierarchy browse and drill-down) · Manage Tracks · the **full Add-Track wizard**
end-to-end (Talmud Bavli/Daf-Yomi path: curriculum → pace → review → starting-point
date-stepper → completion; Chumash path: hierarchy breadcrumb + multi-select checklist +
study-days toggles) · portrait/landscape rotation on Dashboard, Settings, Manage Tracks.

## Regression re-verification — both previously-fixed bugs confirmed still fixed

- **Learn-tab / Notifications chevron double-flip** (`144452f0`) — correct, not double-flipped.
- **HierarchySelectionPanel breadcrumb chevrons** (`84f9e690`) — correct in *both* places
  the panel is used (Learn-tab content browse **and** the wizard's Chumash book picker).
  Breadcrumb `ברכות ‹ פרק א ‹ משנה א` renders right-to-left with the correct left-pointing
  separator; the back arrow correctly points right.
- **Hebrew Terms toggle absence** — confirmed intentional (`c8569b6c` / test E2E-922).
  Correctly **not** reported. (A previous run wasted a cycle "fixing" this.)

## Investigated and confirmed NOT bugs

Recorded deliberately so no future run re-burns a cycle on them. Each looked wrong at a
glance and was run to ground:

1. **Shabbat "choose city" / "auto-detect" buttons** — icon appeared left-of-text; a 2×
   crop showed the icon is correctly at the RTL-start (right) edge in both.
2. **Calendar-type + Nikud segmented toggles** — the selected option sitting visually on
   the left looked wrong; traced to source (`PreferenceSegmentedTile options: [false, true]`)
   and `Row` correctly reverses child order under RTL. Correct.
3. **Wizard progress bar** — fills right-to-left as steps complete (verified by crop at
   0% / 14% / 50% / 75%). Correct.
4. **Add-Track date-stepper ("מיקום התחלתי")** — centred text with arrows on both sides
   looked inconsistent with the list-tile chevron convention, but it is a different widget
   (a bounded stepper). Empirically: right = decrement (back in time), left = increment
   (forward), hidden at the "today" bound — matching the app's back=right / forward=left
   convention. Correct.
5. **Study-days `Switch` toggles** — ON thumb sits left, OFF thumb sits right. Correct RTL
   `Switch` mirroring.

## Tablet layout and rotation

No stretching, no use-impairing dead space, and **no truncation, clipping, or ellipsis
anywhere** — including long names (`תלמוד ירושלמי`, `משנה ברורה`) and breadcrumbs — in both
orientations (2560×1600 landscape / 1600×2560 portrait). Rotation preserved state and
scroll position, layout re-flowed cleanly, RTL mirroring held. Attribution: guest clean.

Mixed Hebrew/English (`v1.0.66 (1)`, `Torah Study Tracker`, `Firebase` in the diagnostics
row) showed no bidi corruption.

## ENVIRONMENT events — not app defects, not escalated

1. **emulator-5564 died twice** under host contention (load 25–37; other emulators'
   transport IDs churned at the same moments, i.e. host-wide, not app-specific).
   Relaunched per protocol both times; locale and theme persisted.
2. **App force-stopped mid-session** right after two Dashboard taps — initially looked
   like a tap-triggered crash. Guest logcat showed `installPackageLI` /
   `PackageManager: installation completed for package:…learning_tracker` at the exact
   timestamp: an external process reinstalled the build, which force-stopped the app.
   Attribution for that window was guest-clean; app data survived.
   **This was the coordinator's APK deployment at ~19:05**, not a defect. (The 5554
   auditor independently diagnosed the same event the same way.)
3. One `adb: error: closed` mid-rotation-test — same host-contention pattern as (1).

## Caveat on build identity

`versionName` reads **1.0.66 on both the pre- and post-deployment builds** (it comes from
pubspec and does not change on rebuild), so it cannot distinguish them. Observations
before ~19:05 came from the earlier APK; use `dumpsys package … lastUpdateTime` to key
any figure precisely.
