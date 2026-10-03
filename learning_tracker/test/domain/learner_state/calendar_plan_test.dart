// Mirror test for `lib/domain/learner_state/calendar_plan.dart` (AD-35
// "Calendar programs"): `deriveCalendarPlan`, `followsCalendarProgram` and
// the `CalendarPlan` queries, exercised directly (the engine-level
// behaviour is in calendar_program_planning_test.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/calendar_plan.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

const _program = 'mishnah_yomit';
const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b21 = 'Mishnah Berakhot 2:1';
const _p11 = 'Mishnah Peah 1:1';
const _p12 = 'Mishnah Peah 1:2';

NodeEntry _leaf(String ref) => NodeEntry(level: 'mishnah', ref: ref);

MainTrackIntent _intent({
  String? programId = _program,
  String? startDate = '2026-09-03',
  MainTrackState state = MainTrackState.active,
  DateTime? trackEndedAt,
  DateTime? programEndedAt,
}) => MainTrackIntent(
  curriculumId: engineCurriculum,
  track: MainTrack(
    curriculumId: engineCurriculum,
    state: state,
    endedAt: trackEndedAt,
  ),
  program: MainTrackProgram(
    curriculumId: engineCurriculum,
    programId: programId,
    trackingStartDate: startDate,
    endedAt: programEndedAt,
  ),
);

ChangeLogEntry _entry(
  int id,
  GovernedEntity entity, {
  required DateTime at,
  DateTime? originalAt,
  String entityId = engineCurriculum,
}) => ChangeLogEntry(
  id: engineUlid(id),
  entity: entity,
  entityId: entityId,
  actionId: engineUlid(id),
  before: {'profile_programs/$entityId.program_id': null},
  after: {'profile_programs/$entityId.program_id': 1},
  at: at,
  originalAt: originalAt,
  actor: parentActor,
);

final _calendar = <String, List<CalendarAssignment>>{
  _program: [
    const CalendarAssignment('2026-09-01', berakhot1),
    CalendarAssignment('2026-09-03', _leaf(_b21)),
    CalendarAssignment('2026-09-03', _leaf('Mishnah Nope 1:1')),
    const CalendarAssignment('2026-09-04', peah),
    // Same leaf assigned twice on one day: listed once.
    CalendarAssignment('2026-09-07', _leaf(_b21)),
    CalendarAssignment('2026-09-07', _leaf(_b21)),
    CalendarAssignment('2026-09-08', _leaf(_b21)),
  ],
};

CalendarPlan? _derive({
  MainTrackIntent? intent,
  Set<LeafRef> learnt = const {},
  List<ChangeLogEntry> history = const [],
  bool Function(LeafRef)? inScope,
  Set<CurriculumValidationError>? errors,
  Map<String, List<CalendarAssignment>>? calendars,
}) => deriveCalendarPlan(
  curriculumId: engineCurriculum,
  intent: intent ?? _intent(),
  calendars: calendars ?? _calendar,
  corpus: mishnayosCorpus(),
  inScope: inScope ?? (_) => true,
  learnt: learnt,
  intentHistory: history,
  settingsHistory: c0SettingsHistory(),
  errors: errors ?? <CurriculumValidationError>{},
);

void main() {
  group('followsCalendarProgram', () {
    test('true for a live track with a live program naming a program_id', () {
      expect(followsCalendarProgram(_intent()), isTrue);
    });

    test('false without an intent, program, program_id', () {
      expect(followsCalendarProgram(null), isFalse);
      expect(followsCalendarProgram(_intent(programId: null)), isFalse);
      expect(
        followsCalendarProgram(
          MainTrackIntent(
            curriculumId: engineCurriculum,
            track: MainTrack(
              curriculumId: engineCurriculum,
              state: MainTrackState.active,
            ),
          ),
        ),
        isFalse,
      );
    });

    test('false when the track or the program is ended', () {
      expect(
        followsCalendarProgram(_intent(trackEndedAt: DateTime.utc(2026, 9))),
        isFalse,
      );
      expect(
        followsCalendarProgram(_intent(programEndedAt: DateTime.utc(2026, 9))),
        isFalse,
      );
    });
  });

  group('deriveCalendarPlan', () {
    test('is null when the curriculum does not follow a program', () {
      expect(_derive(intent: _intent(programId: null)), isNull);
      expect(
        deriveCalendarPlan(
          curriculumId: engineCurriculum,
          intent: null,
          calendars: _calendar,
          corpus: mishnayosCorpus(),
          inScope: (_) => true,
          learnt: const {},
          intentHistory: const [],
          settingsHistory: c0SettingsHistory(),
          errors: <CurriculumValidationError>{},
        ),
        isNull,
      );
    });

    test('expands nodes to leaves, drops unknown refs and duplicates', () {
      final plan = _derive()!;
      expect(plan.assignments('2026-09-01'), [
        _b11,
        _b12,
        'Mishnah Berakhot 1:3',
      ]);
      expect(plan.assignments('2026-09-03'), [_b21]);
      expect(plan.assignments('2026-09-04'), [_p11, _p12]);
      expect(plan.assignments('2026-09-07'), [_b21]);
      expect(plan.assignments('2026-09-05'), isEmpty);
    });

    test('inScope filters assignments', () {
      final plan = _derive(inScope: (ref) => ref.startsWith('Mishnah Peah'))!;
      expect(plan.assignments('2026-09-01'), isEmpty);
      expect(plan.assignments('2026-09-04'), [_p11, _p12]);
    });

    test('a program absent from calendars assigns nothing', () {
      final plan = _derive(calendars: const {})!;
      expect(plan.assignments('2026-09-04'), isEmpty);
      expect(plan.backlog('2026-09-30'), isEmpty);
      expect(plan.dailyTarget('2026-09-30'), 0);
    });

    test('amnestyFrom is tracking_start_date without a re-anchor', () {
      expect(_derive()!.amnestyFrom, '2026-09-03');
    });

    test('a missing tracking_start_date is a validation error', () {
      final errors = <CurriculumValidationError>{};
      final plan = _derive(intent: _intent(startDate: null), errors: errors)!;
      expect(errors, {CurriculumValidationError.missingTrackingStartDate});
      expect(plan.amnestyFrom, isNull);
      expect(plan.backlog('2026-09-30'), isEmpty);
      expect(plan.dailyTarget('2026-09-30'), isNull);
    });

    test('a later order/program entry moves amnestyFrom forward', () {
      final plan = _derive(
        history: [
          _entry(
            1,
            GovernedEntity.mainTrackOrder,
            at: DateTime.utc(2026, 9, 5, 9),
          ),
          _entry(
            2,
            GovernedEntity.mainTrackProgram,
            at: DateTime.utc(2026, 9, 6, 9),
          ),
        ],
      )!;
      expect(plan.amnestyFrom, '2026-09-06');
    });

    test('a re-anchor before the start never moves it back', () {
      final plan = _derive(
        history: [
          _entry(
            1,
            GovernedEntity.mainTrackProgram,
            at: DateTime.utc(2026, 9, 2),
          ),
        ],
      )!;
      expect(plan.amnestyFrom, '2026-09-03');
    });

    test('original_at wins over at; other entities and curricula ignored', () {
      final plan = _derive(
        history: [
          // Written late, but made on the 5th.
          _entry(
            1,
            GovernedEntity.mainTrackProgram,
            at: DateTime.utc(2026, 9, 20),
            originalAt: DateTime.utc(2026, 9, 5, 9),
          ),
          _entry(
            2,
            GovernedEntity.mainTrackStages,
            at: DateTime.utc(2026, 9, 25),
          ),
          _entry(
            3,
            GovernedEntity.mainTrackOrder,
            at: DateTime.utc(2026, 9, 26),
            entityId: 'other',
          ),
        ],
      )!;
      expect(plan.amnestyFrom, '2026-09-05');
    });
  });

  group('CalendarPlan queries', () {
    test('backlog: unlearnt, from amnesty to before today, once each', () {
      final plan = _derive(learnt: {_p11})!;
      // 09-01 is before amnesty; 09-03 b21; 09-04 p11 (learnt) p12;
      // 09-07 is today and excluded.
      expect(plan.backlog('2026-09-07'), [_b21, _p12]);
    });

    test('backlog lists a leaf at its earliest date only', () {
      final plan = _derive()!;
      expect(plan.backlog('2026-09-09'), [_b21, _p11, _p12]);
    });

    test('dailyTarget counts the unlearnt through today inclusive', () {
      final plan = _derive(learnt: {_p11})!;
      expect(plan.dailyTarget('2026-09-04'), 2); // b21, p12
      expect(plan.dailyTarget('2026-09-07'), 2); // b21 repeats, once
      expect(plan.dailyTarget('2026-09-02'), 0); // before amnesty
    });

    test('learnt leaves stay in assignments but not backlog or target', () {
      final plan = _derive(learnt: {_b21, _p11, _p12})!;
      expect(plan.assignments('2026-09-03'), [_b21]);
      expect(plan.backlog('2026-09-30'), isEmpty);
      expect(plan.dailyTarget('2026-09-30'), 0);
    });

    test('assignments are unmodifiable', () {
      final plan = _derive()!;
      expect(
        () => plan.assignments('2026-09-04').add(_b11),
        throwsUnsupportedError,
      );
    });
  });

  group('CalendarPlan equality', () {
    test('equal over equal inputs, unequal otherwise', () {
      expect(_derive(), _derive());
      expect(_derive()!.hashCode, _derive()!.hashCode);
      expect(_derive(), isNot(_derive(learnt: {_b11})));
      expect(
        _derive(),
        isNot(_derive(intent: _intent(startDate: '2026-09-04'))),
      );
      expect(_derive(), isNot(_derive(calendars: const {})));
      expect(
        _derive(),
        isNot(_derive(inScope: (ref) => ref.startsWith('Mishnah Peah'))),
      );
    });
  });
}
