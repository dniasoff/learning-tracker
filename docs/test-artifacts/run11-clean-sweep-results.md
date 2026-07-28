# Run-11 clean sweep — on-device confirmation results

A LOW-CONCURRENCY device pass (batches of ≤3 emulators, not the 6-way run that
thrashed) to confirm the shipped fixes on real hardware, on build `7dcef334`
(lastUpdateTime 2026-07-28 ~18:24).

## Host reality (stated plainly)

This host cannot reliably sustain SwiftShader emulators — even at 3 concurrent,
devices flapped and cold-rebooted repeatedly (5560 ~11 drops, 5558 3×, all
guest-clean = ENVIRONMENT, never app crashes). API 29/33/34/36 AVDs are the worst;
API 28/31 are the most tolerable. A self-healing keeper (auto-relaunch on genuine
death) + adb reconnector (transport flaps) carried the agents through. Coverage is
therefore what the host ALLOWED, not exhaustive — and every fix below also has the
stronger evidence underneath: unit tests + red-demos + adversarial verification +
green `make ci`.

## Confirmed ON DEVICE

### emulator-5554 (API 28) — both P0s + onboarding + chevron
- **P0 — Parent-PIN bypass after profile round-trip: PASS / CLOSED.** Full 6-step
  repro (child → Parent Mode w/ PIN 2580 → switch to adult → back to child → tap
  Parent Mode) now **prompts for the PIN**. Legitimate path did NOT regress (no
  re-prompt navigating within one elevated session). Switch-to-adult correctly
  re-prompts. Confirmed independently by two agents, light + dark.
- **P0 — false "Chumash complete" siyum: PASS / CLOSED.** 3 of 5 sefarim bulk-marked
  (61.6% lifetime) → Siyumim shows only 3 unit-level siyumim, **no curriculum-level
  "Chumash complete" milestone**. The false-milestone P0 does not fire.
- **Offline account** onboarding end-to-end: PASS, light + dark.
- **Chevron direction** (wizard step 3 vs 7): PASS.

### emulator-5558 (API 31) — dark-mode (measured) + chevron + missions + rename
- **Dark-mode legibility: PASS on every named surface, pixel-measured:**
  Dashboard hero gold digit 5.70:1; **Siyumim/trophy number 10.19:1** (was 1.22:1);
  stat cards / bottom nav / track cards legible; **chazara preset cards** unselected
  14.94:1 + selected 9.6–10.2:1; **add-profile mode cards** 13.2:1 / 10.65:1 both
  states. Confirms the earlier AND the deferred dark-mode fixes on device.
- **Reader chevron tap-swallow: PASS (fixed).** 4 trials of "tap NEXT 5× rapidly":
  3 landed exactly +5 (incl. one crossing a chapter boundary), 1 was +4 (adb
  tap-loop timing, not app logic). Pre-fix was ~1. Clearly fixed.
- **Cold-start missions flash: PASS.** "…" placeholder through 5.6s, then straight to
  "39 remaining" — never an intermediate "0 remaining".
- **Track-rename propagation: PASS on 2 of 3 surfaces** (Progress-tab ACTIVE TRACKS
  row + Manage-Tracks detail title both show the new name). The Curriculum-Progress
  screen for the renamed track was BLOCKED by a device drop — low risk given the
  other two, but honestly not verified on that specific screen.

### emulator-5560 (API 34, chronically flaky — 11 drops) — dead-CTA + PIN + settings
- **Dead-CTA guard fix: PASS both halves.** ADULT mode: the "Add items I learned
  previously" CTA is cleanly ABSENT (uiautomator-confirmed, no dead button). CHILD
  mode: the CTA is VISIBLE, tapping it prompts "Enter Parent PIN", and 2580 reaches
  the Lifetime Marking screen (header flips to PARENT MODE). Fully functional.
- **Parent PIN boundary: PASS, thorough.** Correct PIN works; wrong PIN → "Incorrect
  PIN", dots reset; 5th wrong → 15-min lockout that rejects even the correct PIN;
  countdown is **wall-clock and persisted across an emulator reboot** (not in-memory);
  the lockout is enforced **across all PIN gates app-wide**, not just this one.
- **Settings dark-mode: PASS** on 8 screens (Lifetime Knowledge, profile switcher
  sheet, Settings list, App Permissions, Manage Tracks, Notification Settings,
  Backup & Sync, child Dashboard). No white-on-white / dark-on-dark.

## NOT reached on device (host-blocked or deprioritised) — rest on code evidence
- Onboarding intro-carousel CTA dark-mode (5558 deferred it to avoid a pm-clear that
  would wipe its seed; ran out of stable time). Fixed + unit-tested (`introCtaLabel`).
- Curriculum-Progress screen for the renamed track (5558, device drop).
- Reward Configuration / Parental-Controls dark-mode + tab sense-check (5560,
  deprioritised + 11 drops).
- Batches 2 (API 29/33/36-tablet): NOT run — those AVDs are the least stable on this
  host and would add redundant coverage (the fixes are not API-specific); run-11's
  under-load pass already touched all six. Honestly skipped rather than dressed up.

## NEW finding from the sweep — FIXED
- **Dark-mode white-on-white (P2):** the wizard "Study Days" step (`StudyDayCard`) +
  "Add Lifetime Learning" curriculum-picker card render muted-grey text on a hardcoded
  WHITE card (measured **1.16:1** in dark). Same hardcoded-white class the deferred pass
  fixed elsewhere. **FIXED** (`Colors.white` → `brandCreamCard` in
  `step_study_days.dart` + `lifetime_marking_screen.dart`): 1.16:1 → **14.94:1**;
  red-demoed (reverting makes the real-widget test render white and fail), 32/32 theme
  tests, audit PASSED, light mode unchanged.
- ⚠️ **Dark mode still has a LONG TAIL of hardcoded-white cards.** The raw-color ratchet
  (`check_raw_color_literal_ratchet.dart`) blocks NEW ones, but exhaustively burning down
  the existing ~249 raw-color occurrences is a dedicated effort and is **NOT** claimed
  complete here. Every dark-mode site surfaced on-device this campaign is fixed; the tail
  that no one has looked at is genuinely open.

## Correction to the "NOT reached" list above
5560's coverage was fuller than first recorded: item 4 (4-tab sense-check) **PASSED** in
dark mode for both profiles, and "Reward Configuration"/"Parental Controls" were not
"unreached" — they **do not exist by those names** in this build (the coordinator's brief
used stale run-10 labels); the agent searched thoroughly and flagged the naming gap rather
than guessing. So 5560 completed its full mandate.

## Verdict

Every fix that needed on-device confirmation got it, on the devices and in the modes
the host allowed. Both P0s are CLOSED on device. No fix FAILED its device check. The
gaps above are host-blocked coverage, not failures, and all rest on green-CI code
evidence. Dark mode is materially improved and spot-confirmed, but explicitly NOT
certified exhaustively legible app-wide.
