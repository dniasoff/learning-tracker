/// AC-7 (DNI-464): `FirestoreSubTrackRepository` — sub-track reads page
/// fully, and governed edits merge or tombstone (never delete).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state_fixtures.dart';
import '../../helpers/learning_event_seed.dart';

const _owner = 'owner-uid';

/// Records every batch operation, delegating to the real fake batch.
final class _SpyBatch implements WriteBatch {
  _SpyBatch(this._inner, this.ops);

  final WriteBatch _inner;
  final List<String> ops;

  @override
  Future<void> commit() {
    ops.add('commit');
    return _inner.commit();
  }

  @override
  void delete(DocumentReference<Object?> document) {
    ops.add('delete ${document.path}');
    _inner.delete(document);
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    ops.add('set ${document.path} merge=${options?.merge ?? false}');
    _inner.set(document, data, options);
  }

  @override
  void update(DocumentReference<Object?> document, Map<Object, Object?> data) {
    ops.add('update ${document.path}');
    _inner.update(document, data);
  }
}

final class _SpyFirestore extends FakeFirebaseFirestore {
  final List<String> ops = [];

  @override
  WriteBatch batch() => _SpyBatch(super.batch(), ops);
}

Map<String, Object?> _storedSubTrack(int n) => {
  'curriculum_id': 'mishnayos',
  'name': 'Shiur $n',
  'type': 'ongoing',
  'window_start': '2026-09-01',
  'window_end': null,
  'rate_per_week': 7,
  'weeks_per_year': 40,
  'learns_on_shabbos': false,
  'ground': [
    {'level': 'masechta', 'ref': 'Mishnah Berakhot'},
  ],
  'last_change_id': ulidC,
};

ChangeLogEntry _entry(String subTrackId, Map<String, Object?> after) =>
    ChangeLogEntry(
      id: ulidD,
      entity: GovernedEntity.subTrack,
      entityId: subTrackId,
      actionId: ulidD,
      before: {for (final k in after.keys) k: null},
      after: after,
      at: t0,
      actor: parentActor,
    );

Future<List<CompleteRead<SubTrack>>> _firstComplete(
  Stream<CompleteRead<SubTrack>> stream,
) async {
  final emissions = <CompleteRead<SubTrack>>[];
  final done = Completer<void>();
  final sub = stream.listen((e) {
    emissions.add(e);
    if (e is CompleteReadReady<SubTrack> && !done.isCompleted) done.complete();
  });
  await done.future.timeout(const Duration(seconds: 20));
  await pumpEventQueue();
  await sub.cancel();
  return emissions;
}

void main() {
  final scope = LearnerScope(ownerUid: _owner, profileId: profileUlid);

  group('sub-track reads page fully and governed edits merge or tombstone', () {
    for (final (count, delivered) in <(int, List<int>)>[
      (0, [0]),
      (500, [500, 0]),
      (501, [500, 1]),
    ]) {
      test('$count rows → one loading then one complete read', () async {
        final firestore = FakeFirebaseFirestore();
        final pages = <int>[];
        final repo = FirestoreSubTrackRepository(
          firestore: firestore,
          pageProbe:
              ({
                required pageIndex,
                required afterDocId,
                required limit,
                required delivered,
              }) {
                expect(limit, 500);
                if (delivered != null) pages.add(delivered);
              },
        );
        final col = repo.collectionFor(scope);
        for (var i = 0; i < count; i++) {
          await col.doc(seqUlid(i)).set(_storedSubTrack(i));
        }

        final emissions = await _firstComplete(repo.watchAll(scope));

        expect(emissions, hasLength(2));
        expect(emissions.first, isA<CompleteReadLoading<SubTrack>>());
        final ready = emissions.last as CompleteReadReady<SubTrack>;
        expect(ready.items, hasLength(count));
        expect(ready.items.map((s) => s.id).toSet(), hasLength(count));
        expect(pages, delivered);
        expect(
          col.path,
          'users/$_owner/learner_profiles/$profileUlid/sub_tracks',
        );
      });
    }

    test('tombstoned rows are part of the complete read', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreSubTrackRepository(firestore: firestore);
      await repo.collectionFor(scope).doc(ulidB).set({
        ..._storedSubTrack(0),
        'ended_at': Timestamp.fromDate(t1),
        'end_reason': 'track_deleted',
      });
      final ready =
          (await _firstComplete(repo.watchAll(scope))).last
              as CompleteReadReady<SubTrack>;
      expect(ready.items.single.isEnded, isTrue);
      expect(ready.items.single.endReason, SubTrackEndReason.trackDeleted);
      expect(ready.items.single.endedAt, t1);
    });

    test(
      'changed-fields merge: only changed fields + last_change_id are '
      'written, other fields kept, entry co-written in the same batch',
      () async {
        final firestore = _SpyFirestore();
        final repo = FirestoreSubTrackRepository(firestore: firestore);
        final doc = repo.collectionFor(scope).doc(ulidB);
        await doc.set(_storedSubTrack(0));

        await repo.applyGovernedChange(
          scope,
          SubTrackChange.fields(
            subTrackId: ulidB,
            changedFields: {'rate_per_week': 9},
            entry: _entry(ulidB, {'sub_tracks/$ulidB.rate_per_week': 9}),
          ),
        );

        final data = (await doc.get()).data()!;
        expect(data['rate_per_week'], 9);
        expect(data['name'], 'Shiur 0');
        expect(data['last_change_id'], ulidD);
        expect(SubTrack.fromStorage(ulidB, data).ratePerWeek, 9);

        final entry = await firestore
            .doc(
              'users/$_owner/learner_profiles/$profileUlid/change_log/$ulidD',
            )
            .get();
        expect(entry.exists, isTrue);
        expect(entry.data()!['entity'], 'subTrack');
        expect(entry.data()!['at'], Timestamp.fromDate(t0));
        expect(entry.data()!['after'], {'sub_tracks/$ulidB.rate_per_week': 9});

        const profile = 'users/$_owner/learner_profiles/$profileUlid';
        expect(firestore.ops, [
          'set $profile/sub_tracks/$ulidB merge=true',
          'set $profile/change_log/$ulidD merge=false',
          'commit',
        ]);
      },
    );

    test('tombstone sets ended_at + end_reason; the doc survives; never '
        'delete', () async {
      final firestore = _SpyFirestore();
      final repo = FirestoreSubTrackRepository(firestore: firestore);
      final doc = repo.collectionFor(scope).doc(ulidB);
      await doc.set(_storedSubTrack(0));

      await repo.applyGovernedChange(
        scope,
        SubTrackChange.tombstone(
          subTrackId: ulidB,
          endedAt: t1,
          reason: SubTrackEndReason.deleted,
          entry: _entry(ulidB, {
            'sub_tracks/$ulidB.ended_at': t1,
            'sub_tracks/$ulidB.end_reason': 'deleted',
          }),
        ),
      );

      final snapshot = await doc.get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['ended_at'], Timestamp.fromDate(t1));
      expect(snapshot.data()!['end_reason'], 'deleted');
      final decoded = SubTrack.fromStorage(
        ulidB,
        snapshot.data()!.map(
          (k, v) => MapEntry(k, v is Timestamp ? v.toDate().toUtc() : v),
        ),
      );
      expect(decoded.isEnded, isTrue);
      expect(firestore.ops.where((op) => op.startsWith('delete')), isEmpty);
      expect(firestore.ops.where((op) => op.startsWith('update')), isEmpty);

      final entry = await firestore
          .doc('users/$_owner/learner_profiles/$profileUlid/change_log/$ulidD')
          .get();
      expect(entry.data()!['after'], {
        'sub_tracks/$ulidB.ended_at': Timestamp.fromDate(t1),
        'sub_tracks/$ulidB.end_reason': 'deleted',
      });
    });

    test('an invalid change never reaches Firestore', () async {
      final firestore = _SpyFirestore();
      final repo = FirestoreSubTrackRepository(firestore: firestore);
      expect(
        () => repo.applyGovernedChange(
          scope,
          SubTrackChange.fields(
            subTrackId: ulidB,
            changedFields: {'ended_at': t1},
            entry: _entry(ulidB, {'sub_tracks/$ulidB.ended_at': t1}),
          ),
        ),
        throwsA(isA<StorageFormatException>()),
      );
      expect(firestore.ops, isEmpty);
    });

    test('codec golden keys match the schema', () {
      final track = SubTrack.fromStorage(ulidB, _storedSubTrack(0));
      expect(
        track.toStorage().keys.toSet().difference(SubTrack.storageKeys),
        isEmpty,
      );
    });
  });

  group('change_log is append-only: create-only plus identical replay '
      '(AD-6, AD-38, AD-46; review R2)', () {
    const profile = 'users/$_owner/learner_profiles/$profileUlid';

    SubTrackChange rateChange(int rate) => SubTrackChange.fields(
      subTrackId: ulidB,
      changedFields: {'rate_per_week': rate},
      entry: _entry(ulidB, {'sub_tracks/$ulidB.rate_per_week': rate}),
    );

    test('an identical replay is a no-op: no second batch, and a LATER '
        'change to the sub-track is not reverted', () async {
      final firestore = _SpyFirestore();
      final repo = FirestoreSubTrackRepository(firestore: firestore);
      final doc = repo.collectionFor(scope).doc(ulidB);
      await doc.set(_storedSubTrack(0));

      await repo.applyGovernedChange(scope, rateChange(9));
      // A later governed change landed (simulated directly).
      await doc.set({'rate_per_week': 3}, SetOptions(merge: true));
      firestore.ops.clear();

      await repo.applyGovernedChange(scope, rateChange(9));

      expect(firestore.ops, isEmpty);
      expect((await doc.get()).data()!['rate_per_week'], 3);
    });

    test('a NON-identical retry at an existing entry id throws and leaves '
        'both the audit entry and the sub-track unchanged', () async {
      final firestore = _SpyFirestore();
      final repo = FirestoreSubTrackRepository(firestore: firestore);
      final doc = repo.collectionFor(scope).doc(ulidB);
      await doc.set(_storedSubTrack(0));
      await repo.applyGovernedChange(scope, rateChange(9));

      final entryDoc = firestore.doc('$profile/change_log/$ulidD');
      final entryBefore = (await entryDoc.get()).data();
      final trackBefore = (await doc.get()).data();
      firestore.ops.clear();

      await expectLater(
        repo.applyGovernedChange(scope, rateChange(5)),
        throwsA(
          isA<ChangeLogConflictException>().having(
            (e) => e.entryId,
            'entryId',
            ulidD,
          ),
        ),
      );

      expect(firestore.ops, isEmpty);
      expect((await entryDoc.get()).data(), entryBefore);
      expect((await doc.get()).data(), trackBefore);
    });

    test(
      'an undecodable stored entry is a conflict, never overwritten',
      () async {
        final firestore = _SpyFirestore();
        final repo = FirestoreSubTrackRepository(firestore: firestore);
        final entryDoc = firestore.doc('$profile/change_log/$ulidD');
        await entryDoc.set({'entity': 'subTrack', 'junk': true});

        await expectLater(
          repo.applyGovernedChange(scope, rateChange(9)),
          throwsA(isA<ChangeLogConflictException>()),
        );
        expect(firestore.ops, isEmpty);
        expect((await entryDoc.get()).data(), {
          'entity': 'subTrack',
          'junk': true,
        });
      },
    );

    test('an entry that exists only on the SERVER with different data is a '
        'conflict: nothing is written', () async {
      final firestore = _SpyFirestore();
      final remote = toFirestoreMap(rateChange(5).entry.toStorage());
      final repo = FirestoreSubTrackRepository(
        firestore: firestore,
        guardRead: (_) async => remote,
      );
      await expectLater(
        repo.applyGovernedChange(scope, rateChange(9)),
        throwsA(isA<ChangeLogConflictException>()),
      );
      expect(firestore.ops, isEmpty);
    });

    test('a guard read failure propagates and nothing is written', () async {
      final firestore = _SpyFirestore();
      final repo = FirestoreSubTrackRepository(
        firestore: firestore,
        guardRead: (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'internal',
        ),
      );
      await expectLater(
        repo.applyGovernedChange(scope, rateChange(9)),
        throwsA(isA<FirebaseException>()),
      );
      expect(firestore.ops, isEmpty);
    });
  });
}
