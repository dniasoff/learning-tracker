// Mirror test for
// `lib/features/learning/presentation/providers/completion_providers.dart`
// (Story 1.21, DNI-483 T1): the Browse/text per-item reads derive from the
// active learner's LearnerState instead of the retired `completions` store.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _ref = 'Mishnah Berakhot 1:1';
const _other = 'Mishnah Berakhot 1:2';
const _subTrack = '01ARZ3NDEKTSV4RRFFQ69G5FC1';

var _next = 0;

LearningEvent _learn({
  String ref = _ref,
  String curriculumId = 'mishnayos',
  String source = LearningEvent.sourceMain,
  int? stage = 1,
}) => LearningEvent.learn(
  id: engineUlid(++_next),
  curriculumId: curriculumId,
  ref: ref,
  source: source,
  dateState: DateState.dated,
  learnedOn: '2026-09-01',
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

ProviderContainer _container(LearnerState? state) {
  final container = ProviderContainer(
    overrides: [
      activeLearnerStateFutureProvider.overrideWith((ref) async => state),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('stageOfLearn', () {
    test('main learn keeps its stage', () {
      expect(stageOfLearn(_learn(stage: 3)), 3);
    });

    test('main learn without a stage is the first stage', () {
      expect(stageOfLearn(_learn(stage: null)), kDefaultFirstStageOrder);
      expect(stageOfLearn(_learn(stage: null), firstStageOrder: 4), 4);
    });

    test('a sub-track learn has no stage', () {
      expect(stageOfLearn(_learn(source: _subTrack, stage: null)), isNull);
    });
  });

  group('isStageCompletedProvider', () {
    ({String sefariaRef, int stageId, String trackType}) params(int stage) =>
        (sefariaRef: _ref, stageId: stage, trackType: 'personal');

    test('true only for a counted learn of that ref and stage', () async {
      final container = _container(
        _state([_learn(stage: 1), _learn(ref: _other, stage: 2)]),
      );

      expect(
        await container.read(isStageCompletedProvider(params(1)).future),
        isTrue,
      );
      expect(
        await container.read(isStageCompletedProvider(params(2)).future),
        isFalse,
      );
    });

    test('false while no learner is active', () async {
      final container = _container(null);

      expect(
        await container.read(isStageCompletedProvider(params(1)).future),
        isFalse,
      );
    });

    test('a sub-track learn of the ref is not a stage completion', () async {
      final container = _container(
        _state([_learn(source: _subTrack, stage: null)]),
      );

      expect(
        await container.read(isStageCompletedProvider(params(1)).future),
        isFalse,
      );
    });
  });

  group('itemStageBreakdownProvider', () {
    test('counts counted learns of the item by stage', () async {
      final container = _container(
        _state([
          _learn(stage: 1),
          _learn(stage: 2),
          _learn(stage: 2),
          _learn(stage: null),
          _learn(ref: _other, stage: 1),
          _learn(curriculumId: 'bavli', stage: 1),
          _learn(source: _subTrack, stage: null),
        ]),
      );

      final breakdown = await container.read(
        itemStageBreakdownProvider((
          curriculumId: 'mishnayos',
          sefariaRef: _ref,
        )).future,
      );

      expect(breakdown, {1: 2, 2: 2});
    });

    test('empty while no learner is active', () async {
      final container = _container(null);

      final breakdown = await container.read(
        itemStageBreakdownProvider((
          curriculumId: 'mishnayos',
          sefariaRef: _ref,
        )).future,
      );

      expect(breakdown, isEmpty);
    });
  });
}
