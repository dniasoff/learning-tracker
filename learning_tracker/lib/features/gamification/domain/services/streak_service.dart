import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';

/// Service for computing and managing global learning streaks.
///
/// A streak represents consecutive days with at least one completion
/// across any curriculum. Uses local timezone for day boundaries per FR109.
///
/// Supports a 1-day grace period: if the user misses exactly 1 day and
/// hasn't used grace within the last 7 days, the streak is preserved.
class StreakService {
  final UserDatabase _db;

  StreakService(this._db);

  /// Record a completion and update the streak accordingly.
  ///
  /// Called on every completion event. Only the first completion of the
  /// day triggers a streak increment. Supports streak recovery via
  /// a 1-day grace period.
  Future<Streak> recordCompletion(DateTime completionDateUtc) async {
    final existing = await _db.streakDao.getStreak();
    final completionLocalDate = DateUtils.extractLocalDate(completionDateUtc);

    if (existing == null) {
      // First ever completion
      final companion = StreaksCompanion.insert(
        currentStreak: const Value(1),
        maxStreak: const Value(1),
        lastCompletionDate: Value(completionDateUtc),
      );
      await _db.streakDao.upsertStreak(companion);
      return (await _db.streakDao.getStreak())!;
    }

    // Already completed today — no change
    if (existing.lastCompletionDate != null &&
        DateUtils.isSameLocalDay(
          existing.lastCompletionDate!,
          completionDateUtc,
        )) {
      return existing;
    }

    // Check if this is a consecutive day
    final lastLocalDate = existing.lastCompletionDate != null
        ? DateUtils.extractLocalDate(existing.lastCompletionDate!)
        : null;

    int newStreak;
    DateTime? newGraceUsedDate;
    final dayGap = lastLocalDate != null
        ? completionLocalDate.difference(lastLocalDate).inDays
        : null;

    if (dayGap == 1) {
      // Consecutive day — increment
      newStreak = existing.currentStreak + 1;
    } else if (dayGap == 2 && _canUseGrace(existing, completionLocalDate)) {
      // Missed exactly 1 day — use grace period to preserve streak
      newStreak = existing.currentStreak + 1;
      newGraceUsedDate = completionDateUtc;
    } else {
      // Gap of 2+ days (or grace already used recently) — reset to 1
      newStreak = 1;
    }

    final newMax = newStreak > existing.maxStreak
        ? newStreak
        : existing.maxStreak;

    await _db.streakDao.upsertStreak(
      StreaksCompanion(
        currentStreak: Value(newStreak),
        maxStreak: Value(newMax),
        lastCompletionDate: Value(completionDateUtc),
        graceUsedDate: newGraceUsedDate != null
            ? Value(newGraceUsedDate)
            : const Value.absent(),
      ),
    );

    return (await _db.streakDao.getStreak())!;
  }

  /// Check whether grace can be used: not used within the last 7 days.
  bool _canUseGrace(Streak existing, DateTime todayLocal) {
    if (existing.graceUsedDate == null) return true;
    final graceLocal = DateUtils.extractLocalDate(existing.graceUsedDate!);
    return todayLocal.difference(graceLocal).inDays > 7;
  }

  /// Get streak recovery info — whether the current streak was recently
  /// saved by the grace period.
  Future<StreakRecoveryInfo> getRecoveryInfo() async {
    final streak = await _db.streakDao.getStreak();
    if (streak == null) {
      return const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0);
    }

    final wasRecovered =
        streak.graceUsedDate != null &&
        DateUtils.isSameLocalDay(streak.graceUsedDate!, DateTime.now().toUtc());

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

  /// Get the current streak data.
  Future<Streak?> getStreak() => _db.streakDao.getStreak();

  /// Watch the current streak data for reactive UI updates.
  Stream<Streak?> watchStreak() => _db.streakDao.watchStreak();

  /// Get a map of dates with learning activity within a date range.
  ///
  /// Returns a set of local dates that had at least one completion.
  /// Used for calendar view in Epic 7.
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final completions = await _db.completionDao.getAllCompletions();
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
