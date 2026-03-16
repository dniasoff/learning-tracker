import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Service for computing and managing global learning streaks.
///
/// A streak represents consecutive days with at least one completion
/// across any curriculum. Uses local timezone for day boundaries per FR109.
class StreakService {
  final AppDatabase _db;

  StreakService(this._db);

  /// Record a completion and update the streak accordingly.
  ///
  /// Called on every completion event. Only the first completion of the
  /// day triggers a streak increment.
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
    if (lastLocalDate != null &&
        completionLocalDate.difference(lastLocalDate).inDays == 1) {
      // Consecutive day — increment
      newStreak = existing.currentStreak + 1;
    } else {
      // Gap day(s) — reset to 1
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
      ),
    );

    return (await _db.streakDao.getStreak())!;
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
