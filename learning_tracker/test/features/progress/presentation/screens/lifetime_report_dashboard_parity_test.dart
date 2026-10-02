// Story 5.3 (DNI-518) AC-11: the Dashboard and the lifetime report show
// one status, projected finish and daily target for one `LearnerState`.
//
// Each case is one real `LearnerStateEngine` run (deadline on track,
// deadline behind pace, calendar program behind the calendar). Both
// surfaces get that same state through the shared learner-state provider:
//
// 1. The report screen must paint exactly the state's own values. The
//    oracle below reads the raw `CurriculumState` fields (projection
//    status, projected finish, daily target, calendar shortfall); it does
//    not go through `OnTrackView`, so a mapping slip in the report fails.
// 2. The real `DashboardScreen` (parent, Mishnayos active) is scanned for
//    every on-track figure it paints, and each one must equal the
//    report's. Today's Dashboard paints none: its only pace source,
//    `dashboardPaceStatusProvider`, is watched by no widget (it is only
//    invalidated) and DNI-474 deletes it. So the scan also proves that no
//    second, legacy pace figure is visible beside the report. The
//    Dashboard's own on-track card is Story 2.11 (DNI-502, bead fyh.44,
//    AC-1, which paints "Projected finish: {date} · deadline {date}" and
//    "Daily target: {n} {unit}/day" from `LearnerState`). When it lands,
//    this scan checks it with no change here. Bead fyh.195 then adds a
//    presence assertion so the check cannot pass vacuously.
@Tags(['progress', 'lifetime', 'story_5_3'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:intl/intl.dart' show DateFormat;
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_report_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';

final _now = DateTime.utc(2026, 10, 8, 12);

/// Four dated leaves, one a week since 2026-09-15.
final _events = [
  engineLearn(1, 'Mishnah Berakhot 1:1', learnedOn: '2026-09-15'),
  engineLearn(2, 'Mishnah Berakhot 1:2', learnedOn: '2026-09-22'),
  engineLearn(3, 'Mishnah Berakhot 1:3', learnedOn: '2026-09-29'),
  engineLearn(4, 'Mishnah Berakhot 2:1', learnedOn: '2026-10-06'),
];

/// Three weeks of dated learning since 2026-09-01, evaluated on Thursday
/// 2026-10-08, with a deadline on [targetDate].
LearnerState _deadline(String targetDate) => const LearnerStateEngine().run(
  engineInputs(
    nowUtc: _now,
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        program: MainTrackProgram(
          curriculumId: engineCurriculum,
          trackingStartDate: '2026-09-01',
        ),
      ),
    },
    goals: {
      engineCurriculum: CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: engineCurriculum,
          targetDate: targetDate,
        ),
      ),
    },
    events: _events,
  ),
);

/// The same learning on a calendar program that assigned both Berakhot
/// chapters in early September: behind the calendar (AC-8).
LearnerState _calendar() => const LearnerStateEngine().run(
  engineInputs(
    nowUtc: _now,
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        program: MainTrackProgram(
          curriculumId: engineCurriculum,
          programId: 'mishnah_yomit',
          trackingStartDate: '2026-09-01',
        ),
      ),
    },
    calendars: {
      'mishnah_yomit': [
        const CalendarAssignment('2026-09-02', berakhot1),
        const CalendarAssignment('2026-09-03', berakhot2),
      ],
    },
    events: _events,
  ),
);

typedef _Figures = ({
  String? status,
  String? finish,
  String? target,
  String? calendar,
});

String _mishnayos(int n) => n == 1 ? 'Mishna' : 'Mishnayos';

/// What the report must paint for [c], read straight from the state's
/// fields (AC-7, AC-8, AC-11).
_Figures _expected(CurriculumState c) {
  final projection = c.projection!;
  final String? status;
  if (c.report.calendarProgram) {
    status = switch (c.shortfall) {
      null => 'Too early to tell',
      0 => 'On track',
      _ => 'Behind pace',
    };
  } else {
    status = switch (projection.status) {
      ProjectionStatus.onTrack => 'On track',
      ProjectionStatus.behindPace => 'Behind pace',
      ProjectionStatus.tooEarly => 'Too early to tell',
      ProjectionStatus.noDeadline => null,
    };
  }
  final finish = projection.projectedFinish;
  final behind = c.report.calendarProgram ? c.shortfall : null;
  return (
    status: status,
    finish: finish != null
        ? 'Projected finish: '
              '${DateFormat.yMMMd('en').format(parseCivilDay(finish))}'
        : status == 'Too early to tell'
        ? null
        : projection.status == ProjectionStatus.tooEarly
        ? 'Projected finish: too early to tell'
        : 'Projected finish: not enough recent learning to project',
    target: c.dailyTarget == null
        ? null
        : 'Daily target: ${c.dailyTarget} ${_mishnayos(c.dailyTarget!)}/day',
    calendar: behind != null && behind > 0
        ? '$behind ${_mishnayos(behind)} behind the calendar'
        : null,
  );
}

/// The on-track figures the report screen paints.
_Figures _report(WidgetTester tester) {
  String? text(String key) {
    final f = find.byKey(ValueKey(key));
    if (f.evaluate().isEmpty) return null;
    return tester.widget<Text>(f).data;
  }

  final chip = find.descendant(
    of: find.byKey(const ValueKey('reportOnTrackStatus')),
    matching: find.byType(Text),
  );
  return (
    status: chip.evaluate().isEmpty ? null : tester.widget<Text>(chip).data,
    finish: text('reportOnTrackFinish'),
    target: text('reportOnTrackDailyTarget'),
    calendar: text('reportOnTrackCalendarBehind'),
  );
}

/// Every string painted on screen.
List<String> _painted(WidgetTester tester) => [
  for (final t in tester.widgetList<RichText>(find.byType(RichText)))
    t.text.toPlainText(),
];

/// Overrides that give both surfaces [state] through the shared provider.
List<Override> _learner(LearnerState state) => [
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
  activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
  learnerStateProvider.overrideWith((ref, _) => Stream.value(state)),
];

/// The parent Dashboard with Mishnayos active, over [state].
List<Override> _dashboard(LearnerState state) => [
  ..._learner(state),
  dashboardActiveCurriculaProvider.overrideWith(
    (ref) => Future.value([CurriculumId.mishnayos]),
  ),
  dashboardActiveCurriculaStreamProvider.overrideWith(
    (ref) => Stream.value([CurriculumId.mishnayos]),
  ),
  dashboardUserModeProvider.overrideWith(
    (ref) => Future.value(ProfileMode.adult),
  ),
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
  ),
  dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(0)),
  allDailyTasksProvider.overrideWith((ref) => Future.value([])),
  dashboardStreakRecoveryProvider.overrideWith(
    (ref) => Future.value(
      const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
    ),
  ),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value([
      CurriculumTrackEntity(
        curriculumId: CurriculumId.mishnayos,
        state: 'active',
        stateChangedAt: DateTime.utc(2026, 9, 1),
        activatedAt: DateTime.utc(2026, 9, 1),
      ),
    ]),
  ),
];

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  for (final (label, build, expectedStatus) in [
    ('deadline, on track', () => _deadline('2027-09-01'), 'On track'),
    ('deadline, behind pace', () => _deadline('2026-10-20'), 'Behind pace'),
    ('calendar program, behind the calendar', _calendar, 'Behind pace'),
  ]) {
    testWidgets('$label: the report paints the state\'s status, projected '
        'finish and daily target, and the Dashboard paints no other', (
      tester,
    ) async {
      final state = build();
      final curriculum = state[engineCurriculum]!;
      final expected = _expected(curriculum);
      // The fixture really is the case under test.
      expect(expected.status, expectedStatus);
      expect(expected.target, isNotNull);
      if (curriculum.report.calendarProgram) {
        expect(curriculum.shortfall, greaterThan(0));
        expect(expected.calendar, isNotNull);
      }

      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The report, through the shared learner-state provider.
      await tester.pumpWidget(
        pumpApp(
          child: const LifetimeReportScreen(curriculumId: engineCurriculum),
          overrides: [
            parentSessionProvider.overrideWith((ref) async => true),
            ..._learner(state),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final report = _report(tester);
      expect(report, expected);

      // The real parent Dashboard, in a fresh scope over the same state.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        pumpApp(child: const DashboardScreen(), overrides: _dashboard(state)),
      );
      await tester.pump(const Duration(seconds: 1));
      // The active Dashboard body rendered (greeting over a live track).
      expect(find.textContaining('Learner!'), findsOneWidget);

      for (final s in _painted(tester)) {
        if (const {
          'On track',
          'Behind pace',
          'Too early to tell',
        }.contains(s.trim())) {
          expect(s.trim(), report.status, reason: 'Dashboard status');
        }
        if (s.startsWith('Projected finish')) {
          expect(report.finish, isNotNull);
          expect(s, startsWith(report.finish!), reason: 'Dashboard finish');
        }
        if (s.startsWith('Daily target')) {
          expect(s, report.target, reason: 'Dashboard daily target');
        }
        if (s.contains('behind the calendar')) {
          expect(s, report.calendar, reason: 'Dashboard calendar shortfall');
        }
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  }
}
