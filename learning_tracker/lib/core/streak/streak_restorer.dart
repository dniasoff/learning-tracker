/// `StreakRestorer` — empty-log restore.
///
/// First-launch on a new device sees an empty `streak_events` log even
/// though the user's `completions` log (synced or local) may have
/// history. [restoreIfEmpty] reconstitutes one synthetic `completion`
/// event per distinct UTC completion day so the [StreakReducer]
/// produces the right answer before any new completion is recorded.
///
/// Idempotent: re-running on a non-empty log is a no-op.
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/core/streak/streak_event.dart';
import 'package:learning_tracker/core/streak/streak_event_log.dart';

class StreakRestorer {
  StreakRestorer(this._db) : _log = StreakEventLog(_db);

  final UserDatabase _db;
  final StreakEventLog _log;

  /// Reconstitute events from `completions` if the log is empty for
  /// [profileId]. Picks the earliest completion per distinct UTC day so
  /// the natural-key UNIQUE on `streak_events` remains stable across
  /// repeated restores.
  Future<void> restoreIfEmpty({required int profileId}) async {
    final existing =
        await (_db.select(_db.streakEvents)
              ..where((t) => t.profileId.equals(profileId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return;

    // Only track-based completions credit the streak. Bulk-marked lifetime
    // items use trackId = 0 as a sentinel and must not create streak events
    // (matches the write-path gate in CompletionRepositoryImpl / DNI-381).
    final completions = await (_db.select(
      _db.completions,
    )..where((t) => t.profileId.equals(profileId) & t.trackId.isNotValue(0)))
        .get();

    final firstPerDay = <DateTime, DateTime>{};
    for (final c in completions) {
      final utc = c.completedAt.isUtc ? c.completedAt : c.completedAt.toUtc();
      final day = DateTime.utc(utc.year, utc.month, utc.day);
      final prior = firstPerDay[day];
      if (prior == null || utc.isBefore(prior)) firstPerDay[day] = utc;
    }

    for (final ts in firstPerDay.values) {
      await _log.append(
        StreakEvent(
          profileId: profileId,
          eventType: 'completion',
          eventTimestamp: ts,
        ),
      );
    }
  }
}
