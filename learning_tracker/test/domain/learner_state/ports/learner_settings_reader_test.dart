// Mirror test for
// `lib/domain/learner_state/ports/learner_settings_reader.dart` (DNI-470):
// the port is what `watchLearnerSettingsHistory` consumes; an error event
// (no valid zone) must reach the reader's consumer, never a fallback.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_settings_reader.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';

final class _Reader implements LearnerSettingsReader {
  _Reader(this.events);

  final Stream<LearnerSettings> Function(LearnerScope scope) events;

  @override
  Stream<LearnerSettings> watch(LearnerScope scope) => events(scope);
}

void main() {
  test('a reader yields settings per scope, or an error', () async {
    final ok = _Reader((_) => Stream.value(c0Settings));
    expect(await ok.watch(c0Scope()).first, c0Settings);
    final bad = _Reader((_) => Stream.error(const FormatException('zone')));
    await expectLater(bad.watch(c0Scope()).first, throwsFormatException);
  });
}
