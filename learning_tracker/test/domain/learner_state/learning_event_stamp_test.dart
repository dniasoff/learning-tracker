/// Unit tests for [EventStamper] / [PendingLearningEventWrite].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('stamp reads the clock once and mints the ULID from that instant', () {
    final clockReads = <DateTime>[];
    final idInstants = <DateTime>[];
    final stamper = EventStamper(
      clock: () {
        clockReads.add(t0);
        return t0;
      },
      newUlid: (at) {
        idInstants.add(at);
        return ulidA;
      },
    );
    final stamp = stamper.stamp();
    expect(stamp.id, ulidA);
    expect(stamp.recordedAt, t0);
    expect(clockReads, hasLength(1));
    expect(idInstants, [t0]);
  });

  test('a non-ULID id source is rejected before any write exists', () {
    final stamper = EventStamper(clock: () => t0, newUlid: (_) => 'bad');
    expect(stamper.stamp, throwsA(isA<StorageFormatException>()));
  });

  test('PendingLearningEventWrite validates and freezes the payload', () {
    final scope = LearnerScope(ownerUid: 'owner', profileId: profileUlid);
    final pending = PendingLearningEventWrite(scope, datedLearn());
    expect(pending.payload, datedLearnMap());
    expect(() => pending.payload['kind'] = 'void', throwsUnsupportedError);
    expect(
      () => PendingLearningEventWrite(scope, datedLearn(source: 'x')),
      throwsA(isA<StorageFormatException>()),
    );
  });
}
