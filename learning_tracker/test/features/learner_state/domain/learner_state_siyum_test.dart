// DNI-474 AC-4: a completed in-corpus unit enters the engine's completed
// units at k = 1 from any source, backfill or correction; repeats and
// chazara never change its first completion (Consistency → Siyum, FR-17).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/progress_fixtures.dart';

const _peah = NodeEntry(level: 'masechta', ref: 'Mishnah Peah');
const _zeraim = NodeEntry(level: 'seder', ref: 'Seder Zeraim');

CompletedUnit? _unit(LearnerState state, NodeEntry node) {
  for (final u in state[engineCurriculum]!.completedUnits) {
    if (u.unit == node) return u;
  }
  return null;
}

void main() {
  test('live learning completes a masechta at k = 1, at the effective '
      'instant of the event that completed it', () {
    final state = progressState([
      progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
    ]);
    final peah = _unit(state, _peah)!;
    expect(peah.completionNumber, 1);
    expect(peah.firstCompletedAt, {1: engineAt(2)});
    expect(_unit(state, _zeraim), isNull, reason: 'Berakhot is not learnt');
  });

  test('a sub-track source completes the unit like the main track', () {
    final state = progressState([
      engineLearn(1, 'Mishnah Peah 1:1', source: engineUlid(90)),
      engineLearn(2, 'Mishnah Peah 1:2', source: engineUlid(90), minutes: 1),
    ]);
    expect(_unit(state, _peah)!.completionNumber, 1);
  });

  test('a before-tracking backfill completes the unit (and its seder when '
      'every masechta is covered)', () {
    final state = progressState([
      progressGround(1, 'Seder Zeraim', 'seder', minutes: 3),
    ]);
    expect(_unit(state, _peah)!.firstCompletedAt[1], engineAt(3));
    expect(_unit(state, _zeraim)!.completionNumber, 1);
  });

  test('a correction (void + re-capture at the original instant) completes '
      'the unit at the corrected instant', () {
    final state = progressState([
      progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(2, 'Mishnah Shabbat 1:1', minutes: 2), // wrong mishna
      engineVoid(3, 2, minutes: 10),
      engineLearn(4, 'Mishnah Peah 1:2', minutes: 10, originalMinutes: 2),
    ]);
    expect(_unit(state, _peah)!.firstCompletedAt[1], engineAt(2));
  });

  test('repeats and chazara never move the k = 1 instant; a second full '
      'pass of first-stage learning raises k', () {
    final once = [
      progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
    ];
    final withChazara = progressState([
      ...once,
      progressLearn(3, 'Mishnah Peah 1:1', minutes: 3, stage: 2),
      progressLearn(4, 'Mishnah Peah 1:2', minutes: 4, stage: 2),
    ]);
    final withRepeat = progressState([
      ...once,
      progressLearn(5, 'Mishnah Peah 1:1', minutes: 5),
      progressLearn(6, 'Mishnah Peah 1:2', minutes: 6),
    ]);
    expect(_unit(withChazara, _peah)!.firstCompletedAt[1], engineAt(2));
    expect(_unit(withRepeat, _peah)!.firstCompletedAt, {
      1: engineAt(2),
      2: engineAt(6),
    });
    expect(_unit(withRepeat, _peah)!.completionNumber, 2);
  });

  test('a void that breaks the unit takes the completion away; a later '
      're-completion has a new first-completion instant', () {
    final voided = progressState([
      progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
      engineVoid(3, 2, minutes: 5),
    ]);
    expect(_unit(voided, _peah), isNull);

    final again = progressState([
      progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
      engineVoid(3, 2, minutes: 5),
      progressLearn(4, 'Mishnah Peah 1:2', minutes: 8),
    ]);
    expect(_unit(again, _peah)!.firstCompletedAt[1], engineAt(8));
  });

  test('learning outside the learner corpus never completes a unit', () {
    final state = progressState([
      engineLearn(1, 'Not In Corpus 1:1'),
      engineLearn(2, 'Mishnah Peah 1:1', dateState: DateState.catchUp),
    ]);
    expect(state[engineCurriculum]!.completedUnits, isEmpty);
  });
}
