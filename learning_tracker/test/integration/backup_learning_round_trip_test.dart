// DNI-482 AC-3: export → import round-trip of a fixture learner through
// the real backup service, the real LearningCommands replay and the real
// Firestore repositories (on fake_cloud_firestore). The engine run on the
// imported profile must match the source: distinct count, tri-state,
// per-curriculum streak, completed units, the earningEventIds-filtered
// balance and the lock-ignored set.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/data/repositories/points_ledger_entry.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

import '../helpers/data_export_firestore_test_support.dart';
import '../helpers/firestore_fixtures.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state_fixtures.dart';

const _engine = LearnerStateEngine();

// Minutes after 2026-09-01T00:00Z (a Tuesday). The UTC no-location
// learner's Shabbos lock runs Fri 09-04 12:00Z → Sun 09-06 01:00Z.
int _day(int day, [int hour = 10]) => (day - 1) * 1440 + hour * 60;

final _now = engineAt(_day(9, 12)); // Wed 2026-09-09

LearnerScope _scope() =>
    LearnerScope(ownerUid: testUid, profileId: testProfileId);

String _key(String id, String field) =>
    ChangedFieldKey('sub_tracks', id, field).key;

/// Writes [track] through the Story 1.2 repository: a create, then a
/// tombstone when it is ended.
Future<void> _writeSubTrack(
  FirestoreSubTrackRepository repo,
  SubTrack track,
  int entryId,
) async {
  final fields = {
    for (final MapEntry(:key, :value) in track.toStorage().entries)
      if (key != SubTrack.kLastChangeId &&
          key != SubTrack.kEndedAt &&
          key != SubTrack.kEndReason)
        key: value,
  };
  await repo.applyGovernedChange(
    _scope(),
    SubTrackChange.create(
      subTrackId: track.id,
      changedFields: fields,
      entry: ChangeLogEntry(
        id: engineUlid(entryId),
        entity: GovernedEntity.subTrack,
        entityId: track.id,
        actionId: engineUlid(entryId),
        before: {for (final f in fields.keys) _key(track.id, f): null},
        after: {
          for (final MapEntry(:key, :value) in fields.entries)
            _key(track.id, key): value,
        },
        at: engineAt(0),
        actor: parentActor,
      ),
    ),
  );
  final endedAt = track.endedAt;
  if (endedAt == null) return;
  await repo.applyGovernedChange(
    _scope(),
    SubTrackChange.tombstone(
      subTrackId: track.id,
      endedAt: endedAt,
      reason: track.endReason!,
      entry: ChangeLogEntry(
        id: engineUlid(entryId + 1),
        entity: GovernedEntity.subTrack,
        entityId: track.id,
        actionId: engineUlid(entryId + 1),
        before: {
          _key(track.id, SubTrack.kEndedAt): null,
          _key(track.id, SubTrack.kEndReason): null,
        },
        after: {
          _key(track.id, SubTrack.kEndedAt): endedAt,
          _key(track.id, SubTrack.kEndReason): track.endReason!.storage,
        },
        at: endedAt,
        actor: parentActor,
      ),
    ),
  );
}

final _liveTrack = SubTrack(
  id: engineUlid(900),
  curriculumId: engineCurriculum,
  name: 'Shiur',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 7,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: const [NodeEntry(level: 'masechta', ref: 'Mishnah Peah')],
  lastChangeId: engineUlid(990),
);

final _endedTrack = SubTrack(
  id: engineUlid(901),
  curriculumId: engineCurriculum,
  name: 'Summer',
  type: SubTrackType.ongoing,
  windowStart: '2026-07-01',
  ratePerWeek: 3,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [],
  endedAt: engineAt(_day(3)),
  endReason: SubTrackEndReason.ended,
  lastChangeId: engineUlid(992),
);

LearningEvent _learn(
  int id,
  String ref,
  int minutes, {
  String source = LearningEvent.sourceMain,
  int? originalMinutes,
}) {
  final effective = engineAt(originalMinutes ?? minutes);
  final day = effective.toIso8601String().substring(0, 10);
  return engineLearn(
    id,
    ref,
    minutes: minutes,
    source: source,
    originalMinutes: originalMinutes,
    learnedOn: day,
  );
}

/// The fixture learner's log: streak days, a voided learn, a learn stamped
/// in the Shabbos lock, a sub-track learn, prior ground and an undo copy.
List<LearningEvent> _log() => [
  engineGround(1, berakhot1, minutes: _day(1, 9)),
  _learn(2, 'Mishnah Berakhot 2:1', _day(2)),
  _learn(3, 'Mishnah Berakhot 2:2', _day(3)),
  _learn(4, 'Mishnah Peah 1:1', _day(5)), // inside the Shabbos lock
  _learn(5, 'Mishnah Peah 1:2', _day(7)),
  engineVoid(6, 5, minutes: _day(7, 11)),
  _learn(7, 'Mishnah Peah 1:2', _day(8), source: engineUlid(900)),
  // An undo copy recorded on 09-08 of learning done on 09-07.
  _learn(8, 'Mishnah Shabbat 1:1', _day(8, 11), originalMinutes: _day(7, 9)),
];

Future<void> _seedSource(FakeFirebaseFirestore firestore) async {
  await seedProfile(firestore, uid: testUid, profileId: testProfileId);
  final subTracks = FirestoreSubTrackRepository(firestore: firestore);
  await _writeSubTrack(subTracks, _liveTrack, 990);
  await _writeSubTrack(subTracks, _endedTrack, 992);
  final events = _log();
  // Written with their pts_ entries, as every writer does (AD-50).
  await FirestoreLearningEventRepository(firestore: firestore).commit(
    _scope(),
    LearningWriteChunk(
      events: events,
      awards: [
        for (final e in events)
          if (e.isLearn &&
              e.source == LearningEvent.sourceMain &&
              e.dateState == DateState.dated)
            PointsAward(eventId: e.id, amount: 10, createdAt: effectiveAt(e)),
      ],
    ),
  );
  // A non-event spend.
  await firestore
      .doc('${_scope().profilePath}/points_ledger/${engineUlid(950)}')
      .set(
        PointsLedgerEntry(
          ulid: engineUlid(950),
          entryKind: 'parent_deduct',
          delta: -4,
          createdAt: engineAt(_day(8)),
          source: CompletionSource.live,
        ).toFirestore(),
      );
}

final class _Projection {
  _Projection(this.state, this.events, this.points);

  final LearnerState state;
  final List<LearningEvent> events;
  final List<PointsLedgerRow> points;

  CurriculumState get curriculum => state.curricula[engineCurriculum]!;

  LearningEvent byId(String id) => events.singleWhere((e) => e.id == id);

  /// Lock-ignored events, by what they are (ids differ after import).
  Set<(String?, DateTime)> get lockIgnored => {
    for (final id in state.lockIgnoredEventIds)
      (byId(id).ref, effectiveAt(byId(id))),
  };

  int get balance => pointsTotals(points, state.earningEventIds).balance;
}

Future<List<T>> _complete<T>(Stream<CompleteRead<T>> reads) async {
  final ready =
      await reads.firstWhere((r) => r is CompleteReadReady<T>)
          as CompleteReadReady<T>;
  expect(ready.isClean, isTrue);
  return ready.items;
}

Future<_Projection> _project(FakeFirebaseFirestore firestore) async {
  final events = await _complete(
    FirestoreLearningEventRepository(firestore: firestore).watchAll(_scope()),
  );
  final subTracks = await _complete(
    FirestoreSubTrackRepository(firestore: firestore).watchAll(_scope()),
  );
  final ledger = await firestore
      .collection('${_scope().profilePath}/points_ledger')
      .get();
  final points = [
    for (final doc in ledger.docs)
      pointsLedgerRowOf(
        pointsLedgerEntryFromFirestore(
          Map<String, dynamic>.of(fromFirestoreMap(doc.data())),
          docId: doc.id,
        ),
      ),
  ];
  final state = _engine.run(
    engineInputs(events: events, subTracks: subTracks, nowUtc: _now),
  );
  return _Projection(state, events, points);
}

void main() {
  test('the engine on the imported profile equals the source', () async {
    final source = FakeFirebaseFirestore();
    await _seedSource(source);
    final before = await _project(source);
    // The fixture exercises every compared projection.
    expect(before.state.lockIgnoredEventIds, {engineUlid(4)});
    expect(before.state.earningEventIds, isNotEmpty);
    expect(before.curriculum.completedUnits, isNotEmpty);
    expect(before.curriculum.streak, isNotNull);

    final payload = await backupService(source).exportData();
    expect(payload, isNot(contains('pts_')));

    final target = FakeFirebaseFirestore();
    await seedProfile(target, uid: testUid, profileId: testProfileId);
    final report = await backupService(target).importData(payload);
    expect(report.saved, isTrue);
    final after = await _project(target);

    // Fresh ids everywhere.
    expect(
      after.events
          .map((e) => e.id)
          .toSet()
          .intersection(before.events.map((e) => e.id).toSet()),
      isEmpty,
    );
    final tracks = await _complete(
      FirestoreSubTrackRepository(firestore: target).watchAll(_scope()),
    );
    expect(tracks, hasLength(2));
    expect(tracks.where((t) => t.isEnded), hasLength(1));
    expect(
      tracks.map((t) => t.id).toSet().intersection({
        _liveTrack.id,
        _endedTrack.id,
      }),
      isEmpty,
    );

    // Distinct count and tri-state.
    expect(after.curriculum.learntLeaves, before.curriculum.learntLeaves);
    for (final node in [zeraim, berakhot, berakhot1, berakhot2, peah, moed]) {
      expect(
        after.curriculum.triState(node),
        before.curriculum.triState(node),
        reason: node.ref,
      );
    }
    // Per-curriculum streak and completed units.
    expect(after.curriculum.streak, before.curriculum.streak);
    expect(after.curriculum.completedUnits, before.curriculum.completedUnits);
    // earningEventIds-based balance (pts_ re-derived, spend copied).
    expect(
      after.state.earningEventIds,
      hasLength(before.state.earningEventIds.length),
    );
    expect(after.balance, before.balance);
    // The lock-ignored set.
    expect(after.lockIgnored, before.lockIgnored);
    expect(
      after.state.countedEventIds,
      hasLength(before.state.countedEventIds.length),
    );
  });

  test('the imported profile holds no copy of an old pts_ entry', () async {
    final source = FakeFirebaseFirestore();
    await _seedSource(source);
    final target = FakeFirebaseFirestore();
    await seedProfile(target, uid: testUid, profileId: testProfileId);
    await backupService(
      target,
    ).importData(await backupService(source).exportData());
    final ledger = await target
        .collection('${_scope().profilePath}/points_ledger')
        .get();
    final sourceIds = {for (final e in _log()) e.id};
    for (final doc in ledger.docs) {
      final eventId = doc.data()['event_id'] as String?;
      if (eventId != null) {
        expect(sourceIds, isNot(contains(eventId)));
        expect(doc.id, 'pts_$eventId');
      }
    }
  });
}
