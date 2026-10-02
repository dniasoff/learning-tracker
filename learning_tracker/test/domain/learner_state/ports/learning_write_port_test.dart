// Mirror test for `lib/domain/learner_state/ports/learning_write_port.dart`
// (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';

import '../../../helpers/learner_state_fixtures.dart';

void main() {
  PointsAward award(String eventId) =>
      PointsAward(eventId: eventId, amount: 1, createdAt: t0);

  test('PointsAward maps to pts_{eventId}', () {
    expect(award(ulidA).docId, 'pts_$ulidA');
    expect(award(ulidA), award(ulidA));
  });

  test('a chunk accepts awards for its own events', () {
    final chunk = LearningWriteChunk(
      events: [datedLearn()],
      awards: [award(ulidA)],
    );
    expect(chunk.events.single.id, ulidA);
    expect(chunk.awards.single.docId, 'pts_$ulidA');
  });

  test('a chunk rejects an award for an event outside it', () {
    expect(
      () => LearningWriteChunk(events: [datedLearn()], awards: [award(ulidB)]),
      throwsArgumentError,
    );
  });

  test('a chunk holds at most 450 writes', () {
    final events = [for (var i = 0; i < 225; i++) datedLearn()];
    final awards = [for (var i = 0; i < 225; i++) award(ulidA)];
    expect(
      LearningWriteChunk(events: events, awards: awards).events,
      hasLength(225),
    );
    expect(
      () =>
          LearningWriteChunk(events: events, awards: [...awards, award(ulidA)]),
      throwsArgumentError,
    );
  });

  test('PermanentWriteRejection carries the server code', () {
    expect(
      const PermanentWriteRejection('permission-denied').code,
      'permission-denied',
    );
  });
}
