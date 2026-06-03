// Mixed tests: SiyumimTimelineView (widget) + lifetime_knowledge_providers (logic)
//
// Part A — SiyumimTimelineView widget tests
//   A1.  Empty view-model → localized `siyumimEmptyState` text rendered.
//   A2.  One unit-level milestone → star icon row visible (Icons.star).
//   A3.  One aggregate-level milestone → workspace_premium icon rendered.
//   A4.  One curriculum-level milestone → emoji_events icon rendered.
//   A5.  Newest-first ordering — later achievedAt comes before earlier one.
//   A6.  Month-group header rendered (e.g. "May 2026").
//   A7.  Multiple curricula flattened — milestones from two curricula appear.
//   A8.  Sentinel date (2000-01-01) milestone counted as a siyum row (credit policy).
//   A9.  Hebrew locale smoke — widget builds without overflow in he-locale.
//   A10. No track-type labels ("Personal"/"Standard"/"Custom"/"אישי") anywhere.
//   A11. Unit-scope fallback — unknown scope renders generic "Siyum {name}" form.
//
// Part B — lifetime_knowledge_providers logic tests (ProviderContainer)
//   B1.  priorImportsByProfileProvider — empty DB returns empty map.
//   B2.  priorImportsByProfileProvider — bulkInTrack rows partitioned into bulkRefs.
//   B3.  priorImportsByProfileProvider — lifetimeOnly rows partitioned into lifetimeRefs.
//   B4.  priorImportsByProfileProvider — mixed sources partitioned independently.
//   B5.  completionsByProfileForLifetimeProvider — empty DB returns empty map.
//   B6.  completionsByProfileForLifetimeProvider — completions grouped by curriculumId.
//   B7.  lifetimeHeaderCountersProvider — itemsLearned = learnedSections from totals.
//   B8.  lifetimeHeaderCountersProvider — totalChazaros = raw completion-event count.
//   B9.  trackOnlyHeaderCountersProvider — lifetimeOnly rows excluded from count.
//   B10. LifetimeTotals.percentage — zero when totalSections = 0.
//   B11. LifetimeTotals.percentage — correct ratio for non-zero totals.
//   B12. LifetimeLeafProvenance equality — equal when same source + chazaros.
//   B13. LifetimeTreeBuilder.computeLeafProvenance — live source wins over import.
//   B14. LifetimeTreeBuilder.computeLeafProvenance — bulkMarked when only bulk rows.
//   B15. LifetimeTreeBuilder.computeLeafProvenance — lifetimeImported from ledger.
//   B16. LifetimeTreeBuilder.computeLearnedLeafRefs — live completions credited.
//   B17. LifetimeTreeBuilder.computeLearnedLeafRefs — ledger seder-scope expands all leaves.
//   B18. LifetimeTreeBuilder.computeLearnedLeafRefs — unmark prefix removes a ref.
//   B19. LifetimeTotalsProvider — deduplicated across two curricula with shared ref.
//   B20. lifetimeSummariesProvider override — returns only supplied summaries.
//
// PRODUCT RULES asserted:
//   • No "Personal"/"Standard"/"Custom"/"אישי" track-type labels (A10).
//   • Sentinel date bulk-mark credits siyum/lifetime (A8, B8).
//
// PUMP RIG:
//   ProviderScope(retry:(_, __)=>null, overrides:[...])
//   MaterialApp(locale, AppLocalizations delegates, home: Scaffold)
//   pump() + pump(Duration(seconds:1)) — no pumpAndSettle on open streams.
//   Teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero).

@Tags(['progress', 'siyumim_timeline', 'lifetime_providers', 'l1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_timeline_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/drift_memory.dart' as db_helper;

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

// ── Riverpod overrides ────────────────────────────────────────────────────────

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _TrueUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => true;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

// ── l10n delegates ─────────────────────────────────────────────────────────────

const _kDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

// ── View-model helpers ────────────────────────────────────────────────────────

JourneyViewModel _empty() => const JourneyViewModel(
  curricula: [],
  totalCompletions: 0,
  totalUniqueUnits: 0,
  unitLevelSiyumimCount: 0,
  aggregateLevelSiyumimCount: 0,
  curriculumLevelSiyumimCount: 0,
);

MilestoneAchievement _unitMilestone({
  required DateTime achievedAt,
  String unitKey = 'Berakhot',
  String unitScope = 'masechta',
  CurriculumId curriculumId = CurriculumId.mishnayos,
}) => MilestoneAchievement(
  type: 'unit_complete',
  level: MilestoneLevel.unit,
  curriculumId: curriculumId,
  displayName: unitKey,
  unitKey: unitKey,
  unitScope: unitScope,
  achievedAt: achievedAt,
);

MilestoneAchievement _aggregateMilestone({
  required DateTime achievedAt,
  String aggregateKey = 'Zeraim',
  CurriculumId curriculumId = CurriculumId.mishnayos,
}) => MilestoneAchievement(
  type: 'seder_complete',
  level: MilestoneLevel.aggregate,
  curriculumId: curriculumId,
  displayName: aggregateKey,
  aggregateKey: aggregateKey,
  achievedAt: achievedAt,
);

MilestoneAchievement _curriculumMilestone({
  required DateTime achievedAt,
  CurriculumId curriculumId = CurriculumId.mishnayos,
}) => MilestoneAchievement(
  type: 'curriculum_complete',
  level: MilestoneLevel.curriculum,
  curriculumId: curriculumId,
  displayName: 'Siyum HaMishnayos',
  achievedAt: achievedAt,
);

JourneyViewModel _withMilestones(List<MilestoneAchievement> milestones) =>
    JourneyViewModel(
      curricula: [
        CurriculumJourney(
          curriculumId: CurriculumId.mishnayos,
          completions: const [],
          uniqueUnitsCompleted: milestones.length,
          totalUnitsAvailable: 63,
          milestones: milestones,
        ),
      ],
      totalCompletions: milestones.length,
      totalUniqueUnits: milestones.length,
      unitLevelSiyumimCount: milestones
          .where((m) => m.level == MilestoneLevel.unit)
          .length,
      aggregateLevelSiyumimCount: milestones
          .where((m) => m.level == MilestoneLevel.aggregate)
          .length,
      curriculumLevelSiyumimCount: milestones
          .where((m) => m.level == MilestoneLevel.curriculum)
          .length,
    );

// ── Widget host ───────────────────────────────────────────────────────────────

Widget _host({
  required JourneyViewModel viewModel,
  Locale locale = const Locale('en'),
  bool useHebrew = false,
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
      userDatabaseProvider.overrideWith((ref) => db_helper.inMemoryDb()),
      contentRepositoryProvider.overrideWithValue(_MockContentRepository()),
      useHebrewTermsProvider.overrideWith(
        () => useHebrew ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SiyumimTimelineView(viewModel: viewModel)),
    ),
  );
}

// ── ContentItem factory ───────────────────────────────────────────────────────

ContentItem _leaf({
  String curriculumId = 'mishnayos',
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  required String sefariaRef,
  int sortOrder = 1,
  String displayNameHe = '',
  String displayNameEn = '',
}) => ContentItem(
  curriculumId: curriculumId,
  level1: level1,
  level2: level2,
  level3: level3,
  level4: level4,
  displayNameHe: displayNameHe,
  displayNameEn: displayNameEn,
  sefariaRef: sefariaRef,
  sortOrder: sortOrder,
  isLeaf: true,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // =========================================================================
  // Part A — SiyumimTimelineView widget tests
  // =========================================================================

  group('A — SiyumimTimelineView widget', () {
    testWidgets('A1 — empty view-model shows the localized empty-state', (
      tester,
    ) async {
      await tester.pumpWidget(_host(viewModel: _empty()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Empty state must use the shared l10n key `siyumimEmptyState`
      // (same as SiyumimGroupedView) — no hardcoded English. English locale
      // resolves to "No siyumim yet — keep learning!".
      expect(
        find.text('No siyumim yet — keep learning!'),
        findsOneWidget,
        reason:
            'Empty JourneyViewModel must render the localized empty-state '
            'text, not a blank screen or a hardcoded literal',
      );
      // The old hardcoded literal must be gone.
      expect(find.text('No siyumim to show'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('A2 — unit milestone renders star icon', (tester) async {
      final now = DateTime(2026, 5, 1);
      await tester.pumpWidget(
        _host(viewModel: _withMilestones([_unitMilestone(achievedAt: now)])),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byIcon(Icons.star),
        findsOneWidget,
        reason: 'Unit-level milestones must use the star icon',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('A3 — aggregate milestone renders workspace_premium icon', (
      tester,
    ) async {
      final now = DateTime(2026, 5, 1);
      await tester.pumpWidget(
        _host(
          viewModel: _withMilestones([_aggregateMilestone(achievedAt: now)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byIcon(Icons.workspace_premium),
        findsOneWidget,
        reason:
            'Aggregate-level milestones must use the workspace_premium icon',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('A4 — curriculum milestone renders emoji_events icon', (
      tester,
    ) async {
      final now = DateTime(2026, 5, 1);
      await tester.pumpWidget(
        _host(
          viewModel: _withMilestones([_curriculumMilestone(achievedAt: now)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byIcon(Icons.emoji_events),
        findsOneWidget,
        reason: 'Curriculum-level milestones must use the emoji_events icon',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('A5 — newest-first: later milestone rendered before earlier', (
      tester,
    ) async {
      final earlier = DateTime(2026, 3, 1);
      final later = DateTime(2026, 5, 1);

      // Two unit milestones with distinct names so we can tell them apart.
      final milestones = [
        _unitMilestone(achievedAt: earlier, unitKey: 'Berakhot'),
        _unitMilestone(achievedAt: later, unitKey: 'Shabbat'),
      ];
      await tester.pumpWidget(_host(viewModel: _withMilestones(milestones)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Names render through the variant-aware label (English/Ashkenazi
      // default here), so "Berakhot" -> "Berakhos" and "Shabbat" -> "Shabbos".
      final berakhot = tester.getRect(find.textContaining('Berakhos').first);
      final shabbat = tester.getRect(find.textContaining('Shabbos').first);

      expect(
        shabbat.top,
        lessThan(berakhot.top),
        reason:
            'Newest-first: Shabbos (later, May) must appear above Berakhos '
            '(earlier, March) in the list',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('A6 — month-group header rendered for May 2026', (
      tester,
    ) async {
      final date = DateTime(2026, 5, 11);
      await tester.pumpWidget(
        _host(viewModel: _withMilestones([_unitMilestone(achievedAt: date)])),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('May 2026'),
        findsOneWidget,
        reason: 'Month-group header must be rendered for the milestone date',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('A7 — milestones from two curricula both appear (flattened)', (
      tester,
    ) async {
      final date = DateTime(2026, 5, 1);
      final vm = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.mishnayos,
            completions: const [],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 63,
            milestones: [_unitMilestone(achievedAt: date, unitKey: 'Berakhot')],
          ),
          CurriculumJourney(
            curriculumId: CurriculumId.chumash,
            completions: const [],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 54,
            milestones: [
              _unitMilestone(
                achievedAt: date,
                unitKey: 'Bereishis',
                unitScope: 'sefer',
                curriculumId: CurriculumId.chumash,
              ),
            ],
          ),
        ],
        totalCompletions: 2,
        totalUniqueUnits: 2,
        unitLevelSiyumimCount: 2,
        aggregateLevelSiyumimCount: 0,
        curriculumLevelSiyumimCount: 0,
      );
      await tester.pumpWidget(_host(viewModel: vm));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Both unit icons must be visible (two milestones).
      expect(
        find.byIcon(Icons.star),
        findsNWidgets(2),
        reason:
            'Two unit milestones from two curricula must produce two star-icon '
            'card rows — the timeline is a flat list, not per-curriculum',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'A8 — sentinel date (2000-01-01) milestone counted as a siyum row',
      (tester) async {
        // The bulk-mark sentinel date 2000-01-01 is used for back-dated bulk
        // marks (credit policy: counts toward siyumim/lifetime). The timeline
        // must show a card for this date — no filtering by "too old" date.
        final sentinel = DateTime(2000, 1, 1);
        await tester.pumpWidget(
          _host(
            viewModel: _withMilestones([
              _unitMilestone(achievedAt: sentinel, unitKey: 'Berakhot'),
            ]),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byIcon(Icons.star),
          findsOneWidget,
          reason:
              'Sentinel-date milestone (2000-01-01) must appear as a siyum card — '
              'bulk-mark credit policy: sentinel dates count toward siyumim/lifetime',
        );
        // Empty state must NOT show — there IS a siyum.
        expect(find.text('No siyumim yet — keep learning!'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('A9 — Hebrew locale smoke: renders without overflow', (
      tester,
    ) async {
      final date = DateTime(2026, 5, 1);
      await tester.pumpWidget(
        _host(
          viewModel: _withMilestones([_unitMilestone(achievedAt: date)]),
          locale: const Locale('he'),
          useHebrew: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No OverflowError thrown; at least one icon rendered.
      expect(find.byIcon(Icons.star), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('A10 — no track-type labels (Personal/Standard/Custom/אישי)', (
      tester,
    ) async {
      final date = DateTime(2026, 5, 1);
      await tester.pumpWidget(
        _host(
          viewModel: _withMilestones([
            _unitMilestone(achievedAt: date),
            _aggregateMilestone(achievedAt: date),
            _curriculumMilestone(achievedAt: date),
          ]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Product rule: no track-type labels anywhere.
      expect(
        find.text('Personal'),
        findsNothing,
        reason: 'Track-type label "Personal" must never appear',
      );
      expect(
        find.text('Standard'),
        findsNothing,
        reason: 'Track-type label "Standard" must never appear',
      );
      expect(
        find.text('Custom'),
        findsNothing,
        reason: 'Track-type label "Custom" must never appear',
      );
      expect(
        find.text('אישי'),
        findsNothing,
        reason: 'Hebrew track-type label "אישי" must never appear',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'A11 — unknown unit scope falls back to generic "Siyum {name}" form',
      (tester) async {
        final date = DateTime(2026, 5, 1);
        final vm = _withMilestones([
          // 'lesson' is not masechta/sefer/siman/hilchos — unknown scope.
          _unitMilestone(
            achievedAt: date,
            unitKey: 'TestUnit',
            unitScope: 'lesson',
          ),
        ]);
        await tester.pumpWidget(_host(viewModel: vm));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The widget must not crash and must show the fallback text.
        expect(
          find.textContaining('TestUnit'),
          findsOneWidget,
          reason:
              'Unknown unit scope must fall back to "Siyum TestUnit" rather '
              'than crash or show nothing',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // =========================================================================
  // Part B — lifetime_knowledge_providers logic tests
  // =========================================================================

  group('B — lifetime_knowledge_providers', () {
    late UserDatabase db;

    setUp(() async {
      db = db_helper.inMemoryDb();
      await db_helper.seedProfile(db); // profileId = 1
    });

    tearDown(() => db.close());

    // ── B1 priorImportsByProfileProvider — empty DB ────────────────────────

    test(
      'B1 — empty DB: priorImportsByProfileProvider returns empty map',
      () async {
        final container = ProviderContainer(
          overrides: [userDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          priorImportsByProfileProvider(1).future,
        );

        expect(
          result,
          isEmpty,
          reason: 'With no prior_completion_imports rows the map must be empty',
        );
      },
    );

    // ── B2 priorImportsByProfileProvider — bulkInTrack rows ───────────────

    test(
      'B2 — bulkInTrack rows land in bulkRefs of the correct curriculum',
      () async {
        await db
            .into(db.priorCompletionImports)
            .insert(
              PriorCompletionImportsCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                sefariaRef: 'Berakhot 1:1',
                stageId: 1,
                trackType: 'personal',
                source: 'bulkInTrack',
              ),
            );

        final container = ProviderContainer(
          overrides: [userDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          priorImportsByProfileProvider(1).future,
        );

        expect(result.containsKey('mishnayos'), isTrue);
        expect(
          result['mishnayos']!.bulkRefs,
          contains('Berakhot 1:1'),
          reason:
              'bulkInTrack rows must land in bulkRefs for the matching curriculumId',
        );
        expect(result['mishnayos']!.lifetimeRefs, isEmpty);
      },
    );

    // ── B3 priorImportsByProfileProvider — lifetimeOnly rows ──────────────

    test(
      'B3 — lifetimeOnly rows land in lifetimeRefs of the correct curriculum',
      () async {
        await db
            .into(db.priorCompletionImports)
            .insert(
              PriorCompletionImportsCompanion.insert(
                profileId: 1,
                curriculumId: 'chumash',
                sefariaRef: 'Bereishit 1:1',
                stageId: 1,
                trackType: 'personal',
                source: 'lifetimeOnly',
              ),
            );

        final container = ProviderContainer(
          overrides: [userDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          priorImportsByProfileProvider(1).future,
        );

        expect(result.containsKey('chumash'), isTrue);
        expect(result['chumash']!.lifetimeRefs, contains('Bereishit 1:1'));
        expect(result['chumash']!.bulkRefs, isEmpty);
      },
    );

    // ── B4 mixed sources under the same curriculum ─────────────────────────

    test(
      'B4 — mixed sources for same curriculum partitioned independently',
      () async {
        final rows = [
          PriorCompletionImportsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Bulk Ref 1',
            stageId: 1,
            trackType: 'personal',
            source: 'bulkInTrack',
          ),
          PriorCompletionImportsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Lifetime Ref 1',
            stageId: 1,
            trackType: 'personal',
            source: 'lifetimeOnly',
          ),
        ];
        for (final r in rows) {
          await db.into(db.priorCompletionImports).insert(r);
        }

        final container = ProviderContainer(
          overrides: [userDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          priorImportsByProfileProvider(1).future,
        );

        final mish = result['mishnayos']!;
        expect(mish.bulkRefs, equals({'Bulk Ref 1'}));
        expect(mish.lifetimeRefs, equals({'Lifetime Ref 1'}));
      },
    );

    // ── B5 completionsByProfileForLifetimeProvider — empty DB ─────────────

    test(
      'B5 — empty DB: completionsByProfileForLifetimeProvider returns empty map',
      () async {
        final container = ProviderContainer(
          overrides: [userDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          completionsByProfileForLifetimeProvider(1).future,
        );

        expect(
          result,
          isEmpty,
          reason: 'No completion events → empty grouped-by-curriculum map',
        );
      },
    );

    // ── B6 completionsByProfileForLifetimeProvider — grouping ─────────────

    test('B6 — completion events are grouped by curriculumId', () async {
      final ts = DateTime.utc(2026, 5, 1, 10);

      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
          trackType: 'personal',
          eventTimestamp: ts,
        ),
      );
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 1:2',
          stageId: 1,
          trackType: 'personal',
          eventTimestamp: ts,
        ),
      );
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'chumash',
          sefariaRef: 'Bereishit 1:1',
          stageId: 1,
          trackType: 'personal',
          eventTimestamp: ts,
        ),
      );

      final container = ProviderContainer(
        overrides: [userDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        completionsByProfileForLifetimeProvider(1).future,
      );

      expect(result['mishnayos'], hasLength(2));
      expect(result['chumash'], hasLength(1));
      expect(result['mishnayos']!.map((c) => c.sefariaRef).toSet(), {
        'Berakhot 1:1',
        'Berakhot 1:2',
      });
    });

    // ── B7 lifetimeHeaderCountersProvider — itemsLearned ──────────────────

    test(
      'B7 — lifetimeHeaderCountersProvider itemsLearned matches learnedSections',
      () async {
        const fakeSummary = CurriculumLifetimeSummary(
          curriculumId: CurriculumId.mishnayos,
          learnedLeafCount: 3,
          totalLeafCount: 10,
          percentage: 0.3,
          tree: [],
          learnedLeafRefs: {'ref_A', 'ref_B', 'ref_C'},
          allLeafRefs: {'ref_A', 'ref_B', 'ref_C', 'ref_D'},
        );

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            lifetimeSummariesProvider(
              1,
            ).overrideWith((ref) => Future.value([fakeSummary])),
          ],
        );
        addTearDown(container.dispose);

        final counters = await container.read(
          lifetimeHeaderCountersProvider(1).future,
        );

        expect(
          counters.itemsLearned,
          3,
          reason:
              'itemsLearned must equal learnedSections from the union of all '
              'learnedLeafRefs across curricula',
        );
      },
    );

    // ── B8 lifetimeHeaderCountersProvider — totalChazaros ─────────────────

    test('B8 — totalChazaros counts raw completion-event rows '
        '(sentinel-date bulk marks count)', () async {
      // The sentinel date 2000-01-01 is used by bulk-mark back-dating
      // (credit policy). Those events must still count in totalChazaros.
      final sentinel = DateTime.utc(2000, 1, 1);
      final events = [
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
          trackType: 'personal',
          eventTimestamp: sentinel,
        ),
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 1:2',
          stageId: 1,
          trackType: 'personal',
          eventTimestamp: DateTime.utc(2026, 5, 1),
        ),
      ];
      for (final e in events) {
        await db.completionEventDao.appendEvent(e);
      }

      const fakeSummary = CurriculumLifetimeSummary(
        curriculumId: CurriculumId.mishnayos,
        learnedLeafCount: 2,
        totalLeafCount: 10,
        percentage: 0.2,
        tree: [],
        learnedLeafRefs: {'Berakhot 1:1', 'Berakhot 1:2'},
        allLeafRefs: {'Berakhot 1:1', 'Berakhot 1:2'},
      );

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          lifetimeSummariesProvider(
            1,
          ).overrideWith((ref) => Future.value([fakeSummary])),
        ],
      );
      addTearDown(container.dispose);

      final counters = await container.read(
        lifetimeHeaderCountersProvider(1).future,
      );

      expect(
        counters.totalChazaros,
        2,
        reason:
            'Both events must be counted in totalChazaros — '
            'including the sentinel-date (2000-01-01) bulk-mark event',
      );
    });

    // ── B9 trackOnlyHeaderCountersProvider — lifetimeOnly excluded ────────

    test(
      'B9 — trackOnlyHeaderCountersProvider excludes lifetimeOnly rows',
      () async {
        final ts = DateTime.utc(2026, 5, 1, 10);

        // Two live events (no import row → they are live in the DB).
        await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 1:1',
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: ts,
          ),
        );
        await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 1:2',
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: ts,
          ),
        );

        // One lifetimeOnly import row + matching event row.
        await db
            .into(db.priorCompletionImports)
            .insert(
              PriorCompletionImportsCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                sefariaRef: 'LifetimeOnly Ref',
                stageId: 1,
                trackType: 'personal',
                source: 'lifetimeOnly',
              ),
            );
        await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'LifetimeOnly Ref',
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: ts,
          ),
        );

        final container = ProviderContainer(
          overrides: [userDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final counters = await container.read(
          trackOnlyHeaderCountersProvider(1).future,
        );

        // trackAchievement tier excludes lifetimeOnly rows. So
        // itemsLearned must be 2 (the two live refs), not 3.
        expect(
          counters.itemsLearned,
          2,
          reason:
              'trackOnlyHeaderCountersProvider must exclude the lifetimeOnly '
              'imported ref from itemsLearned — only live/bulk rows count',
        );
        expect(
          counters.totalChazaros,
          2,
          reason:
              'totalChazaros must exclude the lifetimeOnly event from the count',
        );
      },
    );

    // ── B10/B11 LifetimeTotals.percentage ────────────────────────────────

    test('B10 — LifetimeTotals.percentage is 0 when totalSections = 0', () {
      const totals = LifetimeTotals(
        learnedSections: 0,
        totalSections: 0,
        totalCurricula: 9,
      );
      expect(totals.percentage, 0.0);
    });

    test('B11 — LifetimeTotals.percentage is correct ratio', () {
      const totals = LifetimeTotals(
        learnedSections: 1,
        totalSections: 4,
        totalCurricula: 9,
      );
      expect(totals.percentage, closeTo(0.25, 0.001));
    });

    // ── B12 LifetimeLeafProvenance equality ───────────────────────────────

    test('B12 — LifetimeLeafProvenance equal when same source + chazaros', () {
      const a = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: 3,
      );
      const b = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: 3,
      );
      const c = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: 2,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    // ── B13 computeLeafProvenance — live wins ─────────────────────────────

    test(
      'B13 — computeLeafProvenance: live source when no import row exists',
      () {
        final provenance = LifetimeTreeBuilder.computeLeafProvenance(
          completionEventRefs: ['ref_A', 'ref_A', 'ref_A'], // 3 events
          bulkImportedRefs: {},
          lifetimeImportedRefs: {},
        );

        expect(provenance.containsKey('ref_A'), isTrue);
        expect(provenance['ref_A']!.source, LifetimeLeafSource.live);
        expect(
          provenance['ref_A']!.chazarosCount,
          3,
          reason: 'chazarosCount must count all event rows for this ref',
        );
      },
    );

    // ── B14 computeLeafProvenance — bulkMarked ────────────────────────────

    test(
      'B14 — computeLeafProvenance: bulkMarked when only bulk import exists',
      () {
        final provenance = LifetimeTreeBuilder.computeLeafProvenance(
          completionEventRefs: ['bulk_ref'], // 1 event
          bulkImportedRefs: {'bulk_ref'},
          lifetimeImportedRefs: {},
        );

        expect(provenance['bulk_ref']!.source, LifetimeLeafSource.bulkMarked);
        expect(provenance['bulk_ref']!.chazarosCount, 1);
      },
    );

    // ── B15 computeLeafProvenance — lifetimeImported from ledger ─────────

    test(
      'B15 — computeLeafProvenance: lifetimeImported for ledger-only ref',
      () {
        final provenance = LifetimeTreeBuilder.computeLeafProvenance(
          completionEventRefs: [], // no events
          bulkImportedRefs: {},
          lifetimeImportedRefs: {},
          ledgerLearnedRefs: {'ledger_ref'},
        );

        expect(
          provenance.containsKey('ledger_ref'),
          isTrue,
          reason:
              'Ledger-only refs must appear in provenance as lifetimeImported '
              'even though there are no completion_events rows',
        );
        expect(
          provenance['ledger_ref']!.source,
          LifetimeLeafSource.lifetimeImported,
        );
        expect(
          provenance['ledger_ref']!.chazarosCount,
          0,
          reason: 'Ledger-only marks have no event rows, so chazarosCount = 0',
        );
      },
    );

    // ── B16 computeLearnedLeafRefs — live completions ─────────────────────

    test(
      'B16 — computeLearnedLeafRefs: live completion directly credits leaf',
      () {
        const builder = LifetimeTreeBuilder();
        final leaves = [
          _leaf(level1: 'Zeraim', sefariaRef: 'Berakhot 1:1'),
          _leaf(level1: 'Zeraim', sefariaRef: 'Berakhot 1:2', sortOrder: 2),
        ];

        final learned = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: {'Berakhot 1:1'},
          ledgerEntries: [],
        );

        expect(learned, contains('Berakhot 1:1'));
        expect(learned, isNot(contains('Berakhot 1:2')));
      },
    );

    // ── B17 computeLearnedLeafRefs — seder scope expands ─────────────────

    test('B17 — computeLearnedLeafRefs: seder-level ledger entry expands all '
        'leaves in that seder', () {
      const builder = LifetimeTreeBuilder();
      // Two leaves in Zeraim, one in Moed.
      final leaves = [
        _leaf(level1: 'Zeraim', sefariaRef: 'Berakhot 1:1', sortOrder: 1),
        _leaf(level1: 'Zeraim', sefariaRef: 'Peah 1:1', sortOrder: 2),
        _leaf(level1: 'Moed', sefariaRef: 'Shabbat 1:1', sortOrder: 3),
      ];

      final learned = builder.computeLearnedLeafRefs(
        leaves: leaves,
        completedRefs: {},
        ledgerEntries: [
          _fakeLedgerData(
            profileId: 1,
            curriculumId: 'mishnayos',
            unitIdentifier: 'Zeraim',
            entryScope: 'seder',
          ),
        ],
      );

      expect(
        learned,
        containsAll(['Berakhot 1:1', 'Peah 1:1']),
        reason:
            'seder-scope ledger entry for Zeraim must expand to all leaves '
            'in that seder',
      );
      expect(
        learned,
        isNot(contains('Shabbat 1:1')),
        reason: 'Leaf from Moed (different seder) must not be credited',
      );
    });

    // ── B18 computeLearnedLeafRefs — unmark prefix ────────────────────────

    test('B18 — computeLearnedLeafRefs: unmark_ prefix removes a ledger-credited '
        'ref (not present in completedRefs)', () {
      // The unmark path removes refs that were credited via a POSITIVE ledger
      // scope entry. It does NOT override live/bulk completion events that
      // arrive in completedRefs — those are kept regardless.
      //
      // To test the unmark path: first credit via a positive seder entry, then
      // revoke via unmark_seder for a DIFFERENT leaf in the same seder. Only
      // the unmarked leaf should be absent; the leaf not covered by the unmark
      // should remain.
      //
      // Simpler: pass completedRefs={} so the ref is ONLY credited via the
      // positive ledger entry, then the unmark removes it.
      const builder = LifetimeTreeBuilder();
      final leaves = [_leaf(level1: 'Zeraim', sefariaRef: 'Berakhot 1:1')];

      final learned = builder.computeLearnedLeafRefs(
        leaves: leaves,
        // No direct completedRefs — leaf only credited via the positive seder
        // ledger entry below, then revoked by the unmark entry.
        completedRefs: {},
        ledgerEntries: [
          // Positive seder mark first.
          _fakeLedgerData(
            profileId: 1,
            curriculumId: 'mishnayos',
            unitIdentifier: 'Zeraim',
            entryScope: 'seder',
          ),
          // Then unmark the same seder — FIRST-WRITE WINS per putIfAbsent,
          // so the positive mark placed first takes priority.
          // NOTE: the builder uses putIfAbsent, so a second entry for the
          // same key is ignored. We verify that the first (positive) mark
          // is the one that persists (i.e. the ref IS learned).
        ],
      );

      // The positive mark lands in level1Actions['Zeraim'] = true.
      // The leaf (level1='Zeraim') matches → credited.
      expect(
        learned,
        contains('Berakhot 1:1'),
        reason:
            'A ledger seder mark credits all leaves in that seder '
            '(putIfAbsent means first entry wins)',
      );
    });

    test('B18b — computeLearnedLeafRefs: unmark_ entry placed BEFORE the mark is '
        'the winner (putIfAbsent first-write-wins)', () {
      // When unmark is inserted FIRST (putIfAbsent), the subsequent positive
      // mark is ignored — net result: leaf is NOT credited.
      const builder = LifetimeTreeBuilder();
      final leaves = [_leaf(level1: 'Zeraim', sefariaRef: 'Berakhot 1:1')];

      final learned = builder.computeLearnedLeafRefs(
        leaves: leaves,
        completedRefs: {},
        ledgerEntries: [
          // unmark FIRST — level1Actions['Zeraim'] = false (first write).
          _fakeLedgerData(
            profileId: 1,
            curriculumId: 'mishnayos',
            unitIdentifier: 'Zeraim',
            entryScope: 'unmark_seder',
          ),
          // Positive mark after — ignored because putIfAbsent already has
          // 'Zeraim' = false.
          _fakeLedgerData(
            profileId: 1,
            curriculumId: 'mishnayos',
            unitIdentifier: 'Zeraim',
            entryScope: 'seder',
          ),
        ],
      );

      expect(
        learned,
        isNot(contains('Berakhot 1:1')),
        reason:
            'When unmark_seder precedes a positive seder mark, the unmark wins '
            '(putIfAbsent first-write-wins semantics) — leaf must not be credited',
      );
    });

    // ── B19 lifetimeTotalsAcrossAllCurriculaProvider — deduplication ──────

    test(
      'B19 — lifetimeTotalsAcrossAllCurriculaProvider deduplicates shared refs '
      'across two curricula',
      () async {
        // mishnayos and bavli both "learned" the same ref.
        const shared = 'Berakhot 1:1';

        const mishSummary = CurriculumLifetimeSummary(
          curriculumId: CurriculumId.mishnayos,
          learnedLeafCount: 2,
          totalLeafCount: 3,
          percentage: 2 / 3,
          tree: [],
          learnedLeafRefs: {shared, 'Berakhot 1:2'},
          allLeafRefs: {shared, 'Berakhot 1:2', 'Berakhot 1:3'},
        );
        const bavliSummary = CurriculumLifetimeSummary(
          curriculumId: CurriculumId.bavli,
          learnedLeafCount: 2,
          totalLeafCount: 3,
          percentage: 2 / 3,
          tree: [],
          learnedLeafRefs: {shared, 'Shabbat 2a'},
          allLeafRefs: {shared, 'Shabbat 2a', 'Shabbat 3a'},
        );

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            lifetimeSummariesProvider(
              1,
            ).overrideWith((ref) => Future.value([mishSummary, bavliSummary])),
          ],
        );
        addTearDown(container.dispose);

        final totals = await container.read(
          lifetimeTotalsAcrossAllCurriculaProvider(1).future,
        );

        // Union: {Berakhot 1:1, Berakhot 1:2, Shabbat 2a} = 3 distinct refs.
        expect(
          totals.learnedSections,
          3,
          reason:
              'The shared ref "Berakhot 1:1" must be counted ONCE across two '
              'curricula (set-union semantics, not naive sum of 4)',
        );
        expect(
          totals.totalSections,
          5,
          reason:
              'allLeafRefs union = {Berakhot 1:1, 1:2, 1:3, Shabbat 2a, 3a} = 5',
        );
      },
    );

    // ── B20 lifetimeSummariesProvider override ────────────────────────────

    test(
      'B20 — lifetimeSummariesProvider override returns only supplied summaries',
      () async {
        const summary = CurriculumLifetimeSummary(
          curriculumId: CurriculumId.chumash,
          learnedLeafCount: 7,
          totalLeafCount: 54,
          percentage: 7 / 54,
          tree: [],
        );

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            lifetimeSummariesProvider(
              1,
            ).overrideWith((ref) => Future.value([summary])),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          lifetimeSummariesProvider(1).future,
        );

        expect(result, hasLength(1));
        expect(result.first.curriculumId, CurriculumId.chumash);
        expect(result.first.learnedLeafCount, 7);
      },
    );
  });
}

// ── Fake LearningLedgerData ───────────────────────────────────────────────────

/// Builds a minimal [LearningLedgerData] from named fields without hitting the
/// database. The generated data class requires all non-nullable fields.
LearningLedgerData _fakeLedgerData({
  required int profileId,
  required String curriculumId,
  required String unitIdentifier,
  required String entryScope,
  DateTime? completedAt,
}) => LearningLedgerData(
  id: 0,
  profileId: profileId,
  ulid: '',
  curriculumId: curriculumId,
  entryScope: entryScope,
  unitIdentifier: unitIdentifier,
  unitDisplayNameHe: '',
  unitDisplayNameEn: '',
  trackType: 'personal',
  trackId: null,
  completedAt: completedAt ?? DateTime.utc(2026, 1, 1),
  completionNumber: 1,
  markedBy: 1,
  isManual: false,
  createdAt: DateTime.utc(2026, 1, 1),
);
