// Mirror test for `lib/domain/learner_state/learnt_set.dart` (DNI-465 T2:
// AD-31/AD-32 distinct learnt leaves).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  final corpus = mishnayosCorpus();

  group('coveredLeaves', () {
    test('a leaf event covers its leaf, from any source or date state', () {
      for (final e in [
        engineLearn(1, 'Mishnah Peah 1:1'),
        engineLearn(2, 'Mishnah Peah 1:1', stage: 3),
        engineLearn(3, 'Mishnah Peah 1:1', source: engineUlid(900)),
        engineLearn(4, 'Mishnah Peah 1:1', dateState: DateState.catchUp),
        engineLearn(5, 'Mishnah Peah 1:1', dateState: DateState.beforeTracking),
      ]) {
        expect(coveredLeaves(e, corpus), ['Mishnah Peah 1:1']);
      }
    });

    test('a before_tracking node event covers every leaf below it', () {
      expect(coveredLeaves(engineGround(1, berakhot2), corpus), [
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
      ]);
    });

    test('invalid records cover nothing', () {
      expect(
        coveredLeaves(engineLearn(1, 'Mishnah Nope 1:1'), corpus),
        isEmpty,
      );
      // A dated event whose ref is a container is not a leaf event.
      expect(
        coveredLeaves(engineLearn(2, 'Mishnah Berakhot'), corpus),
        isEmpty,
      );
      expect(coveredLeaves(engineVoid(3, 1), corpus), isEmpty);
    });
  });

  test('learntLeaves is the distinct, in-scope covered set', () {
    final learnt = learntLeaves(
      [
        engineLearn(1, 'Mishnah Berakhot 1:1'),
        engineLearn(2, 'Mishnah Berakhot 1:1', stage: 2),
        engineGround(3, berakhot2),
        engineLearn(4, 'Mishnah Shabbat 1:1'),
      ],
      corpus,
      (leaf) => leaf.startsWith('Mishnah Berakhot'),
    );
    expect(learnt, {
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
    });
  });
}
