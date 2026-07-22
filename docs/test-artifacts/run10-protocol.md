# Run-10 device audit — protocol

**Purpose.** Run-8 and run-9 both produced findings that could not be trusted, because
crash attribution was read off the *host* emulator process while the fleet runs on
SwiftShader (which segfaults constantly on the host). Run-10 is the first run with
**guest-side attribution** (`tool/device_e2e/crash_attribution.sh`), so its verdicts
are actually load-bearing.

Run-10 has two jobs:

1. **Settle the open question.** The Learn tab / reader / Content Hierarchy / Search
   path on **API 29** is the hole run-8 *and* run-9 both left. Run-8 called it an OOM
   P0; that was downgraded to ENVIRONMENT. It has never been cleanly tested.
2. **Re-verify the landed fixes on device** and sweep every screen for new damage.

## Non-negotiables

- **Emulators only.** Never the physical device, never `journey_01_signup_profile.py`
  (it points at the real phone).
- **Attribution is guest-side, full stop.** A crash counts *only* if
  `crash_attribution.sh check <port> <label>` exits 1. Host emulator death, a hung
  driver, or a blank screenshot is **ENVIRONMENT**, and must be reported as such.
  Do not escalate what you cannot attribute — that error has already cost this
  campaign two false findings.
- **Clear before, check after, every scenario:**
  ```bash
  ./tool/device_e2e/crash_attribution.sh clear <port>
  # ...drive the scenario...
  ./tool/device_e2e/crash_attribution.sh check <port> "<scenario-name>"
  ```
- **Never "fix" deliberate behavior.** Before calling anything a defect, check
  `git log`/blame and existing tests for intent. Run-8's "Hebrew Terms toggle
  disappears" was *intentional* (commit c8569b6c, test E2E-922) and a cycle was
  wasted "fixing" it.
- **Offline-account flow is in scope.** It is network-gated *by design*: you must cut
  the network to reach "Create Offline Account". That is not a bug.

## Device / surface matrix

| Port | API | Role | Primary surfaces |
|------|-----|------|------------------|
| 5556 | 29  | **PRIORITY — the unaudited hole** | Learn tab, text reader, Content Hierarchy, Search. Drive deep + repeatedly; this is where the alleged OOM lives. |
| 5554 | 28  | Oldest API | Onboarding, offline-account creation, profile setup, parent PIN |
| 5558 | 31  | Mid | Dashboard, progress, Lifetime Knowledge, charts, siyum |
| 5562 | 33  | Mid | Tracks: create/edit/delete, schedules, bulk "mark as previously learned" |
| 5560 | 34  | Modern | Settings, parent mode, PIN gating, profile switching, Hebrew/RTL |
| 5564 | 36  | Tablet | Layout/overflow at tablet size, dark mode, rotation |

## Every finding must carry

1. **Attribution**: `APP` (guest logcat confirms) or `ENVIRONMENT` (it does not).
2. **Evidence**: screenshot path + the exact logcat lines, or the observed vs expected UI.
3. **Reproducibility**: did it happen on a second attempt? Once-only = flag as such.
4. **Severity**: P0 ship-blocker / P1 / P2 / P3, and *why* that grade.
5. **Deliberate-check**: for behavior findings, what git/test evidence says it is NOT intended.

## Severity bar

- **P0** — data loss, child data wrong/over-counted, a crash on a core path, PIN/privacy bypass.
- **P1** — a primary screen unusable or illegible (incl. dark mode), a core action failing.
- **P2** — wrong/confusing content, layout damage that still permits the task.
- **P3** — cosmetic.

Report "no findings" honestly if that is the result. A clean run that is *trusted* is
worth more than a long list that is not.
