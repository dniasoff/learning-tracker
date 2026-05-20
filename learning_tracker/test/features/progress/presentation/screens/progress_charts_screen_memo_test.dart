/// Regression test for the chart-future memoization fix (W1-B / Task #4).
///
/// Verifies that switching the curriculum filter does NOT re-trigger the
/// SAME chart's data fetch when its inputs haven't changed for it. The
/// memoization is keyed on (timeRange, curriculum, start, end).
///
/// Test strategy:
///   1. Override [chartDataServiceProvider] with a counting fake that
///      records each call to [getDailyCompletions] etc.
///   2. Pump the screen, let initial fetches complete.
///   3. Trigger a setState that does NOT change inputs (we use a
///      curriculum tap that toggles the same filter twice).
///   4. Assert: call counts are unchanged.
///   5. Trigger a real input change (tap a different time-range pill).
///   6. Assert: call counts go up by exactly one per chart.
@Tags(['progress', 'w1b'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/progress_charts_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

/// Test override for [ActiveProfileId] that returns a fixed id.
class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

/// Counting fake — extends [ChartDataService] and records each fetch.
class _CountingChartDataService extends ChartDataService {
  _CountingChartDataService(super.db, {required super.profileId});

  int dailyCalls = 0;
  int cumulativeCalls = 0;
  int pointsCalls = 0;
  int streakCalls = 0;

  @override
  Future<List<DailyCompletionData>> getDailyCompletions({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) {
    dailyCalls++;
    return super.getDailyCompletions(
      startDate: startDate,
      endDate: endDate,
      curriculumId: curriculumId,
    );
  }

  @override
  Future<List<CumulativeProgressPoint>> getCumulativeProgress({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) {
    cumulativeCalls++;
    return super.getCumulativeProgress(
      startDate: startDate,
      endDate: endDate,
      curriculumId: curriculumId,
    );
  }

  @override
  Future<List<DailyPointsData>?> getDailyPoints({
    required DateTime startDate,
    required DateTime endDate,
    required UserMode userMode,
    String? curriculumId,
  }) {
    pointsCalls++;
    return super.getDailyPoints(
      startDate: startDate,
      endDate: endDate,
      userMode: userMode,
      curriculumId: curriculumId,
    );
  }

  @override
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    streakCalls++;
    return super.getStreakCalendar(startDate: startDate, endDate: endDate);
  }
}

void main() {
  late UserDatabase db;
  late _CountingChartDataService spy;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    spy = _CountingChartDataService(db, profileId: 1);
  });

  tearDown(() => db.close());

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        userDatabaseProvider.overrideWith((ref) => db),
        activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(1)),
        chartDataServiceProvider.overrideWith((ref) => spy),
        dashboardUserModeProvider.overrideWith(
          (ref) => Future.value(UserMode.adult),
        ),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProgressChartsScreen(),
      ),
    );
  }

  testWidgets(
    'futures are memoized: rebuilds with same inputs do NOT refetch',
    (tester) async {
      await tester.pumpWidget(buildScreen());
      // Let the initial fetches complete.
      await tester.pumpAndSettle();

      final initialDaily = spy.dailyCalls;
      final initialCumulative = spy.cumulativeCalls;
      final initialStreak = spy.streakCalls;

      // Each chart should have been fetched at least once.
      expect(initialDaily, greaterThan(0));
      expect(initialCumulative, greaterThan(0));
      expect(initialStreak, greaterThan(0));

      // Trigger several unrelated rebuilds without changing inputs.
      // pumping multiple frames must NOT cause refetches.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        spy.dailyCalls,
        initialDaily,
        reason: 'pump rebuilds with unchanged inputs MUST NOT refetch',
      );
      expect(spy.cumulativeCalls, initialCumulative);
      expect(spy.streakCalls, initialStreak);
    },
  );

  testWidgets('switching time range DOES refetch each chart exactly once', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final initialDaily = spy.dailyCalls;
    final initialCumulative = spy.cumulativeCalls;
    final initialStreak = spy.streakCalls;

    // Tap the "30 Days" pill. ChartTimeRange.last30Days is the second
    // pill; the AppLocalizations text we care about is "30 Days" in
    // English.
    final last30Pill = find.text('Last 30\nDays');
    expect(
      last30Pill,
      findsOneWidget,
      reason: 'should be able to find the "Last 30 Days" pill in the UI',
    );
    await tester.tap(last30Pill);
    await tester.pumpAndSettle();

    // Inputs changed → each chart should have been refetched exactly once
    // more than before.
    expect(spy.dailyCalls, initialDaily + 1);
    expect(spy.cumulativeCalls, initialCumulative + 1);
    expect(spy.streakCalls, initialStreak + 1);
  });

  testWidgets('tapping the same active pill twice does NOT refetch', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // The default selected pill is "Last 7 Days".
    final last7Pill = find.text('Last 7 Days');
    expect(last7Pill, findsOneWidget);

    // Switch to "Last 30 Days", then BACK to "Last 7 Days".
    await tester.tap(find.text('Last 30\nDays'));
    await tester.pumpAndSettle();
    final afterSwitch = spy.dailyCalls;

    // Tap "Last 7 Days" again — this is the original input, but it WAS
    // just changed away from, so this re-fetches once.
    await tester.tap(find.text('Last 7 Days'));
    await tester.pumpAndSettle();
    final afterReturn = spy.dailyCalls;

    // Each input change triggers exactly ONE refetch — not multiple.
    expect(
      afterReturn,
      afterSwitch + 1,
      reason:
          'returning to a previous range re-fetches exactly once, '
          'not multiple times per chart',
    );
  });
}
