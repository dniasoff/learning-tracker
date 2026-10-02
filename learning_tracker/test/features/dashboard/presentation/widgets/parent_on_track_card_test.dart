// Story 2.11 (DNI-502): the parent on-track card renders the engine's
// LearnerState as it is (AD-35).
// AC-1 status, projection/deadline and unit-aware target, status as text;
// AC-2 too early to tell at the 13/14-day boundary; AC-3 no deadline;
// AC-8 load failure with a working retry and no rejected-sync state.
import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/dashboard/epic2_surfaces.dart';
import '../../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';

/// The plural Mishnayos leaf unit in English terms.
final _mishnayos = CurriculumLabels.leaf(
  CurriculumId.mishnayos,
).inLanguage(useHebrew: false, plural: true);

Future<void> _pump(
  WidgetTester tester, {
  LearnerState? state,
  bool parent = true,
  List<Override> extra = const [],
}) async {
  // A fresh ProviderScope per pump, so a second pump in one test reads its
  // own overrides.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    pumpApp(
      theme: AppTheme.lightTheme(),
      overrides: [
        ...forecastOverrides(parent: parent, state: state),
        ...extra,
      ],
      child: const Scaffold(
        body: SingleChildScrollView(child: ParentForecastSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LearnerState _state(Projection projection, {int? dailyTarget}) => forecastState(
  [forecastCurriculumState(projection: projection, dailyTarget: dailyTarget)],
);

/// A router that accepts every navigation.
StackRouter _router() {
  final router = Epic2MockRouter();
  when(() => router.isRouteActive(any())).thenReturn(false);
  return router;
}

/// Text inside a rich line (each line is led by an icon placeholder).
Finder _text(String text) => find.textContaining(text, findRichText: true);

void main() {
  group('AC-1: an evaluated deadline goal', () {
    testWidgets('on track: success status, projection, deadline and the '
        'unit-aware daily target from LearnerState', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        state: _state(
          const Projection(
            status: ProjectionStatus.onTrack,
            velocityPerDay: 3,
            projectedFinish: '2029-03-14',
            deadline: '2029-09-10',
          ),
          dailyTarget: 3,
        ),
      );
      expect(_text('On track'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onTrackStatus')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      expect(
        _text('Projected finish: Mar 14, 2029 · deadline Sep 10, 2029'),
        findsOneWidget,
      );
      expect(_text('Daily target: 3 $_mishnayos/day'), findsOneWidget);
      // Status is announced as text, never by colour alone (UX-DR-157).
      expect(find.bySemanticsLabel('On track'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Projected finish: Mar 14, 2029 · deadline Sep 10, 2029',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('behind pace: amber status with its own icon and text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        state: _state(
          const Projection(
            status: ProjectionStatus.behindPace,
            velocityPerDay: 1,
            projectedFinish: '2030-01-02',
            deadline: '2029-09-10',
          ),
          dailyTarget: 1,
        ),
      );
      expect(find.bySemanticsLabel('Behind pace'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onTrackStatus')),
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );
      // One leaf: the singular unit.
      final mishna = CurriculumLabels.leaf(
        CurriculumId.mishnayos,
      ).inLanguage(useHebrew: false, plural: false);
      expect(_text('Daily target: 1 $mishna/day'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('behind pace with no velocity names no finish date', (
      tester,
    ) async {
      await _pump(
        tester,
        state: _state(
          const Projection(
            status: ProjectionStatus.behindPace,
            velocityPerDay: 0,
            deadline: '2029-09-10',
          ),
          dailyTarget: 5,
        ),
      );
      expect(
        _text('Projected finish: not yet known · deadline Sep 10, 2029'),
        findsOneWidget,
      );
    });
  });

  group('AC-2: too early to tell (real engine, 13/14-day boundary)', () {
    final now = DateTime.utc(2026, 10, 8, 12);
    final events = [
      forecastLearn(1, 'Mishnah Berakhot 1:1', '2026-09-26'),
      forecastLearn(2, 'Mishnah Berakhot 1:2', '2026-10-01'),
    ];

    testWidgets('13 days of history: neutral status, no projection', (
      tester,
    ) async {
      await _pump(
        tester,
        state: engineForecastState(
          nowUtc: now,
          trackingStartDate: '2026-09-26',
          events: events,
          deadline: '2027-06-01',
        ),
      );
      expect(_text('Too early to tell'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onTrackStatus')),
          matching: find.byIcon(Icons.hourglass_empty_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('onTrackProjection')), findsNothing);
      expect(_text('On track'), findsNothing);
      expect(_text('Behind pace'), findsNothing);
    });

    testWidgets('exactly 14 days: evaluated, with status and projection', (
      tester,
    ) async {
      await _pump(
        tester,
        state: engineForecastState(
          nowUtc: now,
          trackingStartDate: '2026-09-25',
          events: events,
          deadline: '2027-06-01',
        ),
      );
      expect(_text('Too early to tell'), findsNothing);
      expect(find.byKey(const Key('onTrackStatus')), findsOneWidget);
      expect(find.byKey(const Key('onTrackProjection')), findsOneWidget);
    });
  });

  group('AC-3: no deadline goal', () {
    testWidgets('projected finish only: no status and no daily target', (
      tester,
    ) async {
      await _pump(
        tester,
        state: _state(
          const Projection(
            status: ProjectionStatus.noDeadline,
            velocityPerDay: 2,
            projectedFinish: '2029-03-14',
          ),
          // A pace or calendar target never shows without a deadline.
          dailyTarget: 7,
        ),
      );
      expect(_text('Projected finish: Mar 14, 2029'), findsOneWidget);
      expect(_text('deadline'), findsNothing);
      expect(find.byKey(const Key('onTrackStatus')), findsNothing);
      expect(find.byKey(const Key('onTrackDailyTarget')), findsNothing);
    });

    testWidgets('no sub-track rate affects anything shown (real engine)', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 8, 12);
      final events = [
        for (final (i, ref) in [
          'Mishnah Berakhot 1:1',
          'Mishnah Berakhot 1:2',
          'Mishnah Berakhot 1:3',
        ].indexed)
          forecastLearn(i + 1, ref, '2026-10-0${i + 1}'),
      ];
      SubTrack school(double rate) => SubTrack(
        id: schoolSubTrackId,
        curriculumId: engineCurriculum,
        name: 'School',
        type: SubTrackType.ongoing,
        windowStart: '2026-09-01',
        ratePerWeek: rate,
        weeksPerYear: 52,
        learnsOnShabbos: false,
        ground: const [peah],
        lastChangeId: engineUlid(901),
      );
      Future<String> rendered(double rate) async {
        await _pump(
          tester,
          state: engineForecastState(
            nowUtc: now,
            trackingStartDate: '2026-09-01',
            events: events,
            subTracks: [school(rate)],
          ),
        );
        expect(_text('Projected finish: '), findsOneWidget);
        expect(find.byKey(const Key('onTrackStatus')), findsNothing);
        expect(find.byKey(const Key('onTrackDailyTarget')), findsNothing);
        final card = find.byKey(const Key('onTrackCard-mishnayos'));
        return [
          for (final t in tester.widgetList<RichText>(
            find.descendant(of: card, matching: find.byType(RichText)),
          ))
            t.text.toPlainText(),
        ].join('|');
      }

      expect(await rendered(200), await rendered(1));
    });
  });

  group('AC-4: a zero daily target with a deadline', () {
    const bonus = 'All covered — any extra learning is a bonus.';
    final zero = _state(
      const Projection(
        status: ProjectionStatus.onTrack,
        projectedFinish: '2029-03-14',
        deadline: '2029-09-10',
      ),
      dailyTarget: 0,
    );

    testWidgets('the parent Dashboard shows the bonus copy once', (
      tester,
    ) async {
      await tester.pumpWidget(
        dashboardSurface(
          router: _router(),
          parent: true,
          mode: ProfileMode.adult,
          state: zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(_text(bonus), findsOneWidget);
      expect(_text('Daily target:'), findsNothing);
    });

    testWidgets('the child Learn today section shows it once', (tester) async {
      await tester.pumpWidget(
        learnSurface(router: _router(), parent: false, state: zero),
      );
      await tester.pumpAndSettle();
      expect(_text(bonus), findsOneWidget);
    });
  });

  group('AC-8: the status fails to load', () {
    testWidgets('InlineAsyncError with a working retry and no rejected-sync '
        'copy', (tester) async {
      var builds = 0;
      final good = _state(
        const Projection(
          status: ProjectionStatus.onTrack,
          projectedFinish: '2029-03-14',
          deadline: '2029-09-10',
        ),
        dailyTarget: 3,
      );
      await _pump(
        tester,
        extra: [
          learnerStateProvider.overrideWith((ref, _) {
            builds++;
            return builds == 1
                ? Stream<LearnerState>.error(StateError('read failed'))
                : Stream.value(good);
          }),
        ],
      );
      expect(find.byType(InlineAsyncError), findsOneWidget);
      expect(_text('On track'), findsNothing);
      expect(find.textContaining('saved'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(InlineAsyncError),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(builds, 2);
      expect(find.byType(InlineAsyncError), findsNothing);
      expect(_text('On track'), findsOneWidget);
    });
  });

  testWidgets('a child session renders nothing (NFR-9)', (tester) async {
    await _pump(
      tester,
      parent: false,
      state: _state(
        const Projection(
          status: ProjectionStatus.behindPace,
          deadline: '2029-09-10',
        ),
        dailyTarget: 3,
      ),
    );
    expect(find.byType(OnTrackCard), findsNothing);
    expect(_text('Behind pace'), findsNothing);
  });

  testWidgets('loading is a static placeholder, not a spinner', (tester) async {
    final never = StreamController<LearnerState>();
    addTearDown(never.close);
    await tester.pumpWidget(
      pumpApp(
        theme: AppTheme.lightTheme(),
        overrides: forecastOverrides(states: never.stream),
        child: const Scaffold(body: ParentForecastSection()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('onTrackCardLoading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
