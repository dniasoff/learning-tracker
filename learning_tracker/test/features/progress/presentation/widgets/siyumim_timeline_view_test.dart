/// Widget tests for [SiyumimTimelineView] — domain-term rendering.
///
/// The chronological timeline used to frame masechta + seder names from the
/// RAW Sefaria storage key, so the per-row "Siyum Masechta {name}" /
/// "Siyum Seder {name}" labels ignored the Hebrew-terms toggle and the
/// Ashkenazi/Sephardi nusach. These tests pin that the timeline now resolves
/// BOTH the unit name (masechta) AND the aggregate name (seder) to their
/// variant-aware display form before passing them into the siyum-label frame,
/// matching the sibling grouped view.
@Tags(['progress', 'siyumim_milestones'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_timeline_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Pins the Hebrew Terms toggle to a known value so the per-row siyum labels
/// stay deterministic.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

Widget _host({
  required JourneyViewModel viewModel,
  Locale? locale,
  bool useHebrewTerms = false,
  Map<CurriculumId, List<ContentItem>> content = const {},
}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: useHebrewTerms),
      ),
      for (final entry in content.entries)
        curriculumContentProvider(
          entry.key,
        ).overrideWith((ref) async => entry.value),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: SiyumimTimelineView(viewModel: viewModel)),
    ),
  );
}

JourneyViewModel _unitViewModel() => JourneyViewModel(
  curricula: [
    CurriculumJourney(
      curriculumId: CurriculumId.bavli,
      completions: const [],
      uniqueUnitsCompleted: 1,
      totalUnitsAvailable: 63,
      milestones: [
        MilestoneAchievement(
          type: 'unit_complete',
          level: MilestoneLevel.unit,
          curriculumId: CurriculumId.bavli,
          displayName: 'Shabbat',
          unitKey: 'Shabbat',
          unitScope: 'masechta',
          achievedAt: DateTime(2026, 5, 11),
        ),
      ],
    ),
  ],
  totalCompletions: 0,
  totalUniqueUnits: 1,
  unitLevelSiyumimCount: 1,
  aggregateLevelSiyumimCount: 0,
  curriculumLevelSiyumimCount: 0,
);

const _shabbosContent = ContentItem(
  curriculumId: 'bavli',
  level1: 'Moed',
  level2: 'Shabbat',
  // Hebrew name for the masechta is supplied by the curriculum content so
  // Hebrew-terms mode renders it instead of the raw storage key.
  displayNameHe: 'שבת',
  displayNameEn: 'Shabbos',
  sefariaRef: 'Shabbat',
  sortOrder: 0,
  isLeaf: false,
);

void main() {
  testWidgets(
    'unit milestone renders the Ashkenazi masechta name (Siyum Masechta '
    'Shabbos) — not the raw Sefaria key',
    (tester) async {
      // English locale + default (Ashkenazi) nusach: the raw key "Shabbat"
      // must transliterate to "Shabbos" inside the "Siyum Masechta " frame.
      await tester.pumpWidget(
        _host(
          viewModel: _unitViewModel(),
          content: const {
            CurriculumId.bavli: [_shabbosContent],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Siyum Masechta Shabbos'), findsOneWidget);
      // The raw Sefaria storage key must NOT leak into the timeline row.
      expect(find.textContaining('Shabbat'), findsNothing);
    },
  );

  testWidgets(
    'unit milestone renders the Hebrew masechta name (שבת) in Hebrew-terms mode',
    (tester) async {
      await tester.pumpWidget(
        _host(
          viewModel: _unitViewModel(),
          useHebrewTerms: true,
          locale: const Locale('he'),
          content: const {
            CurriculumId.bavli: [_shabbosContent],
          },
        ),
      );
      await tester.pumpAndSettle();

      // The Hebrew masechta name "שבת" is framed by the Hebrew "סיום מסכת".
      expect(find.text('סיום מסכת שבת'), findsOneWidget);
      expect(find.textContaining('Shabbat'), findsNothing);
      expect(find.textContaining('Shabbos'), findsNothing);
    },
  );

  testWidgets('aggregate milestone resolves the seder name to its Hebrew form '
      '(Siyum Seder {Hebrew name}) — not the raw Sefaria key', (tester) async {
    // A Mishnayos seder-complete milestone whose raw aggregate key is the
    // Sefaria value "Tahorot". The curriculum content supplies the Hebrew
    // seder name "טהרות" at level 1, so Hebrew-terms mode must frame the
    // Hebrew seder name inside "סיום סדר" rather than leaking "Tahorot".
    const tahorot = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Tahorot',
      level2: 'Keilim',
      displayNameHe: 'כלים',
      displayNameEn: 'Keilim',
      sefariaRef: 'Mishnah Kelim',
      sortOrder: 0,
      isLeaf: false,
    );
    // A second content row that actually carries the seder's Hebrew name at
    // level 1 (the leaf's displayNameHe is the masechta, but the renderer
    // matches on level1 == rawValue and reads that row's Hebrew name).
    const tahorotSeder = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Tahorot',
      displayNameHe: 'טהרות',
      displayNameEn: 'Tahoros',
      sefariaRef: 'Tahorot',
      sortOrder: 0,
      isLeaf: false,
    );
    final viewModel = JourneyViewModel(
      curricula: [
        CurriculumJourney(
          curriculumId: CurriculumId.mishnayos,
          completions: const [],
          uniqueUnitsCompleted: 1,
          totalUnitsAvailable: 63,
          milestones: [
            MilestoneAchievement(
              type: 'seder_complete',
              level: MilestoneLevel.aggregate,
              curriculumId: CurriculumId.mishnayos,
              displayName: 'Tahorot',
              aggregateKey: 'Tahorot',
              containedUnitKeys: const ['Keilim'],
              achievedAt: DateTime(2026, 5, 11),
            ),
          ],
        ),
      ],
      totalCompletions: 0,
      totalUniqueUnits: 1,
      unitLevelSiyumimCount: 0,
      aggregateLevelSiyumimCount: 1,
      curriculumLevelSiyumimCount: 0,
    );

    await tester.pumpWidget(
      _host(
        viewModel: viewModel,
        useHebrewTerms: true,
        locale: const Locale('he'),
        content: const {
          CurriculumId.mishnayos: [tahorotSeder, tahorot],
        },
      ),
    );
    await tester.pumpAndSettle();

    // The Hebrew seder name "טהרות" framed by the Hebrew "סיום סדר".
    expect(find.text('סיום סדר טהרות'), findsOneWidget);
    // The raw Sefaria storage key must NOT leak into the aggregate row.
    expect(find.textContaining('Tahorot'), findsNothing);
  });

  // ── Data-consistency fix (run-9 audit) ──────────────────────────────────
  //
  // A section bulk-marked "previously learned" is stamped with the
  // bulk-prior sentinel date (kBulkPriorSentinelDate, 2000-01-01 UTC). The
  // timeline used to format that sentinel through DateFormat.yMMMd for the
  // per-row date AND group it under a real-looking "Jan 2000" month header —
  // both surfaced the bogus date to the user. These tests pin that both
  // spots instead show the localized "Previously learned" string; the
  // stored sentinel itself is untouched.

  JourneyViewModel sentinelUnitViewModelWithDate(DateTime achievedAt) =>
      JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.bavli,
            completions: const [],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 63,
            milestones: [
              MilestoneAchievement(
                type: 'unit_complete',
                level: MilestoneLevel.unit,
                curriculumId: CurriculumId.bavli,
                displayName: 'Shabbat',
                unitKey: 'Shabbat',
                unitScope: 'masechta',
                achievedAt: achievedAt,
              ),
            ],
          ),
        ],
        totalCompletions: 0,
        totalUniqueUnits: 1,
        unitLevelSiyumimCount: 1,
        aggregateLevelSiyumimCount: 0,
        curriculumLevelSiyumimCount: 0,
      );

  testWidgets(
    'a sentinel-dated milestone shows "Previously learned" as both the '
    'row subtitle date and the month-group header — not "Jan 2000"',
    (tester) async {
      await tester.pumpWidget(
        _host(
          viewModel: sentinelUnitViewModelWithDate(kBulkPriorSentinelDate),
          content: const {
            CurriculumId.bavli: [_shabbosContent],
          },
        ),
      );
      await tester.pumpAndSettle();

      // Month-group header.
      expect(
        find.text('Previously learned'),
        findsWidgets,
        reason:
            'The month-group header for a sentinel-dated milestone must read '
            '"Previously learned", not a formatted "Jan 2000".',
      );
      expect(
        find.textContaining('2000'),
        findsNothing,
        reason:
            'The sentinel year must never leak into the timeline as a bogus '
            'month header or row date (the run-9 audit finding).',
      );
      // Row subtitle date fragment (" · Previously learned").
      expect(find.textContaining(' · Previously learned'), findsOneWidget);
    },
  );

  testWidgets(
    'sentinel-dated and real-dated milestones group under separate headers '
    '— the sentinel does not merge into a real month bucket',
    (tester) async {
      final realDate = DateTime(2026, 3, 10);
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.bavli,
            completions: const [],
            uniqueUnitsCompleted: 2,
            totalUnitsAvailable: 63,
            milestones: [
              MilestoneAchievement(
                type: 'unit_complete',
                level: MilestoneLevel.unit,
                curriculumId: CurriculumId.bavli,
                displayName: 'Shabbat',
                unitKey: 'Shabbat',
                unitScope: 'masechta',
                achievedAt: realDate,
              ),
              MilestoneAchievement(
                type: 'unit_complete',
                level: MilestoneLevel.unit,
                curriculumId: CurriculumId.bavli,
                displayName: 'Berakhot',
                unitKey: 'Berakhot',
                unitScope: 'masechta',
                achievedAt: kBulkPriorSentinelDate,
              ),
            ],
          ),
        ],
        totalCompletions: 0,
        totalUniqueUnits: 2,
        unitLevelSiyumimCount: 2,
        aggregateLevelSiyumimCount: 0,
        curriculumLevelSiyumimCount: 0,
      );

      await tester.pumpWidget(_host(viewModel: viewModel));
      await tester.pumpAndSettle();

      final realHeader = DateFormat.yMMM('en_US').format(realDate);
      expect(find.text(realHeader), findsOneWidget);
      expect(find.text('Previously learned'), findsOneWidget);
      expect(find.textContaining('2000'), findsNothing);
    },
  );
}
