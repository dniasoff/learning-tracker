// Story 5.2 (DNI-517): the report's sections render the engine's
// projection numbers unchanged: totals, By source (one row per source) and
// School years disclosures (AC-1, AC-3, AC-4, AC-5, AC-8).
@Tags(['progress', 'lifetime', 'story_5_2'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';

import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/pump_app.dart';

LifetimeReportView _view(ReportProjection report) => LifetimeReportView(
  curriculumId: report.curriculumId,
  curricula: [report.curriculumId],
  report: report,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    pumpApp(
      child: Scaffold(body: SingleChildScrollView(child: child)),
      overrides: [effectiveUseHebrewTermsProvider.overrideWithValue(false)],
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

/// Everything painted under [finder], as plain text.
String _painted(WidgetTester tester, Finder finder) => [
  for (final t in tester.widgetList<RichText>(
    find.descendant(of: finder, matching: find.byType(RichText)),
  ))
    t.text.toPlainText(),
].join(' | ');

final _distinct = find.byKey(const ValueKey('lifetimeReportDistinct'));
final _events = find.byKey(const ValueKey('lifetimeReportEvents'));

void main() {
  group('formatReportCount', () {
    testWidgets('groups thousands for the locale', (tester) async {
      late String en;
      await tester.pumpWidget(
        pumpApp(
          child: Builder(
            builder: (context) {
              en = formatReportCount(context, 1204);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(en, '1,204');
    });
  });

  group('LifetimeReportCard', () {
    testWidgets('shows its title as a header and its child', (tester) async {
      await _pump(
        tester,
        const LifetimeReportCard(title: 'Hello', child: Text('body')),
      );
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('omits the title when none is given', (tester) async {
      await _pump(tester, const LifetimeReportCard(child: Text('body')));
      expect(find.text('body'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('LifetimeReportTotals', () {
    testWidgets('shows the projection totals unchanged with the unit', (
      tester,
    ) async {
      await _pump(tester, LifetimeReportTotals(view: _view(fullReport())));
      expect(
        _painted(tester, _distinct),
        allOf(contains('1,204'), contains('Mishnayos')),
      );
      expect(_painted(tester, _events), contains('2,040'));
    });

    testWidgets('a single leaf takes the singular unit', (tester) async {
      await _pump(
        tester,
        LifetimeReportTotals(
          view: _view(
            ReportProjection(
              curriculumId: reportCurriculum,
              distinctLearnt: 1,
              totalEvents: 1,
              sources: const {},
            ),
          ),
        ),
      );
      expect(_painted(tester, _distinct), contains('1 Mishna'));
      expect(_painted(tester, _distinct), isNot(contains('Mishnayos')));
    });

    testWidgets('an empty report shows zero totals', (tester) async {
      await _pump(
        tester,
        LifetimeReportTotals(
          view: _view(
            ReportProjection(
              curriculumId: reportCurriculum,
              distinctLearnt: 0,
              totalEvents: 0,
              sources: const {},
            ),
          ),
        ),
      );
      expect(_painted(tester, _distinct), contains('0'));
      expect(_painted(tester, _events), contains('0'));
    });

    testWidgets('stacks the tiles on a narrow screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: LifetimeReportTotals(view: _view(fullReport())),
          ),
          overrides: [effectiveUseHebrewTermsProvider.overrideWithValue(false)],
        ),
      );
      await tester.pumpAndSettle();
      final a = tester.getTopLeft(
        find.byKey(const ValueKey('lifetimeReportDistinct')),
      );
      final b = tester.getTopLeft(
        find.byKey(const ValueKey('lifetimeReportEvents')),
      );
      expect(b.dy, greaterThan(a.dy));
      expect(b.dx, a.dx);
    });

    testWidgets('sits side by side when there is room', (tester) async {
      await _pump(tester, LifetimeReportTotals(view: _view(fullReport())));
      final a = tester.getTopLeft(
        find.byKey(const ValueKey('lifetimeReportDistinct')),
      );
      final b = tester.getTopLeft(
        find.byKey(const ValueKey('lifetimeReportEvents')),
      );
      expect(b.dy, a.dy);
      expect(b.dx, greaterThan(a.dx));
    });
  });

  group('ReportSourceChip', () {
    for (final (kind, icon) in [
      (LifetimeReportSourceKind.home, Icons.home_outlined),
      (LifetimeReportSourceKind.schoolYear, Icons.school_outlined),
      (LifetimeReportSourceKind.ongoing, Icons.person_outline),
      (LifetimeReportSourceKind.unknown, Icons.alt_route),
      (LifetimeReportSourceKind.beforeTracking, Icons.history),
    ]) {
      testWidgets('${kind.name} shows its label and icon', (tester) async {
        await _pump(tester, ReportSourceChip(kind: kind, label: 'Label'));
        expect(find.text('Label'), findsOneWidget);
        expect(find.byIcon(icon), findsOneWidget);
      });
    }
  });

  group('LifetimeReportBySource', () {
    testWidgets('one row per projection source with its own counts', (
      tester,
    ) async {
      final report = fullReport();
      await _pump(tester, LifetimeReportBySource(view: _view(report)));
      expect(find.text('By source'), findsOneWidget);
      for (final row in _view(report).sourceRows) {
        expect(
          find.byKey(ValueKey('lifetimeReportSource-${row.totals.source}')),
          findsOneWidget,
        );
      }
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Before tracking'), findsOneWidget);
      expect(find.text('Rebbe'), findsOneWidget);
      expect(find.text('1,020 learning events · 700 Mishnayos'), findsOne);
      expect(find.text('2024–25'), findsOneWidget);
    });

    testWidgets('an unknown sub-track is labelled, not dropped', (
      tester,
    ) async {
      const ghost = '01J00000000000000000GHOST0';
      final report = ReportProjection(
        curriculumId: reportCurriculum,
        distinctLearnt: 3,
        totalEvents: 3,
        sources: {
          LearningEvent.sourceMain: reportTotals(
            LearningEvent.sourceMain,
            events: 0,
            distinct: 0,
          ),
          ghost: reportTotals(
            ghost,
            events: 3,
            distinct: 3,
            kind: ReportSourceKind.unknownSubTrack,
          ),
        },
      );
      await _pump(tester, LifetimeReportBySource(view: _view(report)));
      expect(find.text('Ended sub-track'), findsOneWidget);
    });
  });

  group('LifetimeReportSchoolYears', () {
    testWidgets('groups start collapsed and expand to member lines', (
      tester,
    ) async {
      await _pump(tester, LifetimeReportSchoolYears(view: _view(fullReport())));
      expect(find.text('School years'), findsOneWidget);
      expect(find.text('School · 640 Mishnayos'), findsOneWidget);
      expect(find.text('Rebbe · ongoing · 216 Mishnayos'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lifetimeReportLine-$school2026')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('lifetimeReportGroupHeader-school')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      for (final id in [school2024, school2025, school2026]) {
        expect(find.byKey(ValueKey('lifetimeReportLine-$id')), findsOneWidget);
      }
      expect(find.text('Ended'), findsNWidgets(2));
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('180 Mishnayos'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('lifetimeReportGroupHeader-school')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('lifetimeReportLine-$school2026')),
        findsNothing,
      );
    });

    testWidgets('a deleted member shows the same Ended marker', (tester) async {
      await _pump(
        tester,
        LifetimeReportSchoolYears(view: _view(fullReport(deleted2025: true))),
      );
      await tester.tap(
        find.byKey(const ValueKey('lifetimeReportGroupHeader-school')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ended'), findsNWidgets(2));
    });
  });
}
