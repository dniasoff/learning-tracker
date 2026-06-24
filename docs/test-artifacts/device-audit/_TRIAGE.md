# On-device audit — coordinator triage (2026-06-23)

Build: v1.0.65 (fresh HEAD debug APK) on 3 Windows-hosted emulators driven from WSL.
Devices: `emulator-5554` (Pixel 2, API 28, small/old) · `emulator-5560` (Pixel 7, API 34) ·
`emulator-5562` (tablet, API 36, Hebrew/RTL).

Each finding below was **independently verified by the coordinator** (code + on-device + vision)
before being accepted or rejected. Auditor agents are good at *seeing* problems but several
root-causes/severities were wrong — verification matters.

## ✅ CONFIRMED defects — being fixed (no behaviour-change risk)

| ID | Sev | Screen | Defect | Root cause (verified) | Fix |
|----|-----|--------|--------|------------------------|-----|
| F1 | P2 | Add Track · scope step | Seder **Taharos** shows generic gloss "Core section focus" instead of "Purity & Ritual Law" | `step_scope.dart` `_scopeDescription` switch case key `'seder taharos'` ≠ the real rawValue → falls to `_ => scopeGlossCoreFocus` | fixer-1 |
| F2 | P3 | Settings · Manage Profiles | Profile tiles show generic person icon, not the colored-initials avatar used by the profile picker | `manage_learners_screen.dart` uses a default avatar | fixer-1 |
| F3 | P2 | Settings · account card | Raw offline email `offline_xxxx@offline.local` shown (truncated) for local-born accounts | account card renders raw `email`; `offlineAccountLabel` exists + used in account picker but not here | fixer-1 |

## ✅ CONFIRMED + FIXED + on-device re-verified

| ID | Sev | Screen | Defect | Fix | Re-verify |
|----|-----|--------|--------|-----|-----------|
| F4 | P1 | Onboarding (offline) | "Skip for now" after creating a profile lands on **EmptyLoginScreen** (no bottom nav), **persistent** across relaunch — only escape was the gear icon | `onboarding_screen.dart` `_navigateToDashboardSkipped` now mirrors `_navigateToDashboard`'s profile-aware routing (AppShell when a profile exists; EmptyLogin only for genuine zero-profile / tutor-join) | ✅ PASS on 5554 — lands in AppShell w/ bottom nav; persistence holds |

## ⛔ CONFIRMED P1 — NOT fixed (delicate; deferred to team)

| ID | Sev | Screen | Defect | Why not auto-fixed |
|----|-----|--------|--------|---------------------|
| F5 | P1 | Parent PIN **setup** (first-time) | After confirming a new PIN the screen **loops back to "Set Parent PIN"**; back/nav don't escape (force-stop recovers). The PIN IS saved + parent mode activates; the **verify** flow (existing PIN) works fine — setup-only. | Real-device AutoRoute guard/`unawaited`-pop **timing** race in `pin_flow_screen.dart` `_handleCompletion` (setup case). High blast radius (parent-mode guard with documented prior loop bugs). Deep static analysis eliminated the scope-mismatch / async-save / null-id hypotheses but could NOT pinpoint the trigger with confidence → not guessing. Needs debugger-driven on-device iteration. Confined edge (PIN saves; recoverable). |

## ⚠️ REAL but not auto-fixing (surface to user — product/data decisions)

- **Program subtitles English in Hebrew UI** — "Two mishnayos per day…", "One Mishnah perek per day."
  These are **seed data** (`lib/core/database/seed/learning_program_seeds.dart` `description` fields),
  English-only — NOT a missing ARB key. Real localization gap; fix = add Hebrew descriptions to the
  seed/program data. Lower priority, data task.
- **Shabbos defaults ON as a study day** (Add Track · study days) — flagged as contradicting the
  Shabbat-lock feature. **Intentional**: `track_creation_service.dart:19` documents "Default study
  days: all 7 days active." Sound UX argument, but a product decision, not a bug.
- **Streak banner flame far from streak text (RTL)** + **"1 פעיל" badge far from heading on wide
  tablet** — minor P3 RTL/tablet polish; cosmetic.

## ❌ REJECTED — false positives (verified)

| Claimed | Sev claimed | Why rejected |
|---------|-------------|--------------|
| "I want to learn everything!" CTA selects only 1 of 6 sedarim | P1 | Measurement artifact: Step-3 hero card + title + breadcrumb collapse into ONE semantics node, so find("learn everything")'s center resolves onto the זרעים row — the tap never hit the card. Code: `onLearnAll → onComplete(null)` = whole-curriculum-advance, by design. (Real residue: the merged semantics is a minor **a11y** concern — the card isn't an independent tap target.) |
| In-app language toggle is a no-op (P0) | P0 | There is **intentionally no in-app language switcher** — `learning_tracker_app.dart:84` `locale: null`, UI follows DEVICE locale. The "English/Hebrew" control the agent toggled is the Hebrew-Terms/pronunciation setting, not app language. Agent then forced Hebrew via `adb`. Not a bug. |
| FAB at bottom-LEFT in RTL is wrong | P1 | `FloatingActionButtonLocation.endFloat` (verified in 3 screens) is direction-aware: end = left in RTL. Bottom-left is the **correct** Material placement. |
| Drill-down chevron on wrong side in RTL | P1 | Verified in screenshots: trailing chevron correctly moves to the trailing edge and points forward-in-reading-direction in RTL. Renders correctly. |
| Track-card progress bar fills LTR in RTL | P3 | `LinearProgressIndicator` respects ambient `Directionality`; fills from the start edge per locale. |

## Wave-2 (data-dependent screens, 5560) — additional triage

37 more screens audited (content browse, scheduler, track detail, edit goal, gamification/parent
hub via PIN, reward/point config, child redemption, progress sub-screens) — **the large majority
PASS**. Beyond F5 (above), the remainder:

- **Surface to you (enhancements/polish, not auto-fixed):**
  - *Content Search is Hebrew-only with no guidance* (P2) — searching "berachot" returns "no results"
    with no hint to use Hebrew (ברכות). Real UX gap; needs product decision (transliteration search
    vs. an empty-state hint).
  - *Progress-bar a11y label* (P3) — track card content-desc reads "0, משניות…" (raw progress value
    leaks into the screen-reader label). Minor a11y.
  - *Wizard step count "6"→"7"* after curriculum selection (P3) — minor copy.
- **By-design / not bugs (rejected):**
  - *Browse text has no "Mark complete"* — browse is read-only preview by design; completion is via
    the daily-task path. (Agent itself flagged "may be intentional.")
  - *Settings "Sync paused — 29 queued" banner* — expected sync-paused state on a sideloaded test
    build (no App Check attestation); not a product defect. Deliberate warning treatment.

## Process lessons (fed back to the fleet)
- The find-by-text → tap-center heuristic is unreliable when Flutter **merges semantics nodes** —
  the tap lands on the wrong widget and fabricates "broken" findings. Always confirm the intended
  state actually changed after a tap.
- RTL conventions are easy to invert (FAB end-alignment, trailing chevrons). Check against Material
  direction-aware defaults before filing an RTL bug.
- Audit POPULATED state — empty-state-only audits are low value and trigger false "blank gap" findings.
