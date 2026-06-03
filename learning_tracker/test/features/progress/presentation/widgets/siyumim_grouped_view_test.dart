/// Widget tests for [SiyumimGroupedView] — covers Wave 7-C / F8:
///
///   * The empty state renders the localized string (no hardcoded English).
///   * The aggregate-row subtitle is built via the l10n template
///     `siyumimAggregateSubtitle({count}, {date})`.
///   * Dates flow through `DateFormat.yMMMd(locale)` so a Hebrew locale
///     produces locale-aware formatting instead of the legacy `d/M/yyyy`
///     numeric form.
@Tags(['progress', 'siyumim_milestones'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_grouped_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Pins the Hebrew Terms toggle to a known value so the per-row siyum
/// labels (Siyum Seder Zeraim, Siyum Masechta …) stay deterministic — we
/// only assert empty-state / date formatting in this file.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

/// Pins the transliteration nusach so the aggregate seder name (Tahoros vs
/// Tahorot) is deterministic across the grouped-view tests.
class _VariantOverride extends CurrentTransliterationVariant {
  _VariantOverride(this.variant);
  final TransliterationVariant variant;
  @override
  TransliterationVariant build() => variant;
}

Widget _host({
  required JourneyViewModel viewModel,
  Locale? locale,
  bool useHebrewTerms = false,
  TransliterationVariant variant = TransliterationVariant.ashkenazi,
  Map<CurriculumId, List<ContentItem>> content = const {},
}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: useHebrewTerms),
      ),
      currentTransliterationVariantProvider.overrideWith(
        () => _VariantOverride(variant),
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
      home: Scaffold(body: SiyumimGroupedView(viewModel: viewModel)),
    ),
  );
}

JourneyViewModel _emptyViewModel() => const JourneyViewModel(
  curricula: [],
  totalCompletions: 0,
  totalUniqueUnits: 0,
  unitLevelSiyumimCount: 0,
  aggregateLevelSiyumimCount: 0,
  curriculumLevelSiyumimCount: 0,
);

JourneyViewModel _viewModelWithCompletedAggregate({
  required DateTime achievedAt,
}) {
  return JourneyViewModel(
    curricula: [
      CurriculumJourney(
        curriculumId: CurriculumId.mishnayos,
        completions: const [],
        uniqueUnitsCompleted: 11,
        totalUnitsAvailable: 63,
        milestones: [
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
        ],
      ),
    ],
    totalCompletions: 0,
    totalUniqueUnits: 11,
    unitLevelSiyumimCount: 0,
    aggregateLevelSiyumimCount: 1,
    curriculumLevelSiyumimCount: 0,
  );
}

void main() {
  testWidgets('F8 — empty state uses the localized string (English locale)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(viewModel: _emptyViewModel()));
    await tester.pumpAndSettle();

    expect(find.text('No siyumim yet — keep learning!'), findsOneWidget);
  });

  testWidgets('F8 — empty state uses the localized string (Hebrew locale)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(viewModel: _emptyViewModel(), locale: const Locale('he')),
    );
    await tester.pumpAndSettle();

    // The exact Hebrew text from app_he.arb must surface — proves the
    // hardcoded English (F8) is gone.
    expect(find.text('אין סיומים עדיין — המשיכו ללמוד!'), findsOneWidget);
    // And the previous English literal must be absent so we don't leak
    // mixed-language content to a Hebrew user.
    expect(find.text('No siyumim yet — keep learning!'), findsNothing);
  });

  testWidgets(
    'F8 — aggregate subtitle pre-formats the date via DateFormat.yMMMd(en)',
    (tester) async {
      final achieved = DateTime(2026, 5, 11);
      await tester.pumpWidget(
        _host(
          viewModel: _viewModelWithCompletedAggregate(achievedAt: achieved),
        ),
      );
      await tester.pumpAndSettle();

      // The ARB template "All {count} complete · {date}" must resolve with
      // a locale-formatted date — DateFormat.yMMMd('en') yields "May 11,
      // 2026" — proving the legacy d/M/yyyy formatter is gone.
      final expectedDate = DateFormat.yMMMd('en').format(achieved.toLocal());
      expect(
        find.text('All 11 complete · $expectedDate'),
        findsOneWidget,
        reason:
            'F8: aggregate subtitle must come from siyumimAggregateSubtitle '
            'with the date already locale-formatted (no more raw $achieved '
            'd/M/yyyy form)',
      );
    },
  );

  testWidgets('F8 — aggregate subtitle date respects Hebrew locale', (
    tester,
  ) async {
    final achieved = DateTime(2026, 5, 11);
    await tester.pumpWidget(
      _host(
        viewModel: _viewModelWithCompletedAggregate(achievedAt: achieved),
        locale: const Locale('he'),
      ),
    );
    await tester.pumpAndSettle();

    // Under Locale('he') the DateFormat.yMMMd helper renders the month
    // name in Hebrew. We don't pin the exact glyphs (intl bundle may
    // shift) — instead we assert the legacy English `5/11/2026`-style
    // numeric form is gone AND that the date is somewhere in the
    // rendered ARB template "כל {count} הושלמו · {date}".
    final expectedDate = DateFormat.yMMMd('he').format(achieved.toLocal());
    expect(
      find.text('כל 11 הושלמו · $expectedDate'),
      findsOneWidget,
      reason:
          'F8: the aggregate subtitle in Hebrew must use Hebrew vocabulary '
          'AND a locale-aware DateFormat.yMMMd(he) date',
    );
    // The legacy d/M/yyyy formatter would have produced "11/5/2026" — it
    // must not appear in the widget tree.
    expect(find.text('11/5/2026'), findsNothing);
  });

  testWidgets(
    'contained-unit rows render the Hebrew masechta name in Hebrew-terms mode '
    '(no raw storage key leak)',
    (tester) async {
      // Bavli aggregate (Seder Zeraim) containing one masechta whose raw
      // content key is "Berakhos". The curriculum content supplies the
      // Hebrew name "ברכות" for that level-2 key.
      const berakhos = ContentItem(
        curriculumId: 'bavli',
        level1: 'Zeraim',
        level2: 'Berakhos',
        displayNameHe: 'ברכות',
        displayNameEn: 'Berakhos',
        sefariaRef: 'Berakhot',
        sortOrder: 0,
        isLeaf: false,
      );
      final viewModel = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.bavli,
            completions: const [],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 63,
            milestones: [
              MilestoneAchievement(
                type: 'seder_complete',
                level: MilestoneLevel.aggregate,
                curriculumId: CurriculumId.bavli,
                displayName: 'Zeraim',
                aggregateKey: 'Zeraim',
                containedUnitKeys: const ['Berakhos'],
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
          content: const {
            CurriculumId.bavli: [berakhos],
          },
        ),
      );
      await tester.pumpAndSettle();

      // Expand the aggregate tile so the contained-unit rows render.
      await tester.tap(find.byIcon(Icons.workspace_premium));
      await tester.pumpAndSettle();

      // The contained masechta must render via the shared CurriculumLabel
      // control as the Hebrew name "ברכות" — NOT the raw storage key.
      expect(find.text('ברכות'), findsOneWidget);
      expect(find.text('Berakhos'), findsNothing);
    },
  );

  testWidgets('standalone unit row resolves the masechta name variant-awarely '
      '(Hebrew-terms mode shows the Hebrew name in the Siyum Masechta frame)', (
    tester,
  ) async {
    // A standalone (un-absorbed) masechta-level siyum. Its raw key is the
    // Sefaria value "Shabbat"; the curriculum content supplies the Hebrew
    // name "שבת". Under Hebrew-terms mode the row must read "סיום מסכת שבת"
    // — proving the unit NAME flows through the variant-aware renderer
    // rather than leaking the raw key into the label frame.
    const shabbos = ContentItem(
      curriculumId: 'bavli',
      level1: 'Moed',
      level2: 'Shabbat',
      displayNameHe: 'שבת',
      displayNameEn: 'Shabbos',
      sefariaRef: 'Shabbat',
      sortOrder: 0,
      isLeaf: false,
    );
    final viewModel = JourneyViewModel(
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

    await tester.pumpWidget(
      _host(
        viewModel: viewModel,
        useHebrewTerms: true,
        locale: const Locale('he'),
        content: const {
          CurriculumId.bavli: [shabbos],
        },
      ),
    );
    await tester.pumpAndSettle();

    // The Hebrew masechta name "שבת" is framed by the Hebrew "סיום מסכת".
    expect(find.text('סיום מסכת שבת'), findsOneWidget);
    // The raw English storage key must NOT leak into the row.
    expect(find.textContaining('Shabbat'), findsNothing);
  });

  // ── Aggregate (seder) name transliteration — the P1 fix ────────────────────
  //
  // The aggregate tile previously passed `milestone.aggregateKey` RAW into
  // aggregateSiyumLabel, so "Siyum Seder Tahorot" never transliterated (always
  // the raw academic/Sephardi form, even under the Ashkenazi nusach). These
  // tests pin the milestone to a Tahorot-seder Mishnayos aggregate (the one
  // seder whose name differs by nusach) and assert it resolves variant-awarely.

  JourneyViewModel tahorotAggregate() => JourneyViewModel(
    curricula: [
      CurriculumJourney(
        curriculumId: CurriculumId.mishnayos,
        completions: const [],
        uniqueUnitsCompleted: 12,
        totalUnitsAvailable: 63,
        milestones: [
          MilestoneAchievement(
            type: 'seder_complete',
            level: MilestoneLevel.aggregate,
            curriculumId: CurriculumId.mishnayos,
            displayName: 'Tahorot',
            aggregateKey: 'Tahorot',
            containedUnitKeys: const [],
            achievedAt: DateTime(2026, 5, 11),
          ),
        ],
      ),
    ],
    totalCompletions: 0,
    totalUniqueUnits: 12,
    unitLevelSiyumimCount: 0,
    aggregateLevelSiyumimCount: 1,
    curriculumLevelSiyumimCount: 0,
  );

  // Content row supplying the Hebrew seder name for the level-1 key "Tahorot",
  // so Hebrew-terms mode can render "טהרות" instead of transliterating.
  const tahorotSeder = ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Tahorot',
    displayNameHe: 'טהרות',
    displayNameEn: 'Tahorot',
    sefariaRef: 'Tahorot',
    sortOrder: 0,
    isLeaf: false,
  );

  testWidgets(
    'aggregate seder name transliterates to Ashkenazi (Tahoros) — not raw',
    (tester) async {
      await tester.pumpWidget(
        _host(
          viewModel: tahorotAggregate(),
          content: const {
            CurriculumId.mishnayos: [tahorotSeder],
          },
        ),
      );
      await tester.pumpAndSettle();

      // Ashkenazi nusach: "Tahorot" → "Taharos", framed by "Siyum Seder".
      expect(find.text('Siyum Seder Taharos'), findsOneWidget);
      // The raw academic key must NOT leak through.
      expect(find.text('Siyum Seder Tahorot'), findsNothing);
    },
  );

  testWidgets('aggregate seder name transliterates to Sephardi (Tahorot)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        viewModel: tahorotAggregate(),
        variant: TransliterationVariant.sephardi,
        content: const {
          CurriculumId.mishnayos: [tahorotSeder],
        },
      ),
    );
    await tester.pumpAndSettle();

    // Sephardi nusach keeps "Tahorot"; the Ashkenazi form must be absent.
    expect(find.text('Siyum Seder Tahorot'), findsOneWidget);
    expect(find.text('Siyum Seder Taharos'), findsNothing);
  });

  testWidgets('aggregate seder name renders the Hebrew seder name '
      'in Hebrew-terms mode', (tester) async {
    await tester.pumpWidget(
      _host(
        viewModel: tahorotAggregate(),
        useHebrewTerms: true,
        locale: const Locale('he'),
        content: const {
          CurriculumId.mishnayos: [tahorotSeder],
        },
      ),
    );
    await tester.pumpAndSettle();

    // Hebrew-terms mode: the Hebrew seder name "טהרות" framed by "סיום סדר".
    expect(find.text('סיום סדר טהרות'), findsOneWidget);
    // No raw Latin key in Hebrew mode.
    expect(find.textContaining('Tahorot'), findsNothing);
  });
}
