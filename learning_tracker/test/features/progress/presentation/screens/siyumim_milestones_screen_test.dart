/// Widget tests for the new Siyumim & Milestones screen (W3-B / Task #10).
///
/// Verifies the hierarchy-aware grouped view at the screen level:
///
/// * The screen title comes from the new domainTermLabels wiring
///   (`tierLensSiyumimMilestones`).
/// * Top counters split by level (unit / aggregate / curriculum).
/// * Curriculum-complete card appears first within a curriculum block,
///   then aggregate rows, then standalone unit rows.
/// * No provenance label ("Live · {date}", "via bulk-mark", or the legacy
///   "Personal" track-type badge) appears anywhere on the screen.
@Tags(['progress', 'siyumim_milestones'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/siyumim_milestones_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

/// Test override for [ActiveProfileId] that returns a fixed id.
class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

/// Pins the Hebrew Terms toggle to a known value so tests can assert
/// against the English-default labels.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

JourneyViewModel _viewModelWithAllThreeLevels() {
  final achievedAt = DateTime(2026, 5, 4);
  return JourneyViewModel(
    curricula: [
      CurriculumJourney(
        curriculumId: CurriculumId.mishnayos,
        completions: const [],
        uniqueUnitsCompleted: 63,
        totalUnitsAvailable: 63,
        milestones: [
          // Curriculum-complete — should render first.
          MilestoneAchievement(
            type: 'curriculum_complete',
            level: MilestoneLevel.curriculum,
            curriculumId: CurriculumId.mishnayos,
            displayName: 'Mishnayos',
            achievedAt: achievedAt,
          ),
          // Aggregate-level — Zeraim complete with all 11 masechtos.
          MilestoneAchievement(
            type: 'seder_complete',
            level: MilestoneLevel.aggregate,
            curriculumId: CurriculumId.mishnayos,
            displayName: 'Zeraim',
            aggregateKey: 'Zeraim',
            containedUnitKeys: const [
              'Berakhot',
              'Peah',
              'Demai',
              'Kilayim',
              'Sheviit',
              'Terumot',
              'Maasrot',
              'Maaser Sheni',
              'Challah',
              'Orlah',
              'Bikkurim',
            ],
            achievedAt: achievedAt,
          ),
          // Unit-level inside Zeraim — should be hidden, rolled into the
          // aggregate row's expansion body.
          MilestoneAchievement(
            type: 'unit_complete',
            level: MilestoneLevel.unit,
            curriculumId: CurriculumId.mishnayos,
            displayName: 'Berakhot',
            unitKey: 'Berakhot',
            unitScope: 'masechta',
            parentAggregateKey: 'Zeraim',
            achievedAt: achievedAt,
          ),
          // Unit-level NOT part of a completed seder — should appear as a
          // standalone row below the aggregate.
          MilestoneAchievement(
            type: 'unit_complete',
            level: MilestoneLevel.unit,
            curriculumId: CurriculumId.mishnayos,
            displayName: 'Shabbat',
            unitKey: 'Shabbat',
            unitScope: 'masechta',
            parentAggregateKey: 'Moed',
            achievedAt: achievedAt,
          ),
        ],
      ),
    ],
    totalCompletions: 0,
    totalUniqueUnits: 63,
    unitLevelSiyumimCount: 2,
    aggregateLevelSiyumimCount: 1,
    curriculumLevelSiyumimCount: 1,
  );
}

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async => db.close());

  Widget buildScreen({
    required JourneyViewModel viewModel,
    bool useHebrew = false,
  }) => ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWith((ref) => db),
      activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(1)),
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: useHebrew),
      ),
      activeCurriculaProvider.overrideWith(
        (ref) => Future.value(const [CurriculumId.mishnayos]),
      ),
      curriculumContentProvider(
        CurriculumId.mishnayos,
      ).overrideWith((ref) => Future.value(const [])),
      journeyViewModelProvider(
        1,
      ).overrideWith((ref) => Future.value(viewModel)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SiyumimMilestonesScreen(),
    ),
  );

  testWidgets(
    'screen title comes from tierLensSiyumimMilestones (English default)',
    (tester) async {
      await tester.pumpWidget(
        buildScreen(viewModel: _viewModelWithAllThreeLevels()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siyumim & Milestones'), findsOneWidget);
    },
  );

  testWidgets('top counters split by level — curriculum, aggregate, unit',
      (tester) async {
    await tester.pumpWidget(
      buildScreen(viewModel: _viewModelWithAllThreeLevels()),
    );
    await tester.pumpAndSettle();

    expect(find.text('curriculum-level siyumim'), findsOneWidget);
    expect(find.text('aggregate-level siyumim'), findsOneWidget);
    expect(find.text('unit-level siyumim'), findsOneWidget);
    // The counts (1, 1, 2) must all appear.
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
    'hierarchy: curriculum-complete first, aggregate expandable, standalone unit visible',
    (tester) async {
      await tester.pumpWidget(
        buildScreen(viewModel: _viewModelWithAllThreeLevels()),
      );
      await tester.pumpAndSettle();

      // ── Curriculum-complete hero card renders the curriculum-specific
      //   label "Siyum HaMishnayos" — proves the per-curriculum mapping
      //   replaces the legacy generic "Mishnayos" displayName. ─────────────
      final heroFinder = find.text('Siyum HaMishnayos');
      expect(heroFinder, findsOneWidget);

      // ── Aggregate row renders "Siyum Seder Zeraim" and is collapsed. ────
      final aggregateFinder = find.text('Siyum Seder Zeraim');
      expect(aggregateFinder, findsOneWidget);
      expect(find.byType(ExpansionTile), findsOneWidget);
      // While collapsed the contained masechtos are NOT in the widget tree.
      expect(find.text('Berakhot'), findsNothing);

      // ── Standalone unit appears as "Siyum Masechta Shabbat" because
      //   Moed is not yet fully complete. ──────────────────────────────────
      expect(find.text('Siyum Masechta Shabbat'), findsOneWidget);
      // The Berakhot unit-level milestone is hidden because Zeraim is a
      // completed aggregate (it shows only on expansion).
      expect(find.text('Siyum Masechta Berakhot'), findsNothing);

      // ── Tapping the aggregate expands it; contained masechtos appear. ──
      await tester.tap(aggregateFinder);
      await tester.pumpAndSettle();
      expect(find.text('Berakhot'), findsOneWidget);
      expect(find.text('Peah'), findsOneWidget);

      // ── Vertical order: curriculum-complete hero is above the aggregate
      //   row, which is above the standalone unit row. ─────────────────────
      final heroCentre = tester.getCenter(heroFinder);
      final aggregateCentre = tester.getCenter(aggregateFinder);
      final standaloneCentre = tester.getCenter(
        find.text('Siyum Masechta Shabbat'),
      );
      expect(heroCentre.dy, lessThan(aggregateCentre.dy));
      expect(aggregateCentre.dy, lessThan(standaloneCentre.dy));
    },
  );

  testWidgets(
    'no provenance label appears on the screen',
    (tester) async {
      await tester.pumpWidget(
        buildScreen(viewModel: _viewModelWithAllThreeLevels()),
      );
      await tester.pumpAndSettle();

      // Legacy provenance terms that explicitly distinguished how a siyum
      // was earned must not leak onto the screen.
      expect(find.textContaining('via bulk-mark'), findsNothing);
      expect(find.textContaining('Via bulk-mark'), findsNothing);
      expect(find.textContaining('Bulk-marked'), findsNothing);
      expect(find.textContaining('bulkInTrack'), findsNothing);
      // The old per-row "Personal" track-type chip used to render provenance.
      expect(find.text('Personal'), findsNothing);
    },
  );
}
