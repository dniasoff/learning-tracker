/// Rework regression: OverallStatsCard is TWO clearly-labelled scope
/// sections, not one card that mixes scopes.
///
/// Owner decision 2026-07-28 (`docs/planning/post-sweep-decisions.md` #3):
/// the card must present the track-scoped current-cycle numbers and the
/// whole-curriculum lifetime numbers under SEPARATE, explicit scope headers,
/// so "Not started 858" (track scope) can never read as contradictory beside
/// "Lifetime 100%" (whole curriculum). Both numbers are correct; they answer
/// different questions. This suite pins:
///   * both scope headers render;
///   * the current-cycle % sits under Section A ("This track · this cycle");
///   * the lifetime % sits under Section B ("Whole [curriculum] · lifetime");
///   * the track-scoped count rows sit under Section A, and the
///     whole-curriculum "items touched" line under Section B.
///
/// Placement is asserted by vertical order (the card is one top-to-bottom
/// Column), so moving a value into the wrong section — or dropping a header —
/// fails the test. RED-DEMO: revert either scope header (or swap the two
/// fractions' placement) in overall_stats_card.dart → these fail; restore →
/// pass.
@Tags(['progress', 'curriculum_progress'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';

import '../../../../helpers/pump_app.dart';

// Distinct counts so no stat value collides with a percentage string.
const _stats = OverallCurriculumStats(
  totalItems: 200,
  completedAllStages: 30,
  inProgress: 20,
  notStarted: 150,
);

const _sectionAHeader = 'This track · this cycle';
const _sectionBHeaderEn = 'Whole Mishnayos · lifetime';

Widget _card({Locale locale = const Locale('en'), String? curriculumName}) {
  return pumpApp(
    locale: locale,
    child: Scaffold(
      body: SingleChildScrollView(
        child: OverallStatsCard(
          stats: _stats,
          // Section A headline — time-gated current-cycle %.
          trackProgressFraction: 0.10,
          // Section B headline — whole-curriculum lifetime %.
          lifetimeFraction: 0.42,
          // Section B "items touched X / total" line — whole-curriculum.
          lifetimeLearnedCount: 42,
          lifetimeTotalCount: 100,
          curriculumName: curriculumName ?? 'Mishnayos',
        ),
      ),
    ),
  );
}

/// Vertical position of the single text [t] inside the card.
double _dyOf(WidgetTester tester, String t) {
  final finder = find.descendant(
    of: find.byType(OverallStatsCard),
    matching: find.text(t),
  );
  expect(finder, findsOneWidget, reason: 'expected exactly one "$t" in card');
  return tester.getTopLeft(finder).dy;
}

void main() {
  group('OverallStatsCard — two labelled scope sections', () {
    testWidgets('both scope headers render', (tester) async {
      await tester.pumpWidget(_card());
      await tester.pumpAndSettle();

      expect(
        find.text(_sectionAHeader),
        findsOneWidget,
        reason:
            'Section A must carry the explicit "This track · this cycle" '
            'scope header.',
      );
      expect(
        find.text(_sectionBHeaderEn),
        findsOneWidget,
        reason:
            'Section B must carry the explicit whole-curriculum lifetime '
            'scope header naming the curriculum.',
      );
    });

    testWidgets(
      'the current-cycle % sits under Section A, the lifetime % under Section B',
      (tester) async {
        await tester.pumpWidget(_card());
        await tester.pumpAndSettle();

        final aHeaderDy = _dyOf(tester, _sectionAHeader);
        final bHeaderDy = _dyOf(tester, _sectionBHeaderEn);
        final cyclePctDy = _dyOf(tester, '10%');
        final lifetimePctDy = _dyOf(tester, '42%');

        expect(
          aHeaderDy < bHeaderDy,
          isTrue,
          reason:
              'Section A (this track · this cycle) must come before '
              'Section B (whole curriculum · lifetime).',
        );
        expect(
          aHeaderDy < cyclePctDy && cyclePctDy < bHeaderDy,
          isTrue,
          reason:
              'The current-cycle % (10%) must sit under Section A, above '
              'the Section B header — it is track/cycle-scoped, not lifetime.',
        );
        expect(
          lifetimePctDy > bHeaderDy,
          isTrue,
          reason:
              'The lifetime % (42%) must sit under Section B — it is the '
              'whole-curriculum figure.',
        );
      },
    );

    testWidgets(
      'track-scoped count rows sit under Section A; items-touched under Section B',
      (tester) async {
        await tester.pumpWidget(_card());
        await tester.pumpAndSettle();

        final aHeaderDy = _dyOf(tester, _sectionAHeader);
        final bHeaderDy = _dyOf(tester, _sectionBHeaderEn);

        // Track-scoped breakdown — Section A.
        for (final label in const [
          'Total items',
          'Completed all stages',
          'In progress',
          'Not started',
        ]) {
          final dy = _dyOf(tester, label);
          expect(
            dy > aHeaderDy && dy < bHeaderDy,
            isTrue,
            reason:
                '"$label" is track/scope-scoped and must sit under '
                'Section A (between the two scope headers).',
          );
        }

        // Whole-curriculum "items touched X / total" — Section B.
        final touchedDy = _dyOf(tester, 'Items touched');
        expect(
          touchedDy > bHeaderDy,
          isTrue,
          reason:
              'The whole-curriculum "items touched" line must sit under '
              'Section B.',
        );
        // The value reads distinct whole-curriculum counts (42 of 100), not
        // the track-scoped totals — proving the two scopes are not conflated.
        expect(
          find.descendant(
            of: find.byType(OverallStatsCard),
            matching: find.text('42 of 100'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Hebrew (RTL): both scope headers render localized', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(locale: const Locale('he'), curriculumName: 'משניות'),
      );
      await tester.pumpAndSettle();

      expect(find.text('המסלול הזה · המחזור הזה'), findsOneWidget);
      expect(find.text('כל משניות · ידע כולל'), findsOneWidget);
      // English scope headers must not leak in the Hebrew locale.
      expect(find.text(_sectionAHeader), findsNothing);
    });
  });
}
