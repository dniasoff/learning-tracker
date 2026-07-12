/// `StreakRestorer` — empty-log restore.
///
/// First-launch on a new device sees an empty `streak_events` log even
/// though the user's `completions_view` (backed by `completion_events`,
/// synced or local) may have history. [restoreIfEmpty] reconstitutes one
/// synthetic `completion` event per distinct UTC completion day so the
/// [StreakReducer] produces the right answer before any new completion
/// is recorded.
///
/// Idempotent: re-running on a non-empty log is a no-op.
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_log.dart';
import 'package:learning_tracker/features/gamification/streak/streak_log_event.dart';

class StreakRestorer {
  StreakRestorer(this._db) : _log = StreakEventLog(_db);

  final UserDatabase _db;
  final StreakEventLog _log;

  /// Reconstitute events from `completions_view` if the log is empty for
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
    // learning sessions. [kBulkPriorSentinelMs] is core's single source of
    // truth for this sentinel (features/ → core/ is a legal import direction;
    // see docs/coding-standards.md Rule 1/Rule 2 — the layering hazard here
    // would have been a cross-feature import of SchedulerEngine, not a
    // core→features one).
    // Reads from completionsView (C1: backed by completion_events).
    final allCompletions = await _db.completionDao.getCompletionsByProfile(
      profileId,
    );
    final completions = allCompletions
        .where(
          (c) =>
              c.trackId != 0 &&
              c.completedAt.millisecondsSinceEpoch != kBulkPriorSentinelMs,
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
        StreakLogEvent(
          profileId: profileId,
          eventType: 'completion',
          eventTimestamp: ts,
        ),
      );
    }
  }
}
