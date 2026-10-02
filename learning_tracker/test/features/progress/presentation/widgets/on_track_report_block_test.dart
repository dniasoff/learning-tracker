// Story 5.3 (DNI-518) AC-6, AC-7, AC-8: the On-track block renders the
// engine's status, projected finish, daily target and shortfalls exactly.
@Tags(['progress', 'lifetime', 'story_5_3'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/on_track_report_block.dart';

import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/progress/pace_report_fixtures.dart';
import '../../../../helpers/pump_app.dart';

/// The block the report shows for the engine values given.
OnTrackView _view(
  ProjectionStatus status, {
  int? dailyTarget = 3,
  bool calendar = false,
  int? shortfall,
  Map<String, SubTrackState> subTracks = const {
    school2026: paceSchoolShortfall,
    rebbeId: paceRebbeNoShortfall,
  },
  String? finish = '2029-03-14',
}) {
  final report = paceReport(status: status, calendarProgram: calendar);
  return PaceReportView.of(
    LifetimeReportView(
      curriculumId: report.curriculumId,
      curricula: [report.curriculumId],
      report: report,
    ),
    paceCurriculumState(
      report,
      projection: paceProjection(status, finish: finish),
      dailyTarget: dailyTarget,
      shortfall: shortfall,
      subTracks: subTracks,
    ),
  )!.onTrack!;
}

Future<void> _pump(
  WidgetTester tester,
  OnTrackView view, {
  Size size = const Size(400, 900),
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    pumpApp(
      child: Scaffold(
        body: SingleChildScrollView(
          child: OnTrackReportBlock(
            view: view,
            curriculum: CurriculumId.mishnayos,
          ),
        ),
      ),
      overrides: [effectiveUseHebrewTermsProvider.overrideWithValue(false)],
      theme: AppTheme.themeFor(brightness: brightness),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

final _status = find.byKey(const ValueKey('reportOnTrackStatus'));
final _finish = find.byKey(const ValueKey('reportOnTrackFinish'));
final _target = find.byKey(const ValueKey('reportOnTrackDailyTarget'));

String _text(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).data!;

Iterable<String> _painted(WidgetTester tester) => [
  for (final t in tester.widgetList<RichText>(find.byType(RichText)))
    t.text.toPlainText(),
];

void main() {
  group('AC-6 deadline status and shortfall come from state', () {
    for (final (status, text, icon) in [
      (ProjectionStatus.onTrack, 'On track', Icons.check_circle_outline),
      (ProjectionStatus.behindPace, 'Behind pace', Icons.trending_down),
      (ProjectionStatus.tooEarly, 'Too early to tell', Icons.hourglass_empty),
    ]) {
      testWidgets('${status.name}: exact status with icon, finish and '
          'daily target', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _view(status, dailyTarget: 4));
        expect(
          find.descendant(of: _status, matching: find.text(text)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _status, matching: find.byIcon(icon)),
          findsOneWidget,
        );
        // Announced as text, not colour alone (UX-DR-157).
        expect(find.bySemanticsLabel('Status: $text'), findsOneWidget);
        if (status == ProjectionStatus.tooEarly) {
          // No projection is made under 14 days.
          expect(_finish, findsNothing);
        } else {
          expect(_text(tester, _finish), 'Projected finish: Mar 14, 2029');
        }
        expect(_text(tester, _target), 'Daily target: 4 Mishnayos/day');
        handle.dispose();
      });
    }

    testWidgets('On track is success green, Behind pace amber, Too early '
        'neutral', (tester) async {
      Color? colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style!.color;

      await _pump(tester, _view(ProjectionStatus.onTrack));
      final colors = tester.element(_status).colors;
      expect(colorOf('On track'), colors.statusSuccessSoftText);

      await _pump(tester, _view(ProjectionStatus.behindPace));
      expect(colorOf('Behind pace'), colors.brandWarningDeep);

      await _pump(tester, _view(ProjectionStatus.tooEarly));
      expect(colorOf('Too early to tell'), colors.brandInkMuted);
    });

    testWidgets('a shortfall message only for a positive sub-track '
        'shortfall, in FR-21 wording', (tester) async {
      await _pump(tester, _view(ProjectionStatus.behindPace));
      expect(
        find.byKey(const ValueKey('reportShortfall-$school2026')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reportShortfall-$rebbeId')),
        findsNothing,
      );
      expect(
        find.text(
          'School may not reach Berakhot 3 before June 2027. About 12 '
          'Mishnayos will return to home learning.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an open-window sub-track names the deadline instead', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(
          ProjectionStatus.behindPace,
          subTracks: const {
            rebbeId: SubTrackState(
              subTrackId: rebbeId,
              holdsGround: true,
              inForecast: true,
              onHome: true,
              capacity: 10,
              shortfall: 1,
              lastShortfallNode: NodeEntry(level: 'masechta', ref: 'Peah'),
            ),
          },
        ),
      );
      expect(
        find.text(
          'Rebbe may not reach Peah by the deadline. About 1 Mishna will '
          'return to home learning.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no shortfall anywhere: no message', (tester) async {
      await _pump(
        tester,
        _view(
          ProjectionStatus.onTrack,
          subTracks: const {rebbeId: paceRebbeNoShortfall},
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('behind pace with no recent learning: the finish is not '
        'invented', (tester) async {
      await _pump(tester, _view(ProjectionStatus.behindPace, finish: null));
      expect(
        _text(tester, _finish),
        'Projected finish: not enough recent learning to project',
      );
    });
  });

  group('AC-7 no-deadline projection has no status', () {
    testWidgets('projected finish only: no status chip, no daily target', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(ProjectionStatus.noDeadline, dailyTarget: null),
      );
      expect(_text(tester, _finish), 'Projected finish: Mar 14, 2029');
      expect(_status, findsNothing);
      expect(_target, findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      for (final text in _painted(tester)) {
        expect(text, isNot(contains('On track')));
        expect(text, isNot(contains('Behind pace')));
      }
    });

    testWidgets('too early with no deadline: neutral finish line, no chip', (
      tester,
    ) async {
      await _pump(tester, _view(ProjectionStatus.tooEarly, dailyTarget: null));
      expect(_status, findsNothing);
      expect(_text(tester, _finish), 'Projected finish: too early to tell');
      expect(_target, findsNothing);
    });
  });

  group('AC-8 calendar curriculum uses engine calendar state', () {
    testWidgets('behind the calendar: Behind pace and the engine shortfall', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(
          ProjectionStatus.noDeadline,
          calendar: true,
          shortfall: 4,
          dailyTarget: 5,
          subTracks: const {},
        ),
      );
      expect(
        find.descendant(of: _status, matching: find.text('Behind pace')),
        findsOneWidget,
      );
      expect(find.text('4 Mishnayos behind the calendar'), findsOneWidget);
      expect(_text(tester, _target), 'Daily target: 5 Mishnayos/day');
    });

    testWidgets('caught up: On track, no shortfall line', (tester) async {
      await _pump(
        tester,
        _view(
          ProjectionStatus.noDeadline,
          calendar: true,
          shortfall: 0,
          dailyTarget: 1,
          subTracks: const {},
        ),
      );
      expect(
        find.descendant(of: _status, matching: find.text('On track')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reportOnTrackCalendarBehind')),
        findsNothing,
      );
      expect(_text(tester, _target), 'Daily target: 1 Mishna/day');
    });
  });

  group('layout (UX-DR-156, UX-DR-164)', () {
    for (final (name, size, brightness, locale) in [
      ('narrow phone', const Size(320, 900), Brightness.light, 'en'),
      ('dark', const Size(400, 900), Brightness.dark, 'en'),
      ('tablet', const Size(1024, 900), Brightness.light, 'en'),
      ('Hebrew narrow', const Size(320, 900), Brightness.dark, 'he'),
    ]) {
      testWidgets('$name: no overflow', (tester) async {
        await _pump(
          tester,
          _view(ProjectionStatus.behindPace),
          size: size,
          brightness: brightness,
          locale: Locale(locale),
        );
        expect(tester.takeException(), isNull);
        expect(_status, findsOneWidget);
      });
    }
  });
}
