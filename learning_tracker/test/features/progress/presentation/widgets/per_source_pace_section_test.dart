// Story 5.3 (DNI-518) AC-1, AC-4, AC-5, AC-8: the Per-source pace section
// renders the engine's per-source velocity unchanged, one row per source.
@Tags(['progress', 'lifetime', 'story_5_3'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/per_source_pace_section.dart';

import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/progress/pace_report_fixtures.dart';
import '../../../../helpers/pump_app.dart';

PaceReportView _pace(ReportProjection report) => PaceReportView.of(
  LifetimeReportView(
    curriculumId: report.curriculumId,
    curricula: [report.curriculumId],
    report: report,
  ),
  paceCurriculumState(report, shortfall: report.calendarProgram ? 2 : null),
)!;

Future<void> _pump(
  WidgetTester tester,
  ReportProjection report, {
  Size size = const Size(400, 1400),
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    pumpApp(
      child: Scaffold(
        body: SingleChildScrollView(
          child: PerSourcePaceSection(view: _pace(report)),
        ),
      ),
      overrides: [effectiveUseHebrewTermsProvider.overrideWithValue(false)],
      theme: AppTheme.themeFor(brightness: brightness),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _row(String source) => find.byKey(ValueKey('reportPaceRow-$source'));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// Every string painted on screen.
Iterable<String> _painted(WidgetTester tester) => [
  for (final t in tester.widgetList<RichText>(find.byType(RichText)))
    t.text.toPlainText(),
];

void main() {
  group('AC-1 renders Home and active source rows', () {
    testWidgets('one row per source with its chip, measured rate, trailing '
        'figure and estimate', (tester) async {
      await _pump(tester, paceReport());

      expect(find.text('Per-source pace'), findsOneWidget);
      expect(_row(LearningEvent.sourceMain), findsOneWidget);
      expect(_row(school2026), findsOneWidget);
      expect(_row(rebbeId), findsOneWidget);
      // No Before-tracking row.
      expect(_row(reportBeforeTrackingKey), findsNothing);
      expect(find.byType(PerSourcePaceRow), findsNWidgets(3));

      // Chips.
      expect(
        find.descendant(
          of: _row(LearningEvent.sourceMain),
          matching: find.widgetWithText(ReportSourceChip, 'Home'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row(school2026),
          matching: find.widgetWithText(ReportSourceChip, 'School'),
        ),
        findsOneWidget,
      );

      // Home: 48 leaves over 35 days = 9.6 / week; trailing 32 over 28.
      expect(_text(tester, 'reportPaceSince-main'), '9.6 / week');
      expect(
        _text(tester, 'reportPaceTrailing-main'),
        'Last 28 days: 8 / week',
      );
      // The curriculum's own leaf unit labels the rates.
      expect(
        find.descendant(
          of: _row(LearningEvent.sourceMain),
          matching: find.text('Since tracking started · Mishnayos per week'),
        ),
        findsOneWidget,
      );
      // School: 30 over 35 = 6 / week; estimate is the stored 10.
      expect(_text(tester, 'reportPaceSince-$school2026'), '6 / week');
      expect(
        _text(tester, 'reportPaceEstimate-$school2026'),
        '10 / week estimate',
      );
      expect(
        _text(tester, 'reportPaceEstimate-$rebbeId'),
        '5 / week estimate',
      );
    });

    testWidgets('the since-tracking figure is headline-small', (tester) async {
      await _pump(tester, paceReport());
      final theme = Theme.of(tester.element(_row(LearningEvent.sourceMain)));
      final style = tester
          .widget<Text>(find.byKey(const ValueKey('reportPaceSince-main')))
          .style!;
      expect(style.fontSize, theme.textTheme.headlineSmall!.fontSize);
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('Home has no estimate (a source with no estimate)', (
      tester,
    ) async {
      await _pump(tester, paceReport());
      expect(
        find.byKey(const ValueKey('reportPaceEstimate-main')),
        findsNothing,
      );
    });

    testWidgets('the footnote is exact', (tester) async {
      await _pump(tester, paceReport());
      expect(
        _text(tester, 'reportPaceFootnote'),
        "Before-tracking learning isn't counted in pace.",
      );
    });

    testWidgets('no "On pace" or "Steady" label anywhere', (tester) async {
      await _pump(tester, paceReport(ended2025: true, unknownSource: true));
      for (final text in _painted(tester)) {
        expect(text, isNot(contains('On pace')));
        expect(text, isNot(contains('Steady')));
        expect(text, isNot(contains('On track')));
        expect(text, isNot(contains('Behind')));
      }
    });
  });

  group('AC-4 short source history keeps the since-start rate', () {
    testWidgets('under 14 days: neutral "Too early to tell", since-tracking '
        'still shown', (tester) async {
      await _pump(tester, paceReport(homeDays: 13));
      expect(_text(tester, 'reportPaceTrailing-main'), 'Too early to tell');
      // 48 over 13 days.
      expect(_text(tester, 'reportPaceSince-main'), '25.8 / week');
      final context = tester.element(_row(LearningEvent.sourceMain));
      final color = tester
          .widget<Text>(find.byKey(const ValueKey('reportPaceTrailing-main')))
          .style!
          .color;
      expect(color, context.colors.brandInkMuted);
      expect(color, isNot(context.colors.brandWarning));
      expect(color, isNot(context.colors.brandWarningDeep));
    });

    testWidgets('exactly 14 days uses all of the history', (tester) async {
      await _pump(tester, paceReport(homeDays: 14));
      expect(
        _text(tester, 'reportPaceTrailing-main'),
        'Last 14 days: 16 / week',
      );
    });

    testWidgets('27 days uses all of it; 28 days and more caps at 28', (
      tester,
    ) async {
      await _pump(tester, paceReport(homeDays: 27));
      expect(
        _text(tester, 'reportPaceTrailing-main'),
        startsWith('Last 27 days:'),
      );
      await _pump(tester, paceReport(homeDays: 60));
      expect(
        _text(tester, 'reportPaceTrailing-main'),
        startsWith('Last 28 days:'),
      );
    });

    testWidgets('zero qualifying leaves reads 0 / week, not an error', (
      tester,
    ) async {
      final report = paceReport();
      final zero = ReportProjection(
        curriculumId: report.curriculumId,
        distinctLearnt: report.distinctLearnt,
        totalEvents: report.totalEvents,
        sources: {
          ...report.sources,
          LearningEvent.sourceMain: paceTotals(
            LearningEvent.sourceMain,
            paceVelocity(0, 30),
          ),
        },
        groups: report.groups,
        allSources: report.allSources,
        projectionStatus: report.projectionStatus,
      );
      await _pump(tester, zero);
      expect(_text(tester, 'reportPaceSince-main'), '0 / week');
      expect(
        _text(tester, 'reportPaceTrailing-main'),
        'Last 28 days: 0 / week',
      );
    });
  });

  group('AC-5 ended source uses its end date', () {
    for (final deleted in [false, true]) {
      testWidgets('${deleted ? 'deleted' : 'ended'}: "Ended", its own '
          'window, no estimate and no status', (tester) async {
        await _pump(
          tester,
          paceReport(ended2025: !deleted, deleted2025: deleted),
        );
        final row = _row(school2025);
        expect(row, findsOneWidget);
        expect(
          find.byKey(const ValueKey('reportPaceEnded-$school2025')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('Ended')),
          findsOneWidget,
        );
        // 12 leaves over its own 20 days (through its end day).
        expect(_text(tester, 'reportPaceSince-$school2025'), '4.2 / week');
        expect(
          find.byKey(const ValueKey('reportPaceEstimate-$school2025')),
          findsNothing,
        );
        for (final text in _painted(tester)) {
          expect(text, isNot(contains('estimate · ')));
        }
      });
    }

    testWidgets('a sub-track with no doc is an Ended sub-track row', (
      tester,
    ) async {
      await _pump(tester, paceReport(unknownSource: true));
      final row = _row('01J0000000000000000000UNKN');
      expect(
        find.descendant(
          of: row,
          matching: find.widgetWithText(ReportSourceChip, 'Ended sub-track'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Ended')),
        findsOneWidget,
      );
    });
  });

  testWidgets('AC-8 calendar curriculum: no sub-track pace rows', (
    tester,
  ) async {
    await _pump(tester, paceReport(calendarProgram: true));
    expect(find.byType(PerSourcePaceRow), findsOneWidget);
    expect(_row(LearningEvent.sourceMain), findsOneWidget);
    expect(_row(school2026), findsNothing);
    expect(_row(rebbeId), findsNothing);
  });

  group('layout (UX-DR-156, UX-DR-161, UX-DR-164)', () {
    for (final (name, size, brightness, locale) in [
      ('narrow phone', const Size(320, 1600), Brightness.light, 'en'),
      ('dark', const Size(400, 1400), Brightness.dark, 'en'),
      ('tablet', const Size(1024, 1400), Brightness.light, 'en'),
      ('Hebrew narrow', const Size(320, 1600), Brightness.light, 'he'),
    ]) {
      testWidgets('$name: no overflow', (tester) async {
        await _pump(
          tester,
          paceReport(ended2025: true),
          size: size,
          brightness: brightness,
          locale: Locale(locale),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(PerSourcePaceRow), findsNWidgets(4));
      });
    }
  });

  testWidgets('each row is one screen-reader node with its figures', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, paceReport());
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Home · Since tracking started · Mishnayos per week: '
          r'9\.6 / week · Last 28 days: 8 / week$',
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
