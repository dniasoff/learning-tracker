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

    // Skip (a) non-track completions (trackId == 0) and (b) bulk-prior sentinel
    // completions (completedAt == year-2000 sentinel date). Neither should seed
    // streak_events — (a) are lifetime/non-tracked items; (b) are prior-mark
    // placeholders inserted when a user bulk-marks past learning, not genuine
    // learning sessions. The sentinel date matches SchedulerEngine
    // kBulkPriorSentinelMs (DateTime.utc(2000, 1, 1)); we define it locally to
    // avoid a core→features layering violation.
    // Reads from completionsView (C1: backed by completion_events).
    const bulkPriorSentinelMs = 946684800000; // DateTime.utc(2000,1,1) ms
    final allCompletions = await _db.completionDao.getCompletionsByProfile(
      profileId,
    );
    final completions = allCompletions
        .where(
          (c) =>
              c.trackId != 0 &&
              c.completedAt.millisecondsSinceEpoch != bulkPriorSentinelMs,
        )
        .toList();

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
