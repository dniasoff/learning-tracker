// Story 5.2 (DNI-517): the lifetime report screen renders the engine's
// report projection (Story 5.1) unchanged for a parent session.
//
// The learner state comes from fakes holding chosen projections (C0 test
// rule), except the engine-backed case, which runs the real
// `LearnerStateEngine` so the screen is checked against a projection it
// did not build.
@Tags(['progress', 'lifetime', 'story_5_2'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_report_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/pump_app.dart';

/// Overrides for a parent session whose learner state is [state], or the
/// stream [states] when given.
List<Override> _overrides({
  LearnerState? state,
  Stream<LearnerState> Function()? states,
  bool hebrewTerms = false,
}) => [
  parentSessionProvider.overrideWith((ref) async => true),
  // English units ("Mishnayos"); the Hebrew-terms toggle has its own tests.
  if (!hebrewTerms) effectiveUseHebrewTermsProvider.overrideWithValue(false),
  activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
  learnerStateProvider.overrideWith(
    (ref, _) => states != null ? states() : Stream.value(state!),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  LearnerState? state,
  Stream<LearnerState> Function()? states,
  String? curriculumId,
  Size size = const Size(400, 900),
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    pumpApp(
      child: LifetimeReportScreen(curriculumId: curriculumId),
      overrides: _overrides(state: state, states: states),
      theme: AppTheme.themeFor(brightness: brightness),
      locale: locale,
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Every string painted on screen.
Iterable<String> _paintedText(WidgetTester tester) => [
  for (final t in tester.widgetList<RichText>(find.byType(RichText)))
    t.text.toPlainText(),
];

/// Pumps frames until [condition] holds (at most [maxFrames]).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxFrames = 20,
}) async {
  for (var i = 0; i < maxFrames && !condition(); i++) {
    await tester.pump();
  }
}

/// Scrolls the group header for [key] into view and taps it.
Future<void> _toggle(WidgetTester tester, String key) async {
  await tester.ensureVisible(_groupHeader(key));
  await tester.pumpAndSettle();
  await tester.tap(_groupHeader(key));
  await tester.pumpAndSettle();
}

Finder _source(String source) =>
    find.byKey(ValueKey('lifetimeReportSource-$source'));

Finder _groupHeader(String key) =>
    find.byKey(ValueKey('lifetimeReportGroupHeader-$key'));

Finder _line(String id) => find.byKey(ValueKey('lifetimeReportLine-$id'));

void main() {
  group('AC-1 sections and totals', () {
    testWidgets('renders Distinct, Learning events, By source and School '
        'years with the projection totals', (tester) async {
      await _pump(tester, state: reportState([fullReport()]));

      expect(find.text('Lifetime report'), findsOneWidget);
      expect(find.text('Distinct'), findsOneWidget);
      expect(find.text('Learning events'), findsOneWidget);
      expect(find.text('By source'), findsOneWidget);
      expect(find.text('School years'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Distinct · 1,204 Mishnayos'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Learning events · 2,040'), findsOneWidget);
    });

    testWidgets('the totals are headline-small stat numerals', (tester) async {
      await _pump(tester, state: reportState([fullReport()]));
      final context = tester.element(find.byType(LifetimeReportTotals));
      final headline = Theme.of(context).textTheme.headlineSmall!;
      for (final value in ['1,204', '2,040']) {
        final span = _spanWithText(tester, value);
        expect(span, isNotNull, reason: value);
        expect(span!.style?.fontSize, headline.fontSize);
        expect(span.style?.fontWeight, FontWeight.w600);
      }
    });

    testWidgets('"Reviews" appears nowhere, and no pace or export control '
        'ships in this story', (tester) async {
      await _pump(tester, state: reportState([fullReport()]));
      await _toggle(tester, 'school');
      final painted = _paintedText(tester).join('\n');
      expect(painted.toLowerCase(), isNot(contains('review')));
      expect(painted, isNot(contains('Per-source pace')));
      expect(painted, isNot(contains('Export PDF')));
    });
  });

  group('AC-3 By source', () {
    testWidgets('one row per source with its own event and distinct counts', (
      tester,
    ) async {
      await _pump(tester, state: reportState([fullReport()]));
      final rows = {
        LearningEvent.sourceMain: '1,020 learning events · 700 Mishnayos',
        rebbeId: '230 learning events · 216 Mishnayos',
        school2024: '260 learning events · 210 Mishnayos',
        school2025: '300 learning events · 250 Mishnayos',
        school2026: '190 learning events · 180 Mishnayos',
        reportBeforeTrackingKey: '40 learning events · 40 Mishnayos',
      };
      for (final MapEntry(:key, :value) in rows.entries) {
        expect(_source(key), findsOneWidget, reason: key);
        expect(
          find.descendant(of: _source(key), matching: find.text(value)),
          findsOneWidget,
          reason: key,
        );
      }
      // 1,020 + 230 + 260 + 300 + 190 + 40 = the Learning events total.
      expect(1020 + 230 + 260 + 300 + 190 + 40, 2040);
    });

    testWidgets('source chips are display only', (tester) async {
      await _pump(tester, state: reportState([fullReport()]));
      final chips = find.byType(ReportSourceChip);
      expect(chips, findsNWidgets(6));
      for (final chip in chips.evaluate()) {
        expect(
          find.ancestor(
            of: find.byWidget(chip.widget),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is InkWell ||
                  w is GestureDetector ||
                  w is ButtonStyleButton,
            ),
          ),
          findsNothing,
        );
      }
    });

    testWidgets('Before tracking has its own row with the gold-soft badge', (
      tester,
    ) async {
      await _pump(tester, state: reportState([fullReport()]));
      final chip = find.descendant(
        of: _source(reportBeforeTrackingKey),
        matching: find.byType(ReportSourceChip),
      );
      expect(
        find.descendant(of: chip, matching: find.text('Before tracking')),
        findsOneWidget,
      );
      final box = tester.widget<Container>(
        find.descendant(of: chip, matching: find.byType(Container)).first,
      );
      final context = tester.element(chip);
      expect(
        (box.decoration! as BoxDecoration).color,
        context.colors.brandGoldSoft,
      );
    });

    testWidgets('renders an engine-built projection unchanged, the renamed '
        'sub-track under its current name only (AC-6)', (tester) async {
      // The sub-track was "Cheder" and is now "School": the doc carries only
      // its current name, and its events keep its ULID (Story 5.1 G-4).
      final school = SubTrack(
        id: engineUlid(10),
        curriculumId: engineCurriculum,
        name: 'School',
        type: SubTrackType.schoolYear,
        academicYear: 2026,
        windowStart: '2026-09-01',
        windowEnd: '2027-06-30',
        ratePerWeek: 2,
        weeksPerYear: 40,
        learnsOnShabbos: false,
        ground: const [berakhot],
        lastChangeId: engineUlid(11),
      );
      final state = const LearnerStateEngine().run(
        engineInputs(
          subTracks: [school],
          events: [
            engineLearn(1, 'Mishnah Berakhot 1:1', stage: 1),
            engineLearn(2, 'Mishnah Berakhot 1:2', source: school.id),
            engineLearn(3, 'Mishnah Berakhot 1:3', source: school.id),
            engineGround(4, peah),
          ],
        ),
      );
      final report = state[engineCurriculum]!.report;
      await _pump(tester, state: state, curriculumId: engineCurriculum);

      expect(
        find.bySemanticsLabel('Distinct · ${report.distinctLearnt} Mishnayos'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Learning events · ${report.totalEvents}'),
        findsOneWidget,
      );
      final schoolTotals = report.sources[school.id]!;
      expect(
        find.descendant(
          of: _source(school.id),
          matching: find.text(
            '${schoolTotals.events} learning events · '
            '${schoolTotals.distinctLeaves} Mishnayos',
          ),
        ),
        findsOneWidget,
      );
      expect(_source(reportBeforeTrackingKey), findsOneWidget);
      expect(find.textContaining('Cheder'), findsNothing);
      expect(_groupHeader('school'), findsOneWidget);
      expect(find.byType(LifetimeReportGroupTile), findsOneWidget);
    });
  });

  group('AC-4 School years', () {
    testWidgets('one collapsed School row expanding to its three years; '
        'Rebbe grouped separately', (tester) async {
      await _pump(tester, state: reportState([fullReport()]));

      expect(find.text('School · 640 Mishnayos'), findsOneWidget);
      expect(find.text('Rebbe · ongoing · 216 Mishnayos'), findsOneWidget);
      expect(_line(school2024), findsNothing);

      await _toggle(tester, 'school');
      expect(
        find.descendant(of: _line(school2024), matching: find.text('2024–25')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _line(school2024),
          matching: find.text('210 Mishnayos'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _line(school2025), matching: find.text('2025–26')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _line(school2026), matching: find.text('2026–27')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _line(school2026),
          matching: find.text('In progress'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _line(school2026),
          matching: find.text('180 Mishnayos'),
        ),
        findsOneWidget,
      );
      expect(find.text('In progress'), findsOneWidget);
      // Rebbe stays collapsed and is never shown as a school year.
      expect(_line(rebbeId), findsNothing);

      await _toggle(tester, 'school');
      expect(_line(school2024), findsNothing);
    });
  });

  testWidgets('AC-5 a deleted year stays under School with its counts and '
      'an Ended marker, and in the totals', (tester) async {
    await _pump(tester, state: reportState([fullReport(deleted2025: true)]));
    expect(find.bySemanticsLabel('Learning events · 2,040'), findsOneWidget);
    expect(find.text('School · 640 Mishnayos'), findsOneWidget);
    await _toggle(tester, 'school');
    expect(
      find.descendant(of: _line(school2025), matching: find.text('Ended')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _line(school2025),
        matching: find.text('250 Mishnayos'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('omplete'), findsNothing);
  });

  testWidgets('AC-7 no sub-tracks: Home and Before tracking only, no School '
      'years and no prompt to create a sub-track', (tester) async {
    await _pump(tester, state: reportState([homeOnlyReport()]));
    expect(_source(LearningEvent.sourceMain), findsOneWidget);
    expect(_source(reportBeforeTrackingKey), findsOneWidget);
    expect(find.byType(ReportSourceChip), findsNWidgets(2));
    expect(find.text('School years'), findsNothing);
    expect(find.textContaining('sub-track'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('AC-7 Home only, without Before tracking', (tester) async {
    await _pump(
      tester,
      state: reportState([homeOnlyReport(withBeforeTracking: false)]),
    );
    expect(find.byType(ReportSourceChip), findsOneWidget);
    expect(_source(reportBeforeTrackingKey), findsNothing);
  });

  testWidgets('AC-8 no counted events: zero totals only', (tester) async {
    await _pump(
      tester,
      state: reportState([ReportProjection.empty(reportCurriculum)]),
    );
    expect(find.bySemanticsLabel('Distinct · 0 Mishnayos'), findsOneWidget);
    expect(find.bySemanticsLabel('Learning events · 0'), findsOneWidget);
    expect(find.text('By source'), findsNothing);
    expect(find.text('School years'), findsNothing);
  });

  testWidgets('AC-9 switching curriculum shows only that curriculum\'s '
      'totals and unit, the retired one included', (tester) async {
    final state = reportState([
      fullReport(),
      homeOnlyReport(
        curriculumId: reportRetiredCurriculum,
        events: 30,
        distinct: 25,
        withBeforeTracking: false,
      ),
    ]);
    await _pump(tester, state: state, curriculumId: reportCurriculum);
    expect(find.bySemanticsLabel('Distinct · 1,204 Mishnayos'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('lifetimeReportCurriculum-chumash')),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Distinct · 25 Pesukim'), findsOneWidget);
    expect(find.bySemanticsLabel('Learning events · 30'), findsOneWidget);
    for (final section in [LifetimeReportTotals, LifetimeReportBySource]) {
      expect(
        find.descendant(
          of: find.byType(section),
          matching: find.textContaining('Mishnayos'),
        ),
        findsNothing,
      );
    }
    expect(find.text('School years'), findsNothing);
    // No velocity UI in this story, for any curriculum.
    expect(find.textContaining('/ week'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('lifetimeReportCurriculum-mishnayos')),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Distinct · 1,204 Mishnayos'), findsOneWidget);
  });

  group('AC-10 loading and errors', () {
    testWidgets('LoadingIndicator while the learner state pages, never '
        'partial totals', (tester) async {
      final controller = StreamController<LearnerState>();
      addTearDown(controller.close);
      await _pump(tester, states: () => controller.stream, settle: false);
      await tester.pump();
      expect(find.byType(LoadingIndicator), findsOneWidget);
      expect(find.byType(LifetimeReportTotals), findsNothing);

      controller.add(reportState([fullReport()]));
      await tester.pumpAndSettle();
      expect(find.byType(LoadingIndicator), findsNothing);
      expect(find.bySemanticsLabel('Learning events · 2,040'), findsOneWidget);
    });

    testWidgets('a load error shows AppErrorView; Retry re-reads the inputs', (
      tester,
    ) async {
      final streams = <StreamController<LearnerState>>[];
      addTearDown(() {
        for (final c in streams) {
          unawaited(c.close());
        }
      });
      Stream<LearnerState> next() {
        final c = StreamController<LearnerState>();
        streams.add(c);
        return c.stream;
      }

      await _pump(tester, states: next, settle: false);
      await _pumpUntil(tester, () => streams.isNotEmpty);
      streams.single.addError(StateError('intent_history page failed'));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byType(LifetimeReportTotals), findsNothing);

      await tester.tap(find.text('Retry'));
      await _pumpUntil(tester, () => streams.length == 2);
      expect(streams, hasLength(2));
      streams.last.add(reportState([fullReport()]));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorView), findsNothing);
      expect(find.bySemanticsLabel('Learning events · 2,040'), findsOneWidget);
    });
  });

  testWidgets('AC-11 learning recorded after the goal updates the report '
      'live, with no record-stopped wording', (tester) async {
    final controller = StreamController<LearnerState>();
    addTearDown(controller.close);
    await _pump(tester, states: () => controller.stream, settle: false);
    controller.add(reportState([homeOnlyReport(events: 12)]));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Learning events · 17'), findsOneWidget);

    controller.add(reportState([homeOnlyReport(events: 13)]));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Learning events · 18'), findsOneWidget);
    final painted = _paintedText(tester).join('\n').toLowerCase();
    for (final word in ['goal reached', 'complete', 'finished', 'stopped']) {
      expect(painted, isNot(contains(word)));
    }
  });

  group('AC-12 layout', () {
    testWidgets('tablet ≥ 840 dp puts By source and School years side by '
        'side', (tester) async {
      await _pump(
        tester,
        state: reportState([fullReport()]),
        size: const Size(1024, 900),
      );
      final bySource = tester.getRect(
        find.byKey(const ValueKey('lifetimeReportBySource')),
      );
      final years = tester.getRect(
        find.byKey(const ValueKey('lifetimeReportSchoolYears')),
      );
      expect(years.top, bySource.top);
      expect(years.left, greaterThan(bySource.right));
    });

    testWidgets('phone stacks the sections', (tester) async {
      await _pump(tester, state: reportState([fullReport()]));
      final bySource = tester.getRect(
        find.byKey(const ValueKey('lifetimeReportBySource')),
      );
      final years = tester.getRect(
        find.byKey(const ValueKey('lifetimeReportSchoolYears')),
      );
      expect(years.top, greaterThan(bySource.bottom));
    });

    testWidgets('cards are flat with a 1 px outline and no shadow', (
      tester,
    ) async {
      await _pump(tester, state: reportState([fullReport()]));
      final cards = find.byType(LifetimeReportCard);
      expect(cards, findsWidgets);
      for (final card in cards.evaluate()) {
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byWidget(card.widget),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.boxShadow, isNull);
        expect((decoration.border! as Border).top.width, 1);
      }
      expect(
        find.descendant(
          of: find.byType(LifetimeReportScreen),
          matching: find.byType(Card),
        ),
        findsNothing,
      );
    });

    testWidgets('dark mode uses the dark tokens', (tester) async {
      await _pump(
        tester,
        state: reportState([fullReport()]),
        brightness: Brightness.dark,
      );
      final context = tester.element(find.byType(LifetimeReportTotals));
      expect(Theme.of(context).brightness, Brightness.dark);
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('lifetimeReportBySource')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        Theme.of(context).colorScheme.surface,
      );
    });
  });

  group('AC-13 cached first frame and expansion', () {
    testWidgets('a perf-size cached projection renders its totals on the '
        'first frame, well under 1 s', (tester) async {
      final state = reportState([_perfReport()]);
      final stopwatch = Stopwatch()..start();
      await _pump(tester, state: state, settle: false);
      // The cached value lands within the first frames after the session
      // and scope futures resolve.
      await _pumpUntil(
        tester,
        () => find.byType(LifetimeReportTotals).evaluate().isNotEmpty,
      );
      stopwatch.stop();
      expect(find.byType(LifetimeReportTotals), findsOneWidget);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    testWidgets('expanding a group re-reads no learner state', (tester) async {
      var builds = 0;
      var listens = 0;
      await _pump(
        tester,
        states: () {
          builds++;
          return Stream.value(reportState([_perfReport()])).map((s) {
            listens++;
            return s;
          });
        },
      );
      expect((builds, listens), (1, 1));
      await _toggle(tester, 'school');
      await _toggle(tester, 'school');
      expect((builds, listens), (1, 1));
    });
  });
}

/// A report at the Story 5.1 perf-fixture size: 40,200 events over Home,
/// eight "School" years (seven ended) and seven more sub-tracks.
ReportProjection _perfReport() {
  final sources = <String, ReportSourceTotals>{
    LearningEvent.sourceMain: reportTotals(
      LearningEvent.sourceMain,
      events: 24000,
      distinct: 3000,
    ),
  };
  final schoolLines = <ReportMemberLine>[];
  for (var i = 0; i < 8; i++) {
    final id = '01J00000000000000000SCH00$i';
    final totals = reportTotals(id, events: 1500, distinct: 400);
    sources[id] = totals;
    schoolLines.add(schoolYearLine(id, 2018 + i, totals, ended: i < 7));
  }
  final groups = [
    ReportGroup(key: 'school', name: 'School', members: schoolLines),
  ];
  for (var i = 0; i < 7; i++) {
    final id = '01J00000000000000000RBB00$i';
    final totals = reportTotals(id, events: 571, distinct: 300);
    sources[id] = totals;
    groups.add(
      ReportGroup(
        key: 'rebbe $i',
        name: 'Rebbe $i',
        members: [ongoingLine(id, totals, name: 'Rebbe $i')],
      ),
    );
  }
  return ReportProjection(
    curriculumId: reportCurriculum,
    distinctLearnt: 4200,
    totalEvents: 24000 + 8 * 1500 + 7 * 571 + 200,
    sources: sources,
    beforeTracking: reportTotals(
      reportBeforeTrackingKey,
      events: 200,
      distinct: 200,
    ),
    groups: groups,
  );
}

/// The [TextSpan] painting exactly [text], if any.
TextSpan? _spanWithText(WidgetTester tester, String text) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    TextSpan? found;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span;
        return false;
      }
      return true;
    });
    if (found != null) return found;
  }
  return null;
}
