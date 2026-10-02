import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';

/// Track and curriculum progress over the engine's learner state — the one
/// aggregation every progress card shares (DNI-474).
///
/// * [completionPercent] is goal progress (FR-14): the engine's distinct
///   learnt leaves over the track's scoped leaf count. With `since`, only
///   leaves first learnt at or after that instant by tracked learning
///   (`dated` / `catch_up`) count.
/// * [dailyCounts] and [cumulativeProgress] bucket the engine's counted
///   learn events by their `learned_on` day.
///
/// It reads only `LearnerState`; voids, lock-ignored events and repeats are
/// already resolved by the engine.
class TrackProgressService {
  const TrackProgressService();

  /// The learnt share of [curriculumId]'s [totalItems] scoped leaves.
  double completionPercent({
    required LearnerState? state,
    required CurriculumId curriculumId,
    required int totalItems,
    DateTime? since,
  }) {
    if (totalItems <= 0 || state == null) return 0.0;
    final curriculum = state[curriculumId.storageKey];
    if (curriculum == null) return 0.0;
    if (since == null) {
      return (curriculum.distinctLearnt / totalItems).clamp(0.0, 1.0);
    }
    final first = <String, DateTime>{};
    for (final e in countedLearnsOf(
      state,
      curricula: {curriculumId.storageKey},
    )) {
      if (e.dateState == DateState.beforeTracking) continue;
      final ref = e.ref;
      if (ref == null || !curriculum.learntLeaves.contains(ref)) continue;
      first.putIfAbsent(ref, () => effectiveAt(e));
    }
    final count = first.values.where((at) => !at.isBefore(since)).length;
    return (count / totalItems).clamp(0.0, 1.0);
  }

  /// Counted learn events per local day in `[startDate, endDate]`.
  List<DailyCompletionData> dailyCounts({
    required LearnerState? state,
    required DateTime startDate,
    required DateTime endDate,
    CurriculumId? curriculumId,
  }) {
    final days = dailyActivityOf(
      state,
      curricula: curriculumId == null ? null : {curriculumId.storageKey},
    );
    final result = <DailyCompletionData>[];
    var current = _day(startDate);
    final end = _day(endDate);
    while (!current.isAfter(end)) {
      result.add(
        DailyCompletionData(date: current, count: days[current]?.events ?? 0),
      );
      current = DateTime(current.year, current.month, current.day + 1);
    }
    return result;
  }

  /// Distinct leaves newly learnt per day, cumulative over
  /// `[startDate, endDate]`.
  List<CumulativeDataPoint> cumulativeProgress({
    required LearnerState? state,
    required DateTime startDate,
    required DateTime endDate,
    CurriculumId? curriculumId,
  }) {
    final days = dailyActivityOf(
      state,
      curricula: curriculumId == null ? null : {curriculumId.storageKey},
    );
    final result = <CumulativeDataPoint>[];
    var runningTotal = 0;
    var current = _day(startDate);
    final end = _day(endDate);
    while (!current.isAfter(end)) {
      runningTotal += days[current]?.newLeaves ?? 0;
      result.add(CumulativeDataPoint(date: current, total: runningTotal));
      current = DateTime(current.year, current.month, current.day + 1);
    }
    return result;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// One point of a cumulative series.
class CumulativeDataPoint {
  const CumulativeDataPoint({required this.date, required this.total});

  final DateTime date;
  final int total;
}
