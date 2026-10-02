import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';

/// Ranges longer than this many days are bucketed into weeks.
const int kChartDailyMaxDays = 60;

/// The "all time" floor of a chart range.
final DateTime kChartAllTimeFloor = DateTime.utc(2000, 1, 1);

/// Chart series over the active learner's [LearnerState] (DNI-474).
///
/// Every series buckets the engine's counted learn events
/// ([LearnerState.countedLearns]) by their `learned_on` local day: voided
/// and lock-ignored events never appear, before-tracking backfill has no
/// day, and a learn on an already-learnt leaf is a chazara (the PRD derived
/// count, AD-32). Nothing here reads completions or `learning_events`.
///
/// Ranges up to [kChartDailyMaxDays] are daily; longer ranges are weekly
/// buckets starting at the first active day (never before the requested
/// start).
class ChartDataService {
  /// The service is stateless.
  const ChartDataService();

  /// Counted learn events per day.
  List<DailyCompletionData> getDailyCompletions(
    LearnerState? state, {
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
    Corpus? Function(String curriculumId)? corpusFor,
  }) {
    final days = _days(state, curriculumId, corpusFor);
    final start = _effectiveStart(days.keys, startDate, endDate);
    return _bucketize(
      start,
      endDate,
      (from, to) => _sum(days, from, to, (d) => d.events),
      (date, n) => DailyCompletionData(date: date, count: n),
    );
  }

  /// Limud (first learning of a leaf) and chazara (repeat) events per day.
  List<DailyLimudChazaraData> getDailyLimudimAndChazaros(
    LearnerState? state, {
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
    Corpus? Function(String curriculumId)? corpusFor,
  }) {
    final days = _days(state, curriculumId, corpusFor);
    final start = _effectiveStart(days.keys, startDate, endDate);
    final out = <DailyLimudChazaraData>[];
    _walk(start, endDate, (from, to) {
      out.add(
        DailyLimudChazaraData(
          date: from,
          limudCount: _sum(days, from, to, (d) => d.limudim),
          chazaraCount: _sum(days, from, to, (d) => d.chazaros),
        ),
      );
    });
    return out;
  }

  /// Distinct leaves newly learnt, cumulative from the requested start:
  /// the running total starts at the leaves learnt on earlier days.
  List<CumulativeProgressPoint> getCumulativeProgress(
    LearnerState? state, {
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
    Corpus? Function(String curriculumId)? corpusFor,
  }) {
    final days = _days(state, curriculumId, corpusFor);
    final start = _effectiveStart(days.keys, startDate, endDate);
    var running = 0;
    for (final MapEntry(key: day, value: activity) in days.entries) {
      if (day.isBefore(start)) running += activity.newLeaves;
    }
    final out = <CumulativeProgressPoint>[];
    _walk(start, endDate, (from, to) {
      running += _sum(days, from, to, (d) => d.newLeaves);
      out.add(CumulativeProgressPoint(date: from, total: running));
    });
    return out;
  }

  /// The days in `[startDate, endDate]` with counted learning.
  Set<DateTime> getStreakCalendar(
    LearnerState? state, {
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) {
    final from = _day(startDate);
    final to = _day(endDate);
    return {
      for (final day in _days(state, curriculumId, null).keys)
        if (!day.isBefore(from) && !day.isAfter(to)) day,
    };
  }

  /// Points earned per day (child profiles only; null for adults): each
  /// [awards] row whose event earns (AD-50 `earningEventIds`) counts on its
  /// event's `learned_on` day.
  List<DailyPointsData>? getDailyPoints(
    LearnerState? state, {
    required List<PointsLedgerRow> awards,
    required DateTime startDate,
    required DateTime endDate,
    required ProfileMode userMode,
    String? curriculumId,
  }) {
    if (userMode.isAdult) return null;
    final dayOf = <String, DateTime>{
      for (final e in countedLearnsOf(
        state,
        curricula: curriculumId == null ? null : {curriculumId},
      ))
        if (learnedOnDay(e) case final day?) e.id: day,
    };
    final earning = state?.earningEventIds ?? const <String>{};
    final byDay = <DateTime, int>{};
    for (final row in awards) {
      final eventId = row.eventId;
      if (eventId == null || !earning.contains(eventId)) continue;
      final day = dayOf[eventId];
      if (day == null) continue;
      byDay[day] = (byDay[day] ?? 0) + row.amount;
    }
    final start = _effectiveStart(byDay.keys, startDate, endDate);
    final out = <DailyPointsData>[];
    _walk(start, endDate, (from, to) {
      var sum = 0;
      byDay.forEach((day, points) {
        if (!day.isBefore(from) && day.isBefore(to)) sum += points;
      });
      out.add(DailyPointsData(date: from, points: sum));
    });
    return out;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Map<DateTime, DayActivity> _days(
    LearnerState? state,
    String? curriculumId,
    Corpus? Function(String curriculumId)? corpusFor,
  ) => dailyActivityOf(
    state,
    curricula: curriculumId == null ? null : {curriculumId},
    corpusFor: corpusFor,
  );

  static int _sum(
    Map<DateTime, DayActivity> days,
    DateTime from,
    DateTime toExclusive,
    int Function(DayActivity d) pick,
  ) {
    var sum = 0;
    days.forEach((day, activity) {
      if (!day.isBefore(from) && day.isBefore(toExclusive)) {
        sum += pick(activity);
      }
    });
    return sum;
  }

  /// Calls [bucket] for each daily (short range) or weekly (long range)
  /// bucket `[from, toExclusive)` from [start] through [end].
  static void _walk(
    DateTime start,
    DateTime end,
    void Function(DateTime from, DateTime toExclusive) bucket,
  ) {
    final step = _calendarDaysBetween(start, end) <= kChartDailyMaxDays ? 1 : 7;
    final last = _day(end);
    var current = _day(start);
    while (!current.isAfter(last)) {
      final next = _addDays(current, step);
      bucket(current, next);
      current = next;
    }
  }

  static List<T> _bucketize<T>(
    DateTime start,
    DateTime end,
    int Function(DateTime from, DateTime toExclusive) count,
    T Function(DateTime date, int count) make,
  ) {
    final out = <T>[];
    _walk(start, end, (from, to) => out.add(make(from, count(from, to))));
    return out;
  }

  /// A long range starts at its first active day (never before
  /// [requestedStart]); an inactive long range collapses to its end day.
  static DateTime _effectiveStart(
    Iterable<DateTime> activeDays,
    DateTime requestedStart,
    DateTime requestedEnd,
  ) {
    final floor = _day(requestedStart);
    if (_calendarDaysBetween(requestedStart, requestedEnd) <=
        kChartDailyMaxDays) {
      return floor;
    }
    final end = _day(requestedEnd);
    DateTime? earliest;
    for (final day in activeDays) {
      if (day.isBefore(floor) || day.isAfter(end)) continue;
      if (earliest == null || day.isBefore(earliest)) earliest = day;
    }
    return earliest ?? end;
  }

  static int _calendarDaysBetween(DateTime start, DateTime end) {
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    return (b.difference(a).inHours / 24).round();
  }

  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
