import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';

/// Provider wiring for the Recent Activity screen (engagement-tier lens).
///
/// The screen renders four data feeds, each live-only:
///  1. Limudim & Chazaros stacked bar chart
///     ([ChartDataService.getDailyLimudimAndChazaros]).
///  2. Cumulative line chart, live-only
///     ([ChartDataService.getCumulativeProgressLive]).
///  3. Points-over-time bar (child mode only)
///     ([ChartDataService.getDailyPoints], already live-only by tier policy).
///  4. Streak weekly dots / calendar
///     ([ChartDataService.getStreakCalendarLive]).
///
/// All four feeds share the same window. We pin the window into a single
/// [RecentActivityWindow] value (used as a [FutureProvider.family] key) so
/// each provider naturally memoizes per (range, curriculum, dates) without
/// the screen having to maintain ad-hoc caches in `setState`.
///
/// Provider families are `autoDispose` so off-screen disposal frees the
/// service work; rebuilding with the same key replays the cached future.

/// Identifier for a Recent Activity data window.
///
/// Equality is structural so [FutureProvider.family] memoizes per identical
/// (range, curriculum, start, end) — re-renders with the same window get the
/// cached future, switching range or curriculum gets a fresh fetch.
class RecentActivityWindow {
  final DateTime startDate;
  final DateTime endDate;
  final String? curriculumId;

  const RecentActivityWindow({
    required this.startDate,
    required this.endDate,
    this.curriculumId,
  });

  @override
  bool operator ==(Object other) =>
      other is RecentActivityWindow &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.curriculumId == curriculumId;

  @override
  int get hashCode => Object.hash(startDate, endDate, curriculumId);
}

/// Live limudim+chazaros stacked-bar data for the given window.
final recentActivityLimudimChazarosProvider = FutureProvider.autoDispose
    .family<List<DailyLimudChazaraData>, RecentActivityWindow>((
      ref,
      window,
    ) async {
      final service = ref.watch(chartDataServiceProvider);
      return service.getDailyLimudimAndChazaros(
        startDate: window.startDate,
        endDate: window.endDate,
        curriculumId: window.curriculumId,
      );
    });

/// Live cumulative-line data for the given window.
final recentActivityCumulativeProvider = FutureProvider.autoDispose
    .family<List<CumulativeProgressPoint>, RecentActivityWindow>((
      ref,
      window,
    ) async {
      final service = ref.watch(chartDataServiceProvider);
      return service.getCumulativeProgressLive(
        startDate: window.startDate,
        endDate: window.endDate,
        curriculumId: window.curriculumId,
      );
    });

/// Live streak calendar for the given window. The set contains every local
/// date in [window.startDate]..[window.endDate] that has at least one live
/// completion.
final recentActivityStreakDatesProvider = FutureProvider.autoDispose
    .family<Set<DateTime>, RecentActivityWindow>((ref, window) async {
      final service = ref.watch(chartDataServiceProvider);
      return service.getStreakCalendarLive(
        startDate: window.startDate,
        endDate: window.endDate,
      );
    });

/// Live daily-points data for the given window. The underlying service
/// returns `null` for adult mode; we forward that so the screen can
/// conditionally hide the section.
final recentActivityPointsProvider = FutureProvider.autoDispose
    .family<List<DailyPointsData>?, RecentActivityWindow>((ref, window) async {
      final service = ref.watch(chartDataServiceProvider);
      return service.getDailyPoints(
        startDate: window.startDate,
        endDate: window.endDate,
        userMode: UserMode.child,
        curriculumId: window.curriculumId,
      );
    });
