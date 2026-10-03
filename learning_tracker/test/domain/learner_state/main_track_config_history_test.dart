// Mirror test for `lib/domain/learner_state/main_track_config_history.dart`
// (AD-35 "Complete inputs"): the stages and study days in force at any
// instant, reconstructed from the current docs and the intent history.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/main_track_config_history.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

MainTrackConfigDoc _stage(
  int order, {
  String type = 'delay',
  int? delay,
  List<int>? days,
  int? window,
  DateTime? endedAt,
}) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.stages,
  docId: '${engineCurriculum}_$order',
  curriculumId: engineCurriculum,
  fields: {
    'stage_order': order,
    'schedule_type': type,
    'delay_days': ?delay,
    'days_of_week': ?days,
    'rolling_window_size': ?window,
  },
  endedAt: endedAt,
);

MainTrackConfigDoc _day(int dow, String type) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.studyDays,
  docId: '${engineCurriculum}_$dow',
  curriculumId: engineCurriculum,
  fields: {'day_of_week': dow, 'day_type': type},
);

MainTrackIntent _intent({
  List<MainTrackConfigDoc> stages = const [],
  List<MainTrackConfigDoc> days = const [],
}) => MainTrackIntent(
  curriculumId: engineCurriculum,
  track: MainTrack(
    curriculumId: engineCurriculum,
    state: MainTrackState.active,
  ),
  stages: stages,
  studyDays: days,
);

String _stageKey(int order, String field) =>
    '${MainTrackConfigDoc.stages}/${engineCurriculum}_$order.$field';

String _dayKey(int dow, String field) =>
    '${MainTrackConfigDoc.studyDays}/${engineCurriculum}_$dow.$field';

ChangeLogEntry _entry(
  int id,
  GovernedEntity entity,
  Map<String, Object?> before,
  Map<String, Object?> after, {
  required DateTime at,
  DateTime? originalAt,
  String entityId = engineCurriculum,
}) => ChangeLogEntry(
  id: engineUlid(id),
  entity: entity,
  entityId: entityId,
  actionId: engineUlid(id),
  before: before,
  after: after,
  at: at,
  originalAt: originalAt,
  actor: parentActor,
);

MainTrackConfigHistory _build(
  MainTrackIntent intent,
  List<ChangeLogEntry> history,
) => MainTrackConfigHistory.build(
  curriculumId: engineCurriculum,
  intent: intent,
  intentHistory: history,
);

final _sep3 = DateTime.utc(2026, 9, 3);
final _sep5 = DateTime.utc(2026, 9, 5);
final _sep7 = DateTime.utc(2026, 9, 7);

void main() {
  group('StageSpec.fromFields', () {
    test('types a full doc', () {
      final spec = StageSpec.fromFields({
        'stage_order': 3,
        'schedule_type': 'weekly',
        'delay_days': 4,
        'days_of_week': [1, 3, 9, 'x', 0],
        'rolling_window_size': 5,
      })!;
      expect(spec.stageOrder, 3);
      expect(spec.scheduleType, StageScheduleType.weekly);
      expect(spec.delayDays, 4);
      expect(spec.daysOfWeek, {1, 3});
      expect(spec.rollingWindowSize, 5);
    });

    test('defaults to a zero-delay delay stage', () {
      final spec = StageSpec.fromFields({'stage_order': 1})!;
      expect(spec.scheduleType, StageScheduleType.delay);
      expect(spec.delayDays, 0);
      expect(spec.daysOfWeek, isEmpty);
      expect(spec.rollingWindowSize, isNull);
    });

    test('an unknown type reads as delay; bad numbers are ignored', () {
      final spec = StageSpec.fromFields({
        'stage_order': 2,
        'schedule_type': 'monthly',
        'delay_days': -3,
        'rolling_window_size': 0,
      })!;
      expect(spec.scheduleType, StageScheduleType.delay);
      expect(spec.delayDays, 0);
      expect(spec.rollingWindowSize, isNull);
    });

    test('is null without an int stage_order', () {
      expect(StageSpec.fromFields({'schedule_type': 'delay'}), isNull);
      expect(StageSpec.fromFields({'stage_order': '1'}), isNull);
    });

    test('compares by value', () {
      final a = StageSpec(stageOrder: 1, daysOfWeek: {1, 2});
      final b = StageSpec(stageOrder: 1, daysOfWeek: {2, 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(StageSpec(stageOrder: 2, daysOfWeek: {1, 2})));
      expect(
        a,
        isNot(StageSpec(stageOrder: 1, delayDays: 1, daysOfWeek: {1, 2})),
      );
      expect(a.toString(), contains('delay'));
    });

    test('StageScheduleType.byStorage maps every storage string', () {
      for (final t in StageScheduleType.values) {
        expect(StageScheduleType.byStorage[t.storage], t);
      }
    });
  });

  group('MainTrackConfig', () {
    test('firstStageOrder and stageAfter follow the ascending stages', () {
      final config = MainTrackConfig(
        stages: [StageSpec(stageOrder: 1), StageSpec(stageOrder: 4)],
        studyDays: _build(_intent(), const []).current.studyDays,
      );
      expect(config.firstStageOrder, 1);
      expect(config.stageAfter(0)!.stageOrder, 1);
      expect(config.stageAfter(1)!.stageOrder, 4);
      expect(config.stageAfter(4), isNull);
    });

    test('with no stage there is no first stage or next stage', () {
      final config = _build(_intent(), const []).current;
      expect(config.stages, isEmpty);
      expect(config.firstStageOrder, isNull);
      expect(config.stageAfter(1), isNull);
    });
  });

  group('MainTrackConfigHistory.build', () {
    test('without history every instant sees the current docs', () {
      final history = _build(
        _intent(
          stages: [_stage(2, delay: 3), _stage(1)],
          days: [_day(1, 'study'), _day(2, 'review')],
        ),
        const [],
      );
      final now = history.current;
      expect(now.stages.map((s) => s.stageOrder), [1, 2]);
      expect(now.stages.last.delayDays, 3);
      expect(now.studyDays.studyWeekdays, {1});
      expect(now.studyDays.activeWeekdays, {1, 2});
      expect(
        history.at(DateTime.utc(2000)),
        same(history.at(DateTime.utc(2100))),
      );
      expect(history.at(_sep5).stages, now.stages);
    });

    test('no docs and no history yields the default config', () {
      final config = _build(_intent(), const []).at(_sep5);
      expect(config.stages, isEmpty);
      expect(config.studyDays.studyWeekdays, {1, 2, 3, 4, 5, 6, 7});
    });

    test('a field edit is undone for instants before it', () {
      final history = _build(
        _intent(stages: [_stage(1), _stage(2, delay: 3)]),
        [
          _entry(
            1,
            GovernedEntity.mainTrackStages,
            {_stageKey(2, 'delay_days'): 1},
            {_stageKey(2, 'delay_days'): 3},
            at: _sep5,
          ),
        ],
      );
      expect(
        history.at(_sep3).stages.last.delayDays,
        1,
        reason: 'before the edit',
      );
      expect(history.at(_sep5).stages.last.delayDays, 3, reason: 'at the edit');
      expect(history.at(_sep7).stages.last.delayDays, 3);
      expect(history.current.stages.last.delayDays, 3);
    });

    test('a doc created by an entry did not exist before it', () {
      final history = _build(
        _intent(stages: [_stage(1), _stage(2, delay: 3)]),
        [
          _entry(
            1,
            GovernedEntity.mainTrackStages,
            {
              _stageKey(2, 'stage_order'): null,
              _stageKey(2, 'schedule_type'): null,
              _stageKey(2, 'delay_days'): null,
            },
            {
              _stageKey(2, 'stage_order'): 2,
              _stageKey(2, 'schedule_type'): 'delay',
              _stageKey(2, 'delay_days'): 3,
            },
            at: _sep5,
          ),
        ],
      );
      expect(history.at(_sep3).stages.map((s) => s.stageOrder), [1]);
      expect(history.at(_sep5).stages.map((s) => s.stageOrder), [1, 2]);
    });

    test('an ended doc is absent now and present before it ended', () {
      final history = _build(
        _intent(
          stages: [
            _stage(1),
            _stage(2, endedAt: _sep5),
          ],
        ),
        [
          _entry(
            1,
            GovernedEntity.mainTrackStages,
            {_stageKey(2, GovernedKeys.endedAt): null},
            {_stageKey(2, GovernedKeys.endedAt): _sep5},
            at: _sep5,
          ),
        ],
      );
      expect(history.current.stages.map((s) => s.stageOrder), [1]);
      expect(history.at(_sep3).stages.map((s) => s.stageOrder), [1, 2]);
    });

    test('study-day entries are reconstructed too', () {
      final history = _build(_intent(days: [_day(1, 'review')]), [
        _entry(
          1,
          GovernedEntity.mainTrackStudyDays,
          {_dayKey(1, 'day_type'): 'study'},
          {_dayKey(1, 'day_type'): 'review'},
          at: _sep5,
        ),
      ]);
      expect(history.at(_sep3).studyDays.studyWeekdays, {1});
      expect(history.current.studyDays.studyWeekdays, isEmpty);
    });

    test('several entries unwind newest first; original_at orders them', () {
      final history = _build(_intent(stages: [_stage(1, delay: 9)]), [
        // Written first but made last (original_at Sep 7): 5 -> 9.
        _entry(
          1,
          GovernedEntity.mainTrackStages,
          {_stageKey(1, 'delay_days'): 5},
          {_stageKey(1, 'delay_days'): 9},
          at: _sep3,
          originalAt: _sep7,
        ),
        // Made Sep 5: 2 -> 5.
        _entry(
          2,
          GovernedEntity.mainTrackStages,
          {_stageKey(1, 'delay_days'): 2},
          {_stageKey(1, 'delay_days'): 5},
          at: _sep5,
        ),
      ]);
      expect(history.at(DateTime.utc(2026, 9, 4)).stages.single.delayDays, 2);
      expect(history.at(DateTime.utc(2026, 9, 6)).stages.single.delayDays, 5);
      expect(history.at(DateTime.utc(2026, 9, 8)).stages.single.delayDays, 9);
    });

    test('entries at the same instant order by id', () {
      final history = _build(_intent(stages: [_stage(1, delay: 9)]), [
        _entry(
          1,
          GovernedEntity.mainTrackStages,
          {_stageKey(1, 'delay_days'): 2},
          {_stageKey(1, 'delay_days'): 5},
          at: _sep5,
        ),
        _entry(
          2,
          GovernedEntity.mainTrackStages,
          {_stageKey(1, 'delay_days'): 5},
          {_stageKey(1, 'delay_days'): 9},
          at: _sep5,
        ),
      ]);
      expect(history.at(_sep3).stages.single.delayDays, 2);
      expect(history.at(_sep5).stages.single.delayDays, 9);
    });

    test('other curricula, entities and malformed keys are ignored', () {
      final history = _build(_intent(stages: [_stage(1, delay: 9)]), [
        _entry(
          1,
          GovernedEntity.mainTrackStages,
          {_stageKey(1, 'delay_days'): 1},
          {_stageKey(1, 'delay_days'): 9},
          at: _sep5,
          entityId: 'other',
        ),
        _entry(
          2,
          GovernedEntity.mainTrackOrder,
          {_stageKey(1, 'delay_days'): 1},
          {_stageKey(1, 'delay_days'): 9},
          at: _sep5,
        ),
        _entry(
          3,
          GovernedEntity.mainTrackStages,
          {'not-a-key': 1},
          {'not-a-key': 2},
          at: _sep5,
        ),
      ]);
      expect(history.at(_sep3).stages.single.delayDays, 9);
    });

    test('a stage doc with a duplicate order keeps the first by doc key', () {
      final history = _build(
        _intent(
          stages: [
            MainTrackConfigDoc(
              collection: MainTrackConfigDoc.stages,
              docId: '${engineCurriculum}_b',
              curriculumId: engineCurriculum,
              fields: {'stage_order': 1, 'delay_days': 8},
            ),
            MainTrackConfigDoc(
              collection: MainTrackConfigDoc.stages,
              docId: '${engineCurriculum}_a',
              curriculumId: engineCurriculum,
              fields: {'stage_order': 1, 'delay_days': 4},
            ),
          ],
        ),
        const [],
      );
      expect(history.current.stages, hasLength(1));
      expect(history.current.stages.single.delayDays, 4);
    });
  });
}
