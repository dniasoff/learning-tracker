/// DNI-470 AC-1, AC-2 (batch shape), AC-5 (revert lookup) and AC-8:
/// `FirestoreChangeLogRepository` pages the complete intent history, finds
/// action members and reverts across pages, commits governed batches
/// atomically, and per-field merges from two devices both survive.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_change_log_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

const _owner = 'owner-uid';
const _orderDoc = 'mishnayos_berakhot';

/// Records every batch operation, delegating to the real fake batch.
final class _SpyBatch implements WriteBatch {
  _SpyBatch(this._inner, this.ops, this.failWith);

  final WriteBatch _inner;
  final List<String> ops;
  final FirebaseException? failWith;

  @override
  Future<void> commit() {
    ops.add('commit');
    final failure = failWith;
    if (failure != null) return Future.error(failure);
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
  void update<T>(DocumentReference<T> document, T data) {
    ops.add('update ${document.path}');
    _inner.update(document, data);
  }
}

final class _SpyFirestore extends FakeFirebaseFirestore {
  final List<String> ops = [];
  FirebaseException? failCommitWith;

  @override
  WriteBatch batch() => _SpyBatch(super.batch(), ops, failCommitWith);
}

typedef _Probe = ({int page, String? after, int limit, int? delivered});

/// An entry of [entity] numbered [n] (ids sort by [n]).
ChangeLogEntry _entry(
  int n,
  GovernedEntity entity, {
  String? actionId,
  String? revertsActionId,
}) {
  final (entityId, key) = switch (entity) {
    GovernedEntity.learnerSettings => (
      profileUlid,
      'learner_profiles/$profileUlid.time_zone',
    ),
    GovernedEntity.subTrack => (ulidA, 'sub_tracks/$ulidA.name'),
    GovernedEntity.goal => (
      'mishnayos_deadline',
      'goals/mishnayos_deadline.target_date',
    ),
    _ => ('mishnayos', '${entity.collection}/$_orderDoc.curriculum_id'),
  };
  return ChangeLogEntry(
    id: engineUlid(n),
    entity: entity,
    entityId: entityId,
    actionId: actionId ?? engineUlid(n),
    revertsActionId: revertsActionId,
    before: {key: null},
    after: {key: 'v$n'},
    at: t0.add(Duration(minutes: n)),
    actor: parentActor,
  );
}

Future<void> _seed(
  FirebaseFirestore firestore,
  LearnerScope scope,
  Iterable<ChangeLogEntry> entries,
) async {
  final log = firestore.collection(
    'users/${scope.ownerUid}/learner_profiles/${scope.profileId}/change_log',
  );
  for (final e in entries) {
    await log.doc(e.id).set(toFirestoreMap(e.toStorage()));
  }
}

/// Every emission up to and including the first complete read.
Future<List<CompleteRead<ChangeLogEntry>>> _firstComplete(
  Stream<CompleteRead<ChangeLogEntry>> stream,
) async {
  final emissions = <CompleteRead<ChangeLogEntry>>[];
  final done = Completer<void>();
  final sub = stream.listen((e) {
    emissions.add(e);
    if (e is CompleteReadReady<ChangeLogEntry> && !done.isCompleted) {
      done.complete();
    }
  });
  await done.future.timeout(const Duration(seconds: 30));
  await pumpEventQueue();
  await sub.cancel();
  return emissions;
}

GovernedBatch _batch(
  String entryId,
  Map<String, Object?> fields, {
  Map<String, Object?>? before,
  GovernedEntity entity = GovernedEntity.mainTrackOrder,
  String docId = _orderDoc,
  DateTime? at,
}) {
  final entityId = entity == GovernedEntity.learnerSettings
      ? profileUlid
      : 'mishnayos';
  return GovernedBatch(
    entry: ChangeLogEntry(
      id: entryId,
      entity: entity,
      entityId: entityId,
      actionId: entryId,
      before: {
        for (final f in fields.keys)
          ChangedFieldKey(entity.collection, docId, f).key: before?[f],
      },
      after: {
        for (final MapEntry(:key, :value) in fields.entries)
          ChangedFieldKey(entity.collection, docId, key).key: value,
      },
      at: at ?? t0,
      actor: parentActor,
    ),
    merges: [
      GovernedDocMerge(
        collection: entity.collection,
        docId: docId,
        fields: fields,
      ),
    ],
  );
}

void main() {
  final scope = LearnerScope(ownerUid: _owner, profileId: profileUlid);
  const profilePath = 'users/$_owner/learner_profiles/$profileUlid';

  group('AC-1: watchIntentHistory pages the complete filtered history', () {
    test('exactly the five intent entities, in document-id order; loading '
        'first, then complete', () async {
      final firestore = FakeFirebaseFirestore();
      final all = [
        for (final (i, e) in GovernedEntity.values.indexed) _entry(i, e),
      ];
      await _seed(firestore, scope, all.reversed);
      final repo = FirestoreChangeLogRepository(firestore: firestore);

      final emissions = await _firstComplete(repo.watchIntentHistory(scope));

      expect(emissions.first, isA<CompleteReadLoading<ChangeLogEntry>>());
      expect(emissions, hasLength(2), reason: 'no partial result');
      final ready = emissions.last as CompleteReadReady<ChangeLogEntry>;
      expect(ready.rejected, isEmpty);
      expect(
        ready.items.map((e) => e.entity).toSet(),
        intentHistoryEntities,
        reason: 'subTrack, goal, mainTrack and mainTrackScope are excluded',
      );
      expect(ready.items, [
        for (final e in all)
          if (intentHistoryEntities.contains(e.entity)) e,
      ]);
      expect(intentHistoryEntityValues, [
        'mainTrackOrder',
        'mainTrackProgram',
        'mainTrackStudyDays',
        'mainTrackStages',
        'learnerSettings',
      ]);
    });

    test('an empty log is loading, then complete and empty', () async {
      final repo = FirestoreChangeLogRepository(
        firestore: FakeFirebaseFirestore(),
      );
      final emissions = await _firstComplete(repo.watchIntentHistory(scope));
      expect(emissions.first, isA<CompleteReadLoading<ChangeLogEntry>>());
      expect(
        (emissions.last as CompleteReadReady<ChangeLogEntry>).items,
        isEmpty,
      );
    });

    test('1,001 entries: pages of at most 500 by document-id cursor, and no '
        'result before every page is in', () async {
      final firestore = FakeFirebaseFirestore();
      final history = [
        for (var i = 0; i < 1001; i++)
          _entry(
            i,
            i.isEven
                ? GovernedEntity.learnerSettings
                : GovernedEntity.mainTrackOrder,
          ),
      ];
      await _seed(firestore, scope, [
        ...history,
        for (var i = 2000; i < 2010; i++) _entry(i, GovernedEntity.goal),
      ]);
      final probes = <_Probe>[];
      final repo = FirestoreChangeLogRepository(
        firestore: firestore,
        pageProbe:
            ({
              required pageIndex,
              required afterDocId,
              required limit,
              required delivered,
            }) => probes.add((
              page: pageIndex,
              after: afterDocId,
              limit: limit,
              delivered: delivered,
            )),
      );

      final emissions = await _firstComplete(repo.watchIntentHistory(scope));

      expect(emissions, hasLength(2));
      expect(emissions.first, isA<CompleteReadLoading<ChangeLogEntry>>());
      final ready = emissions.last as CompleteReadReady<ChangeLogEntry>;
      expect(ready.items, history);
      expect(probes.every((p) => p.limit == 500), isTrue);
      final delivered = [
        for (final p in probes)
          if (p.delivered != null) (p.page, p.after, p.delivered),
      ];
      expect(delivered, [
        (0, null, 500),
        (1, engineUlid(499), 500),
        (2, engineUlid(999), 1),
      ]);
    });

    test('no composite index is added for change_log (AD-54)', () {
      final file = File('firestore.indexes.json').existsSync()
          ? File('firestore.indexes.json')
          : File('learning_tracker/firestore.indexes.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final indexes = json['indexes']! as List<Object?>;
      expect(
        indexes.where(
          (i) =>
              (i! as Map<String, Object?>)['collectionGroup'] == 'change_log',
        ),
        isEmpty,
      );
    });
  });

  group('AC-4/AC-5: action members and revert lookup', () {
    test('entriesOfAction pages every member to the end, in id order, and '
        'ignores other actions', () async {
      final firestore = FakeFirebaseFirestore();
      final action = engineUlid(0);
      final members = [
        for (var i = 0; i < 501; i++)
          _entry(i, GovernedEntity.mainTrackOrder, actionId: action),
      ];
      await _seed(firestore, scope, [
        ...members,
        for (var i = 600; i < 610; i++) _entry(i, GovernedEntity.goal),
      ]);
      final pages = <int>[];
      final repo = FirestoreChangeLogRepository(
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

      expect(await repo.entriesOfAction(scope, action), members);
      expect(pages, [500, 1]);
      expect(await repo.entriesOfAction(scope, engineUlid(9999)), isEmpty);
    });

    test('watchIsReverted is false until an entry reverts the action, even '
        'when that entry sorts after 500 others', () async {
      final firestore = FakeFirebaseFirestore();
      final undone = engineUlid(0);
      await _seed(firestore, scope, [
        for (var i = 0; i < 600; i++) _entry(i, GovernedEntity.mainTrackOrder),
      ]);
      final repo = FirestoreChangeLogRepository(firestore: firestore);
      final seen = <bool>[];
      final sub = repo.watchIsReverted(scope, undone).listen(seen.add);
      await pumpEventQueue();
      expect(seen, [false]);

      await _seed(firestore, scope, [
        _entry(700, GovernedEntity.mainTrackOrder, revertsActionId: undone),
      ]);
      await pumpEventQueue();
      expect(seen, [false, true], reason: 'every device marks it Undone');
      await sub.cancel();
    });
  });

  group('AC-2: commitGoverned', () {
    test('one batch: field-level merge with last_change_id, then the entry '
        'create; other fields are untouched', () async {
      final firestore = _SpyFirestore();
      final doc = firestore.doc('$profilePath/track_learning_order/$_orderDoc');
      await doc.set({'curriculum_id': 'mishnayos', 'ref': 'Berakhot 1'});
      final repo = FirestoreChangeLogRepository(firestore: firestore);
      final batch = _batch(
        engineUlid(1),
        {'user_sort_order': 3},
        before: {'user_sort_order': null},
      );

      await repo.commitGoverned(scope, batch);

      expect(firestore.ops, [
        'set $profilePath/track_learning_order/$_orderDoc merge=true',
        'set $profilePath/change_log/${engineUlid(1)} merge=false',
        'commit',
      ]);
      expect((await doc.get()).data(), {
        'curriculum_id': 'mishnayos',
        'ref': 'Berakhot 1',
        'user_sort_order': 3,
        'last_change_id': engineUlid(1),
      });
      final stored = await firestore
          .doc('$profilePath/change_log/${engineUlid(1)}')
          .get();
      expect(
        ChangeLogEntry.fromStorage(stored.id, fromFirestoreMap(stored.data()!)),
        batch.entry,
      );
    });

    test('learnerSettings merges onto the profile doc itself and keeps '
        'ordinary profile fields', () async {
      final firestore = _SpyFirestore();
      await firestore.doc(profilePath).set({'display_name': 'Avi'});
      final repo = FirestoreChangeLogRepository(firestore: firestore);

      await repo.commitGoverned(
        scope,
        _batch(
          engineUlid(2),
          {'time_zone': 'Asia/Jerusalem', 'in_israel': true},
          entity: GovernedEntity.learnerSettings,
          docId: profileUlid,
        ),
      );

      expect(firestore.ops.first, 'set $profilePath merge=true');
      expect((await firestore.doc(profilePath).get()).data(), {
        'display_name': 'Avi',
        'time_zone': 'Asia/Jerusalem',
        'in_israel': true,
        'last_change_id': engineUlid(2),
      });
    });

    test('an identical replay is a no-op; a different entry at the same id '
        'conflicts and writes nothing', () async {
      final firestore = _SpyFirestore();
      final repo = FirestoreChangeLogRepository(firestore: firestore);
      final batch = _batch(engineUlid(3), {'user_sort_order': 1});
      await repo.commitGoverned(scope, batch);
      firestore.ops.clear();

      await repo.commitGoverned(scope, batch);
      expect(firestore.ops, isEmpty);

      await expectLater(
        repo.commitGoverned(
          scope,
          _batch(engineUlid(3), {'user_sort_order': 9}),
        ),
        throwsA(isA<ChangeLogConflictException>()),
      );
      expect(firestore.ops, isEmpty);
      final doc = await firestore
          .doc('$profilePath/track_learning_order/$_orderDoc')
          .get();
      expect(doc.data()!['user_sort_order'], 1);
    });

    test('a terminal server rejection is a PermanentWriteRejection', () async {
      final firestore = _SpyFirestore()
        ..failCommitWith = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      final repo = FirestoreChangeLogRepository(firestore: firestore);
      await expectLater(
        repo.commitGoverned(scope, _batch(engineUlid(4), {'ref': 'x'})),
        throwsA(
          isA<PermanentWriteRejection>().having(
            (r) => r.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });
  });

  group('AC-8: concurrent owner updates resolve per field', () {
    test('two devices patch different fields of one doc: both survive and '
        'both entries remain', () async {
      final firestore = FakeFirebaseFirestore();
      final deviceA = FirestoreChangeLogRepository(firestore: firestore);
      final deviceB = FirestoreChangeLogRepository(firestore: firestore);

      await deviceA.commitGoverned(
        scope,
        _batch(engineUlid(10), {'user_sort_order': 4}),
      );
      await deviceB.commitGoverned(
        scope,
        _batch(engineUlid(11), {'ref': 'Berakhot 2'}),
      );

      final doc = await firestore
          .doc('$profilePath/track_learning_order/$_orderDoc')
          .get();
      expect(doc.data(), {
        'user_sort_order': 4,
        'ref': 'Berakhot 2',
        'last_change_id': engineUlid(11),
      });
      final ready =
          (await _firstComplete(deviceA.watchIntentHistory(scope))).last
              as CompleteReadReady<ChangeLogEntry>;
      expect(ready.items.map((e) => e.id), [engineUlid(10), engineUlid(11)]);
    });

    test('the same field: the later server commit wins, both entries '
        'remain', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreChangeLogRepository(firestore: firestore);
      await repo.commitGoverned(
        scope,
        _batch(engineUlid(21), {'user_sort_order': 1}, at: t1),
      );
      // Device B's change was made earlier (client `at`) but commits later.
      await repo.commitGoverned(
        scope,
        _batch(engineUlid(20), {'user_sort_order': 2}, at: t0),
      );

      final doc = await firestore
          .doc('$profilePath/track_learning_order/$_orderDoc')
          .get();
      expect(doc.data()!['user_sort_order'], 2);
      expect(doc.data()!['last_change_id'], engineUlid(20));
      expect(
        (await repo.entriesOfAction(scope, engineUlid(20))).single.id,
        engineUlid(20),
      );
      expect(
        (await repo.entriesOfAction(scope, engineUlid(21))).single.id,
        engineUlid(21),
      );
    });
  });

  group('GovernedDocReader', () {
    test('currentDoc decodes timestamps to UTC and is null when absent; '
        'entry decodes, or is null when missing or malformed', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.doc('$profilePath/goals/mishnayos_deadline').set({
        'target_date': '2027-01-01',
        'ended_at': Timestamp.fromDate(t1),
      });
      await _seed(firestore, scope, [_entry(5, GovernedEntity.goal)]);
      await firestore.doc('$profilePath/change_log/${engineUlid(6)}').set({
        'entity': 'nope',
      });
      final repo = FirestoreChangeLogRepository(firestore: firestore);

      expect(await repo.currentDoc(scope, 'goals', 'mishnayos_deadline'), {
        'target_date': '2027-01-01',
        'ended_at': t1,
      });
      expect(await repo.currentDoc(scope, 'goals', 'mishnayos_pace'), isNull);
      expect(
        await repo.entry(scope, engineUlid(5)),
        _entry(5, GovernedEntity.goal),
      );
      expect(await repo.entry(scope, engineUlid(6)), isNull);
      expect(await repo.entry(scope, engineUlid(7)), isNull);
    });

    test('learnerSettings reads the profile doc itself', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.doc(profilePath).set({'time_zone': 'UTC'});
      final repo = FirestoreChangeLogRepository(firestore: firestore);
      expect(await repo.currentDoc(scope, 'learner_profiles', profileUlid), {
        'time_zone': 'UTC',
      });
    });
  });
}
