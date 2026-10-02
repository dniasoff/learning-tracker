// Mirror test for `lib/domain/learner_state/learner_state_engine.dart`
// (DNI-465): AC-1, AC-2, AC-4, AC-5 and AC-6 of Story 1.3.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  const engine = LearnerStateEngine();

  group('AC-1', () {
    test('is pure and limits plan evaluation to active tracks', () {
      final inputs = engineInputs(
        events: [engineLearn(1, 'Mishnah Berakhot 1:1')],
        intents: {
          engineCurriculum: engineIntent(),
          'retired': engineIntent(
            curriculumId: 'retired',
            state: MainTrackState.retired,
          ),
          'ended': engineIntent(curriculumId: 'ended', endedAt: engineAt(1)),
        },
      );
      final first = engine.run(inputs);
      final second = engine.run(inputs);
      expect(first.curricula.keys, second.curricula.keys);
      for (final c in first.curricula.keys) {
        expect(first[c], second[c], reason: c);
      }
      expect(first.countedEventIds, second.countedEventIds);
      expect(first.nowUtc, inputs.nowUtc);

      expect(first[engineCurriculum]!.evaluated, isTrue);
      expect(first['retired']!.evaluated, isFalse);
      expect(first['ended']!.evaluated, isFalse);
    });
  });

  test('no inputs give no curricula', () {
    final state = engine.run(
      engineInputs(intents: const {}, corpora: const {}),
    );
    expect(state.curricula, isEmpty);
    expect(state.countedEventIds, isEmpty);
  });

  test('CalendarAssignment compares by value', () {
    const node = NodeEntry(level: 'daf', ref: 'Berakhot 2');
    expect(
      const CalendarAssignment('2026-09-01', node),
      const CalendarAssignment('2026-09-01', node),
    );
    expect(
      const CalendarAssignment('2026-09-01', node),
      isNot(const CalendarAssignment('2026-09-02', node)),
    );
  });

  test('TriState has the three AD values', () {
    expect(TriState.values, [
      TriState.empty,
      TriState.partial,
      TriState.complete,
    ]);
  });
}
