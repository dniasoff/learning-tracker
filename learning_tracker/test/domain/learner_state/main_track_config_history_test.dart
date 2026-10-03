// Main-track stage and study-day config as of any instant: the current docs
// rewound through the change log's `before` values (AD-38, AD-43).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/main_track_config_history.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

MainTrackConfigDoc _studyDay(int dow, String type) => MainTrackConfigDoc(
  collection: MainTrackConfigDoc.studyDays,
  docId: '${engineCurriculum}_$dow',
  curriculumId: engineCurriculum,
  fields: {'day_of_week': dow, 'day_type': type},
);

void main() {
  test('StageSpec.fromFields reads the schedule and drops invalid values', () {
    expect(StageSpec.fromFields(const {'schedule_type': 'weekly'}), isNull);
    final spec = StageSpec.fromFields(const {
      'stage_order': 2,
      'schedule_type': 'weekly',
      'delay_days': -1,
      'days_of_week': [1, 8, 3],
      'rolling_window_size': 0,
    })!;
    expect(spec.stageOrder, 2);
    expect(spec.scheduleType, StageScheduleType.weekly);
    expect(spec.delayDays, 0);
    expect(spec.daysOfWeek, {1, 3});
    expect(spec.rollingWindowSize, isNull);
    expect(
      StageSpec.fromFields(const {
        'stage_order': 1,
        'schedule_type': 'x',
      })!.scheduleType,
      StageScheduleType.delay,
    );
  });

  test('MainTrackConfig orders stages and finds the next stage', () {
    final intent = MainTrackIntent(
      curriculumId: engineCurriculum,
      track: engineIntent().track,
      stages: [engineStage(3), engineStage(1)],
    );
    final config = MainTrackConfigHistory.build(
      curriculumId: engineCurriculum,
      intent: intent,
      intentHistory: const [],
    ).current;
    expect([for (final s in config.stages) s.stageOrder], [1, 3]);
    expect(config.firstStageOrder, 1);
    expect(config.stageAfter(1)?.stageOrder, 3);
    expect(config.stageAfter(3), isNull);
  });

  test('a study-day change applies from its instant on, not before', () {
    final intent = MainTrackIntent(
      curriculumId: engineCurriculum,
      track: engineIntent().track,
      studyDays: [_studyDay(1, 'study')],
    );
    final change = ChangeLogEntry(
      id: engineUlid(10),
      entity: GovernedEntity.mainTrackStudyDays,
      entityId: engineCurriculum,
      actionId: engineUlid(11),
      before: {'study_day_configs/${engineCurriculum}_1.day_type': 'review'},
      after: {'study_day_configs/${engineCurriculum}_1.day_type': 'study'},
      at: engineAt(100),
      actor: parentActor,
    );
    final history = MainTrackConfigHistory.build(
      curriculumId: engineCurriculum,
      intent: intent,
      intentHistory: [change],
    );

    expect(history.current.studyDays.studyWeekdays, {1});
    expect(history.at(engineAt(200)).studyDays.studyWeekdays, {1});
    expect(history.at(engineAt(100)).studyDays.studyWeekdays, {1});
    expect(history.at(engineAt(50)).studyDays.studyWeekdays, isEmpty);
    expect(history.at(engineAt(50)).studyDays.activeWeekdays, {1});
  });
}
