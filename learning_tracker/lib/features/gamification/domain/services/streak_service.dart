import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';

/// Transitional read facade over the cached `streaks` snapshot table.
///
/// Story 25.16 (DNI-337) removed the write side of this service —
/// `recordCompletion` and `reconcileFromEvents`. Streak state is now
/// derived by `core/streak/StreakReducer` from the append-only
/// `streak_events` log; reads should flow through
/// `core/streak/StreakStateProvider`. The remaining methods (calendar,
/// cached snapshot reads) are kept as a compatibility shim for the
/// notification/parent-mode/data-export call sites that have not yet
/// been migrated.
class StreakService {
  final UserDatabase _db;
  final int _profileId;

  StreakService(this._db, {int profileId = 0}) : _profileId = profileId;

  /// Get streak recovery info — whether the current streak was recently
  /// saved by the grace period.
  Future<StreakRecoveryInfo> getRecoveryInfo() async {
    final streak = await _db.streakDao.getStreakByProfile(_profileId);
    if (streak == null) {
      return const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0);
    }

    final wasRecovered =
        streak.graceUsedDate != null &&
        DateUtils.isSameLocalDay(
          streak.graceUsedDate!,
          DateTimeFactory.nowUtc(),
        );

    final missedDate = wasRecovered && streak.graceUsedDate != null
        ? DateUtils.extractLocalDate(
            streak.graceUsedDate!,
          ).subtract(const Duration(days: 1))
        : null;

    return StreakRecoveryInfo(
      wasRecovered: wasRecovered,
      currentStreak: streak.currentStreak,
      missedDate: missedDate,
    );
  }

  Future<Streak?> getStreak() => _db.streakDao.getStreakByProfile(_profileId);

  Stream<Streak?> watchStreak() =>
      _db.streakDao.watchStreakByProfile(_profileId);

  /// Get a map of dates with learning activity within a date range,
  /// scoped to this profile.
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final completions = await _db.completionDao.getCompletionsByProfile(
      _profileId,
    );
    final activeDates = <DateTime>{};

    for (final completion in completions) {
      final localDate = DateUtils.extractLocalDate(completion.completedAt);
      final startLocal = DateUtils.extractLocalDate(startUtc);
      final endLocal = DateUtils.extractLocalDate(endUtc);

      if (!localDate.isBefore(startLocal) && !localDate.isAfter(endLocal)) {
        activeDates.add(localDate);
      }
    }

    return activeDates;
  }
}
