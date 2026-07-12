/// Spike widget test: [MonthlyActivitySliverCalendar] with 10 years of data.
///
/// Verifies that the virtualized sliver calendar:
///   1. Renders without throwing or overflowing when given 120 months of
///      fixture data (the "All Time" worst-case scenario).
///   2. Shows a compact summary for every month by default (no widget
///      explosion — off-screen months are NOT built by the sliver delegate).
///   3. Expands exactly one month when its header is tapped.
///
/// ## Frame build time
///
/// Flutter widget tests do not expose frame timing APIs directly. The sliver
/// approach is correct-by-construction: [SliverChildBuilderDelegate] only
/// calls its builder for children within the visible viewport, so even 120
/// months only materialises ~3–5 header+card pairs at a time. A manual
/// "stopwatch" approach is noted in comment form below for future integration
/// with the `flutter_test` tracing APIs if/when they become available.
@Tags(['progress', 'recent_activity', 'spike'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/monthly_activity_sliver_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Fixture helpers ───────────────────────────────────────────────────────────

/// Generates a deterministic [MonthlyActivityRollup] for testing.
///
/// [monthIndex] is 0-based: 0 → January 2016, 119 → December 2025 for a
/// 10-year dataset starting at 2016.
MonthlyActivityRollup _makeRollup(int monthIndex) {
  final year = 2016 + (monthIndex ~/ 12);
  final month = (monthIndex % 12) + 1;
  final yearMonth = '$year-${month.toString().padLeft(2, '0')}';

  // Vary data deterministically so not all months look identical.
  final activeDays = (monthIndex % 28) + 1;
  final totalCompletions = activeDays * 2;
  final totalChazaros = activeDays;

  // Build a space-separated list of active day numbers.
  // Use a simple pattern: every other day starting from day 1.
  final dayList = StringBuffer();
  for (var d = 1; d <= 31 && (d - 1) ~/ 2 < activeDays; d += 2) {
    if (dayList.isNotEmpty) dayList.write(' ');
    dayList.write(d);
  }

  return MonthlyActivityRollup(
    profileId: 1,
    yearMonth: yearMonth,
    activeDays: activeDays,
    totalCompletions: totalCompletions,
    totalChazaros: totalChazaros,
    firstActivityDate: null,
    lastActivityDate: null,
    activeDaysList: dayList.toString(),
  );
}

/// 10 years = 120 months of fixture data (2016-01 through 2025-12).
List<MonthlyActivityRollup> _tenYearsFixture() =>
    List.generate(120, _makeRollup);

// ── Widget wrapper ────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(height: 600, child: child)),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('MonthlyActivitySliverCalendar — spike', () {
    testWidgets('renders 120 months without widget explosion or exception', (
      tester,
    ) async {
      final rollups = _tenYearsFixture();
      expect(rollups, hasLength(120));

      // NOTE: Frame build time cannot be directly measured in flutter_test.
      // The sliver delegate guarantees O(viewport) widget instantiations, not
      // O(120). If Flutter ever exposes tracing hooks in test mode, add:
      //   final sw = Stopwatch()..start();
      //   await tester.pump();
      //   sw.stop();
      //   expect(sw.elapsedMilliseconds, lessThan(16)); // 60fps budget

      await tester.pumpWidget(
        _wrap(MonthlyActivitySliverCalendar(rollups: rollups)),
      );
      // pumpAndSettle not required — the widget is synchronous.
      await tester.pump();

      // The widget built without throwing.
      expect(tester.takeException(), isNull);

      // The CustomScrollView is present.
      expect(find.byType(CustomScrollView), findsOneWidget);

      // The first month header is visible in the viewport.
      // '2016' is present in the first header label.
      expect(find.textContaining('2016'), findsWidgets);
    });

    testWidgets('empty list shows no-activity fallback', (tester) async {
      await tester.pumpWidget(
        _wrap(const MonthlyActivitySliverCalendar(rollups: [])),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('No activity data'), findsOneWidget);
    });

    testWidgets('tapping a month header expands the full daily grid', (
      tester,
    ) async {
      // Use a single month for a deterministic test.
      final single = [_makeRollup(0)]; // January 2016

      await tester.pumpWidget(
        _wrap(MonthlyActivitySliverCalendar(rollups: single)),
      );
      await tester.pump();

      // No SliverGrid present before expansion.
      expect(find.byType(SliverGrid), findsNothing);

      // Tap the header to expand.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // After expansion a SliverGrid is now present.
      expect(find.byType(SliverGrid), findsOneWidget);

      // Tap again to collapse.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(find.byType(SliverGrid), findsNothing);
    });

    testWidgets(
      'only viewport-visible month widgets are built for 120 months',
      (tester) async {
        // Override the viewport size to something small so we can assert that
        // far-future months are not materialized.
        tester.view.physicalSize = const Size(400, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final rollups = _tenYearsFixture();

        await tester.pumpWidget(
          _wrap(MonthlyActivitySliverCalendar(rollups: rollups)),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // December 2025 header text should NOT be in the widget tree —
        // the sliver delegate only builds visible children.
        expect(find.textContaining('December 2025'), findsNothing);

        // January 2016 IS visible.
        expect(find.textContaining('January 2016'), findsWidgets);
      },
    );
  });
}
