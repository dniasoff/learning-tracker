import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_points_awards_source.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/learner_progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_lens_refresh_tick_provider.dart';

part 'recent_activity_providers.freezed.dart';

/// Recent Activity drill-down providers (DNI-474): every series is the
/// active learner's counted learning from `LearnerState`, so a capture,
/// void or correction anywhere updates the charts with no extra
/// invalidation.
///
///   * Limudim + chazaros per day
///     ([ChartDataService.getDailyLimudimAndChazaros]).
///   * Cumulative distinct leaves ([ChartDataService.getCumulativeProgress]).
///   * Points earned per day ([ChartDataService.getDailyPoints]).
///   * Active days ([ChartDataService.getStreakCalendar]).
@freezed
abstract class RecentActivityWindow with _$RecentActivityWindow {
  const factory RecentActivityWindow({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) = _RecentActivityWindow;
}

final recentActivityLimudimChazarosProvider = FutureProvider.autoDispose
    .family<List<DailyLimudChazaraData>, RecentActivityWindow>((
      ref,
      window,
    ) async {
      ref.watch(progressLensRefreshTickProvider);
      final state = await watchActiveLearnerState(ref);
      final corpora = await watchCorpora(ref);
      return ref
          .watch(chartDataServiceProvider)
          .getDailyLimudimAndChazaros(
            state,
            startDate: window.startDate,
            endDate: window.endDate,
            curriculumId: window.curriculumId,
            corpusFor: (c) => corpora[c],
          );
    });

final recentActivityCumulativeProvider = FutureProvider.autoDispose
    .family<List<CumulativeProgressPoint>, RecentActivityWindow>((
      ref,
      window,
    ) async {
      ref.watch(progressLensRefreshTickProvider);
      final state = await watchActiveLearnerState(ref);
      final corpora = await watchCorpora(ref);
      return ref
          .watch(chartDataServiceProvider)
          .getCumulativeProgress(
            state,
            startDate: window.startDate,
            endDate: window.endDate,
            curriculumId: window.curriculumId,
            corpusFor: (c) => corpora[c],
          );
    });

final recentActivityStreakDatesProvider = FutureProvider.autoDispose
    .family<Set<DateTime>, RecentActivityWindow>((ref, window) async {
      ref.watch(progressLensRefreshTickProvider);
      final state = await watchActiveLearnerState(ref);
      return ref
          .watch(chartDataServiceProvider)
          .getStreakCalendar(
            state,
            startDate: window.startDate,
            endDate: window.endDate,
            curriculumId: window.curriculumId,
          );
    });

final recentActivityPointsProvider = FutureProvider.autoDispose
    .family<List<DailyPointsData>?, RecentActivityWindow>((ref, window) async {
      ref.watch(progressLensRefreshTickProvider);
      final state = await watchActiveLearnerState(ref);
      final awards = await ref.watch(progressPointsAwardsProvider.future);
      return ref
          .watch(chartDataServiceProvider)
          .getDailyPoints(
            state,
            awards: awards,
            startDate: window.startDate,
            endDate: window.endDate,
            userMode: ProfileMode.child,
            curriculumId: window.curriculumId,
          );
    });
