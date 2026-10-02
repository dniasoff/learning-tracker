// DNI-467 AC-4: calendar-program assignments, backlog, amnesty anchor and
// calendar daily target (AD-35 "Calendar programs").
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

const _program = 'mishnah_yomit';

/// `engineAt(10000)` is 2026-09-07 (UTC learner).
const _today = '2026-09-07';

/// Minutes after 2026-09-01T00:00Z of [day] (1-based day of September) at
/// [hour]:00.
int _minutesOn(int day, {int hour = 10}) => (day - 1) * 1440 + hour * 60;

NodeEntry _leaf(String ref) => NodeEntry(level: 'mishnah', ref: ref);

final _calendar = <CalendarAssignment>[
  // Before tracking_start_date: never backlog.
  const CalendarAssignment('2026-09-01', berakhot1),
  // On tracking_start_date (inclusive); the unknown ref expands to nothing.
  CalendarAssignment('2026-09-03', _leaf('Mishnah Berakhot 2:1')),
  CalendarAssignment('2026-09-03', _leaf('Mishnah Nope 1:1')),
  // A parent node: expanded to its leaves.
  const CalendarAssignment('2026-09-04', peah),
  // Today, and a future date.
  CalendarAssignment(_today, _leaf('Mishnah Shabbat 1:1')),
  CalendarAssignment('2026-09-08', _leaf('Mishnah Shabbat 1:2')),
];

MainTrackIntent _intent({
  String? startDate = '2026-09-03',
  MainTrackConfigDoc? scope,
}) => MainTrackIntent(
  curriculumId: engineCurriculum,
  track: MainTrack(
    curriculumId: engineCurriculum,
    state: MainTrackState.active,
  ),
  program: MainTrackProgram(
    curriculumId: engineCurriculum,
    programId: _program,
    trackingStartDate: startDate,
  ),
  scope: scope,
);

ChangeLogEntry _entry(
  int id,
  GovernedEntity entity, {
  required int minutes,
  int? originalMinutes,
  String curriculumId = engineCurriculum,
}) {
  final key = entity == GovernedEntity.mainTrackOrder
      ? 'track_learning_order/${curriculumId}_masechta_x.user_sort_order'
      : 'profile_programs/$curriculumId.program_id';
  return ChangeLogEntry(
    id: engineUlid(id),
    entity: entity,
    entityId: curriculumId,
    actionId: engineUlid(id),
    before: {key: null},
    after: {key: 1},
    at: engineAt(minutes),
    originalAt: originalMinutes == null ? null : engineAt(originalMinutes),
    actor: parentActor,
  );
}

final _events = [
  engineLearn(1, 'Mishnah Peah 1:1', minutes: 10, stage: 1),
  // A voided learn leaves 2:1 unlearnt.
  engineLearn(2, 'Mishnah Berakhot 2:1', minutes: 11, stage: 1),
  engineVoid(3, 2, minutes: 12),
];

CurriculumState _run({
  MainTrackIntent? intent,
  List<ChangeLogEntry> history = const [],
  List<LearningEvent>? events,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events ?? _events,
    intents: {engineCurriculum: intent ?? _intent()},
    intentHistory: history,
    calendars: {_program: _calendar},
  ),
)[engineCurriculum]!;

void main() {
  group('programAssignments', () {
    final state = _run();

    test('a parent node is expanded to its leaves', () {
      expect(state.programAssignments('2026-09-04'), [
        'Mishnah Peah 1:1',
        'Mishnah Peah 1:2',
      ]);
    });

    test('refs outside the corpus are dropped; learnt leaves stay', () {
      expect(state.programAssignments('2026-09-03'), ['Mishnah Berakhot 2:1']);
      expect(
        state.programAssignments('2026-09-04'),
        contains('Mishnah Peah 1:1'),
      );
    });

    test('a date with no assignment is empty', () {
      expect(state.programAssignments('2026-09-05'), isEmpty);
    });

    test('assignments are intersected with the learner corpus (scope)', () {
      final scoped = _run(
        intent: _intent(
          scope: engineScope({'level': 'seder', 'ref': 'Seder Zeraim'}),
        ),
      );
      expect(scoped.programAssignments(_today), isEmpty);
      expect(scoped.programAssignments('2026-09-04'), hasLength(2));
    });

    test('a program missing from the calendars input assigns nothing', () {
      final state = const LearnerStateEngine().run(
        engineInputs(events: _events, intents: {engineCurriculum: _intent()}),
      )[engineCurriculum]!;
      expect(state.programAssignments('2026-09-04'), isEmpty);
      expect(state.programBacklog(_today), isEmpty);
      expect(state.dailyTarget, 0);
    });
  });

  group('programBacklog', () {
    test('assigned before today, on/after tracking_start_date, unlearnt', () {
      expect(_run().programBacklog(_today), [
        'Mishnah Berakhot 2:1',
        'Mishnah Peah 1:2',
      ]);
    });

    test(
      'both anchors are inclusive: the start date counts, today does not',
      () {
        final backlog = _run().programBacklog(_today);
        expect(backlog, contains('Mishnah Berakhot 2:1'));
        expect(backlog, isNot(contains('Mishnah Shabbat 1:1')));
        expect(backlog, isNot(contains('Mishnah Berakhot 1:1')));
      },
    );

    test('backlog is a pure function of its today argument', () {
      final state = _run();
      expect(state.programBacklog('2026-09-04'), ['Mishnah Berakhot 2:1']);
      expect(state.programBacklog('2026-09-09'), [
        'Mishnah Berakhot 2:1',
        'Mishnah Peah 1:2',
        'Mishnah Shabbat 1:1',
        'Mishnah Shabbat 1:2',
      ]);
    });

    test(
      'a later mainTrackOrder entry moves amnestyFrom to its civil date',
      () {
        final state = _run(
          history: [
            _entry(50, GovernedEntity.mainTrackOrder, minutes: _minutesOn(4)),
          ],
        );
        expect(state.programBacklog(_today), ['Mishnah Peah 1:2']);
      },
    );

    test('a mainTrackProgram entry anchors by original_at ?? at', () {
      final state = _run(
        history: [
          _entry(
            50,
            GovernedEntity.mainTrackProgram,
            minutes: _minutesOn(6),
            originalMinutes: _minutesOn(4),
          ),
        ],
      );
      expect(state.programBacklog(_today), ['Mishnah Peah 1:2']);
    });

    test('an entry older than tracking_start_date, another curriculum or '
        'another entity does not move the anchor', () {
      final state = _run(
        history: [
          _entry(50, GovernedEntity.mainTrackOrder, minutes: _minutesOn(1)),
          _entry(
            60,
            GovernedEntity.mainTrackOrder,
            minutes: _minutesOn(6),
            curriculumId: 'bavli',
          ),
          ChangeLogEntry(
            id: engineUlid(70),
            entity: GovernedEntity.mainTrackStages,
            entityId: engineCurriculum,
            actionId: engineUlid(70),
            before: {'stage_definitions/${engineCurriculum}_2.delay_days': 1},
            after: {'stage_definitions/${engineCurriculum}_2.delay_days': 2},
            at: engineAt(_minutesOn(6)),
            actor: parentActor,
          ),
        ],
      );
      expect(state.programBacklog(_today), hasLength(2));
    });

    test('retired anchors last_reorder_at and activated_at are never read', () {
      final intent = MainTrackIntent.fromStorageDocs(engineCurriculum, {
        'curriculum_tracks/$engineCurriculum': {
          'curriculum_id': engineCurriculum,
          'state': 'active',
          'last_reorder_at': engineAt(_minutesOn(6)),
          'activated_at': engineAt(_minutesOn(6)),
        },
        'profile_programs/$engineCurriculum': {
          'curriculum_id': engineCurriculum,
          'program_id': _program,
          'tracking_start_date': '2026-09-03',
        },
      });
      expect(_run(intent: intent).programBacklog(_today), hasLength(2));
    });
  });

  group('calendar dailyTarget and shortfall', () {
    test('target = assigned through today minus learnt; shortfall = '
        'backlog', () {
      final state = _run();
      // Backlog (Berakhot 2:1, Peah 1:2) + today (Shabbat 1:1).
      expect(state.dailyTarget, 3);
      expect(state.shortfall, 2);
    });

    test('learning today\'s assignment lowers the target', () {
      final state = _run(
        events: [
          ..._events,
          engineLearn(9, 'Mishnah Shabbat 1:1', minutes: 9000, stage: 1),
        ],
      );
      expect(state.dailyTarget, 2);
    });

    test('no AD-44 pace or projection inputs are needed', () {
      expect(_run().paceRate, isNull);
    });
  });

  group('missing tracking_start_date', () {
    final state = _run(intent: _intent(startDate: null));

    test('is a validation error, not a default', () {
      expect(state.validationErrors, {
        CurriculumValidationError.missingTrackingStartDate,
      });
      expect(state.programBacklog(_today), isEmpty);
      expect(state.dailyTarget, isNull);
      expect(state.shortfall, isNull);
    });

    test('assignments are still derived', () {
      expect(state.programAssignments('2026-09-04'), hasLength(2));
    });
  });

  test('a valid calendar curriculum has no validation error', () {
    expect(_run().validationErrors, isEmpty);
  });

  test('an ended program plans from the main track, not the calendar', () {
    final intent = MainTrackIntent(
      curriculumId: engineCurriculum,
      track: MainTrack(
        curriculumId: engineCurriculum,
        state: MainTrackState.active,
      ),
      program: MainTrackProgram(
        curriculumId: engineCurriculum,
        programId: _program,
        trackingStartDate: '2026-09-03',
        endedAt: engineAt(1),
      ),
    );
    final state = _run(intent: intent);
    expect(state.programAssignments('2026-09-04'), isEmpty);
    expect(state.dailyTarget, isNull);
  });
}
