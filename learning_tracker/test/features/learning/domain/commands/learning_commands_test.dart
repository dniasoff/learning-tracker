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
}
