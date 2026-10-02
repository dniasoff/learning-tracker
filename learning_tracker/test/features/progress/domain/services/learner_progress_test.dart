// Mirror test for
// `lib/features/progress/domain/services/learner_progress.dart`
// (DNI-474: read-side selections over LearnerState).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

void main() {
  final corpus = progressCorpus();

  group('learntLeavesFor', () {
    test("is the engine's set, or empty without a state", () {
      final state = progressState([progressLearn(1, 'Mishnah Peah 1:1')]);
      expect(learntLeavesFor(state, engineCurriculum), {'Mishnah Peah 1:1'});
      expect(learntLeavesFor(null, engineCurriculum), isEmpty);
    });

    test('a composite unions its subsets within its own corpus (I-4)', () {
      final state = fakeLearnerState(
        curricula: {
          'tanach': FakeCurriculumState(learntLeaves: const {'Genesis 1:1'}),
          'chumash': FakeCurriculumState(
            learntLeaves: const {'Mishnah Peah 1:1', 'Elsewhere 1:1'},
          ),
        },
      );
      expect(
        learntLeavesFor(
          state,
          'tanach',
          subsetIds: const ['chumash'],
          corpus: corpus,
        ),
        {'Genesis 1:1', 'Mishnah Peah 1:1'},
      );
    });
  });

  test('learntTriState and learntCount follow the engine rule', () {
    const berakhot = NodeEntry(level: 'masechta', ref: 'Mishnah Berakhot');
    final learnt = {'Mishnah Berakhot 1:1'};
    expect(
      learntTriState(berakhot, corpus: corpus, learnt: learnt),
      TriState.partial,
    );
    expect(learntCount(berakhot, corpus: corpus, learnt: learnt), (
      learnt: 1,
      total: 5,
    ));
  });

  test('leafActivityOf counts events per leaf (a node event once per leaf), '
      'tracked events and stages', () {
    final state = progressState([
      progressGround(1, 'Mishnah Peah', 'masechta'),
      progressLearn(2, 'Mishnah Peah 1:1', minutes: 2, stage: 1),
      progressLearn(3, 'Mishnah Peah 1:1', minutes: 3, stage: 2),
    ]);
    final activity = leafActivityOf(state, corpus);
    final peah1 = activity['Mishnah Peah 1:1']!;
    expect(peah1.events, 3);
    expect(peah1.chazaros, 2);
    expect(peah1.trackedEvents, 2);
    expect(peah1.stages, {1, 2});
    expect(peah1.firstBeforeTracking, isTrue);
    expect(peah1.firstAt, engineAt(0));
    expect(peah1.lastAt, engineAt(3));
    expect(activity['Mishnah Peah 1:2']!.events, 1);
  });

  test('learnedOnDay is the local day of learned_on; none before '
      'tracking', () {
    expect(
      learnedOnDay(progressLearn(1, 'x', learnedOn: '2026-09-07')),
      DateTime(2026, 9, 7),
    );
    expect(learnedOnDay(progressGround(2, 'Mishnah Peah', 'masechta')), isNull);
  });

  test('chazaraCount counts repeats; trackedOnly skips before-tracking '
      'repeats', () {
    final state = progressState([
      progressGround(1, 'Mishnah Peah', 'masechta'),
      progressLearn(2, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(3, 'Mishnah Peah 1:1', minutes: 2),
      progressGround(4, 'Mishnah Peah', 'masechta', minutes: 3),
    ]);
    expect(chazaraCount(state, corpusFor: (_) => corpus), 3);
    expect(chazaraCount(state, corpusFor: (_) => corpus, trackedOnly: true), 2);
  });

  test('lastLearntAt is the latest effective instant of a counted learn', () {
    final state = progressState([
      progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(2, 'Mishnah Peah 1:2', minutes: 7),
      engineVoid(3, 2, minutes: 8),
    ]);
    expect(lastLearntAt(state), engineAt(1));
    expect(lastLearntAt(null), isNull);
  });

  test('CurriculumProgressIndex answers per-node progress', () {
    final index = CurriculumProgressIndex.of(
      progressState([
        progressLearn(1, 'Mishnah Peah 1:1'),
        progressLearn(2, 'Mishnah Peah 1:1', minutes: 1),
      ]),
      corpus,
    );
    final peah = index.nodeProgress('Mishnah Peah')!;
    expect(
      (peah.state, peah.learnt, peah.total, peah.events),
      (TriState.partial, 1, 2, 0),
    );
    final leaf = index.nodeProgress('Mishnah Peah 1:1')!;
    expect((leaf.state, leaf.events), (TriState.complete, 2));
    expect(index.nodeProgress('Unknown'), isNull);
    expect(index.nodeProgress('Mishnah Peah 1:2')!.state, TriState.empty);
  });

  test('DayActivity starts empty', () {
    final day = DayActivity();
    expect(
      (day.events, day.limudim, day.chazaros, day.newLeaves),
      (0, 0, 0, 0),
    );
    expect(DateState.dated, isNotNull);
  });
}
