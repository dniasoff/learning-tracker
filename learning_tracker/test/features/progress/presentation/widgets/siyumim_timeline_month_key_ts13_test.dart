/// Regression test for TS-13 — timeline month headers must be locale-aware.
///
/// Root cause: [SiyumimTimelineView._monthKey()] indexed a hardcoded English
/// [months] array regardless of the active locale, so a French, Hebrew, or
/// any non-English locale still rendered "January 2026" instead of the
/// locale-appropriate equivalent.
///
/// The fix replaces the hardcoded array with [DateFormat.yMMM(locale)] so the
/// month header adapts to the locale just like the per-card date (which already
/// uses [formatMilestoneDate] / [DateFormat.yMMMd]).
@Tags(['progress', 'siyumim_milestones', 'ts13'])
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
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_timeline_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class _UseHebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

Widget _host({
  required JourneyViewModel viewModel,
  Locale locale = const Locale('en', 'US'),
  Map<CurriculumId, List<ContentItem>> content = const {},
}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(() => _UseHebrewTermsOff()),
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

/// Builds a ViewModel with a single unit milestone achieved on [date].
JourneyViewModel _vmWithDate(DateTime date) => JourneyViewModel(
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
          displayName: 'Berakhot',
          unitKey: 'Berakhot',
          unitScope: 'masechta',
          achievedAt: date,
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

void main() {
  // TS-13: the month header must NOT be the hardcoded English array result.
  group('Timeline month header is locale-aware (TS-13)', () {
    testWidgets(
      'en-US locale renders the locale-aware month header for January 2026',
      (tester) async {
        final date = DateTime(2026, 1, 15);
        // Compute the expected header via DateFormat — same mechanism the
        // fixed code must use. Note this en-US assertion by itself already
        // differs from the old hardcoded array's "January 2026" output
        // (DateFormat.yMMM abbreviates to "Jan 2026" — see the
        // format-string test below for that direct comparison). What it
        // does NOT prove is that the header is locale-aware rather than
        // English-only; the Hebrew-locale test further below renders under
        // Locale('he') and asserts a Hebrew-formatted header to close that
        // gap.
        final expected = DateFormat.yMMM('en_US').format(date);

        await tester.pumpWidget(_host(viewModel: _vmWithDate(date)));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
      },
    );

    testWidgets(
      'month header format matches DateFormat.yMMM output (not hardcoded "Month YYYY")',
      (tester) async {
        // The old code produced "January 2026" (full name + 4-digit year,
        // no comma).  DateFormat.yMMM('en_US') produces "Jan 2026" (abbreviated
        // name).  These are different strings, so asserting the DateFormat result
        // is present AND the old full-name form is absent confirms the switch.
        final date = DateTime(2026, 1, 15);
        final dateFormatHeader = DateFormat.yMMM('en_US').format(date);
        const oldHardcodedHeader = 'January 2026';

        await tester.pumpWidget(_host(viewModel: _vmWithDate(date)));
        await tester.pumpAndSettle();

        // The rendered month header must match the locale-aware DateFormat form.
        expect(find.text(dateFormatHeader), findsOneWidget);
        // It must NOT be the old hardcoded "January 2026" form.
        expect(find.text(oldHardcodedHeader), findsNothing);
      },
    );

    testWidgets(
      'milestones on different months produce separate locale-aware headers',
      (tester) async {
        final date1 = DateTime(2026, 3, 10);
        final date2 = DateTime(2025, 11, 5);
        final header1 = DateFormat.yMMM('en_US').format(date1);
        final header2 = DateFormat.yMMM('en_US').format(date2);

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
                  achievedAt: date1,
                ),
                MilestoneAchievement(
                  type: 'unit_complete',
                  level: MilestoneLevel.unit,
                  curriculumId: CurriculumId.bavli,
                  displayName: 'Berakhot',
                  unitKey: 'Berakhot',
                  unitScope: 'masechta',
                  achievedAt: date2,
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

        expect(find.text(header1), findsOneWidget);
        expect(find.text(header2), findsOneWidget);
      },
    );

    testWidgets(
      'he locale renders a Hebrew-formatted month header, not the old '
      'hardcoded English form',
      (tester) async {
        // This is the actual locale-switch regression test: it renders under
        // a non-English locale and asserts the header follows suit, which is
        // what the old hardcoded English `months` array could never do (it
        // would render "January 2026" regardless of the active locale).
        final date = DateTime(2026, 1, 15);

        await tester.pumpWidget(
          _host(viewModel: _vmWithDate(date), locale: const Locale('he')),
        );
        await tester.pumpAndSettle();

        // Compute the expected header only after pumping — the Hebrew intl
        // locale data is registered as a side effect of loading the 'he'
        // localizations delegate, the same pattern used elsewhere in this
        // codebase (see siyumim_grouped_view_test.dart's Hebrew-locale case).
        final expected = DateFormat.yMMM('he').format(date);

        // The rendered month header must match the Hebrew-locale-aware
        // DateFormat form …
        expect(find.text(expected), findsOneWidget);
        // … and must NOT be the old hardcoded English form, which a
        // locale-blind implementation would still produce even when the
        // active locale is Hebrew.
        expect(find.text('January 2026'), findsNothing);
      },
    );
  });
}
