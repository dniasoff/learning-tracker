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

## C2 — Add foreign keys on `profileId` / `curriculumId`

**What:** Currently only `trackId` is FK-constrained. A deleted profile silently orphans rows across multiple tables. Add explicit cascade-delete FKs for `profileId` and `curriculumId`.

**Why it needs planning:** Requires a Drift schema version bump and a migration. Must be co-ordinated with C1 (if completion tables are consolidated first, the FK targets change).

---

## C3 — Unify delete semantics

**What:** Three delete policies exist in one flow: tracks soft-delete (`deletedAt`), stages/goals hard-delete, completions are append-only except `purgeHistory` which hard-deletes them against the table's INSERT-only contract. Unify to one stated policy per entity with a single enforcement point.

**Why it needs planning:** Any change to delete semantics touches the sync engine's conflict-resolution logic and the `purgeHistory` path. Must be designed alongside C1 so the event-log contract and the delete policy are consistent.

---

## I-5 — Two-way cross-device sync

**What:** Full bidirectional sync so two devices converge to identical state. Changes on either device must propagate reliably.

**Why it needs planning:** Requires a conflict-resolution strategy (last-write-wins per field, or CRDT), pull-on-launch with additive merge, and an end-to-end test harness simulating two devices. The multi-table write path (C1) makes conflict resolution ambiguous until that is settled.

**Recommended sequencing:** Complete C1 → C2 → C3 first, then design I-5.
