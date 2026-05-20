/// Conflict resolution rules for non-event-log data (Epic 20 v2 §4.1).
///
/// Event-sourced data (streaks / XP) is handled by reducers, not by
/// these rules — see `streak_reducer.dart` / `xp_reducer.dart`.
///
/// These rules handle the rest:
///
///   - **LWW** (last-write-wins by `updatedAt`): profile settings,
///     user preferences, goals + deadlines. Whichever side has the
///     later `updatedAt` wins the whole record.
///
///   - **Merge-forward** (union / max): progress markers like
///     "furthest completed lesson". Neither side should ever
///     *reduce* progress on sync, so we always take the max.
library;

/// Result of merging a single field or record.
class MergeResult<T> {
  const MergeResult({required this.winner, required this.wasConflict});
  final T winner;
  final bool wasConflict;
}

/// Last-write-wins: pick whichever side has the later `updatedAt`.
///
/// If timestamps are equal, prefer [local] — the device making the
/// decision is doing so because it needed to sync, and keeping the
/// local value avoids flapping.
MergeResult<T> lwwMerge<T>({
  required T local,
  required T remote,
  required DateTime localUpdatedAt,
  required DateTime remoteUpdatedAt,
}) {
  if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
    return MergeResult(winner: remote, wasConflict: true);
  }
  return MergeResult(
    winner: local,
    wasConflict:
        localUpdatedAt.isBefore(remoteUpdatedAt) ||
        localUpdatedAt.isAtSameMomentAs(remoteUpdatedAt) && local != remote,
  );
}

/// Merge-forward max for integer progress markers. Never reduces.
int mergeForwardMaxInt(int local, int remote) =>
    local > remote ? local : remote;

/// Merge-forward max for DateTime progress markers.
DateTime mergeForwardMaxDate(DateTime local, DateTime remote) =>
    local.isAfter(remote) ? local : remote;

/// Union-merge for sets of IDs (e.g. completed lesson IDs).
/// Strictly additive — a sync never removes entries.
Set<T> mergeForwardUnion<T>(Iterable<T> local, Iterable<T> remote) => {
  ...local,
  ...remote,
};

/// Predicate used by the sync engine's pull loops to decide whether
/// an incoming remote row should overwrite the current local row
/// under the LWW rule. Returns `true` only when [remoteUpdatedAt] is
/// strictly after [localUpdatedAt] — ties go to local, matching
/// [lwwMerge]'s flapping-free behaviour.
bool remoteIsNewer({
  required DateTime? localUpdatedAt,
  required DateTime? remoteUpdatedAt,
}) {
  if (remoteUpdatedAt == null) return false;
  if (localUpdatedAt == null) return true;
  return remoteUpdatedAt.isAfter(localUpdatedAt);
}
