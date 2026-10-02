/// AC-5 / AC-6 / edges (DNI-464): `FirestoreLearningEventRepository`.
///
/// Runs against `fake_cloud_firestore` (live query snapshots, document-id
/// ordering, `startAfterDocument` cursors). Page requests are observed
/// through the repository's `pageProbe` seam. TQ-6: fixed instants only.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state_fixtures.dart';
import '../../helpers/learning_event_seed.dart';

const _owner = 'owner-uid';

typedef _PageCall = ({int page, String? after, int limit, int? delivered});

final class _Harness {
  _Harness() : firestore = FakeFirebaseFirestore() {
    repository = FirestoreLearningEventRepository(
      firestore: firestore,
      pageProbe:
          ({
            required pageIndex,
            required afterDocId,
            required limit,
            required delivered,
          }) => calls.add((
            page: pageIndex,
            after: afterDocId,
            limit: limit,
            delivered: delivered,
          )),
    );
  }

  final FakeFirebaseFirestore firestore;
  late final FirestoreLearningEventRepository repository;
  final List<_PageCall> calls = [];
  final scope = LearnerScope(ownerUid: _owner, profileId: profileUlid);

  List<int?> get deliveredCounts => [
    for (final c in calls)
      if (c.delivered != null) c.delivered,
  ];

  List<String?> get openedCursors => [
    for (final c in calls)
      if (c.delivered == null) c.after,
  ];
}

/// Subscribes and collects emissions until the first Ready (plus a settle
/// window so any stray extra emission would be caught).
Future<List<CompleteRead<LearningEvent>>> _firstComplete(
  Stream<CompleteRead<LearningEvent>> stream,
) async {
  final emissions = <CompleteRead<LearningEvent>>[];
  final done = Completer<void>();
  final sub = stream.listen((e) {
    emissions.add(e);
    if (e is CompleteReadReady<LearningEvent> && !done.isCompleted) {
      done.complete();
    }
  });
  await done.future.timeout(const Duration(seconds: 20));
  await pumpEventQueue();
  await sub.cancel();
  return emissions;
}

void main() {
  group('watchAll waits for all three 500-row pages before publishing '
      'complete data', () {
    test(
      '1,201 events → pages of 500, 500, 201; one loading, one complete',
      () async {
        final h = _Harness();
        await seedLearningEvents(h.firestore, _owner, profileUlid, 1201);

        final emissions = await _firstComplete(h.repository.watchAll(h.scope));

        expect(emissions, hasLength(2));
        expect(emissions.first, isA<CompleteReadLoading<LearningEvent>>());
        final ready = emissions.last as CompleteReadReady<LearningEvent>;
        expect(ready.items, hasLength(1201));
        expect(ready.isClean, isTrue);
        expect(ready.items.map((e) => e.id).toSet(), hasLength(1201));
        expect(ready.items.first.id, seqUlid(0));
        expect(ready.items.last.id, seqUlid(1200));

        expect(h.deliveredCounts, [500, 500, 201]);
        expect(h.openedCursors, [null, seqUlid(499), seqUlid(999)]);
        expect(h.calls.every((c) => c.limit == 500), isTrue);
      },
    );

    test(
      'reads exactly users/{uid}/learner_profiles/{profileULID}/'
      'learning_events — another profile\'s or owner\'s events never leak',
      () async {
        final h = _Harness();
        await seedLearningEvents(h.firestore, _owner, profileUlid, 3);
        await seedLearningEvents(h.firestore, _owner, ulidE, 2, from: 10);
        await seedLearningEvents(
          h.firestore,
          'other-owner',
          profileUlid,
          2,
          from: 20,
        );

        final emissions = await _firstComplete(h.repository.watchAll(h.scope));
        final ready = emissions.last as CompleteReadReady<LearningEvent>;
        expect(ready.items.map((e) => e.id), [
          seqUlid(0),
          seqUlid(1),
          seqUlid(2),
        ]);
        expect(
          h.repository.collectionFor(h.scope).path,
          'users/$_owner/learner_profiles/$profileUlid/learning_events',
        );
      },
    );

    test(
      'a later change publishes a new complete list, never a partial one',
      () async {
        final h = _Harness();
        await seedLearningEvents(h.firestore, _owner, profileUlid, 500);
        final emissions = <CompleteRead<LearningEvent>>[];
        final sub = h.repository.watchAll(h.scope).listen(emissions.add);
        addTearDown(sub.cancel);
        await pumpEventQueue(times: 50);
        expect(emissions, hasLength(2));

        await seedLearningEvents(
          h.firestore,
          _owner,
          profileUlid,
          1,
          from: 500,
        );
        await pumpEventQueue(times: 50);

        final readies = emissions.whereType<CompleteReadReady<LearningEvent>>();
        expect(readies.map((r) => r.items.length), [500, 501]);
        expect(
          emissions.whereType<CompleteReadLoading<LearningEvent>>(),
          hasLength(1),
        );
      },
    );

    test(
      'a malformed row is surfaced as rejected, not silently dropped',
      () async {
        final h = _Harness();
        await seedLearningEvents(h.firestore, _owner, profileUlid, 2);
        await profileCollection(
          h.firestore,
          _owner,
          profileUlid,
          'learning_events',
        ).doc(seqUlid(5)).set({...storedLearnEvent(5), 'points': 3});

        final emissions = await _firstComplete(h.repository.watchAll(h.scope));
        final ready = emissions.last as CompleteReadReady<LearningEvent>;
        expect(ready.items, hasLength(2));
        expect(ready.rejected.single.docId, seqUlid(5));
        expect(ready.rejected.single.error, isA<StorageFormatException>());
      },
    );

    test(
      'decoded timestamps are UTC DateTimes equal to the stored instant',
      () async {
        final h = _Harness();
        await seedLearningEvents(h.firestore, _owner, profileUlid, 1);
        final emissions = await _firstComplete(h.repository.watchAll(h.scope));
        final event =
            (emissions.last as CompleteReadReady<LearningEvent>).items.single;
        expect(effectiveAt(event), t0);
        expect(effectiveAt(event).isUtc, isTrue);
      },
    );
  });

  group('empty and exact-page-multiple logs terminate correctly', () {
    for (final (count, expectedDelivered) in <(int, List<int>)>[
      (0, [0]),
      (500, [500, 0]),
      (1000, [500, 500, 0]),
      (1001, [500, 500, 1]),
    ]) {
      test(
        '$count events → one loading, one complete with $count unique ids',
        () async {
          final h = _Harness();
          await seedLearningEvents(h.firestore, _owner, profileUlid, count);

          final emissions = await _firstComplete(
            h.repository.watchAll(h.scope),
          );

          expect(emissions, hasLength(2), reason: '$emissions');
          expect(emissions.first, isA<CompleteReadLoading<LearningEvent>>());
          final ready = emissions.last as CompleteReadReady<LearningEvent>;
          expect(ready.items, hasLength(count));
          expect(ready.items.map((e) => e.id).toSet(), hasLength(count));
          // The terminating probe of an exact multiple is a query, never a
          // published (phantom) page.
          expect(h.deliveredCounts, expectedDelivered);
        },
      );
    }
  });

  group('DNI-475 Mishna history: a repeat and the void that explains it '
      'on later pages are part of the one complete read', () {
    test('learn on page 1, its repeat and a void of it on page 2 → every '
        'id preserved, nothing published before page 2', () async {
      final h = _Harness();
      await seedLearningEvents(h.firestore, _owner, profileUlid, 520);
      final events = profileCollection(
        h.firestore,
        _owner,
        profileUlid,
        'learning_events',
      );
      // A repeat of event 0's ref, recorded later (page 2).
      await events.doc(seqUlid(520)).set({
        ...storedLearnEvent(0),
        'recorded_at': Timestamp.fromDate(t1),
      });
      // A void of event 0, also on page 2.
      await events.doc(seqUlid(521)).set({
        'kind': 'void',
        'target_id': seqUlid(0),
        'recorded_at': Timestamp.fromDate(t1),
        'actor': Map<String, Object?>.of(parentActorMap),
      });

      final emissions = await _firstComplete(h.repository.watchAll(h.scope));

      expect(emissions, hasLength(2));
      final ready = emissions.last as CompleteReadReady<LearningEvent>;
      expect(ready.items, hasLength(522));
      final byId = {for (final e in ready.items) e.id: e};
      expect(byId[seqUlid(0)]!.ref, byId[seqUlid(520)]!.ref);
      expect(byId[seqUlid(521)]!.isVoid, isTrue);
      expect(byId[seqUlid(521)]!.targetId, seqUlid(0));
      expect(h.deliveredCounts, [500, 22]);
    });
  });

  group('create (AC-6 storage side)', () {
    test(
      'writes at the event ULID with Timestamps and no FieldValue',
      () async {
        final h = _Harness();
        final event = datedLearn(originalRecordedAt: t2);
        await h.repository.create(h.scope, event);

        final doc = await profileCollection(
          h.firestore,
          _owner,
          profileUlid,
          'learning_events',
        ).doc(ulidA).get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['recorded_at'], Timestamp.fromDate(t0));
        expect(data['original_recorded_at'], Timestamp.fromDate(t2));
        expect(data.values.whereType<FieldValue>(), isEmpty);
        expect(data.keys.toSet(), event.toStorage().keys.toSet());
      },
    );

    test('a retry of the same event leaves one identical doc', () async {
      final h = _Harness();
      await h.repository.create(h.scope, datedLearn());
      final first = (await profileCollection(
        h.firestore,
        _owner,
        profileUlid,
        'learning_events',
      ).doc(ulidA).get()).data();
      await h.repository.create(h.scope, datedLearn());
      final all = await profileCollection(
        h.firestore,
        _owner,
        profileUlid,
        'learning_events',
      ).get();
      expect(all.docs.map((d) => d.id), [ulidA]);
      expect(all.docs.single.data(), first);
    });

    test('a CONFLICTING replay at an existing ULID throws and leaves the '
        'original event unchanged (append-only)', () async {
      final h = _Harness();
      final events = profileCollection(
        h.firestore,
        _owner,
        profileUlid,
        'learning_events',
      );
      await h.repository.create(h.scope, datedLearn());
      final original = (await events.doc(ulidA).get()).data();

      // Same ULID, rebuilt payload: a different time and a different source.
      await expectLater(
        h.repository.create(
          h.scope,
          datedLearn(recordedAt: t2, source: ulidB, stage: null),
        ),
        throwsA(
          isA<LearningEventConflictException>().having(
            (e) => e.eventId,
            'eventId',
            ulidA,
          ),
        ),
      );

      final all = await events.get();
      expect(all.docs.map((d) => d.id), [ulidA]);
      expect(all.docs.single.data(), original);
    });

    test('an undecodable stored row at the ULID is a conflict, never '
        'overwritten', () async {
      final h = _Harness();
      final doc = profileCollection(
        h.firestore,
        _owner,
        profileUlid,
        'learning_events',
      ).doc(ulidA);
      await doc.set({'kind': 'learn', 'junk': true});

      await expectLater(
        h.repository.create(h.scope, datedLearn()),
        throwsA(isA<LearningEventConflictException>()),
      );
      expect((await doc.get()).data(), {'kind': 'learn', 'junk': true});
    });

    test('an invalid event is rejected before any write', () async {
      final h = _Harness();
      await expectLater(
        h.repository.create(h.scope, datedLearn(source: 'not-a-source')),
        throwsA(isA<StorageFormatException>()),
      );
      final all = await profileCollection(
        h.firestore,
        _owner,
        profileUlid,
        'learning_events',
      ).get();
      expect(all.docs, isEmpty);
    });
  });

  group('create-only guard reads past the cache (review R2)', () {
    final scope = LearnerScope(ownerUid: _owner, profileId: profileUlid);

    CollectionReference<Map<String, dynamic>> events(
      FakeFirebaseFirestore firestore,
    ) => profileCollection(firestore, _owner, profileUlid, 'learning_events');

    test('an event that exists only on the SERVER with a different payload '
        'is a conflict: nothing is written', () async {
      final firestore = FakeFirebaseFirestore();
      final remote = toFirestoreMap(datedLearn(recordedAt: t2).toStorage());
      final repo = FirestoreLearningEventRepository(
        firestore: firestore,
        guardRead: (_) async => remote, // cache missed; server has the row
      );

      await expectLater(
        repo.create(scope, datedLearn()),
        throwsA(isA<LearningEventConflictException>()),
      );
      expect((await events(firestore).get()).docs, isEmpty);
    });

    test('an identical server-only event is an idempotent no-op', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreLearningEventRepository(
        firestore: firestore,
        guardRead: (_) async => toFirestoreMap(datedLearn().toStorage()),
      );
      await repo.create(scope, datedLearn());
      expect((await events(firestore).get()).docs, isEmpty);
    });

    test('a guard read failure propagates and nothing is written (never an '
        'upsert over an unseen event)', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreLearningEventRepository(
        firestore: firestore,
        guardRead: (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'internal',
        ),
      );
      await expectLater(
        repo.create(scope, datedLearn()),
        throwsA(isA<FirebaseException>()),
      );
      expect((await events(firestore).get()).docs, isEmpty);
    });
  });

  group('commit (DNI-469 LearningWritePort)', () {
    final scope = LearnerScope(ownerUid: _owner, profileId: profileUlid);
    String profile() => 'users/$_owner/learner_profiles/$profileUlid';

    LearningWriteChunk chunk() {
      final learn = datedLearn(stage: 1);
      final voided = LearningEvent.voidOf(
        id: ulidB,
        targetId: ulidC,
        recordedAt: t0,
        actor: parentActor,
      );
      return LearningWriteChunk(
        events: [learn, voided],
        awards: [PointsAward(eventId: learn.id, amount: 10, createdAt: t0)],
      );
    }

    test('writes the events and their pts_ entries in one batch with the '
        'prebuilt payloads (no server timestamp)', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreLearningEventRepository(firestore: firestore);
      await repo.commit(scope, chunk());

      final learn = await firestore
          .doc('${profile()}/learning_events/$ulidA')
          .get();
      expect(
        LearningEvent.fromStorage(ulidA, fromFirestoreMap(learn.data()!)),
        datedLearn(stage: 1),
      );
      expect(
        (await firestore.doc('${profile()}/learning_events/$ulidB').get())
            .exists,
        isTrue,
      );
      final pts = await firestore
          .doc('${profile()}/points_ledger/pts_$ulidA')
          .get();
      final data = fromFirestoreMap(pts.data()!);
      expect(data, {
        'ulid': 'pts_$ulidA',
        'entry_kind': 'completion',
        'delta': 10,
        'created_at': t0,
        'source': 'live',
        'event_id': ulidA,
      });
    });

    test(
      'an identical re-commit (retry) leaves the documents unchanged',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = FirestoreLearningEventRepository(firestore: firestore);
        final c = chunk();
        await repo.commit(scope, c);
        await repo.commit(scope, c);
        expect(
          (await firestore.collection('${profile()}/learning_events').get())
              .docs,
          hasLength(2),
        );
        expect(
          (await firestore.collection('${profile()}/points_ledger').get()).docs,
          hasLength(1),
        );
      },
    );

    test('terminal server codes are the permanent-rejection set', () {
      expect(
        FirestoreLearningEventRepository.permanentRejectionCodes,
        containsAll([
          'permission-denied',
          'invalid-argument',
          'failed-precondition',
        ]),
      );
      expect(
        FirestoreLearningEventRepository.permanentRejectionCodes,
        isNot(contains('unavailable')),
      );
    });
  });
}
