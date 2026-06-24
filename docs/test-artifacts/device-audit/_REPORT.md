# On-device E2E audit — final report (2026-06-23)

**Scope:** black-box, real-pixel audit of the shipped app driven over ADB across **3 emulators**
in parallel, English + Hebrew/RTL, on a populated account (track + completions).
**Build:** fresh HEAD debug APK (v1.0.65) → fixed build redeployed to all 3 devices.

| Device | Form factor | Lens |
|---|---|---|
| emulator-5554 | Pixel 2, API 28 (small/old) | first-run onboarding + overflow |
| emulator-5560 | Pixel 7, API 34 | full English walk (populated) |
| emulator-5562 | tablet, API 36 | Hebrew / RTL + wide layout |

**Coverage:** ~60+ distinct screens across onboarding, dashboard, learning + completion, content
browsing, the 7-step Add-Track wizard, scheduler/goals, track detail/edit, gamification + parent
hub (PIN), child mode + redemption, progress sub-screens, settings subtree — English and Hebrew.

## Verdict: **PASS** (all 5 confirmed defects fixed + on-device re-verified)

The app is **solid** — populated screens render correctly, Hebrew/RTL is largely correct,
no crashes, no overflow on the small/old device, no raw l10n keys. Of the auditor findings, **most
were false positives** (caught in triage before they became feature-breaking "fixes"). **5 genuine
defects** were confirmed, and **all 5 are now fixed + on-device re-verified** (the final P1 — the
Parent-PIN setup loop — was resolved empirically via logcat instrumentation; see F5 below).

### Fixed + re-verified (4)
| ID | Sev | Defect | Re-verify |
|----|-----|--------|-----------|
| F1 | P2 | Seder **Taharos** showed placeholder gloss "Core section focus" (key `'seder taharos'` ≠ canonical `'seder tahorot'`) | ✅ now "Purity & Ritual Law" + icon, all 6 sedarim correct |
| F2 | P3 | **Manage Profiles** used a generic person icon, not the picker's initials avatar | ✅ now colored initials (R/P/D), matches picker |
| F3 | P2 | Raw **offline email** `offline_…@offline.local` leaked into the Settings account card | ✅ suppressed; card shows name + "No Backup" |
| F4 | **P1** | **Offline onboarding nav-trap**: "Skip for now" after creating a profile dead-ended on EmptyLoginScreen (no bottom nav), **persistent** | ✅ lands in AppShell w/ bottom nav; persistence holds |

### Confirmed P1 — FIXED empirically (1)
| ID | Sev | Defect | Fix |
|----|-----|--------|-----|
| F5 | **P1** | **First-time Parent-PIN setup looped** back to "Set Parent PIN" after confirm; back/nav didn't escape (force-stop recovered). PIN **was** saved; **verify** flow worked — setup-only. | `pin_flow_screen.dart` `_popResult` used `maybePop(result)`, which removed the route but did NOT complete the guard's `await router.push<bool>(PinFlowSetupRoute)` result-completer → the guard hung, the hub never showed, the screen looped. Fix: `pop(result)` (completes the completer) + post-frame completion. **Root-caused empirically** (static analysis couldn't): instrumented the guard/screen, read `adb logcat` across the confirm — the decisive signal was `guard_setup_result` (logged after the awaited push) NEVER firing despite `maybePop` returning true. On-device re-verify: `guard_setup_result ok=true` now fires and the screen reaches the **Parent Settings hub**; verify flow unregressed. |

### Surfaced for product decision (not bugs / enhancements)
- Hebrew translations missing for study-**program** subtitles (seed data, e.g. "Two mishnayos per day") — `learning_program_seeds.dart`.
- "Shabbos defaults ON" as a study day — intentional (documented), but worth revisiting vs the Shabbat-lock.
- Content Search is Hebrew-only with no guidance (no hint to search in Hebrew).
- Minor a11y / polish: progress-bar semantic label "0,"; wizard step count 6→7; RTL streak-flame placement; a badge gap on the very wide tablet.

### Rejected false positives (verified) — see `_TRIAGE.md`
"learn-everything selects 1 seder" (semantics-merge tap artifact) · "language toggle no-op" (no
in-app switcher by design; follows device locale) · "FAB wrong side in RTL" (`endFloat` is correct)
· "chevrons wrong side" (render correctly) · "progress bar fills LTR in RTL" (Directionality-aware).

## Artifacts
- Per-device findings: `findings_5554.md`, `findings_5560.md`, `findings_5562.md`
- Coordinator triage w/ evidence: `_TRIAGE.md`
- Screenshots: `/tmp/device_e2e/<port>/`
- Code fixes (F1–F4): **applied to the working tree, uncommitted**, deployed to all 3 emulators.
- Device-access lessons added to `docs/testing-guide.md` + `docs/test-options.md`.
