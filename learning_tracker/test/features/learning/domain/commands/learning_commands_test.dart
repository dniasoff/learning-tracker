// Mirror test for
// `lib/features/learning/domain/commands/learning_commands.dart`
// (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

void main() {
  test('EventReplacement keeps every field optional and compares by '
      'value', () {
    const keep = EventReplacement();
    expect(keep.ref, isNull);
    expect(keep.source, isNull);
    expect(keep.learnedOn, isNull);
    expect(keep.dateState, isNull);
    expect(keep.stage, isNull);
    expect(
      const EventReplacement(
        ref: 'Mishnah Berakhot 1:2',
        dateState: DateState.catchUp,
      ),
      const EventReplacement(
        ref: 'Mishnah Berakhot 1:2',
        dateState: DateState.catchUp,
      ),
    );
    expect(keep, isNot(const EventReplacement(stage: 1)));
  });

  test('EventReplacement.resolveLearnedOn: null keeps the target date, a '
      'new date replaces it, and a move to Before tracking clears it', () {
    expect(
      const EventReplacement().resolveLearnedOn('2026-08-30'),
      '2026-08-30',
    );
    expect(
      const EventReplacement(source: 'main').resolveLearnedOn('2026-08-30'),
      '2026-08-30',
    );
    expect(
      const EventReplacement(
        learnedOn: '2026-08-29',
      ).resolveLearnedOn('2026-08-30'),
      '2026-08-29',
    );
    expect(
      const EventReplacement(
        source: 'main',
        dateState: DateState.beforeTracking,
      ).resolveLearnedOn('2026-08-30'),
      isNull,
    );
    expect(
      const EventReplacement(
        dateState: DateState.dated,
        learnedOn: '2026-08-29',
      ).resolveLearnedOn(null),
      '2026-08-29',
    );
  });

  test('EventReplacement rejects a learned_on on a Before-tracking '
      'replacement', () {
    EventReplacement build(String learnedOn) => EventReplacement(
      dateState: DateState.beforeTracking,
      learnedOn: learnedOn,
    );
    expect(() => build('2026-08-30'), throwsA(isA<AssertionError>()));
  });
}
