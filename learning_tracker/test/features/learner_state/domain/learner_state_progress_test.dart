// DNI-474 AC-3: the engine's distinct learnt count and hierarchy tri-state
// are what every progress surface reads (FR-14, FR-15).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/progress_fixtures.dart';

const _berakhot = NodeEntry(level: 'masechta', ref: 'Mishnah Berakhot');
const _berakhot1 = NodeEntry(level: 'perek', ref: 'Mishnah Berakhot 1');
const _zeraim = NodeEntry(level: 'seder', ref: 'Seder Zeraim');
const _moed = NodeEntry(level: 'seder', ref: 'Seder Moed');

void main() {
  group('distinct learnt count (FR-14)', () {
    test('repeats and chazara count a leaf once', () {
      final state = progressState([
        progressLearn(1, 'Mishnah Berakhot 1:1'),
        progressLearn(2, 'Mishnah Berakhot 1:1', minutes: 5),
        progressLearn(3, 'Mishnah Berakhot 1:1', minutes: 9, stage: 2),
        progressLearn(4, 'Mishnah Berakhot 1:2', minutes: 10),
      ]);
      expect(state[engineCurriculum]!.distinctLearnt, 2);
      expect(state.countedLearns, hasLength(4));
    });

    test('before-tracking learning counts; a voided event does not', () {
      final state = progressState([
        progressGround(1, 'Mishnah Peah', 'masechta'),
        progressLearn(2, 'Mishnah Shabbat 1:1', minutes: 3),
        engineVoid(3, 2, minutes: 4),
      ]);
      final mishnayos = state[engineCurriculum]!;
      expect(mishnayos.learntLeaves, {'Mishnah Peah 1:1', 'Mishnah Peah 1:2'});
      expect(state.countedEventIds, {engineUlid(1)});
      expect(state.countedLearns.map((e) => e.id), [engineUlid(1)]);
    });
  });

  group('hierarchy tri-state (FR-15)', () {
    test('no learnt descendant leaves every ancestor empty', () {
      final mishnayos = progressState(const [])[engineCurriculum]!;
      expect(mishnayos.triState(_zeraim), TriState.empty);
      expect(mishnayos.triState(_berakhot), TriState.empty);
    });

    test('one learnt leaf makes its perek, masechta and seder partial', () {
      final mishnayos = progressState([
        progressLearn(1, 'Mishnah Berakhot 1:2'),
      ])[engineCurriculum]!;
      expect(mishnayos.triState(_berakhot1), TriState.partial);
      expect(mishnayos.triState(_berakhot), TriState.partial);
      expect(mishnayos.triState(_zeraim), TriState.partial);
      expect(mishnayos.triState(_moed), TriState.empty);
    });

    test('every descendant learnt makes the ancestor complete', () {
      final mishnayos = progressState([
        progressGround(1, 'Mishnah Berakhot', 'masechta'),
      ])[engineCurriculum]!;
      expect(mishnayos.triState(_berakhot1), TriState.complete);
      expect(mishnayos.triState(_berakhot), TriState.complete);
      expect(mishnayos.triState(_zeraim), TriState.partial);
      expect(mishnayos.distinctLearnt, 5);
    });
  });
}
