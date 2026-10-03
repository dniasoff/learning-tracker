// Mirror test for
// `lib/features/dashboard/presentation/providers/calendar_position_providers.dart`
// (Story 1.21, DNI-483 T1): program calendar progress counts the
// first-stage in-track learns of LearnerState, not `completions` rows.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _subTrack = '01ARZ3NDEKTSV4RRFFQ69G5FC1';

var _next = 0;

LearningEvent _learn(
  String ref, {
  String curriculumId = 'bavli',
  String source = LearningEvent.sourceMain,
  DateState dateState = DateState.dated,
  int? stage = 1,
}) => LearningEvent.learn(
  id: engineUlid(++_next),
  curriculumId: curriculumId,
  ref: ref,
  source: source,
  dateState: dateState,
  learnedOn: dateState == DateState.beforeTracking ? null : '2026-09-01',
  stage: stage,
  recordedAt: t0,
  actor: parentActor,
);

LearnerState _state(List<LearningEvent> learns) => LearnerState(
  nowUtc: t1,
  curricula: const {},
  countedLearns: learns,
  countedEventIds: {for (final e in learns) e.id},
);

void main() {
  group('trackLearntRefs', () {
    test('distinct first-stage in-track refs of the curriculum', () {
      final state = _state([
        _learn('Berakhot 2a'),
        _learn('Berakhot 2a'),
        _learn('Berakhot 2b', dateState: DateState.catchUp),
        _learn('Berakhot 3a', stage: null),
        _learn('Berakhot 3b', stage: 2),
        _learn('Berakhot 4a', dateState: DateState.beforeTracking),
        _learn('Berakhot 4b', source: _subTrack, stage: null),
        _learn('Mishnah Berakhot 1:1', curriculumId: 'mishnayos'),
      ]);

      expect(
        trackLearntRefs(state, curriculumId: 'bavli', firstStageOrder: 1),
        {'Berakhot 2a', 'Berakhot 2b', 'Berakhot 3a'},
      );
    });

    test('a stageless main learn is the configured first stage', () {
      final state = _state([_learn('Berakhot 2a', stage: null)]);

      expect(
        trackLearntRefs(state, curriculumId: 'bavli', firstStageOrder: 3),
        {'Berakhot 2a'},
      );
    });

    test('any main stage counts when no stage is configured', () {
      final state = _state([
        _learn('Berakhot 2a', stage: 2),
        _learn('Berakhot 2b', source: _subTrack, stage: null),
      ]);

      expect(trackLearntRefs(state, curriculumId: 'bavli'), {'Berakhot 2a'});
    });

    test('empty without a learner', () {
      expect(trackLearntRefs(null, curriculumId: 'bavli'), isEmpty);
    });
  });
}
