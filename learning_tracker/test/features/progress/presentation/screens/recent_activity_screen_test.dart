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

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show ActiveProfileDocId, activeProfileDocIdProvider;
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/recent_activity_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/limudim_chazaros_bar_chart.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'recent-activity-screen-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) =>
    AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _uid,
    );

/// Test override for [ActiveProfileId] that returns a fixed id.
class _ProfileIdOverride extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

class _ActiveProfileDocIdOverride extends ActiveProfileDocId {
  @override
  String? build() => _profileId;
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
  _SpyChartDataService(ChartDataRepository repository)
    : super(repository: repository);

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

class _FirestoreChartRepository implements ChartDataRepository {
  _FirestoreChartRepository(FakeFirebaseFirestore firestore)
    : _completions = FirestoreCompletionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      ),
      _goals = FirestoreGoalRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );

  final FirestoreCompletionRepository _completions;
  final FirestoreGoalRepository _goals;

  @override
  Future<List<CompletionEntity>> getCompletionsByTier({
    required CompletionTierFilter tier,
    CurriculumId? curriculumId,
    DateTime? since,
    DateTime? until,
  }) => _completions.getCompletionsByTier(
    tier: tier,
    curriculumId: curriculumId,
    since: since,
    until: until,
  );

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    CurriculumId curriculumId,
  ) => _completions.getCompletionsForCurriculum(curriculumId);

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) =>
      _goals.getGoals(curriculumId);
}

Future<int> _seedLive(
  FakeFirebaseFirestore firestore, {
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.mishnayos,
    sefariaRef: ref,
    stageId: stageId,
    completedAt: at,
    source: CompletionSource.live,
  );
  return 0;
}

Future<void> _seedBulkInTrack(
  FakeFirebaseFirestore firestore, {
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.mishnayos,
    sefariaRef: ref,
    stageId: stageId,
    completedAt: at,
    source: CompletionSource.bulkInTrack,
  );
}

Future<void> _seedLifetimeOnly(
  FakeFirebaseFirestore firestore, {
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await seedLedgerEntry(
    firestore,
    uid: _uid,
    profileId: _profileId,
    ulid: '01ARZ3NDEKTSV4RRFFQ69G5FB0',
    curriculumId: CurriculumId.mishnayos,
    entryScope: 'item',
    unitIdentifier: ref,
    unitDisplayNameEn: ref,
    completedAt: at,
    source: CompletionSource.lifetimeOnly,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _SpyChartDataService spy;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    spy = _SpyChartDataService(_FirestoreChartRepository(firestore));
  });

  tearDown(() {});

  Widget buildScreen({bool useHebrewTerms = false, bool hasChazara = true}) =>
      ProviderScope(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
          activeProfileDocIdProvider.overrideWith(
            () => _ActiveProfileDocIdOverride(),
          ),
          activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
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
          // The screen now hides the chazara term from chart titles + the
          // all-time tile when no active track has chazara stages
          // (per-track chazara rule). Default the override to true so
          // existing assertions exercise the chazara-on path; tests that
          // need the chazara-off path pass `hasChazara: false`.
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
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Title from `tierLensRecentActivity` (English default with the
    // override in [buildScreen]).
    expect(find.text('Recent Activity'), findsOneWidget);

    // Bug 2: the two charts now carry DISTINCT subtitles. The live-only scope
    // disclaimer sits on the Limudim & Chazaros bar chart ONLY (post-tier-
    // unification copy: counts track learning, live + bulk-mark) — it must
    // appear exactly once, not be duplicated onto the cumulative chart.
    expect(
      find.text(
        'Counts track learning (live + bulk-mark). Lifetime-only imports '
        'appear under Lifetime Knowledge.',
      ),
      findsOneWidget,
    );

    // The cumulative chart has its own accurate subtitle describing what its
    // running line plots. It sits lower in the lazily-built ListView, so
    // scroll it into view before asserting.
    final cumulativeSubtitle = find.text('Total completions over time');
    await tester.scrollUntilVisible(
      cumulativeSubtitle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(cumulativeSubtitle, findsOneWidget);

    // Limud/Chazaros title is built from the toggle-aware terms (English
    // default): "Limud & Chazaros".
    expect(find.text('Limud & Chazaros'), findsOneWidget);
  });

  testWidgets('live + bulkInTrack are both included; lifetimeOnly is NOT', (
    tester,
  ) async {
    // Seed three completions today (so the default "Last 7 Days" window
    // includes them):
    //   - 1 live (stage 1) on today @ 10:00 — counts.
    //   - 1 bulkInTrack on today @ 11:00 — counts (track learning).
    //   - 1 lifetimeOnly on today @ 12:00 — does NOT count (outside the
    //     track-learning tier; surfaces under Lifetime Knowledge instead).
    //
    // Track-learning rule (2026-05-21): everything except points and
    // streak treats live + bulk-mark in-track as one source.
    //
    // Note on the bulk-mark date: production bulk-mark stamps `1/1/2000`
    // (sentinel) so bulk items naturally fall outside finite recent
    // windows; this test deliberately seeds the bulkInTrack row with
    // `bulkAt` (today) so the date-windowed query exercises the tier
    // filter rather than the date filter — that's the regression we
    // care about: the SQL filter must NOT exclude bulkInTrack by source.
    //
    // F16: Route through `DateTimeFactory.nowLocal()` so the seed clock
    // matches the production screen's clock when a future test pumps a
    // frozen clock via `useLocalDayClock`.
    final today = DateTimeFactory.nowLocal();
    final liveAt = DateTime(today.year, today.month, today.day, 10);
    final bulkAt = DateTime(today.year, today.month, today.day, 11);
    final lifetimeAt = DateTime(today.year, today.month, today.day, 12);

    await _seedLive(firestore, ref: 'live_a', stageId: 1, at: liveAt);
    await _seedBulkInTrack(firestore, ref: 'bulk_a', stageId: 1, at: bulkAt);
    await _seedLifetimeOnly(
      firestore,
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

    // Bar reflects live + bulkInTrack; lifetimeOnly is dropped by the
    // trackAchievement tier filter on the underlying service.
    expect(
      todayBucket.limudCount,
      2,
      reason: 'one live + one bulkInTrack stage-1 mark today',
    );
    expect(todayBucket.chazaraCount, 0);
    expect(todayBucket.total, 2);
  });

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
    },
  );

  testWidgets(
    'All Time active-days uses singular ICU plural when exactly one day is active',
    (tester) async {
      // Finding #5: "1 Active days" was a static plural. With the ICU-plural
      // fix a single active day must read "1 Active day" (singular).
      final today = DateTimeFactory.nowLocal();
      final at = DateTime(today.year, today.month, today.day, 9);
      await _seedLive(firestore, ref: 'live_one', stageId: 1, at: at);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Switch to the All Time range so the summary card (with the active-days
      // tile) renders instead of the calendar grid.
      final allTimePill = find.text('All Time');
      expect(allTimePill, findsOneWidget);
      await tester.tap(allTimePill);
      await tester.pumpAndSettle();

      // Singular phrase — NOT the static "1 Active days".
      expect(find.text('1 Active day'), findsOneWidget);
      expect(find.text('1 Active days'), findsNothing);
    },
  );

  testWidgets(
    'empty filtered window shows an explicit empty-state message (not a blank chart)',
    (tester) async {
      // Finding #6: with no live completions in the window the charts render a
      // zeroed/blank axis. The empty-state copy must be shown instead.
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // The localized empty-state appears (both the bar + cumulative bodies
      // render it, so at least one is present).
      expect(
        find.text('No learning activity in this range yet.'),
        findsWidgets,
      );
      // The zeroed bar chart must NOT be shown for an empty window.
      expect(find.byType(LimudimChazarosBarChart), findsNothing);
    },
  );

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
    final last30Pill = find.text('Last 30 Days');
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
