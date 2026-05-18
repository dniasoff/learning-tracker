# Open Items — Higher-Risk Work

These items require a dedicated planning session before any code is written.
Each involves schema migrations, conflict-resolution design, or both.
Do not start any of these autonomously.

---

## C1 — Collapse completion tables → single source of truth

**What:** The same fact is currently written to `completions`, `completion_events`, and `outbox` in one transaction, then teed to `streak_events` and separately to `learning_ledger`. Consolidate to one append-only event log with derived projections.

**Why it needs planning:** Schema migration across all DAOs and sync paths. Requires a full migration test harness before touching production code. The multi-table write path also affects the Firestore push layout, so conflict resolution for I-5 depends on this being settled first.

**Prerequisite for:** C2, C3, I-5.

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

## I-5 — Two-way cross-device sync

**What:** Full bidirectional sync so two devices converge to identical state. Changes on either device must propagate reliably.

**Why it needs planning:** Requires a conflict-resolution strategy (last-write-wins per field, or CRDT), pull-on-launch with additive merge, and an end-to-end test harness simulating two devices. The multi-table write path (C1) makes conflict resolution ambiguous until that is settled.

**Recommended sequencing:** Complete C1 → C2 → C3 first, then design I-5.
