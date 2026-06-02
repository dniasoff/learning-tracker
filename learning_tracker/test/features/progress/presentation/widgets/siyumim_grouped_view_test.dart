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
}
