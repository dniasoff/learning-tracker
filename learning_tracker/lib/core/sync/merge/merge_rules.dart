/// Legacy LWW predicate for non-event-log data (Epic 20 v2 §4.1).
///
/// Event-sourced data (streaks / XP) is handled by reducers, not by this
/// file — see `streak_reducer.dart` / `xp_reducer.dart`.
///
/// This file is **superseded**, not authoritative: the documented "Phase 3"
/// upgrade (see `drift_merge_store.dart`) moved every LWW merger's ordering
/// decision onto `DriftMergeStore.remoteIsNewer`, which adds a ±5s
/// clock-skew window and a Firestore `synced_at` tie-break that this file's
/// plain [remoteIsNewer] does not have. Its `lwwMerge` / `mergeForwardMax*`
/// / `mergeForwardUnion` helpers were dropped entirely (AUD-core-sync-37) —
/// they had no production callers left after that migration.
///
/// [remoteIsNewer] itself is kept only because `StudyDayConfigMerger` is
/// the one remaining merger that has not yet been switched over to
/// `DriftMergeStore.remoteIsNewer` (tracked separately as AUD-core-sync-03).
/// Once that migration lands, this file has zero production callers and
/// should be deleted.
library;

/// Predicate used by the sync engine's pull loops to decide whether
/// an incoming remote row should overwrite the current local row
/// under the LWW rule. Returns `true` only when [remoteUpdatedAt] is
/// strictly after [localUpdatedAt] — ties go to local, avoiding flapping.
///
/// Superseded by `DriftMergeStore.remoteIsNewer` for every merger except
/// `StudyDayConfigMerger` — see the file-level doc comment above.
bool remoteIsNewer({
  required DateTime? localUpdatedAt,
  required DateTime? remoteUpdatedAt,
}) {
  if (remoteUpdatedAt == null) return false;
  if (localUpdatedAt == null) return true;
  return remoteUpdatedAt.isAfter(localUpdatedAt);
}
