# Open Items — Higher-Risk Work

These items require a dedicated planning session before any code is written.
Each involves schema migrations, conflict-resolution design, or both.
Do not start any of these autonomously.

---

## C1 — Collapse completion tables → single source of truth (70% done)

**What remains:** `completion_events` is now canonical (UNIQUE natural key, INSERT OR IGNORE).
`CompletionWriter` writes `completion_events` first, then derives a `completions` row tagged
`derivedFromEvents = true`. `purgeHistory` treats the `completions` rows as disposable.

The remaining step is making the derivation *automatic* — replacing the explicit
`completions` insert with a Drift view that is backed by `completion_events`
(filtered by `purgedAt IS NULL`), so the table rows no longer need to be written
by `CompletionWriter` at all.

**Why it needs planning:** Requires a schema migration (drop table, create view), code-gen
regeneration, and verifying that all ~30 `completionDao` read methods still return correct
results. N3/N5/N6 regression tests must stay green throughout.

**Prerequisite for:** I-5 (conflict resolution is cleaner once the write path is settled).

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

## I-5 — Two-way cross-device sync (design + harness complete; C1 prerequisite remains)

**What:** Full bidirectional sync so two devices converge to identical state.

**Done:**
- Conflict-resolution strategy documented in `docs/sync-conflict-resolution.md` (hybrid: set-union for event logs, LWW by timestamp for mutable documents).
- All 7 entity mergers audited and confirmed aligned with the strategy.
- Two-device convergence test harness at `test/integration/two_device_sync_test.dart` (3 scenarios: set-union, LWW deactivation propagation, idempotent re-merge).

**Remaining:**
- Pull-on-launch guarantee (end-to-end smoke test with real or fake Firestore).
- C1 must land first before `completions` can be included in the convergence guarantee — until then, only `completion_events` rows are synced.

**Prerequisite:** C1 (collapse `completions` table to a Drift view projection).
