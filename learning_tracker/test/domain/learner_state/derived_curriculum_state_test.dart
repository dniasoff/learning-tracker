// Mirror test for `lib/domain/learner_state/derived_curriculum_state.dart`
// (DNI-465 T1: the engine's CurriculumState and its stage records).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/derived_curriculum_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  final corpus = mishnayosCorpus();

  DerivedCurriculumState state({Set<String> learnt = const {}}) =>
      DerivedCurriculumState(
        curriculumId: engineCurriculum,
        evaluated: true,
        learnt: LearntRecord(
          corpus: corpus,
          scopedLeaves: corpus.leaves,
          learntLeaves: learnt,
        ),
        mainTrack: MainTrackRecord(
          schedulableRefs: const ['Mishnah Berakhot 1:2'],
          currentUnit: berakhot,
          position: 'Mishnah Berakhot 1:2',
        ),
      );

  test('exposes its stage records through CurriculumState', () {
    final s = state(learnt: {'Mishnah Berakhot 1:1'});
    expect(s.learntLeaves, {'Mishnah Berakhot 1:1'});
    expect(s.distinctLearnt, 1);
    expect(s.currentUnit, berakhot);
    expect(s.mainTrackPosition, 'Mishnah Berakhot 1:2');
    expect(s.mainTrackRemaining, 1);
    expect(s.subTracks, isEmpty);
    expect(s.programAssignments('2026-09-01'), isEmpty);
    expect(s.programBacklog('2026-09-01'), isEmpty);
    expect(s.reviewsDue('2026-09-01'), isEmpty);
    expect(s.dailyTarget, isNull);
    expect(s.paceRate, isNull);
    expect(s.shortfall, isNull);
    expect(s.projection, isNull);
    expect(s.streak, isNull);
    expect(s.completedUnits, isEmpty);
  });

  test('equal records give equal states', () {
    expect(state(learnt: {'a'}), state(learnt: {'a'}));
    expect(state(learnt: {'a'}).hashCode, state(learnt: {'a'}).hashCode);
    expect(state(learnt: {'a'}), isNot(state(learnt: {'b'})));
  });

  test('a curriculum without a corpus is empty and every node is empty', () {
    final s = DerivedCurriculumState(
      curriculumId: 'x',
      evaluated: false,
      learnt: LearntRecord.none(),
    );
    expect(s.learntLeaves, isEmpty);
    expect(s.triState(berakhot), TriState.empty);
    expect(s.schedulableRefs, isEmpty);
    expect(s.mainTrackPosition, isNull);
  });

  test('records are unmodifiable', () {
    final s = state(learnt: {'a'});
    expect(() => s.learntLeaves.add('b'), throwsUnsupportedError);
    expect(() => s.schedulableRefs.add('b'), throwsUnsupportedError);
  });
}
