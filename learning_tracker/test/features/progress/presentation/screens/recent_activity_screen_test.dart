/// Widget tests for the Recent Activity screen over the engine's
/// LearnerState (DNI-474).
///
/// Verifies:
///   - Screen renders the engagement-tier title (`tierLensRecentActivity`)
///     and the Limudim & Chazaros disclaimer.
///   - Bar-chart data is the engine's counted learning by `learned_on` day:
///     dated and catch-up learning today counts; a before-tracking mark has
///     no day; a voided event drops out; a repeat is a chazara.
///   - Switching the time-range pill triggers a fresh fetch.
@Tags(['progress', 'recent_activity'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_points_awards_source.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/recent_activity_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/limudim_chazaros_bar_chart.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

/// Pins the Hebrew Terms toggle so tests can assert English-default labels.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

/// Counting spy over the real [ChartDataService].
class _SpyChartDataService extends ChartDataService {
  _SpyChartDataService();

  int limudChazaraCalls = 0;

  @override
  List<DailyLimudChazaraData> getDailyLimudimAndChazaros(
    LearnerState? state, {
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
    Corpus? Function(String curriculumId)? corpusFor,
  }) {
    limudChazaraCalls++;
    return super.getDailyLimudimAndChazaros(
      state,
      startDate: startDate,
      endDate: endDate,
      curriculumId: curriculumId,
      corpusFor: corpusFor,
    );
  }
}

String _civil(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  late _SpyChartDataService spy;
  final today = DateTimeFactory.nowLocal();
  final todayCivil = _civil(today);

  setUp(() => spy = _SpyChartDataService());

  Widget buildScreen(
    List<LearningEvent> events, {
    bool useHebrewTerms = false,
    bool hasChazara = true,
  }) => ProviderScope(
    overrides: [
      ...progressOverrides(progressState(events)),
      progressPointsAwardsProvider.overrideWith((ref) async => const []),
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: useHebrewTerms),
      ),
      chartDataServiceProvider.overrideWith((ref) => spy),
      dashboardUserModeProvider.overrideWith(
        (ref) => Future.value(ProfileMode.adult),
      ),
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value((currentStreak: 3, maxStreak: 7)),
      ),
      anyActiveTrackHasChazaraProvider.overrideWith(
        (ref) => Future.value(hasChazara),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RecentActivityScreen(),
    ),
  );

  testWidgets('renders Recent Activity title + track-learning disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(const []));
    await tester.pumpAndSettle();

    expect(find.text('Recent Activity'), findsOneWidget);
    expect(
      find.text(
        'Counts track learning (live + bulk-mark). Lifetime-only imports '
        'appear under Lifetime Knowledge.',
      ),
      findsOneWidget,
    );
    final cumulativeSubtitle = find.text('Total completions over time');
    await tester.scrollUntilVisible(
      cumulativeSubtitle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(cumulativeSubtitle, findsOneWidget);
    expect(find.text('Limud & Chazaros'), findsOneWidget);
  });

  testWidgets("today's counted learning is charted by learned_on: dated and "
      'catch-up count, a repeat is a chazara, before-tracking has no day, a '
      'void drops out', (tester) async {
    await tester.pumpWidget(
      buildScreen([
        progressGround(1, 'Mishnah Shabbat', 'masechta'),
        progressLearn(2, 'Mishnah Peah 1:1', minutes: 1, learnedOn: todayCivil),
        engineLearn(
          3,
          'Mishnah Peah 1:2',
          minutes: 2,
          learnedOn: todayCivil,
          dateState: DateState.catchUp,
        ),
        progressLearn(4, 'Mishnah Peah 1:1', minutes: 3, learnedOn: todayCivil),
        progressLearn(
          5,
          'Mishnah Berakhot 1:1',
          minutes: 4,
          learnedOn: todayCivil,
        ),
        engineVoid(6, 5, minutes: 5),
      ]),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LimudimChazarosBarChart>(
      find.byType(LimudimChazarosBarChart),
    );
    final todayBucket = chart.data.firstWhere(
      (d) =>
          d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day,
    );
    expect(todayBucket.limudCount, 2);
    expect(todayBucket.chazaraCount, 1);
  });

  testWidgets(
    'Hebrew Terms toggle swaps domain terms (chart title) but NOT structural title',
    (tester) async {
      await tester.pumpWidget(buildScreen(const [], useHebrewTerms: true));
      await tester.pumpAndSettle();

      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('פעילות אחרונה'), findsNothing);
      expect(find.text('לימוד & חזרות'), findsOneWidget);
    },
  );

  testWidgets(
    'All Time active-days uses singular ICU plural when exactly one day is active',
    (tester) async {
      await tester.pumpWidget(
        buildScreen([
          progressLearn(1, 'Mishnah Peah 1:1', learnedOn: todayCivil),
        ]),
      );
      await tester.pumpAndSettle();

      final allTimePill = find.text('All Time');
      expect(allTimePill, findsOneWidget);
      await tester.tap(allTimePill);
      await tester.pumpAndSettle();

      expect(find.text('1 Active day'), findsOneWidget);
      expect(find.text('1 Active days'), findsNothing);
    },
  );

  testWidgets(
    'empty filtered window shows an explicit empty-state message (not a blank chart)',
    (tester) async {
      await tester.pumpWidget(buildScreen(const []));
      await tester.pumpAndSettle();

      expect(
        find.text('No learning activity in this range yet.'),
        findsWidgets,
      );
      expect(find.byType(LimudimChazarosBarChart), findsNothing);
    },
  );

  testWidgets('switching time-range pill triggers a fresh chart fetch', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(const []));
    await tester.pumpAndSettle();

    final initialCalls = spy.limudChazaraCalls;
    expect(initialCalls, greaterThan(0));

    final last30Pill = find.text('Last 30 Days');
    expect(last30Pill, findsOneWidget);
    await tester.tap(last30Pill);
    await tester.pumpAndSettle();

    expect(spy.limudChazaraCalls, greaterThan(initialCalls));
  });
}
