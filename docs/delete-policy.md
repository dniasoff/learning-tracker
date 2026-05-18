# Delete Policy (C3)

**One stated policy per entity, one enforcement point.**

| Entity | Policy | Column / Mechanism |
|--------|--------|--------------------|
| `curriculum_tracks` | Soft-delete | `deletedAt` — null = active; non-null = deleted |
| `goals` | Hard-delete | Row removed on track/profile deletion |
| `stage_definitions` | Hard-delete | Row removed on track deletion |
| `completion_events` | Tombstone (append-only) | `purgedAt` — null = live; non-null = purged |
| `completions` | Projection-only | Derived from `completion_events`; deleted when the source is tombstoned |
| `learning_ledger` | Append-only, never deleted | Ledger is a permanent audit trail |
| `streak_events` | Append-only, never deleted | Event log; derived summaries are re-computed |
| `bookmarks` | Hard-delete | Removed on track/profile deletion |

## Enforcement point

`TrackDao.purgeHistory(trackId)` is the single place where bulk-delete for a track runs.
It must uphold every policy in the table above:
- stamps `purgedAt` on all `completion_events` rows for the track (tombstone)
- hard-deletes `completions` projection rows (safe — derived)
- hard-deletes `goals`, `stage_definitions`, bookmarks, plan rows (no history required)
- **never** hard-deletes `learning_ledger` or `streak_events`

Invariant **N8** (test: `regression_invariants_test.dart`) asserts that the
`completion_events` row count never decreases after `purgeHistory()`.

## Why soft-delete for tracks but hard-delete for goals/stages?

Tracks carry a `deletedAt` because:
1. The sync engine needs to propagate deletions to other devices (tombstone required).
2. `restoreOrCreate` must detect previously-deleted tracks to avoid re-using stale PKs.

Goals and stage definitions have no such requirements: they are profile-local and
reconstructed fresh on restore, so hard-delete is sufficient.
