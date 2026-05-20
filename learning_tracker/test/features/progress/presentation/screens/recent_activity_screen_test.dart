/// Widget tests for the new Recent Activity screen (W3-A / Task #9).
///
/// Verifies:
///   - Screen renders the engagement-tier title via the new domainTermLabels
///     wiring (`tierLensRecentActivity`).
///   - The Limudim & Chazaros subtitle is the new disclaimer
///     (`recentActivityLiveOnlyDisclaimer`), pinning the live-only contract.
///   - Bar-chart data is live-only: a live completion is reflected; a
///     bulkInTrack completion and a lifetimeOnly completion are NOT.
///   - Switching the time-range pill triggers a fresh fetch on the
///     stacked-bar chart provider (memoization is keyed on the window).
@Tags(['progress', 'recent_activity'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/recent_activity_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/limudim_chazaros_bar_chart.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumId = 'mishnayos';

/// Test override for [ActiveProfileId] that returns a fixed id.
class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

/// Pins the Hebrew Terms toggle to a known value so tests can assert against
/// the English-default labels (the toggle in production reads from
/// `hebrewTermsPreferenceProvider` which defaults to Hebrew in some test
/// environments).
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

/// Counting spy — wraps a real [ChartDataService] and records every call to
/// [getDailyLimudimAndChazaros] so the time-range test can assert that
/// switching the range refetches exactly once.
class _SpyChartDataService extends ChartDataService {
  _SpyChartDataService(super.db, {required super.profileId});

  int limudChazaraCalls = 0;

  @override
  Future<List<DailyLimudChazaraData>> getDailyLimudimAndChazaros({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) {
    limudChazaraCalls++;
    return super.getDailyLimudimAndChazaros(
      startDate: startDate,
      endDate: endDate,
      curriculumId: curriculumId,
    );
  }
}

Future<int> _seedLive(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
  required DateTime at,
}) {
  return db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
}

Future<void> _seedBulkInTrack(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      source: 'bulkInTrack',
    ),
  ]);
}

Future<void> _seedLifetimeOnly(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      source: 'lifetimeOnly',
    ),
  ]);
}

void main() {
  late UserDatabase db;
  late _SpyChartDataService spy;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumId,
    );
    spy = _SpyChartDataService(db, profileId: _profileId);
  });

  tearDown(() => db.close());

  Widget buildScreen({bool useHebrewTerms = false}) => ProviderScope(
        overrides: [
          userDatabaseProvider.overrideWith((ref) => db),
          activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(1)),
          useHebrewTermsProvider.overrideWith(
            () => _UseHebrewTermsOverride(useHebrew: useHebrewTerms),
          ),
          chartDataServiceProvider.overrideWith((ref) => spy),
          dashboardUserModeProvider.overrideWith(
            (ref) => Future.value(UserMode.adult),
          ),
          dashboardStreakProvider.overrideWith(
            (ref) => Stream.value((currentStreak: 3, maxStreak: 7)),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecentActivityScreen(),
        ),
      );

  testWidgets('renders engagement-tier title + live-only disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Title from `tierLensRecentActivity` (English default with the
    // override in [buildScreen]).
    expect(find.text('Recent Activity'), findsOneWidget);

    // Disclaimer used on both the limud+chazara bar chart and the cumulative
    // chart card — so it appears at least once.
    expect(
      find.text(
        'Live learning only — bulk-marked items appear under Lifetime '
        'Knowledge.',
      ),
      findsWidgets,
    );

    // Limud/Chazaros title is built from the toggle-aware terms (English
    // default): "Limud & Chazaros".
    expect(find.text('Limud & Chazaros'), findsOneWidget);
  });

  testWidgets(
    'live completion is included; bulkInTrack + lifetimeOnly are NOT',
    (tester) async {
      // Seed three completions today (so the default "Last 7 Days" window
      // includes them):
      //   - 1 live (stage 1) on today @ 10:00.
      //   - 1 bulkInTrack on today @ 11:00 (must NOT show on bar chart).
      //   - 1 lifetimeOnly on today @ 12:00 (must NOT show on bar chart).
      //
      // F16: Route through `DateTimeFactory.nowLocal()` so the seed clock
      // matches the production screen's clock when a future test pumps a
      // frozen clock via `useLocalDayClock`. The previous `DateTime.now()`
      // call read the system clock directly, leaving open the possibility
      // of seed/production divergence in a clock-injected test.
      final today = DateTimeFactory.nowLocal();
      final liveAt = DateTime(today.year, today.month, today.day, 10);
      final bulkAt = DateTime(today.year, today.month, today.day, 11);
      final lifetimeAt = DateTime(today.year, today.month, today.day, 12);

      await _seedLive(
        db,
        trackId: trackId,
        ref: 'live_a',
        stageId: 1,
        at: liveAt,
      );
      await _seedBulkInTrack(
        db,
        trackId: trackId,
        ref: 'bulk_a',
        stageId: 1,
        at: bulkAt,
      );
      await _seedLifetimeOnly(
        db,
        trackId: trackId,
        ref: 'lifetime_a',
        stageId: 1,
        at: lifetimeAt,
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Drill down into the LimudimChazarosBarChart to inspect the data
      // actually wired through to the widget — guarantees we are checking
      // what the user sees, not the spy.
      final chartFinder = find.byType(LimudimChazarosBarChart);
      expect(chartFinder, findsOneWidget);
      final chart = tester.widget<LimudimChazarosBarChart>(chartFinder);
      final todayBucket = chart.data.firstWhere(
        (d) =>
            d.date.year == today.year &&
            d.date.month == today.month &&
            d.date.day == today.day,
      );

      // Bar reflects the single live mark — bulkInTrack & lifetimeOnly are
      // dropped by the live-only tier filter on the underlying service.
      expect(
        todayBucket.limudCount,
        1,
        reason: 'one live stage-1 mark today',
      );
      expect(todayBucket.chazaraCount, 0);
      expect(todayBucket.total, 1);
    },
  );

  testWidgets(
      'Hebrew Terms toggle swaps domain terms (chart title) but NOT structural title',
      (tester) async {
    // "Recent Activity" is a structural string per product-rules.md Rule 1 —
    // it follows UI locale only and must never change with the Hebrew Terms setting.
    await tester.pumpWidget(buildScreen(useHebrewTerms: true));
    await tester.pumpAndSettle();

    // Structural title must remain in UI locale (English) regardless of Hebrew Terms.
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('פעילות אחרונה'), findsNothing);

    // Domain terms inside the screen DO change: chart section title switches
    // to Hebrew script when the toggle is ON.
    expect(find.text('לימוד & חזרות'), findsOneWidget);
  });

  testWidgets('switching time-range pill triggers a fresh chart fetch', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final initialCalls = spy.limudChazaraCalls;
    expect(
      initialCalls,
      greaterThan(0),
      reason: 'initial render fetches the stacked feed once',
    );

    // Tap "Last 30 Days" pill — switches the window, must refetch.
    final last30Pill = find.text('Last 30\nDays');
    expect(last30Pill, findsOneWidget);
    await tester.tap(last30Pill);
    await tester.pumpAndSettle();

    expect(
      spy.limudChazaraCalls,
      greaterThan(initialCalls),
      reason: 'changing the time range refetches the stacked feed',
    );
  });
}
