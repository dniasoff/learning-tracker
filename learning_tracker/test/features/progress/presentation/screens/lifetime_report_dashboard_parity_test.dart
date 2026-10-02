// Story 5.3 (DNI-518) AC-11: the Dashboard and the lifetime report show
// one status, projected finish and daily target for one `LearnerState`.
//
// Each case is one real `LearnerStateEngine` run (deadline on track,
// deadline behind pace, calendar program behind the calendar). Both
// surfaces get that same state through the shared learner-state provider.
//
// 1. Report half (live): the report screen must paint exactly the state's
//    own values. The oracle below reads the raw `CurriculumState` fields
//    (projection status, projected finish, daily target, calendar
//    shortfall); it does not go through `OnTrackView`, so a mapping slip in
//    the report fails.
// 2. Dashboard half (DEFERRED to DNI-502): the Dashboard's on-track card is
//    Story 2.11 (DNI-502, bead fyh.44, AC-1: "Projected finish: {date} ·
//    deadline {date}" and "Daily target: {n} {unit}/day" from
//    `LearnerState`), and it is not built yet. The parity test below
//    requires the real `DashboardScreen` to paint the report's status,
//    projected finish and daily target (presence, then equality), so it
//    cannot pass on an empty Dashboard. It is skipped until DNI-502 lands
//    (bead fyh.195 unskips it).
// 3. Tripwire (live): today's Dashboard paints no on-track figure at all
//    (its only legacy pace source, `dashboardPaceStatusProvider`, is
//    watched by no widget and DNI-474 deletes it), so no second, divergent
//    pace figure is visible beside the report. When the DNI-502 card lands
//    this tripwire fails on purpose: delete it and unskip the parity test.
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

/// The fixtures under test: label, state builder, expected status.
final _cases = <(String, LearnerState Function(), String)>[
  ('deadline, on track', () => _deadline('2027-09-01'), 'On track'),
  ('deadline, behind pace', () => _deadline('2026-10-20'), 'Behind pace'),
  ('calendar program, behind the calendar', _calendar, 'Behind pace'),
];

/// AC-11's Dashboard half waits for the DNI-502 on-track card (bead
/// fyh.195). Flip to false when that card is on the Dashboard.
const _dashboardCardPending = true;

/// A phone-width surface tall enough that nothing on-track is off-screen.
Future<void> _tallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Pumps the parent report over [state] and returns what it paints.
Future<_Figures> _pumpReport(WidgetTester tester, LearnerState state) async {
  await _tallSurface(tester);
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
  return _report(tester);
}

/// Pumps the real parent Dashboard over [state], in a fresh scope, and
/// returns every string it paints.
Future<List<String>> _pumpDashboard(
  WidgetTester tester,
  LearnerState state,
) async {
  await _tallSurface(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    pumpApp(child: const DashboardScreen(), overrides: _dashboard(state)),
  );
  await tester.pump(const Duration(seconds: 1));
  // The active Dashboard body rendered (greeting over a live track).
  expect(find.textContaining('Learner!'), findsOneWidget);
  return _painted(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

const _statuses = {'On track', 'Behind pace', 'Too early to tell'};

/// Whether [s] is an on-track figure (status, finish, target, shortfall).
bool _isOnTrackFigure(String s) =>
    _statuses.contains(s.trim()) ||
    s.startsWith('Projected finish') ||
    s.startsWith('Daily target') ||
    s.contains('behind the calendar');

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  for (final (label, build, expectedStatus) in _cases) {
    testWidgets('$label: the report paints the state\'s status, projected '
        'finish and daily target', (tester) async {
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

      expect(await _pumpReport(tester, state), expected);
      await _unmount(tester);
    });

    testWidgets(
      '[deferred to DNI-502] $label: the Dashboard on-track card paints the '
      'report\'s status, projected finish and daily target',
      skip: _dashboardCardPending,
      (tester) async {
        final state = build();
        final report = await _pumpReport(tester, state);
        expect(report.status, expectedStatus);
        final painted = await _pumpDashboard(tester, state);

        // Presence first, so an empty Dashboard cannot pass.
        final status = painted.where((s) => _statuses.contains(s.trim()));
        expect(status, isNotEmpty, reason: 'Dashboard paints no status');
        final finish = painted.where((s) => s.startsWith('Projected finish'));
        expect(finish, isNotEmpty, reason: 'Dashboard paints no finish');
        final target = painted.where((s) => s.startsWith('Daily target'));
        expect(target, isNotEmpty, reason: 'Dashboard paints no target');

        // Then every figure it paints equals the report's.
        for (final s in status) {
          expect(s.trim(), report.status, reason: 'Dashboard status');
        }
        for (final s in finish) {
          expect(report.finish, isNotNull);
          expect(s, startsWith(report.finish!), reason: 'Dashboard finish');
        }
        for (final s in target) {
          expect(s, report.target, reason: 'Dashboard daily target');
        }
        for (final s in painted.where(
          (s) => s.contains('behind the calendar'),
        )) {
          expect(s, report.calendar, reason: 'Dashboard calendar shortfall');
        }
        await _unmount(tester);
      },
    );
  }

  testWidgets('tripwire: the Dashboard paints no on-track figure until the '
      'DNI-502 card lands', (tester) async {
    for (final (_, build, _) in _cases) {
      final painted = await _pumpDashboard(tester, build());
      expect(
        painted.where(_isOnTrackFigure),
        isEmpty,
        reason:
            'The Dashboard now paints an on-track figure (DNI-502 landed?). '
            'Set _dashboardCardPending to false so AC-11 parity runs, and '
            'delete this tripwire (bead fyh.195).',
      );
    }
    await _unmount(tester);
  });
}
