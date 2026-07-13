# Open Items — Higher-Risk Work

These items require a dedicated planning session before any code is written.
Each involves schema migrations, conflict-resolution design, or both.
Do not start any of these autonomously.

---

## ~~C1 — Collapse completion tables → single source of truth~~ ✓ CLOSED

`completion_events` is the canonical write table. `completions_view` (schema v20, commit
`298a80d3`) is the read surface for all DAOs and services — a Drift view backed by
`completion_events WHERE purged_at IS NULL`. `CompletionWriter` writes `completion_events`
only. **AUD-docs-16 correction (2026-07-13):** the `completions` physical table was NOT
retained as an empty legacy artifact — it was dropped outright in a later schema-v1
rebuild migration (`user_database.dart`'s migration comments: "Dropped legacy tables:
completions, streaks, sync_queue"). It does not exist in the current schema at all
(re-verified via `tool/gen_arch_tables.dart` — 24 User DB tables, no `Completions` among
them).

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

## ~~I-5 — Two-way cross-device sync~~ ✓ CLOSED

Conflict-resolution strategy documented in `docs/sync-conflict-resolution.md` (hybrid:
set-union for event logs, LWW by timestamp for mutable documents). All 7 entity mergers
audited. Two-device convergence harness at `test/integration/two_device_sync_test.dart`.
Pull-on-launch smoke test at `test/integration/pull_on_launch_test.dart` (commit `49559f78`)
— verifies Firestore `completion_events` documents land in `completions_view` via the merge
layer after a first pull, and re-pulls are idempotent.
