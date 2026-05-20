import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';

/// Threshold (in days) above which chart series are aggregated into weekly
/// buckets instead of returning one point per day.
///
/// 60 days keeps the daily granularity for the 7-day and 30-day pills and
/// also for moderate "all-time" ranges. Anything beyond gets bucketed so the
/// fl_chart series never exceeds ~520 points for a decade of data.
const int kChartDailyMaxDays = 60;

/// Service for aggregating completion data into chart-ready structures.
///
/// All reads are scoped to a single profile so charts never mix data
/// across profiles on the same account.
class ChartDataService {
  final UserDatabase _db;
  final int _profileId;

  ChartDataService(this._db, {int profileId = 0}) : _profileId = profileId;

  /// Get completion counts within a date range — bucketed daily for short
  /// ranges (≤ [kChartDailyMaxDays]) and weekly otherwise.
  ///
  /// Uses [CompletionTierFilter.trackAchievement] so live AND bulk-in-track
  /// completions are visible on the activity chart (per the three-tier
  /// completion credit policy: bulk-marks made inside a track wizard count
  /// toward chart visibility but do not earn streak/points).
  ///
  /// For ranges > [kChartDailyMaxDays] days the effective start date is
  /// capped to the earliest matching completion (after the tier filter) so
  /// users with sparse data never see thousands of empty leading buckets.
  /// The fl_chart widget can render either daily or weekly series — the
  /// bucket boundary is encoded in [DailyCompletionData.date] (which always
  /// holds the *start* of the bucket).
  Future<List<DailyCompletionData>> getDailyCompletions({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    final curriculum = _resolveCurriculum(curriculumId);
    final effectiveStart = await _effectiveStartDate(
      requestedStart: startDate,
      requestedEnd: endDate,
      curriculumId: curriculum,
    );

    // SQL pushdown: bound by [effectiveStart, endDate].
    final completions = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.trackAchievement,
      curriculumId: curriculum,
      since: effectiveStart,
      until: _endOfDay(endDate),
    );

    final counts = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      counts[localDate] = (counts[localDate] ?? 0) + 1;
    }

    return _bucketizeDaily(
      counts: counts,
      startDate: effectiveStart,
      endDate: endDate,
    );
  }

  /// Get cumulative progress over time — bucketed daily or weekly as for
  /// [getDailyCompletions].
  ///
  /// Uses [CompletionTierFilter.trackAchievement] (live + bulk-in-track)
  /// because the cumulative-progress chart represents real per-track
  /// learning across time, not streak engagement.
  ///
  /// [CumulativeProgressPoint.date] is the start of the bucket; [total] is
  /// the cumulative count at the END of the bucket.
  Future<List<CumulativeProgressPoint>> getCumulativeProgress({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    final curriculum = _resolveCurriculum(curriculumId);
    final effectiveStart = await _effectiveStartDate(
      requestedStart: startDate,
      requestedEnd: endDate,
      curriculumId: curriculum,
    );

    // SQL count of completions strictly before [effectiveStart] to seed the
    // running total. Subtracting 1ms keeps "before" strictly exclusive.
    final beforeStartCutoff = effectiveStart.subtract(
      const Duration(milliseconds: 1),
    );
    final priorRows = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.trackAchievement,
      curriculumId: curriculum,
      until: beforeStartCutoff,
    );
    final cumulativeBeforeStart = priorRows.length;

    // Completions within the window.
    final completions = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.trackAchievement,
      curriculumId: curriculum,
      since: effectiveStart,
      until: _endOfDay(endDate),
    );

    final dailyCounts = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      dailyCounts[localDate] = (dailyCounts[localDate] ?? 0) + 1;
    }

    return _bucketizeCumulative(
      counts: dailyCounts,
      startDate: effectiveStart,
      endDate: endDate,
      cumulativeBeforeStart: cumulativeBeforeStart,
    );
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

  /// Get points earned per bucket for the points-over-time chart.
  ///
  /// Uses [CompletionTierFilter.liveOnly] — points are only earned by live
  /// in-session marks (per the three-tier credit policy: engagement tier).
  Future<List<DailyPointsData>?> getDailyPoints({
    required DateTime startDate,
    required DateTime endDate,
    required UserMode userMode,
    String? curriculumId,
  }) async {
    if (userMode == UserMode.adult) return null;

    final curriculum = _resolveCurriculum(curriculumId);
    final effectiveStart = await _effectiveStartDate(
      requestedStart: startDate,
      requestedEnd: endDate,
      curriculumId: curriculum,
      // Points are awarded only on live marks; use the same tier here so
      // the effective-start calc doesn't over-narrow against bulk rows.
      tier: CompletionTierFilter.liveOnly,
    );

    final completions = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.liveOnly,
      curriculumId: curriculum,
      since: effectiveStart,
      until: _endOfDay(endDate),
    );

    final pointsByDate = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      pointsByDate[localDate] = (pointsByDate[localDate] ?? 0) + c.points;
    }

    return _bucketizePoints(
      points: pointsByDate,
      startDate: effectiveStart,
      endDate: endDate,
    );
  }

  /// Get streak calendar data — set of dates with activity for this profile.
  ///
  /// Pushes the date filter to SQL via [CompletionDao.getCompletionsByTier]
  /// instead of loading every row for the profile and filtering in Dart.
  /// Uses [CompletionTierFilter.trackAchievement] so the calendar lights up
  /// for both live and bulk-in-track marks (consistent with the other
  /// per-track charts).
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final completions = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.trackAchievement,
      since: startDate,
      until: _endOfDay(endDate),
    );
    final activeDates = <DateTime>{};

    for (final c in completions) {
      activeDates.add(_extractLocalDate(c.completedAt));
    }

    return activeDates;
  }

  // ── Bucketization helpers ──────────────────────────────────────────────

  /// Returns the number of LOCAL CALENDAR DAYS between [start] and [end]
  /// inclusive. DST-safe: uses y/m/d components rather than millisecond
  /// arithmetic, which would slip by an hour when the interval crosses a
  /// DST transition and accumulate to one missing bucket over a month.
  static int _calendarDaysBetween(DateTime start, DateTime end) {
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    return (b.difference(a).inHours / 24).round();
  }

  /// Adds [days] calendar days to [date], snapping back to midnight local
  /// so DST transitions don't drift the time-of-day.
  static DateTime _addDays(DateTime date, int days) {
    return DateTime(date.year, date.month, date.day + days);
  }

  /// Returns daily or weekly buckets for [counts] within [startDate]..[endDate].
  ///
  /// - When the span ≤ [kChartDailyMaxDays], one [DailyCompletionData] per day.
  /// - Otherwise weekly buckets starting at [startDate].
  static List<DailyCompletionData> _bucketizeDaily({
    required Map<DateTime, int> counts,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final spanDays = _calendarDaysBetween(startDate, endDate);
    if (spanDays <= kChartDailyMaxDays) {
      final result = <DailyCompletionData>[];
      var current = startDate;
      while (!current.isAfter(endDate)) {
        result.add(
          DailyCompletionData(date: current, count: counts[current] ?? 0),
        );
        current = _addDays(current, 1);
      }
      return result;
    }

    // Weekly bucketing — each bucket covers [bucketStart, bucketStart+7).
    final result = <DailyCompletionData>[];
    var bucketStart = startDate;
    while (!bucketStart.isAfter(endDate)) {
      final bucketEndExclusive = _addDays(bucketStart, 7);
      var sum = 0;
      counts.forEach((date, n) {
        if (!date.isBefore(bucketStart) && date.isBefore(bucketEndExclusive)) {
          sum += n;
        }
      });
      result.add(DailyCompletionData(date: bucketStart, count: sum));
      bucketStart = bucketEndExclusive;
    }
    return result;
  }

  /// Bucketized cumulative points: same bucketing as [_bucketizeDaily], but
  /// each point's [total] is the running total at the END of the bucket.
  static List<CumulativeProgressPoint> _bucketizeCumulative({
    required Map<DateTime, int> counts,
    required DateTime startDate,
    required DateTime endDate,
    required int cumulativeBeforeStart,
  }) {
    final spanDays = _calendarDaysBetween(startDate, endDate);
    if (spanDays <= kChartDailyMaxDays) {
      final result = <CumulativeProgressPoint>[];
      var runningTotal = cumulativeBeforeStart;
      var current = startDate;
      while (!current.isAfter(endDate)) {
        runningTotal += counts[current] ?? 0;
        result.add(CumulativeProgressPoint(date: current, total: runningTotal));
        current = _addDays(current, 1);
      }
      return result;
    }

    // Weekly bucketing.
    final result = <CumulativeProgressPoint>[];
    var runningTotal = cumulativeBeforeStart;
    var bucketStart = startDate;
    while (!bucketStart.isAfter(endDate)) {
      final bucketEndExclusive = _addDays(bucketStart, 7);
      counts.forEach((date, n) {
        if (!date.isBefore(bucketStart) && date.isBefore(bucketEndExclusive)) {
          runningTotal += n;
        }
      });
      result.add(
        CumulativeProgressPoint(date: bucketStart, total: runningTotal),
      );
      bucketStart = bucketEndExclusive;
    }
    return result;
  }

  /// Bucketized daily points: same shape as [_bucketizeDaily], summing
  /// [DailyPointsData.points] over the bucket.
  static List<DailyPointsData> _bucketizePoints({
    required Map<DateTime, int> points,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final spanDays = _calendarDaysBetween(startDate, endDate);
    if (spanDays <= kChartDailyMaxDays) {
      final result = <DailyPointsData>[];
      var current = startDate;
      while (!current.isAfter(endDate)) {
        result.add(
          DailyPointsData(date: current, points: points[current] ?? 0),
        );
        current = _addDays(current, 1);
      }
      return result;
    }

    final result = <DailyPointsData>[];
    var bucketStart = startDate;
    while (!bucketStart.isAfter(endDate)) {
      final bucketEndExclusive = _addDays(bucketStart, 7);
      var sum = 0;
      points.forEach((date, p) {
        if (!date.isBefore(bucketStart) && date.isBefore(bucketEndExclusive)) {
          sum += p;
        }
      });
      result.add(DailyPointsData(date: bucketStart, points: sum));
      bucketStart = bucketEndExclusive;
    }
    return result;
  }

  /// Returns the effective start date for chart aggregation.
  ///
  /// For ranges within [kChartDailyMaxDays], the requested start is honored
  /// verbatim — daily granularity is fine. For longer ranges (e.g. "all
  /// time" from year 2000), the effective start is bumped forward to the
  /// earliest matching completion so the chart never displays thousands of
  /// leading empty buckets.
  ///
  /// If there are no matching completions in the requested window the
  /// effective start is set to one bucket before [requestedEnd] so the
  /// chart still renders a single empty trailing bucket rather than
  /// thousands.
  Future<DateTime> _effectiveStartDate({
    required DateTime requestedStart,
    required DateTime requestedEnd,
    required CurriculumId? curriculumId,
    CompletionTierFilter tier = CompletionTierFilter.trackAchievement,
  }) async {
    final span = requestedEnd.difference(requestedStart).inDays;
    if (span <= kChartDailyMaxDays) return requestedStart;

    // Look up the earliest matching completion within the requested window.
    final all = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: tier,
      curriculumId: curriculumId,
      since: requestedStart,
      until: _endOfDay(requestedEnd),
    );
    if (all.isEmpty) {
      // No data in the requested window. Snap to [endDate, endDate] so the
      // chart renders a single empty bucket on the right edge rather than
      // a thousand. The chart widget shows "No data" when the series is
      // empty otherwise.
      return _extractLocalDate(requestedEnd);
    }
    var earliest = _extractLocalDate(all.first.completedAt);
    for (final c in all) {
      final d = _extractLocalDate(c.completedAt);
      if (d.isBefore(earliest)) earliest = d;
    }
    return earliest.isBefore(requestedStart) ? requestedStart : earliest;
  }

  static DateTime _extractLocalDate(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Returns the inclusive end-of-day instant for a date-only local value.
  ///
  /// Used as the SQL `until` bound so completions logged after midnight on
  /// the requested end date are still counted.
  static DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Resolve a storage-key string to [CurriculumId], or null if null/unknown.
  static CurriculumId? _resolveCurriculum(String? key) {
    if (key == null) return null;
    for (final c in CurriculumId.values) {
      if (c.storageKey == key) return c;
    }
    return null;
  }
}
