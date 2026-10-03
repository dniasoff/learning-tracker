// Story 4.3 (DNI-511) T2: what each talmid row state may show and do
// (AD-36 fail closed; AC-7 retry only where it can help).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';

void main() {
  test('no identity and no tap until the lock is known open', () {
    for (final state in const <TalmidRowState>[
      TalmidRowPending(),
      TalmidRowLocked(),
    ]) {
      expect(state.identityVisible, isFalse, reason: '$state');
      expect(state.opensLearner, isFalse, reason: '$state');
    }
  });

  test('an open learner shows his identity and opens', () {
    for (final state in const <TalmidRowState>[
      TalmidRowLoading(),
      TalmidRowReady(status: TalmidStatus.onTrack),
    ]) {
      expect(state.identityVisible, isTrue, reason: '$state');
      expect(state.opensLearner, isTrue, reason: '$state');
    }
  });

  test('a timed-out or failed row never opens', () {
    expect(const TalmidRowTimedOut(identityVisible: true).opensLearner, false);
    expect(
      const TalmidRowFailed(TalmidRowFailure.loadFailed).opensLearner,
      isFalse,
    );
  });

  test('only a load failure is retryable', () {
    expect(const TalmidRowFailed(TalmidRowFailure.loadFailed).retryable, true);
    expect(
      const TalmidRowFailed(TalmidRowFailure.accessEnded).retryable,
      isFalse,
    );
    expect(
      const TalmidRowFailed(TalmidRowFailure.invalidLearner).retryable,
      isFalse,
    );
  });

  test('value equality, so an unchanged recompute does not rebuild', () {
    const line = TalmidTrackNext(
      subTrackId: 's',
      curriculumId: 'mishnayos',
      name: 'Rebbe',
      position: 'Mishnah Beitzah 3:1',
    );
    expect(
      const TalmidRowReady(status: TalmidStatus.tooEarly, line: line),
      const TalmidRowReady(status: TalmidStatus.tooEarly, line: line),
    );
    expect(
      const TalmidRowReady(status: TalmidStatus.tooEarly, line: line),
      isNot(const TalmidRowReady(status: TalmidStatus.onTrack, line: line)),
    );
  });
}
