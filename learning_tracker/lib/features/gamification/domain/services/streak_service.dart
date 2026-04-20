import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';

/// Service for computing and managing per-profile learning streaks.
///
/// A streak represents consecutive days with at least one completion for
/// a single profile. Each profile on the account has its own independent
/// streak row — nothing is shared across profiles.
class StreakService {
  final UserDatabase _db;
  final int _profileId;

  StreakService(this._db, {int profileId = 0}) : _profileId = profileId;

  /// Record a completion and update the streak accordingly.
  Future<Streak> recordCompletion(DateTime completionDateUtc) async {
    final existing = await _db.streakDao.getStreakByProfile(_profileId);
    final completionLocalDate = DateUtils.extractLocalDate(completionDateUtc);

    if (existing == null) {
      final companion = StreaksCompanion.insert(
        profileId: Value(_profileId),
        currentStreak: const Value(1),
        maxStreak: const Value(1),
        lastCompletionDate: Value(completionDateUtc),
      );
      await _db.streakDao.upsertStreakByProfile(_profileId, companion);
      return (await _db.streakDao.getStreakByProfile(_profileId))!;
    }

    if (existing.lastCompletionDate != null &&
        DateUtils.isSameLocalDay(
          existing.lastCompletionDate!,
          completionDateUtc,
        )) {
      return existing;
    }

    final lastLocalDate = existing.lastCompletionDate != null
        ? DateUtils.extractLocalDate(existing.lastCompletionDate!)
        : null;

    int newStreak;
    DateTime? newGraceUsedDate;
    final dayGap = lastLocalDate != null
        ? completionLocalDate.difference(lastLocalDate).inDays
        : null;

    if (dayGap == 1) {
      newStreak = existing.currentStreak + 1;
    } else if (dayGap == 2 && _canUseGrace(existing, completionLocalDate)) {
      newStreak = existing.currentStreak + 1;
      newGraceUsedDate = completionDateUtc;
    } else {
      newStreak = 1;
    }

    final newMax = newStreak > existing.maxStreak
        ? newStreak
        : existing.maxStreak;

    await _db.streakDao.upsertStreakByProfile(
      _profileId,
      StreaksCompanion(
        profileId: Value(_profileId),
        currentStreak: Value(newStreak),
        maxStreak: Value(newMax),
        lastCompletionDate: Value(completionDateUtc),
        graceUsedDate: newGraceUsedDate != null
            ? Value(newGraceUsedDate)
            : const Value.absent(),
      ),
    );

    return (await _db.streakDao.getStreakByProfile(_profileId))!;
  }

  bool _canUseGrace(Streak existing, DateTime todayLocal) {
    if (existing.graceUsedDate == null) return true;
    final graceLocal = DateUtils.extractLocalDate(existing.graceUsedDate!);
    return todayLocal.difference(graceLocal).inDays > 7;
  }

  /// Get streak recovery info — whether the current streak was recently
  /// saved by the grace period.
  Future<StreakRecoveryInfo> getRecoveryInfo() async {
    final streak = await _db.streakDao.getStreakByProfile(_profileId);
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
