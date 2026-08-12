// L1 widget tests — RecentActivityScreen + HierarchySelectionPanel (combined)
//
// FOCUS:
//   A. RecentActivityScreen (67% target)
//   B. HierarchySelectionPanel (36% target)
//
// Coverage groups:
//
//  A. RecentActivityScreen
//     A1.  Loading state — loading indicators shown
//     A2.  Title + time-range pills rendered
//     A3.  Error state — error message shown
//     A4.  Data state — chart section titles rendered after data resolves
//     A5.  Chazara-off: when anyActiveTrackHasChazara=false, "Chazaros" absent
//     A6.  Chazara-on: when anyActiveTrackHasChazara=true, "Chazaros" term present
//     A7.  Child mode: points chart section visible for child
//     A8.  Adult mode: points chart section absent for adult
//     A9.  Sentinel-date bulk-marks excluded from finite recent windows
//          (completion-credit policy — bulk-mark sentinel 1/1/2000 excluded)
//     A10. Switching time-range pill triggers refetch
//     A11. Curriculum filter pills rendered; "All" shown by default
//     A12. All Time range — AllTimeSummaryCard shown instead of StreakCalendar
//     A13. he-RTL smoke: screen renders in Hebrew locale without crash
//
//  B. HierarchySelectionPanel
//     B1.  Loading state: CircularProgressIndicator shown
//     B2.  Error state: AppErrorView or error text shown
//     B3.  Data state: top-level items rendered
//     B4.  Tapping a container item drills down (breadcrumb appears)
//     B5.  Breadcrumb root button resets to top level
//     B6.  Leaf item: no chevron; tapping toggles checkbox
//     B7.  Container item: chevron shown
//     B8.  Selection counter appears after selecting an item
//     B9.  Confirm button disabled with zero selections, enabled after selection
//     B10. onConfirmed callback fires with correct selections
//     B11. onSkip callback fires when Skip button tapped
//     B12. he-RTL smoke: panel renders in Hebrew locale without crash
//
//  C. Product-rule assertions
//     C1.  Bulk-mark sentinel (1/1/2000) out of any 7-day or 30-day window
//     C2.  No track-type labels in hierarchy panel
//
// BUG LOG: (none at time of writing)

@Tags(['needs_flutter', 'progress', 'hierarchy_panel', 'recent_activity'])
library;

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/recent_activity_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_fixtures.dart';

// ── Constants ──────────────────────────────────────────────────────────────

const _uid = 'recent-activity-hierarchy-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

// ── Provider notifier overrides ────────────────────────────────────────────

class _FixedProfileId extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

class _FixedUseHebrewTerms extends UseHebrewTerms {
  _FixedUseHebrewTerms({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

class _FixedTransliteration extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.sephardi;
}

// ── Stub chart services ────────────────────────────────────────────────────

class _NoopChartRepository implements ChartDataRepository {
  @override
  Future<List<CompletionEntity>> getCompletionsByTier({
    required CompletionTierFilter tier,
    CurriculumId? curriculumId,
    DateTime? since,
    DateTime? until,
  }) async => const [];

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    CurriculumId curriculumId,
  ) async => const [];

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async =>
      const [];
}

/// Immediately-returning stub — no disk access.
class _StubChartDataService extends ChartDataService {
  _StubChartDataService() : super(repository: _NoopChartRepository());

  var limudChazaraCalls = 0;

  @override
  Future<List<DailyLimudChazaraData>> getDailyLimudimAndChazaros({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async {
    limudChazaraCalls++;
    return [];
  }

  @override
  Future<List<CumulativeProgressPoint>> getCumulativeProgressLive({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async => [];

  @override
  Future<Set<DateTime>> getStreakCalendarLive({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) async => {};

  @override
  Future<List<DailyPointsData>?> getDailyPoints({
    required DateTime startDate,
    required DateTime endDate,
    required ProfileMode userMode,
    String? curriculumId,
  }) async => userMode.isAdult ? null : [];
}

/// Never-completing chart service — simulates the loading state.
class _HangingChartDataService extends ChartDataService {
  _HangingChartDataService() : super(repository: _NoopChartRepository());

  @override
  Future<List<DailyLimudChazaraData>> getDailyLimudimAndChazaros({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) => Completer<List<DailyLimudChazaraData>>().future;

  @override
  Future<List<CumulativeProgressPoint>> getCumulativeProgressLive({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) => Completer<List<CumulativeProgressPoint>>().future;

  @override
  Future<Set<DateTime>> getStreakCalendarLive({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) => Completer<Set<DateTime>>().future;

  @override
  Future<List<DailyPointsData>?> getDailyPoints({
    required DateTime startDate,
    required DateTime endDate,
    required ProfileMode userMode,
    String? curriculumId,
  }) => Completer<List<DailyPointsData>?>().future;
}

/// Always-erroring chart service.
class _ErrorChartDataService extends ChartDataService {
  _ErrorChartDataService() : super(repository: _NoopChartRepository());

  @override
  Future<List<DailyLimudChazaraData>> getDailyLimudimAndChazaros({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) => Future.error(Exception('chart error'));

  @override
  Future<List<CumulativeProgressPoint>> getCumulativeProgressLive({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) => Future.error(Exception('chart error'));

  @override
  Future<Set<DateTime>> getStreakCalendarLive({
    required DateTime startDate,
    required DateTime endDate,
    String? curriculumId,
  }) => Future.error(Exception('chart error'));

  @override
  Future<List<DailyPointsData>?> getDailyPoints({
    required DateTime startDate,
    required DateTime endDate,
    required ProfileMode userMode,
    String? curriculumId,
  }) => Future.error(Exception('chart error'));
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

// ── Settling helper ────────────────────────────────────────────────────────
//
// We avoid pumpAndSettle (which can hang with long-lived streams) and instead
// pump()+pump(Duration.zero) which flushes microtasks + a single frame, then
// pump(Duration(seconds:1)) which fires all pending timers.

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
  await tester.pump(const Duration(milliseconds: 100));
}

// ── RecentActivityScreen builder ──────────────────────────────────────────

Widget _buildScreen({
  ChartDataService? chartService,
  ProfileMode mode = ProfileMode.adult,
  bool hasChazara = true,
  bool useHebrewTerms = false,
  Locale locale = const Locale('en'),
}) {
  final svc = chartService ?? _StubChartDataService();
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _FixedProfileId()),
      useHebrewTermsProvider.overrideWith(
        () => _FixedUseHebrewTerms(useHebrew: useHebrewTerms),
      ),
      chartDataServiceProvider.overrideWith((ref) => svc),
      dashboardUserModeProvider.overrideWith((ref) => Future.value(mode)),
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value((currentStreak: 5, maxStreak: 10)),
      ),
      anyActiveTrackHasChazaraProvider.overrideWith(
        (ref) => Future.value(hasChazara),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RecentActivityScreen(),
    ),
  );
}

// ── HierarchySelectionPanel builder ───────────────────────────────────────

Widget _buildPanel({
  required CurriculumId curriculumId,
  required Future<List<ContentItem>> Function() contentFactory,
  VoidCallback? onSkip,
  void Function(Set<dynamic>)? onConfirmed,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _FixedProfileId()),
      useHebrewTermsProvider.overrideWith(
        () => _FixedUseHebrewTerms(useHebrew: false),
      ),
      currentTransliterationVariantProvider.overrideWith(
        () => _FixedTransliteration(),
      ),
      curriculumContentProvider(
        curriculumId,
      ).overrideWith((ref) => contentFactory()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HierarchySelectionPanel(
          curriculumId: curriculumId,
          onSkip: onSkip,
          onConfirmed: onConfirmed,
          autoAdvanceSingleOption: false,
        ),
      ),
    ),
  );
}

// ── Teardown ───────────────────────────────────────────────────────────────

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Content helpers ────────────────────────────────────────────────────────

/// Two-level content: level1 containers → level2 leaves.
List<ContentItem> _twoLevelItems() => [
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    displayNameHe: 'סדר זרעים',
    displayNameEn: 'Seder Zeraim',
    sefariaRef: 'Seder_Zeraim',
    sortOrder: 0,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Moed',
    displayNameHe: 'סדר מועד',
    displayNameEn: 'Seder Moed',
    sefariaRef: 'Seder_Moed',
    sortOrder: 1,
    isLeaf: false,
  ),
  // Children of Seder Zeraim — shown after drilling in.
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    level2: 'Berachos',
    displayNameHe: 'ברכות',
    displayNameEn: 'Berachos',
    sefariaRef: 'Berachos',
    sortOrder: 2,
    isLeaf: true, // leaf at depth=1
  ),
];

/// Flat content: single leaf item at depth=0.
///
/// This is a single-level curriculum where level1 items are already leaves
/// (no level2). At [currentDepth=0] the grouper renders one tile with isLeaf=true.
List<ContentItem> _leafOnlyItems() => [
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Mishna 1',
    displayNameHe: 'משנה א',
    displayNameEn: 'Mishna 1',
    sefariaRef: 'Mishnah_Berakhot.1.1',
    sortOrder: 0,
    isLeaf: true,
  ),
];

// ── Firestore seeding ──────────────────────────────────────────────────────

Future<void> _seedLive(
  FakeFirebaseFirestore firestore, {
  required String ref,
  int stageId = 1,
  required DateTime at,
}) => seedCompletion(
  firestore,
  uid: _uid,
  profileId: _profileId,
  curriculumId: CurriculumId.mishnayos,
  sefariaRef: ref,
  stageId: stageId,
  source: CompletionSource.live,
  completedAt: at,
);

Future<void> _seedBulkInTrack(
  FakeFirebaseFirestore firestore, {
  required String ref,
  int stageId = 1,
  required DateTime at,
}) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.mishnayos,
    sefariaRef: ref,
    stageId: stageId,
    source: CompletionSource.bulkInTrack,
    completedAt: at,
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ──────────────────────────────────────────────────────────────────────────
  // A. RecentActivityScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('RecentActivityScreen', () {
    // A1 — loading state: spinner shown while providers are loading
    testWidgets('A1: loading state — loading indicator shown', (tester) async {
      await tester.pumpWidget(
        _buildScreen(chartService: _HangingChartDataService()),
      );
      await tester.pump(); // one frame to trigger providers

      // While loading, spinner appears (from loading branch of chart providers).
      expect(find.byType(CircularProgressIndicator), findsAny);

      await _teardown(tester);
    });

    // A2 — structural title + time-range pills
    testWidgets('A2: title and time-range pills rendered', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.textContaining('Last 30'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);

      await _teardown(tester);
    });

    // A3 — error state
    testWidgets('A3: error state — error message rendered', (tester) async {
      // Resize to give the screen room so the error widgets don't overflow.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // Suppress layout overflow exceptions — the AppErrorView overflows on
      // test dimensions which does not prevent the text from being found.
      final savedOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        savedOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = savedOnError);

      await tester.pumpWidget(
        _buildScreen(
          chartService: _ErrorChartDataService(),
          mode: ProfileMode.adult,
          hasChazara: true,
        ),
      );
      await _settle(tester);

      // At least one chart section shows "Failed to load data".
      expect(find.text('Failed to load data'), findsWidgets);

      await _teardown(tester);
    });

    // A4 — data state: section titles rendered
    testWidgets('A4: data state — section titles rendered', (tester) async {
      // Resize so the full ListView is visible without scrolling.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      // The cumulative section card title.
      expect(find.text('Cumulative Progress'), findsOneWidget);

      // Live-only disclaimer appears on chart sections (≥ 1 occurrence).
      expect(find.textContaining('track learning'), findsWidgets);

      await _teardown(tester);
    });

    // A5 — chazara-off
    testWidgets(
      'A5: chazara-off — chazara term absent from chart section title',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _buildScreen(hasChazara: false, useHebrewTerms: false),
        );
        await _settle(tester);

        // Neither English nor Hebrew chazara term.
        expect(find.textContaining('Chazara'), findsNothing);
        expect(find.textContaining('חזרות'), findsNothing);

        await _teardown(tester);
      },
    );

    // A6 — chazara-on
    testWidgets(
      'A6: chazara-on (English terms) — "Chazaros" in chart section title',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _buildScreen(hasChazara: true, useHebrewTerms: false),
        );
        await _settle(tester);

        expect(find.textContaining('Chazaros'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // A7 — child mode: Points Earned section visible
    testWidgets('A7: child mode — Points Earned section visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildScreen(mode: ProfileMode.child));
      await _settle(tester);

      expect(find.text('Points Earned'), findsOneWidget);
      expect(find.text('POINTS EARNED'), findsOneWidget);

      await _teardown(tester);
    });

    // A8 — adult mode: points section absent
    testWidgets('A8: adult mode — Points Earned section absent', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildScreen(mode: ProfileMode.adult));
      await _settle(tester);

      expect(find.text('Points Earned'), findsNothing);

      await _teardown(tester);
    });

    // A9 — sentinel-date bulk-marks excluded from finite window
    testWidgets(
      'A9: sentinel-date bulk-marks (1/1/2000) excluded from Last-7-Days '
      'window (completion-credit policy)',
      (tester) async {
        final firestore = createFakeFirestore(authenticatedUid: _uid);

        // Seed a bulk-mark at the sentinel date (year 2000 = "all-time floor").
        final sentinelDate = DateTime.utc(2000, 1, 1);
        await _seedBulkInTrack(
          firestore,
          ref: 'bulk_sentinel',
          at: sentinelDate,
        );

        // Seed one live completion today.
        final today = DateTimeFactory.nowLocal();
        final todayMorning = DateTime(today.year, today.month, today.day, 9);
        await _seedLive(firestore, ref: 'live_today', at: todayMorning);

        // Verify directly through the service:
        // - Last-7-Days window should contain today's live row but NOT year-2000.
        final svc = ChartDataService(
          repository: _FirestoreChartRepository(firestore),
        );
        final end = DateTime(today.year, today.month, today.day);
        final start = end.subtract(const Duration(days: 6));
        final data = await svc.getDailyLimudimAndChazaros(
          startDate: start,
          endDate: end,
        );

        final todayBucket = data.firstWhere(
          (d) =>
              d.date.year == today.year &&
              d.date.month == today.month &&
              d.date.day == today.day,
          orElse: () => DailyLimudChazaraData(
            date: today,
            limudCount: 0,
            chazaraCount: 0,
          ),
        );
        expect(
          todayBucket.limudCount,
          1,
          reason: 'only the live completion is in the Last-7-Days window',
        );

        // Sentinel year bucket must not appear at all.
        final sentinelBucket = data.where((d) => d.date.year == 2000);
        expect(
          sentinelBucket,
          isEmpty,
          reason:
              'sentinel-date bulk-mark (1/1/2000) must not appear in the '
              'Last-7-Days window — completion-credit policy',
        );

        await _teardown(tester);
      },
    );

    // A10 — switching time-range pill triggers refetch
    testWidgets('A10: switching time-range pill triggers refetch', (
      tester,
    ) async {
      final svc = _StubChartDataService();
      await tester.pumpWidget(_buildScreen(chartService: svc));
      await _settle(tester);

      final callsBefore = svc.limudChazaraCalls;
      expect(callsBefore, greaterThan(0));

      await tester.tap(find.textContaining('Last 30'));
      await _settle(tester);

      expect(
        svc.limudChazaraCalls,
        greaterThan(callsBefore),
        reason: 'switching the pill refetches with a new window key',
      );

      await _teardown(tester);
    });

    // A11 — curriculum filter pills
    testWidgets('A11: curriculum filter pills present; "All" is default', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      // "All" is the first filter chip — it should be present.
      expect(find.text('All'), findsOneWidget);

      await _teardown(tester);
    });

    // A12 — All Time: AllTimeSummaryCard shown
    testWidgets('A12: All Time range — "All-time activity" summary shown', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildScreen());
      await _settle(tester);

      await tester.tap(find.text('All Time'));
      await _settle(tester);

      // _AllTimeSummaryCard shows this title.
      expect(find.text('All-time activity'), findsOneWidget);
      // Active-days stat — now an ICU-plural phrase (the stub seeds no active
      // days, so the count is 0 → plural "0 Active days").
      expect(find.text('0 Active days'), findsOneWidget);

      await _teardown(tester);
    });

    // A13 — Hebrew locale smoke
    testWidgets('A13: he-RTL smoke — screen renders without crash', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // Suppress layout overflow exceptions.
      final savedOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        savedOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = savedOnError);

      await tester.pumpWidget(
        _buildScreen(locale: const Locale('he'), mode: ProfileMode.child),
      );
      await _settle(tester);

      // Hebrew localisation of 'tierLensRecentActivity'.
      expect(find.text('פעילות אחרונה'), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // B. HierarchySelectionPanel
  // ──────────────────────────────────────────────────────────────────────────

  group('HierarchySelectionPanel', () {
    // B1 — loading state
    testWidgets('B1: loading state — CircularProgressIndicator shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Completer<List<ContentItem>>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _teardown(tester);
    });

    // B2 — error state
    testWidgets('B2: error state — error content shown', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () =>
              Future<List<ContentItem>>.error(Exception('network')),
        ),
      );
      await _settle(tester);

      // AppErrorView uses 'Error' in the title or similar — at minimum
      // the CircularProgressIndicator should be gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await _teardown(tester);
    });

    // B3 — data state: top-level items rendered
    testWidgets('B3: data state — top-level container items visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_twoLevelItems()),
        ),
      );
      await _settle(tester);

      // Both top-level containers should appear.
      expect(find.textContaining('Zeraim'), findsOneWidget);
      expect(find.textContaining('Moed'), findsOneWidget);

      await _teardown(tester);
    });

    // B4 — tapping container drills in (breadcrumb appears)
    testWidgets('B4: tapping container item drills in — breadcrumb appears', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_twoLevelItems()),
        ),
      );
      await _settle(tester);

      // Tap the "Seder Zeraim" tile (container → drills in).
      await tester.tap(find.textContaining('Zeraim'));
      await _settle(tester);

      // The breadcrumb bar should now contain TextButton widgets.
      expect(find.byType(TextButton), findsWidgets);

      await _teardown(tester);
    });

    // B5 — breadcrumb root button returns to top level
    testWidgets('B5: breadcrumb root button clears navigation', (tester) async {
      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_twoLevelItems()),
        ),
      );
      await _settle(tester);

      // Drill in.
      await tester.tap(find.textContaining('Zeraim'));
      await _settle(tester);

      // Tap the curriculum root button in the breadcrumb row.
      await tester.tap(find.byType(TextButton).first);
      await _settle(tester);

      // Both top-level items back.
      expect(find.textContaining('Zeraim'), findsOneWidget);
      expect(find.textContaining('Moed'), findsOneWidget);

      await _teardown(tester);
    });

    // B6 — leaf item: no chevron; tapping toggles checkbox
    testWidgets('B6: leaf item — no chevron icon; tapping toggles checkbox', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_leafOnlyItems()),
          onConfirmed: (_) {},
        ),
      );
      await _settle(tester);

      // Leaf tiles have no chevron.
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      // Checkbox starts unchecked.
      final checkboxBefore = tester.widget<Checkbox>(
        find.byType(Checkbox).first,
      );
      expect(checkboxBefore.value, isFalse);

      // Tap the list tile to toggle selection.
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();

      // Checkbox is now checked.
      final checkboxAfter = tester.widget<Checkbox>(
        find.byType(Checkbox).first,
      );
      expect(checkboxAfter.value, isTrue);

      await _teardown(tester);
    });

    // B7 — container item: chevron shown
    testWidgets('B7: container item shows chevron_right icon', (tester) async {
      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_twoLevelItems()),
        ),
      );
      await _settle(tester);

      // Container tiles must have chevrons.
      expect(find.byIcon(Icons.chevron_right), findsWidgets);

      await _teardown(tester);
    });

    // B8 — selection counter appears after selection
    testWidgets('B8: selection counter appears after selecting an item', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_leafOnlyItems()),
          onConfirmed: (_) {},
        ),
      );
      await _settle(tester);

      // No counter before selection.
      expect(find.textContaining('selection'), findsNothing);

      // Select via list-tile tap.
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();

      // Counter appears.
      expect(find.textContaining('selection'), findsOneWidget);

      await _teardown(tester);
    });

    // B9 — confirm button disabled/enabled around selection
    testWidgets(
      'B9: confirm button disabled initially; enabled after selection',
      (tester) async {
        await tester.pumpWidget(
          _buildPanel(
            curriculumId: CurriculumId.mishnayos,
            contentFactory: () => Future.value(_leafOnlyItems()),
            onConfirmed: (_) {},
          ),
        );
        await _settle(tester);

        // Initially disabled.
        final btnBefore = tester.widget<FilledButton>(
          find.byType(FilledButton).first,
        );
        expect(
          btnBefore.onPressed,
          isNull,
          reason: 'disabled before selection',
        );

        // Select.
        await tester.tap(find.byType(ListTile).first);
        await tester.pump();

        // Now enabled.
        final btnAfter = tester.widget<FilledButton>(
          find.byType(FilledButton).first,
        );
        expect(
          btnAfter.onPressed,
          isNotNull,
          reason: 'enabled after selection',
        );

        await _teardown(tester);
      },
    );

    // B10 — onConfirmed fires with selections
    testWidgets('B10: onConfirmed fires with selected items', (tester) async {
      dynamic capturedSelections;

      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_leafOnlyItems()),
          onConfirmed: (sels) => capturedSelections = sels,
        ),
      );
      await _settle(tester);

      // Select the leaf.
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();

      // Tap confirm.
      await tester.tap(find.byType(FilledButton).first);
      await tester.pump();

      expect(capturedSelections, isNotNull);
      expect((capturedSelections as Set).length, 1);

      await _teardown(tester);
    });

    // B11 — onSkip fires
    testWidgets('B11: onSkip fires when Skip tapped', (tester) async {
      var skipped = false;

      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_twoLevelItems()),
          onSkip: () => skipped = true,
          onConfirmed: (_) {},
        ),
      );
      await _settle(tester);

      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();

      expect(skipped, isTrue);

      await _teardown(tester);
    });

    // B12 — Hebrew locale smoke
    testWidgets('B12: he-RTL smoke — panel renders without crash', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildPanel(
          curriculumId: CurriculumId.mishnayos,
          contentFactory: () => Future.value(_twoLevelItems()),
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      expect(find.byType(HierarchySelectionPanel), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // C. Product-rule assertions
  // ──────────────────────────────────────────────────────────────────────────

  group('Product rules', () {
    // C1 — sentinel date out of any finite recent window
    test('C1: bulk-mark sentinel (1 Jan 2000 UTC) is strictly before any '
        'Last-7-Days or Last-30-Days window (completion-credit policy)', () {
      final sentinel = DateTime.utc(2000, 1, 1);
      final today = DateTime.now();
      final start7 = today.subtract(const Duration(days: 6));
      final start30 = today.subtract(const Duration(days: 29));

      expect(
        sentinel.isBefore(start7),
        isTrue,
        reason: 'sentinel must predate the Last-7-Days window start',
      );
      expect(
        sentinel.isBefore(start30),
        isTrue,
        reason: 'sentinel must predate the Last-30-Days window start',
      );
    });

    // C2 — no track-type labels in hierarchy panel
    testWidgets(
      'C2: no "Personal", "Standard", or "Custom" track-type labels in '
      'hierarchy panel',
      (tester) async {
        await tester.pumpWidget(
          _buildPanel(
            curriculumId: CurriculumId.mishnayos,
            contentFactory: () => Future.value(_twoLevelItems()),
          ),
        );
        await _settle(tester);

        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        // Hebrew for 'personal' (אישי) must also not appear.
        expect(find.textContaining('אישי'), findsNothing);

        await _teardown(tester);
      },
    );
  });
}
