/// Mirror test for `learning_event_time.dart` (part of
/// `learning_event.dart`): the two time accessors.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('effectiveAt = original_recorded_at ?? recorded_at', () {
    expect(effectiveAt(datedLearn(recordedAt: t1)), t1);
    expect(effectiveAt(datedLearn(recordedAt: t1, originalRecordedAt: t2)), t2);
  });

  test('rawRecordedAtForSkewRule always returns recorded_at (AD-54)', () {
    expect(
      rawRecordedAtForSkewRule(
        datedLearn(recordedAt: t1, originalRecordedAt: t2),
      ),
      t1,
    );
  });

  test('a decoded event exposes the same instants', () {
    final decoded = LearningEvent.fromStorage(
      ulidA,
      datedLearnMap()..['original_recorded_at'] = t2,
    );
    expect(effectiveAt(decoded), t2);
    expect(rawRecordedAtForSkewRule(decoded), t0);
  });
}
