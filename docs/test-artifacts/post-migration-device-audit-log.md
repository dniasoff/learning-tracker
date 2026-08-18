# Post-migration on-device audit log

**Purpose:** fresh on-device vision-audit campaign against the app as it exists
after the Drift→Firestore migration finished (dev HEAD `f9818b55`). The old
`reassurance-log.md` campaign's baseline (`f8b42240`) is 518 commits and a
full sync/auth/data-layer rewrite stale — its remaining open items (notably
R4, sync/cloud/rules, explicitly "not started") were scoped against code that
no longer exists in that form. This is a new campaign, not a continuation.

Uses the proven `tool/device_e2e/` methodology from the historical run2–run11
campaigns: 3 devices (5554 API 28, 5560 API 34, 5562 API 36 tablet), each
seeded to a known populated state then walking a disjoint set of feature
areas (16 total, EN + Hebrew/RTL), every candidate finding adversarially
verified against code + screenshot before being counted, then synthesized
into a gate report at `docs/test-artifacts/device-audit-run{N}/_REPORT.md`.

## Runs

| Run | Workflow run ID | Launched | Status | Report |
|---|---|---|---|---|
| 12 | `wf_aace6c7b-bcd` (task `wr8644yti`) | 2026-08-18 | IN FLIGHT | `docs/test-artifacts/device-audit-run12/_REPORT.md` (not yet written) |

## Resume protocol

1. Check the run's status via `/workflows` or the task notification. If the
   session that launched it ended, the workflow itself may still be running
   in the background (workflows survive independently) — check
   `docs/test-artifacts/device-audit-run{N}/_REPORT.md` for existence first.
2. If a run finished with real findings: triage by severity, fix P0/P1
   findings on `dev` (small, targeted commits — this is a real children's-app
   production codebase, not a scratch branch), then launch the next
   `runN_full_suite.mjs` (bump `runNum`, update `reportIntro`) to validate the
   fixes and continue coverage, mirroring the historical run2→run11 pattern.
2b. Environment note (new this campaign): `pm clear`/`uninstall`/fresh
   `adb install` on these AVDs can fail with `INSTALL_FAILED_INSUFFICIENT_STORAGE`
   / `DELETE_FAILED_INTERNAL_ERROR` even with hundreds of MB nominally free
   (`df -h /data`) — this is PackageManager state degradation from
   accumulated use, not real disk pressure. Fix: `adb -s <serial> emu kill`
   then relaunch with `-wipe-data`. Reproduced on both `emulator-5556` and
   `emulator-5560` in this campaign's setup.
3. Workflow scripts get no filesystem/import access — `tool/device_e2e/run12_full_suite.mjs`
   inlines the shared `_full_suite_lib.mjs` content verbatim rather than
   importing it (the old `runN` files import it, which only works when
   invoked through whatever mechanism ran runs 2–11; the current `Workflow`
   tool's `scriptPath` requires `export const meta` as the literal first
   statement with no prior imports). Any new `runN` script must do the same:
   copy `_full_suite_lib.mjs`'s current content in rather than importing it.
4. Campaign has no fixed "done" criterion yet (unlike the old reassurance
   campaign's per-surface Scorecard) — define one once run12's findings are
   in hand and triaged with the owner.
