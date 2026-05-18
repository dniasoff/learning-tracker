# Open Items — Higher-Risk Work

These items require a dedicated planning session before any code is written.
Each involves schema migrations, conflict-resolution design, or both.
Do not start any of these autonomously.

---

## ~~C1 — Collapse completion tables → single source of truth~~ ✓ CLOSED

`completion_events` is the canonical write table. `completions_view` (schema v20, commit
`298a80d3`) is the read surface for all DAOs and services — a Drift view backed by
`completion_events WHERE purged_at IS NULL`. `CompletionWriter` writes `completion_events`
only. The `completions` physical table is retained as an empty legacy artifact (no rows
written post-C1).

---

## ~~C2 — Add foreign keys on `profileId` / `curriculumId`~~ ✓ CLOSED

`profileId` FKs with `CASCADE DELETE` are in place on all profile-scoped tables (schema
v16→v17, commit `5b2a4b05`). `curriculumId` FKs were intentionally omitted — curricula
are defined in code (enum), not as mutable DB rows, so there is no parent table to
reference.

---

## ~~C3 — Unify delete semantics~~ ✓ CLOSED

`purgeHistory` uses `purgedAt` tombstones on `completion_events` (never deletes rows).
Invariant N8 regression test guards this. Policy documented in `docs/delete-policy.md`.

---

## I-5 — Two-way cross-device sync (design + harness complete)

**What:** Full bidirectional sync so two devices converge to identical state.

**Done:**
- Conflict-resolution strategy documented in `docs/sync-conflict-resolution.md` (hybrid: set-union for event logs, LWW by timestamp for mutable documents).
- All 7 entity mergers audited and confirmed aligned with the strategy.
- Two-device convergence test harness at `test/integration/two_device_sync_test.dart` (3 scenarios: set-union, LWW deactivation propagation, idempotent re-merge).

**Remaining:**
- Pull-on-launch guarantee (end-to-end smoke test — in progress).
