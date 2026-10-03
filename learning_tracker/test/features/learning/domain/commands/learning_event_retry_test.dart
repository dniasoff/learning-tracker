/// AC-6 (DNI-464): a retry reuses the event ULID and the immutable
/// timestamp payload — the id is allocated before the first write, the
/// clock is read once, and no retry payload carries a fresh time or a
/// server timestamp (AD-46, parent AD-5).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';

import '../../../../helpers/learner_state_fixtures.dart';

/// Records the exact Firestore-form payload of each attempt; the first
/// [failures] attempts throw like a transient network failure.
final class _FlakyRecordingRepository implements LearningEventRepository {
  _FlakyRecordingRepository({this.failures = 1});

  int failures;
  final List<(String, Map<String, Object?>)> attempts = [];

  @override
  Future<void> create(LearnerScope scope, LearningEvent event) async {
    attempts.add((event.id, toFirestoreMap(event.toStorage())));
    if (failures > 0) {
      failures--;
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
  }

  @override
  Stream<CompleteRead<LearningEvent>> watchAll(LearnerScope scope) =>
      const Stream.empty();
}

/// A clock that moves forward on every read, so any second read would be
/// visible in the payload.
final class _TickingClock {
  int reads = 0;

  DateTime call() => t0.add(Duration(minutes: reads++));
}

void main() {
  final scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

  LearningEvent build(EventStamp stamp) => LearningEvent.learn(
    id: stamp.id,
    curriculumId: 'mishnayos',
    ref: 'Mishnah Berakhot 1:1',
    source: LearningEvent.sourceMain,
    dateState: DateState.dated,
    learnedOn: '2026-09-01',
    recordedAt: stamp.recordedAt,
    actor: parentActor,
  );

  group('retry reuses event ULID and immutable timestamp payload', () {
    test('id allocated before the first write; retry sends the same id and '
        'value-equivalent data; the clock is read once', () async {
      final clock = _TickingClock();
      final mintedIds = <String>[];
      final stamper = EventStamper(
        clock: clock.call,
        newUlid: (at) {
          final id = mintedIds.isEmpty ? ulidA : ulidB;
          mintedIds.add(id);
          return id;
        },
      );
      final repository = _FlakyRecordingRepository(failures: 2);

      final pending = PendingLearningEventWrite(scope, build(stamper.stamp()));
      // Allocated before any write.
      expect(mintedIds, [ulidA]);
      expect(repository.attempts, isEmpty);

      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await pending.attempt(repository);
          break;
        } on FirebaseException {
          continue;
        }
      }

      expect(repository.attempts, hasLength(3));
      expect(repository.attempts.map((a) => a.$1).toSet(), {ulidA});
      final first = repository.attempts.first.$2;
      for (final (_, payload) in repository.attempts) {
        expect(payload, first);
      }
      expect(first['recorded_at'], Timestamp.fromDate(t0));
      expect(clock.reads, 1);
      expect(mintedIds, [ulidA]);
    });

    test('no payload contains a FieldValue (serverTimestamp) anywhere', () {
      final pending = PendingLearningEventWrite(
        scope,
        build(EventStamper(clock: () => t0, newUlid: (_) => ulidA).stamp()),
      );
      bool containsFieldValue(Object? v) => switch (v) {
        FieldValue() => true,
        Map<Object?, Object?>() => v.values.any(containsFieldValue),
        List<Object?>() => v.any(containsFieldValue),
        _ => false,
      };
      expect(containsFieldValue(toFirestoreMap(pending.payload)), isFalse);
    });

    test('against the Firestore repository, a replay leaves exactly one doc '
        'at the pre-allocated id with the original timestamp', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreLearningEventRepository(firestore: firestore);
      final clock = _TickingClock();
      final pending = PendingLearningEventWrite(
        scope,
        build(EventStamper(clock: clock.call, newUlid: (_) => ulidC).stamp()),
      );

      await pending.attempt(repository);
      await pending.attempt(repository);

      final docs = await repository.collectionFor(scope).get();
      expect(docs.docs.map((d) => d.id), [ulidC]);
      expect(docs.docs.single.data()['recorded_at'], Timestamp.fromDate(t0));
      expect(clock.reads, 1);
    });
  });
}
