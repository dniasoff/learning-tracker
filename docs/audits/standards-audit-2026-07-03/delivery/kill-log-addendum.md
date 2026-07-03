# Delivery kill-log addendum

Per doctrine §3.9: findings a builder/reviewer discovers are wrong or already-fixed during
delivery are marked `skipped-refuted` in the ledger, never forced into a manufactured change.
This file is the evidence trail for every such disposition, across all waves. One entry per
finding, appended as it happens.

---

## AUD-learning-05 — Mirror the daily-task-card chevron icon for RTL

- **Wave:** 0
- **Severity:** P2
- **Register evidence:** `learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart:509,615` — two `const Icon(Icons.chevron_right_rounded, ...)` call sites, no `matchTextDirection`.
- **Register verify status (audit time):** CONFIRMED, UPHELD 1/1, no refutations (`_work/verify-chunks/grp-060.json`).
- **Delivery disposition:** `skipped-refuted` (wave-0 engine run, 2026-07-03). No commit exists for this id anywhere in the run's branch/worktree history — unlike every other wave-0 id that reached a build, none was attempted for this one.
- **Evidence gap — read before trusting this disposition:** this reconciliation pass (ledger reconciliation, 2026-07-03, run after the wave-0 engine already terminated) was handed only the engine's summary verdict (`refuted`) for this id, with no accompanying rationale, review transcript, or write-up. None was found anywhere on disk (searched `_work/`, `delivery/`, all dangling/worktree branches). Independently re-checking the current tree: **both call sites still lack `matchTextDirection` today** — so this was *not* refuted on an "already fixed in code" basis (the one refutation basis that would be trivially self-evidencing). The actual basis (wrong rule application? design-intent override? something else?) is not recoverable from any persisted artifact.
- **Action required before wave-0 is certified:** the wave-0 closing-gate reviewer (opus, §4) must independently confirm this refutation with real evidence (or reopen the finding as `todo`/`blocked` for a real fix). Do not treat this entry as sufficient evidence on its own — it records that the disposition happened and that its rationale is currently unverified, nothing more.
- **Logged by:** wave-0 ledger reconciliation agent (sonnet), 2026-07-03.
