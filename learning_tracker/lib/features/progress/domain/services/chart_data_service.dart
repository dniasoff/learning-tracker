import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';

/// Service for aggregating completion data into chart-ready structures.
///
/// All date operations use local timezone for day boundaries.
class ChartDataService {
  final UserDatabase _db;

  ChartDataService(this._db);

  /// Get daily completion counts within a date range.
  ///
  /// Returns one entry per day in the range, with zero for inactive days.
  Future<List<DailyCompletionData>> getDailyCompletions({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    final completions = curriculumId != null
        ? await _db.completionDao.getCompletionsByCurriculum(curriculumId)
        : await _db.completionDao.getAllCompletions();

    // Count completions per local date
    final counts = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate)) {
        counts[localDate] = (counts[localDate] ?? 0) + 1;
      }
    }

    // Fill in all days in range (zero for gaps)
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
  /// Returns monotonically increasing totals from the first completion date.
  Future<List<CumulativeProgressPoint>> getCumulativeProgress({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    final completions = curriculumId != null
        ? await _db.completionDao.getCompletionsByCurriculum(curriculumId)
        : await _db.completionDao.getAllCompletions();

    // Count completions per local date
    final dailyCounts = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate)) {
        dailyCounts[localDate] = (dailyCounts[localDate] ?? 0) + 1;
      }
    }

    // Count completions before start date for initial cumulative
    var cumulativeBeforeStart = 0;
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (localDate.isBefore(startDate)) {
        cumulativeBeforeStart++;
      }
    }

    // Build cumulative series
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
  ///
  /// Returns null if no goal exists for the curriculum.
  Future<List<TargetLinePoint>?> getTargetLine({
    required String curriculumId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final goals = await _db.goalDao.getGoalsByCurriculum(curriculumId);
    if (goals.isEmpty) return null;

    final goal = goals.first;
    if (goal.targetDate == null) return null;

    // Get total completions at goal start to calculate baseline
    final completions = await _db.completionDao.getCompletionsByCurriculum(
      curriculumId,
    );
    final baselineCount = completions
        .where((c) => _extractLocalDate(c.completedAt).isBefore(goal.createdAt))
        .length;

    // Linear interpolation from goal start to target date
    final goalStart = _extractLocalDate(goal.createdAt);
    final goalEnd = _extractLocalDate(goal.targetDate!);
    final totalDays = goalEnd.difference(goalStart).inDays;
    if (totalDays <= 0) return null;

    // We need a target total — use targetPercent * total items
    // For now approximate with completions count as proxy
    final targetTotal = completions.length; // Best available approximation

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
  ///
  /// Only returns data when userMode is child. Returns null for adult mode.
  Future<List<DailyPointsData>?> getDailyPoints({
    required DateTime startDate,
    required DateTime endDate,
    required UserMode userMode,
    String? curriculumId,
  }) async {
    if (userMode == UserMode.adult) return null;

    final completions = curriculumId != null
        ? await _db.completionDao.getCompletionsByCurriculum(curriculumId)
        : await _db.completionDao.getAllCompletions();

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

  /// Get streak calendar data — set of dates with activity.
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final completions = await _db.completionDao.getAllCompletions();
    final activeDates = <DateTime>{};

    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate)) {
        activeDates.add(localDate);
      }
    }

    return activeDates;
  }

  /// Extract local date (midnight) from a DateTime.
  static DateTime _extractLocalDate(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
