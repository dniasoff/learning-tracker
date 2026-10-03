/// Story 2.7 (DNI-498): `FirestoreSubTrackRepository.applyGovernedChangeToLatest`
/// — the ground picker's append derived from the server's row inside one
/// transaction, so two devices appending at once never overwrite each
/// other's whole `ground` list.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_latest_write.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state_fixtures.dart';

const _owner = 'owner-uid';
const _profile = 'users/$_owner/learner_profiles/$profileUlid';
const _berakhot = {'level': 'masechta', 'ref': 'Mishnah Berakhot'};
const _peah = {'level': 'masechta', 'ref': 'Mishnah Peah'};

/// Applies transaction writes with their real merge semantics (the fake's
/// own transaction drops `SetOptions`) and records them.
final class _RecordingTransaction implements Transaction {
  _RecordingTransaction(this.ops);

  final List<String> ops;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> document,
  ) {
    ops.add('get ${document.path}');
    return document.get();
  }

  @override
  Transaction set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) {
    ops.add('set ${document.path} merge=${options?.merge ?? false}');
    document.set(data, options);
    return this;
  }

  @override
  Transaction update(DocumentReference document, Map<Object, Object?> data) =>
      throw UnsupportedError('update');

  @override
  Transaction delete(DocumentReference document) =>
      throw UnsupportedError('delete');
}

final class _TxFirestore extends FakeFirebaseFirestore {
  final List<String> ops = [];

  /// A transaction failure to throw instead of running the handler.
  FirebaseException? failWith;

  /// Runs before each handler attempt (a concurrent server write).
  Future<void> Function()? beforeAttempt;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    await beforeAttempt?.call();
    return transactionHandler(_RecordingTransaction(ops));
  }
}

Map<String, Object?> _stored({List<Map<String, String>> ground = const []}) => {
  'curriculum_id': 'mishnayos',
  'name': 'School',
  'type': 'ongoing',
  'window_start': '2026-09-01',
  'rate_per_week': 10,
  'weeks_per_year': 39,
  'learns_on_shabbos': false,
  'ground': ground,
  'last_change_id': ulidC,
};

/// The append of [node] to whatever ground [latest] holds.
SubTrackChange _append(SubTrack latest, Map<String, String> node) {
  const key = 'sub_tracks/$ulidB.ground';
  List<Map<String, String>> stored(List<NodeEntry> ground) => [
    for (final n in ground) {'level': n.level, 'ref': n.ref},
  ];
  final after = [...stored(latest.ground), node];
  return SubTrackChange.fields(
    subTrackId: ulidB,
    changedFields: {'ground': after},
    entry: ChangeLogEntry(
      id: ulidD,
      entity: GovernedEntity.subTrack,
      entityId: ulidB,
      actionId: ulidD,
      before: {key: stored(latest.ground)},
      after: {key: after},
      at: t0,
      actor: parentActor,
    ),
  );
}

void main() {
  final scope = LearnerScope(ownerUid: _owner, profileId: profileUlid);
  late _TxFirestore firestore;
  late FirestoreSubTrackRepository repo;
  late DocumentReference<Map<String, dynamic>> doc;

  setUp(() async {
    firestore = _TxFirestore();
    repo = FirestoreSubTrackRepository(firestore: firestore);
    doc = repo.collectionFor(scope).doc(ulidB);
    await doc.set(_stored());
  });

  test('the repository offers the latest-row write', () {
    expect(repo, isA<SubTrackLatestWrite>());
  });

  test('derives the change from the server row and writes the merged doc '
      'and its entry in one transaction', () async {
    // Another device appended Berakhot after this one last read the row.
    firestore.beforeAttempt = () async {
      firestore.beforeAttempt = null;
      await doc.set({
        'ground': [_berakhot],
        'last_change_id': ulidA,
      }, SetOptions(merge: true));
    };
    final change = await repo.applyGovernedChangeToLatest(
      scope,
      ulidB,
      (latest) => _append(latest, _peah),
    );
    final data = (await doc.get()).data()!;
    expect(data['ground'], [_berakhot, _peah]);
    expect(data['name'], 'School');
    expect(data['last_change_id'], ulidD);
    final entry = (await firestore.doc('$_profile/change_log/$ulidD').get())
        .data()!;
    expect(entry['before'], {
      'sub_tracks/$ulidB.ground': [_berakhot],
    });
    expect(change!.entry.id, ulidD);
    expect(firestore.ops, [
      'get $_profile/sub_tracks/$ulidB',
      'set $_profile/sub_tracks/$ulidB merge=true',
      'set $_profile/change_log/$ulidD merge=false',
    ]);
  });

  test('a build returning null writes nothing', () async {
    final change = await repo.applyGovernedChangeToLatest(
      scope,
      ulidB,
      (_) => null,
    );
    expect(change, isNull);
    expect(firestore.ops, ['get $_profile/sub_tracks/$ulidB']);
    expect((await doc.get()).data(), _stored());
  });

  test('an unknown row throws SubTrackNotFoundException', () async {
    await expectLater(
      repo.applyGovernedChangeToLatest(
        scope,
        ulidA,
        (latest) => _append(latest, _peah),
      ),
      throwsA(isA<SubTrackNotFoundException>()),
    );
  });

  test('a before that is not the server row throws and writes nothing', () {
    expect(
      repo.applyGovernedChangeToLatest(
        scope,
        ulidB,
        (latest) => _append(
          SubTrack.fromStorage(ulidB, _stored(ground: [_berakhot])),
          _peah,
        ),
      ),
      throwsA(isA<ChangeBaselineMismatchException>()),
    );
  });

  for (final (code, matcher) in [
    ('unavailable', isA<OnlineRequiredException>()),
    ('deadline-exceeded', isA<OnlineRequiredException>()),
    (
      'permission-denied',
      isA<PermanentWriteRejection>().having(
        (e) => e.code,
        'code',
        'permission-denied',
      ),
    ),
  ]) {
    test('a $code transaction failure maps for the command', () async {
      firestore.failWith = FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
      );
      await expectLater(
        repo.applyGovernedChangeToLatest(
          scope,
          ulidB,
          (latest) => _append(latest, _peah),
        ),
        throwsA(matcher),
      );
      expect((await doc.get()).data(), _stored());
    });
  }
}
