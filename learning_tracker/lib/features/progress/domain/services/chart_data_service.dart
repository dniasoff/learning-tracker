import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

/// Threshold (in days) above which chart series are aggregated into weekly
/// buckets instead of returning one point per day.
///
/// 60 days keeps the daily granularity for the 7-day and 30-day pills and
/// also for moderate "all-time" ranges. Anything beyond gets bucketed so the
/// fl_chart series never exceeds ~520 points for a decade of data.
const int kChartDailyMaxDays = 60;

/// Floor date for chart "All time" ranges.
///
/// The Recent Activity / Progress charts represent "All time" as a date
/// range whose start is well before any plausible completion. We use
/// 2000-01-01 in UTC; it matches the legacy bulk-prior sentinel epoch
/// (so chart ranges and bulk-prior queries share one anchor) and is far
/// enough in the past that no real completion predates it.
///
/// The chart service caps this internally to the user's first matching
/// completion via [_effectiveStartDate], so the picker can pass this
/// constant without the chart loop ever iterating ~9,600 leading empty
/// days. See also F18 in `docs/_archive/` for the rationale on retiring
/// the literal `DateTime(2000, 1, 1)` use at call sites.
final DateTime kChartAllTimeFloor = DateTime.utc(2000, 1, 1);

/// Domain read seam for [ChartDataService], implemented by an adapter under
/// `features/progress/data/repositories/`.
///
/// The chart service lives in `domain/services/`, and AD-23/AD-28 forbid
/// `lib/features/**/domain/**` from importing
/// `package:learning_tracker/data/firestore/...` or
/// `package:learning_tracker/data/repositories/...` — so the service reads
/// only through this interface and never resolves a Firestore repository
/// itself. The concrete adapter is constructed from a `Ref`
/// (`FirestoreChartDataRepositoryAdapter`), resolves the repositories per
/// call, and owns the D-E not-ready policy.
///
/// ## Not-ready policy (D-E)
///
/// All three reads THROW (e.g. [ProgressRepositoryNotReadyException]) when
/// the backing provider is not ready rather than returning `[]` — including
/// [getGoals], which was previously treated as configuration-shaped (an
/// empty list = "no goal configured"). T-37 correctness fix: an empty list
/// on a not-ready backend was indistinguishable from that legitimate
/// no-goals-configured state, exactly the D-E failure mode this rule
/// exists to prevent — the throw is now consistent across every read here.
abstract class ChartDataRepository {
  /// Completions for [curriculumId] (across all curricula when `null`),
  /// filtered to [tier] and to completions within
  /// `[since, until]` inclusive when those bounds are supplied.
  ///
  /// Achievement-shaped — throws when the backend is not ready (see the
  /// class doc comment).
  Future<List<CompletionEntity>> getCompletionsByTier({
    required CompletionTierFilter tier,
    CurriculumId? curriculumId,
    DateTime? since,
    DateTime? until,
  });

  /// Goals for [curriculumId], sorted by `targetDate` (null-first,
  /// ascending).
  ///
  /// Returns an empty list when none are configured. Throws when the
  /// backend is not ready (see the class doc comment) — a not-ready backend
  /// must never be mistaken for a genuinely goal-less curriculum.
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId);

  /// Every completion for [curriculumId].
  ///
  /// Achievement-shaped — throws when the backend is not ready (see the
  /// class doc comment).
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    CurriculumId curriculumId,
  );
}

/// Service for aggregating completion data into chart-ready structures.
///
/// All reads are scoped to a single profile by the injected
/// [ChartDataRepository] (Firestore repositories are profile-scoped by their
/// collection path), so charts never mix data across profiles on the same
/// account.
class ChartDataService {
  ChartDataService({required ChartDataRepository repository})
    : _repository = repository;

  final ChartDataRepository _repository;

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
  ///
  /// Achievement-shaped read: an empty series must never be a silent
  /// "backend not ready" fallback — the repository throws in that case, so
  /// an empty result here is only ever a truthful "no completions in this
  /// window".
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

    final completions = await _repository.getCompletionsByTier(
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

  /// Get per-bucket counts split into limudim (stage 1) and chazaros
  /// (stage > 1) for the Recent Activity screen's two-colour stacked bar
  /// chart.
  ///
  /// Uses [CompletionTierFilter.trackAchievement] — Recent Activity counts
  /// track learning (live + bulk-mark in-track), per the unified rule that
  /// "track-based learning = actual app learning, except for points and
  /// streak". Bulk-mark items are stamped with the sentinel date (1/1/2000)
  /// so they naturally fall outside finite recent windows; for "all time"
  /// spans the bucketing surfaces them at year 2000.
  ///
  /// Bucketing matches [getDailyCompletions]: daily for spans
  /// ≤ [kChartDailyMaxDays], weekly otherwise. For longer spans the
  /// effective start is bumped to the user's first track-learning completion
  /// so the chart never displays thousands of empty leading buckets — same
  /// cap applied by the other Recent Activity methods.
  ///
  /// Achievement-shaped read — see [getDailyCompletions].
  Future<List<DailyLimudChazaraData>> getDailyLimudimAndChazaros({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    final curriculum = _resolveCurriculum(curriculumId);
    final effectiveStart = await _effectiveStartDate(
      requestedStart: startDate,
      requestedEnd: endDate,
      curriculumId: curriculum,
      tier: CompletionTierFilter.trackAchievement,
    );

    final completions = await _repository.getCompletionsByTier(
      tier: CompletionTierFilter.trackAchievement,
      curriculumId: curriculum,
      since: effectiveStart,
      until: _endOfDay(endDate),
    );

    final limudByDate = <DateTime, int>{};
    final chazaraByDate = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (c.stageId <= 1) {
        limudByDate[localDate] = (limudByDate[localDate] ?? 0) + 1;
      } else {
        chazaraByDate[localDate] = (chazaraByDate[localDate] ?? 0) + 1;
      }
    }

    return _bucketizeLimudChazara(
      limudByDate: limudByDate,
      chazaraByDate: chazaraByDate,
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
  ///
  /// Achievement-shaped read — see [getDailyCompletions].
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

    // Count of completions strictly before [effectiveStart] to seed the
    // running total. Subtracting 1ms keeps "before" strictly exclusive.
    final beforeStartCutoff = effectiveStart.subtract(
      const Duration(milliseconds: 1),
    );
    final priorRows = await _repository.getCompletionsByTier(
      tier: CompletionTierFilter.trackAchievement,
      curriculumId: curriculum,
      until: beforeStartCutoff,
    );
    final cumulativeBeforeStart = priorRows.length;

    // Completions within the window.
    final completions = await _repository.getCompletionsByTier(
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

  /// Track-learning counterpart of [getCumulativeProgress] for the Recent
  /// Activity screen. Both live and bulk-mark-in-track completions contribute
  /// to the running total — only lifetime-only imports are excluded.
  ///
  /// The method name retains the historic "Live" suffix for callsite
  /// stability, but [getCumulativeProgress] already defaults to the same
  /// [CompletionTierFilter.trackAchievement] tier this method used to
  /// duplicate independently, so it is now a one-line delegate rather than a
  /// second ~45-line copy of the query/bucketing logic (AUD-progress-05 —
  /// the twin previously risked silently diverging from
  /// [getCumulativeProgress] the next time only one of them got touched).
  Future<List<CumulativeProgressPoint>> getCumulativeProgressLive({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) => getCumulativeProgress(
    startDate: startDate,
    endDate: endDate,
    curriculumId: curriculumId,
  );

  /// Live-only counterpart of [getStreakCalendar] for the Recent Activity
  /// engagement-tier lens. Lights up only days with a live in-session mark —
  /// consistent with the streak (engagement-tier) policy.
  ///
  /// When [curriculumId] is supplied the active-dates set is scoped to that
  /// curriculum, so the calendar dot pattern follows the screen's curriculum
  /// filter pill (F11 — W7-D fix wave: previously the parameter was missing
  /// and the calendar ignored the chip selection while every other chart
  /// re-fetched).
  ///
  /// The headline streak number on the screen (`dashboardStreakProvider`)
  /// stays profile-global by design — that is the user's overall live
  /// streak across every active curriculum and is the source for the
  /// Dashboard hero pill too. The screen's chart subtitle clarifies that
  /// scope to the user; see `recent_activity_screen.dart`.
  ///
  /// Achievement-shaped read: the returned set answers "on which days did
  /// this learner learn" — the repository throws when not ready rather than
  /// reporting an empty (would-be "learned nothing") set.
  Future<Set<DateTime>> getStreakCalendarLive({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    final curriculum = _resolveCurriculum(curriculumId);
    final completions = await _repository.getCompletionsByTier(
      tier: CompletionTierFilter.liveOnly,
      curriculumId: curriculum,
      since: startDate,
      until: _endOfDay(endDate),
    );
    final activeDates = <DateTime>{};
    for (final c in completions) {
      activeDates.add(_extractLocalDate(c.completedAt));
    }
    return activeDates;
  }

  /// Get target line points for a curriculum's goal.
  ///
  /// Configuration-shaped where the line itself is concerned: `null` is a
  /// legitimate "no goal / no target date configured" state the UI already
  /// renders as no overlay — it is not a fabricated progress figure. When a
  /// goal DOES exist, the completion baseline that seeds the line is an
  /// achievement read, which the repository throws on if not ready.
  Future<List<TargetLinePoint>?> getTargetLine({
    required String curriculumId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final curriculum = _resolveCurriculum(curriculumId);
    if (curriculum == null) return null;

    final goals = await _repository.getGoals(curriculum);
    if (goals.isEmpty) return null;

    final goal = goals.first;
    if (goal.targetDate == null) return null;

    final completions = await _repository.getCompletionsByCurriculum(
      curriculum,
    );
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
  ///
  /// The adult-mode `null` branch is configuration-shaped (adults do not
  /// earn points — a truthful "not applicable"); the counting itself is
  /// achievement-shaped, so the repository throws on a not-ready backend
  /// rather than reporting a fabricated zero-point series.
  Future<List<DailyPointsData>?> getDailyPoints({
    required DateTime startDate,
    required DateTime endDate,
    required ProfileMode userMode,
    String? curriculumId,
  }) async {
    if (userMode.isAdult) return null;

    final curriculum = _resolveCurriculum(curriculumId);
    final effectiveStart = await _effectiveStartDate(
      requestedStart: startDate,
      requestedEnd: endDate,
      curriculumId: curriculum,
      // Points are awarded only on live marks; use the same tier here so
      // the effective-start calc doesn't over-narrow against bulk rows.
      tier: CompletionTierFilter.liveOnly,
    );

    final completions = await _repository.getCompletionsByTier(
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
  /// Uses [CompletionTierFilter.trackAchievement] so the calendar lights up
  /// for both live and bulk-in-track marks (consistent with the other
  /// per-track charts).
  ///
  /// Achievement-shaped read — see [getStreakCalendarLive].
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final completions = await _repository.getCompletionsByTier(
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

  /// Bucketized per-stage split for the Limudim & Chazaros stacked chart.
  ///
  /// Same bucketing rule as [_bucketizeDaily] — daily for short spans, weekly
  /// otherwise. Each bucket sums [limudByDate] and [chazaraByDate]
  /// independently so the caller gets both segment heights per bar.
  static List<DailyLimudChazaraData> _bucketizeLimudChazara({
    required Map<DateTime, int> limudByDate,
    required Map<DateTime, int> chazaraByDate,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final spanDays = _calendarDaysBetween(startDate, endDate);
    if (spanDays <= kChartDailyMaxDays) {
      final result = <DailyLimudChazaraData>[];
      var current = startDate;
      while (!current.isAfter(endDate)) {
        result.add(
          DailyLimudChazaraData(
            date: current,
            limudCount: limudByDate[current] ?? 0,
            chazaraCount: chazaraByDate[current] ?? 0,
          ),
        );
        current = _addDays(current, 1);
      }
      return result;
    }

    final result = <DailyLimudChazaraData>[];
    var bucketStart = startDate;
    while (!bucketStart.isAfter(endDate)) {
      final bucketEndExclusive = _addDays(bucketStart, 7);
      var limudSum = 0;
      var chazaraSum = 0;
      limudByDate.forEach((date, n) {
        if (!date.isBefore(bucketStart) && date.isBefore(bucketEndExclusive)) {
          limudSum += n;
        }
      });
      chazaraByDate.forEach((date, n) {
        if (!date.isBefore(bucketStart) && date.isBefore(bucketEndExclusive)) {
          chazaraSum += n;
        }
      });
      result.add(
        DailyLimudChazaraData(
          date: bucketStart,
          limudCount: limudSum,
          chazaraCount: chazaraSum,
        ),
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
  /// thousands. This is only reached after the repository resolved
  /// successfully (achievement-shaped reads throw when not ready), so the
  /// empty window here is a truthful "no completions" — never a fabricated
  /// zero.
  Future<DateTime> _effectiveStartDate({
    required DateTime requestedStart,
    required DateTime requestedEnd,
    required CurriculumId? curriculumId,
    CompletionTierFilter tier = CompletionTierFilter.trackAchievement,
  }) async {
    final span = requestedEnd.difference(requestedStart).inDays;
    if (span <= kChartDailyMaxDays) return requestedStart;

    // Look up the earliest matching completion within the requested window.
    final all = await _repository.getCompletionsByTier(
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
    // Clamp the effective start to the requested floor as a LOCAL date.
    //
    // `earliest` is a local-midnight date (via [_extractLocalDate]) and the
    // downstream bucketizers key every completion on its local-midnight date
    // too. But the "All time" range's floor ([kChartAllTimeFloor]) is a
    // UTC-midnight instant. In a positive-offset timezone a completion's
    // local-midnight date is an instant slightly BEFORE UTC midnight, so
    // clamping to the raw UTC `requestedStart` would push `effectiveStart`
    // one notch past that date — and the weekly bucket loop
    // (`!date.isBefore(bucketStart)`) then silently drops it. That erased
    // sentinel-dated (2000-01-01) bulk-mark completions from the All-time
    // limud/chazara and cumulative feeds even though the tier includes them.
    // Normalizing the floor to its local date keeps both sides of the compare
    // in one representation. (Finite windows return `requestedStart` verbatim
    // above, before this line, so they are unaffected.)
    final floor = _extractLocalDate(requestedStart);
    return earliest.isBefore(floor) ? floor : earliest;
  }

  static DateTime _extractLocalDate(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Returns the inclusive end-of-day instant for a date-only local value.
  ///
  /// Used as the `until` bound so completions logged after midnight on the
  /// requested end date are still counted.
  static DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Resolve a storage-key string to [CurriculumId], or null if null/unknown.
  static CurriculumId? _resolveCurriculum(String? key) {
    if (key == null) return null;
    return CurriculumId.fromStorageKey(key);
  }
}
