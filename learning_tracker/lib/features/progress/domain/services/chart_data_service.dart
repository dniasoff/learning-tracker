import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';

/// Service for aggregating completion data into chart-ready structures.
///
/// All reads are scoped to a single profile so charts never mix data
/// across profiles on the same account.
class ChartDataService {
  final UserDatabase _db;
  final int _profileId;

  ChartDataService(this._db, {int profileId = 0}) : _profileId = profileId;

  /// Get daily completion counts within a date range.
  ///
  /// Uses [CompletionTierFilter.liveOnly] via [CompletionDao.getCompletionsByTier]
  /// so only in-session completions appear on the activity bar chart.
  /// Replaces the former kBulkPriorSentinelMs magic-constant filter (Layer 3).
  Future<List<DailyCompletionData>> getDailyCompletions({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    final completions = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.liveOnly,
      curriculumId: curriculumId != null
          ? _curriculumIdFromStorageKey(curriculumId)
          : null,
    );

    final counts = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate)) {
        counts[localDate] = (counts[localDate] ?? 0) + 1;
      }
    }

    final result = <DailyCompletionData>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      result.add(
        DailyCompletionData(date: current, count: counts[current] ?? 0),
      );
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Get cumulative progress over time.
  ///
  /// Uses [CompletionTierFilter.liveOnly] via [CompletionDao.getCompletionsByTier]
  /// so the chart plots only live activity. Replaces the former
  /// kBulkPriorSentinelMs magic-constant filter (Layer 3).
  Future<List<CumulativeProgressPoint>> getCumulativeProgress({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    final completions = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.liveOnly,
      curriculumId: curriculumId != null
          ? _curriculumIdFromStorageKey(curriculumId)
          : null,
    );

    final dailyCounts = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate)) {
        dailyCounts[localDate] = (dailyCounts[localDate] ?? 0) + 1;
      }
    }

    var cumulativeBeforeStart = 0;
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (localDate.isBefore(startDate)) {
        cumulativeBeforeStart++;
      }
    }

    final result = <CumulativeProgressPoint>[];
    var runningTotal = cumulativeBeforeStart;
    var current = startDate;
    while (!current.isAfter(endDate)) {
      runningTotal += dailyCounts[current] ?? 0;
      result.add(CumulativeProgressPoint(date: current, total: runningTotal));
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Get target line points for a curriculum's goal.
  Future<List<TargetLinePoint>?> getTargetLine({
    required String curriculumId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final goals = await _db.goalDao.getGoalsByCurriculumAndProfile(
      curriculumId,
      _profileId,
    );
    if (goals.isEmpty) return null;

    final goal = goals.first;
    if (goal.targetDate == null) return null;

    final completions = await _db.completionDao
        .getCompletionsByCurriculumAndProfile(curriculumId, _profileId);
    final baselineCount = completions
        .where((c) => _extractLocalDate(c.completedAt).isBefore(goal.createdAt))
        .length;

    final goalStart = _extractLocalDate(goal.createdAt);
    final goalEnd = _extractLocalDate(goal.targetDate!);
    final totalDays = goalEnd.difference(goalStart).inDays;
    if (totalDays <= 0) return null;

    final targetTotal = completions.length;

    final result = <TargetLinePoint>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      final daysFromGoalStart = current.difference(goalStart).inDays;
      final fraction = daysFromGoalStart / totalDays;
      final expected = baselineCount + (targetTotal * fraction);
      result.add(TargetLinePoint(date: current, expectedTotal: expected));
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Get daily points earned for points-over-time chart.
  Future<List<DailyPointsData>?> getDailyPoints({
    required DateTime startDate,
    required DateTime endDate,
    required UserMode userMode,
    String? curriculumId,
  }) async {
    if (userMode == UserMode.adult) return null;

    final completions = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.liveOnly,
      curriculumId: curriculumId != null
          ? _curriculumIdFromStorageKey(curriculumId)
          : null,
    );

    final pointsByDate = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate)) {
        pointsByDate[localDate] = (pointsByDate[localDate] ?? 0) + c.points;
      }
    }

    final result = <DailyPointsData>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      result.add(
        DailyPointsData(date: current, points: pointsByDate[current] ?? 0),
      );
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Get streak calendar data — set of dates with activity for this profile.
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final completions = await _db.completionDao.getCompletionsByProfile(
      _profileId,
    );
    final activeDates = <DateTime>{};

    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate)) {
        activeDates.add(localDate);
      }
    }

    return activeDates;
  }

  static DateTime _extractLocalDate(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Resolve a storage-key string to [CurriculumId], or null if unknown.
  static CurriculumId? _curriculumIdFromStorageKey(String key) {
    for (final c in CurriculumId.values) {
      if (c.storageKey == key) return c;
    }
    return null;
  }
}
