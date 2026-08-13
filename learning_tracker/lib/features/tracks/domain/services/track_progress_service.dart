import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart'
    show ChartDataRepository;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// Single source of truth for all track and curriculum progress aggregation.
///
/// Replaces the four divergent aggregators that previously answered
/// "how much has the user learned?" with inconsistent semantics:
///
/// - `dashboardTrackCompletionPercentageProvider` (all-time, multi-stage)
/// - `trackDualProgressMetricsProvider.currentCyclePercentage` (time-gated)
/// - `CurriculumProgressService.computeCompletionPercentage` (no stage gate)
/// - `ParentDashboardAggregator.computeCompletionPercentage` (wrong formula)
///
/// Every public method accepts an explicit [CompletionTierFilter] so callers
/// declare their intent rather than accidentally inheriting the wrong rows.
///
/// ### Tier semantics
///
/// | Tier              | Includes                   | Used for                      |
/// |────────────────── |────────────────────────────|───────────────────────────── |
/// | [liveOnly]        | live only                  | streak, points, charts        |
/// | [trackAchievement]| live + bulkInTrack         | Manage Tracks, siyumim        |
/// | [lifetime]        | live + bulkInTrack + etc.  | lifetime views                |
///
/// ## Firestore read seam
///
/// Takes [ChartDataRepository] rather than resolving Firestore itself —
/// AD-23/AD-28 forbid `lib/features/**/domain/**` from importing the data
/// ring at all. Reuses the SAME interface [ChartDataService] already reads
/// through (`chart_data_service.dart`) rather than declaring a second,
/// near-identical one: its `getCompletionsByTier` already carries exactly
/// the D-E contract this service needs (achievement-shaped — throws when
/// the backend is not ready, so a not-ready read can never masquerade as
/// "zero progress"). See `features/tracks/presentation/providers/
/// track_progress_providers.dart` for where the concrete
/// `FirestoreChartDataRepositoryAdapter` is constructed.
class TrackProgressService {
  const TrackProgressService({
    required ChartDataRepository repository,
    required StageDefinitionRepository stageRepo,
  }) : _repository = repository,
       _stageRepo = stageRepo;

  final ChartDataRepository _repository;
  final StageDefinitionRepository _stageRepo;

  // ── Completion-percent ────────────────────────────────────────────────────

  /// Fraction of track items where ALL required stages are complete,
  /// filtered to [tier].
  ///
  /// - [requireAllStages] `true` (default) — "fully done" means every required
  ///   stage has a completion. Set to `false` for a distinct-refs-only count
  ///   (any completion at any stage counts the item).
  /// - [since] — optional lower bound on `completedAt`; pass
  ///   `track.activatedAt` for a cycle-aware calculation.
  /// - [totalItems] — denominator. Pass the scoped leaf-item count for the
  ///   curriculum; if omitted or 0 the method returns 0.0.
  Future<double> completionPercent({
    required CurriculumId curriculumId,
    required CompletionTierFilter tier,
    required int totalItems,
    bool requireAllStages = true,
    DateTime? since,
  }) async {
    if (totalItems == 0) return 0.0;

    final stages = await _stageRepo.getStagesForCurriculum(curriculumId);
    if (stages.isEmpty) return 0.0;

    final completions = await _repository.getCompletionsByTier(
      tier: tier,
      curriculumId: curriculumId,
      since: since,
    );

    if (completions.isEmpty) return 0.0;

    if (!requireAllStages) {
      // Distinct-refs only: count any item that appears at least once.
      final doneRefs = completions.map((c) => c.sefariaRef).toSet();
      return (doneRefs.length / totalItems).clamp(0.0, 1.0);
    }

    // Multi-stage gate: item "done" iff every required stageOrder is present.
    final requiredStageOrders = stages.map((s) => s.stageOrder).toSet();
    final completedStagesByRef = <String, Set<int>>{};
    final lifetimeOnlyRefs = <String>{};
    for (final c in completions) {
      completedStagesByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
      if (c.source == CompletionSource.lifetimeOnly) {
        lifetimeOnlyRefs.add(c.sefariaRef);
      }
    }

    final doneItems = completedStagesByRef.entries
        .where(
          (entry) =>
              lifetimeOnlyRefs.contains(entry.key) ||
              requiredStageOrders.every(entry.value.contains),
        )
        .length;

    return (doneItems / totalItems).clamp(0.0, 1.0);
  }

  // ── Daily counts ──────────────────────────────────────────────────────────

  /// Per-day completion counts within [startDate, endDate] inclusive,
  /// filtered to [tier].
  ///
  /// Returns one [DailyCompletionData] per calendar day in the range,
  /// even if the count is zero.
  Future<List<DailyCompletionData>> dailyCounts({
    required CompletionTierFilter tier,
    required DateTime startDate,
    required DateTime endDate,
    CurriculumId? curriculumId,
  }) async {
    final completions = await _repository.getCompletionsByTier(
      tier: tier,
      curriculumId: curriculumId,
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

  // ── Cumulative progress ───────────────────────────────────────────────────

  /// Running total of completions up to each day in [startDate, endDate],
  /// filtered to [tier].
  ///
  /// The running total starts from 0 at [startDate] (completions before the
  /// range are NOT included in the baseline — the chart plots live activity
  /// only in the chosen window).
  Future<List<CumulativeDataPoint>> cumulativeProgress({
    required CompletionTierFilter tier,
    required DateTime startDate,
    required DateTime endDate,
    CurriculumId? curriculumId,
  }) async {
    final completions = await _repository.getCompletionsByTier(
      tier: tier,
      curriculumId: curriculumId,
    );

    final dailyCounts = <DateTime, int>{};
    for (final c in completions) {
      final localDate = _extractLocalDate(c.completedAt);
      if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate)) {
        dailyCounts[localDate] = (dailyCounts[localDate] ?? 0) + 1;
      }
    }

    final result = <CumulativeDataPoint>[];
    var runningTotal = 0;
    var current = startDate;
    while (!current.isAfter(endDate)) {
      runningTotal += dailyCounts[current] ?? 0;
      result.add(CumulativeDataPoint(date: current, total: runningTotal));
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static DateTime _extractLocalDate(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// A point on the cumulative-progress curve.
class CumulativeDataPoint {
  const CumulativeDataPoint({required this.date, required this.total});

  final DateTime date;
  final int total;
}
