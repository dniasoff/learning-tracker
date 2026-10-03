// Mirror test for
// `lib/features/learning/domain/commands/backup_import_replay.dart`
// (DNI-482 AC-2 replay order and mapping; AC-4 AD-54 chunking and the
// "not saved — retry" recovery of a rejected chunk).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/backup_record_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';

import '../../../../helpers/learner_state/backup_replay_harness.dart';
import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _c = engineCurriculum;
const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';
const _p11 = 'Mishnah Peah 1:1';

String _k(String collection, String doc, String field) =>
    ChangedFieldKey(collection, doc, field).key;

ChangeLogEntry _settings(
  int id, {
  required int minutes,
  required Map<String, Object?> before,
  required Map<String, Object?> after,
}) => ChangeLogEntry(
  id: engineUlid(id),
  entity: GovernedEntity.learnerSettings,
  entityId: profileUlid,
  actionId: engineUlid(id),
  before: {
    for (final e in before.entries)
      _k('learner_profiles', profileUlid, e.key): e.value,
  },
  after: {
    for (final e in after.entries)
      _k('learner_profiles', profileUlid, e.key): e.value,
  },
  at: engineAt(minutes),
  actor: parentActor,
);

final _liveTrack = c0SubTrack(id: engineUlid(900));
final _endedTrack = SubTrack(
  id: engineUlid(901),
  curriculumId: _c,
  name: 'Summer',
  type: SubTrackType.ongoing,
  windowStart: '2026-07-01',
  ratePerWeek: 3,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [],
  endedAt: engineAt(200),
  endReason: SubTrackEndReason.ended,
  lastChangeId: engineUlid(902),
);

/// The fixture learner's record (source ids are small engineUlids).
BackupReplayInput _fixture() => BackupReplayInput(
  events: [
    engineLearn(1, _b11, minutes: 10, stage: 1), // main, earns
    engineLearn(2, _b12, minutes: 20, source: engineUlid(900)), // sub-track
    engineLearn(3, _b13, minutes: 30), // main, earns, voided by 10
    engineLearn(4, _p11, minutes: 300, originalMinutes: 40), // undo copy
    engineLearn(5, 'Mishnah Shabbat 1:1', minutes: 50, source: engineUlid(77)),
    engineVoid(10, 3, minutes: 60),
    engineVoid(11, 99, minutes: 61), // target absent: dropped
    engineVoid(12, 10, minutes: 62), // target is a void: dropped
  ],
  subTracks: [_endedTrack, _liveTrack],
  changeLog: [
    _settings(
      20,
      minutes: 0,
      before: {'time_zone': null, 'in_israel': null},
      after: {'time_zone': 'UTC', 'in_israel': false},
    ),
    _settings(
      21,
      minutes: 100,
      before: {'latitude': null, 'longitude': null},
      after: {'latitude': 40.7, 'longitude': -74.0},
    ),
    // Not a learnerSettings entry: never replayed.
    ChangeLogEntry(
      id: engineUlid(22),
      entity: GovernedEntity.mainTrackProgram,
      entityId: _c,
      actionId: engineUlid(22),
      before: {_k('profile_programs', _c, 'tracking_start_ref'): null},
      after: {_k('profile_programs', _c, 'tracking_start_ref'): _b11},
      at: engineAt(5),
      actor: parentActor,
    ),
  ],
  governed: {
    GovernedEntity.mainTrack: [
      BackupDoc(_c, {
        'curriculum_id': _c,
        'state': 'active',
        'last_change_id': engineUlid(30),
        'updated_at': engineAt(1),
      }),
    ],
    GovernedEntity.mainTrackOrder: [
      for (var i = 0; i < 12; i++)
        BackupDoc('order-${i.toString().padLeft(2, '0')}', {
          'curriculum_id': _c,
          'ref': 'node $i',
          'user_sort_order': i,
        }),
    ],
  },
  pointsEntries: [
    BackupDoc('pts_${engineUlid(1)}', {
      'event_id': engineUlid(1),
      'delta': 10,
      'created_at': engineAt(10),
    }),
    BackupDoc(engineUlid(40), {
      'ulid': engineUlid(40),
      'entry_kind': 'redemption_debit',
      'delta': -5,
      'redemption_ulid': engineUlid(41),
      'created_at': engineAt(400),
    }),
    BackupDoc(engineUlid(42), {
      'ulid': engineUlid(42),
      'entry_kind': 'parent_add',
      'delta': 3,
      'created_at': engineAt(410),
    }),
  ],
  rewardRedemptions: [
    BackupDoc(engineUlid(41), {
      'ulid': engineUlid(41),
      'status': 'pending_fulfilment',
    }),
  ],
);

/// The destination's import-time state: a seeded profile and a paused
/// main track.
BackupReplayHarness _destination() {
  final h = BackupReplayHarness();
  h.store
    ..seedDoc(h.scope, 'learner_profiles', profileUlid, {
      'time_zone': 'Asia/Jerusalem',
      'in_israel': true,
      'last_change_id': engineUlid(4000),
    })
    ..seedDoc(h.scope, 'curriculum_tracks', _c, {
      'curriculum_id': _c,
      'state': 'paused',
      'last_change_id': engineUlid(4001),
    });
  return h;
}

void main() {
  group('AC-2: replay order and mapping', () {
    late BackupReplayHarness h;
    late BackupReplayResult result;

    setUp(() async {
      h = _destination();
      result = await h.commands.importBackup(_fixture());
    });

    test('runs settings, governed, sub-tracks, learns, voids, records in '
        'order and is saved', () {
      expect(result.saved, isTrue);
      expect(result.result, isA<CaptureSuccess>());
      expect(result.steps, BackupReplayStep.values);
      final firstOf = {
        for (final step in [
          'governed:learnerSettings',
          'governed:mainTrack',
          'subTrack:create',
          'events',
          'records',
        ])
          step: h.log.indexOf(step),
      };
      expect(firstOf.values.every((i) => i >= 0), isTrue, reason: '${h.log}');
      expect(firstOf.values.toList(), [...firstOf.values]..sort());
      expect(
        h.log.lastIndexOf('governed:learnerSettings'),
        lessThan(firstOf['governed:mainTrack']!),
      );
      expect(
        h.log.lastIndexOf('subTrack:update'),
        lessThan(firstOf['events']!),
      );
    });

    test('settings replay as ordered updates of the import seed with '
        'original_at', () {
      final settings = [
        for (final (_, b) in h.store.batches)
          if (b.entry.entity == GovernedEntity.learnerSettings) b.entry,
      ];
      expect(settings, hasLength(2));
      final first = settings[0];
      expect(first.before, {
        _k('learner_profiles', profileUlid, 'time_zone'): 'Asia/Jerusalem',
        _k('learner_profiles', profileUlid, 'in_israel'): true,
      });
      expect(first.after, {
        _k('learner_profiles', profileUlid, 'time_zone'): 'UTC',
        _k('learner_profiles', profileUlid, 'in_israel'): false,
      });
      expect(first.originalAt, engineAt(0));
      expect(first.at, h.now);
      expect(settings[1].before.values, everyElement(isNull));
      expect(settings[1].originalAt, engineAt(100));
      final doc = h.store.doc(h.scope, 'learner_profiles', profileUlid)!;
      expect(doc['time_zone'], 'UTC');
      expect(doc['latitude'], 40.7);
      expect(doc['last_change_id'], settings[1].id);
    });

    test('governed docs are field-level logged updates, never creates, at '
        'most 10 docs per batch', () {
      final governed = [
        for (final (_, b) in h.store.batches)
          if (b.entry.entity != GovernedEntity.learnerSettings) b,
      ];
      final track = governed.singleWhere(
        (b) => b.entry.entity == GovernedEntity.mainTrack,
      );
      // Only the changed field, with the cached value as `before`.
      expect(track.entry.before, {
        _k('curriculum_tracks', _c, 'state'): 'paused',
      });
      expect(track.entry.after, {
        _k('curriculum_tracks', _c, 'state'): 'active',
      });
      final order = governed
          .where((b) => b.entry.entity == GovernedEntity.mainTrackOrder)
          .toList();
      expect(order.map((b) => b.merges.length), [10, 2]);
      expect(order.every((b) => b.entry.entityId == _c), isTrue);
      expect(order.expand((b) => b.entry.before.values), everyElement(isNull));
      for (final b in governed) {
        expect(b.merges.length, lessThanOrEqualTo(10));
        for (final m in b.merges) {
          expect(m.fields.keys, isNot(contains('updated_at')));
          expect(m.fields.keys, isNot(contains('last_change_id')));
        }
      }
      // Unrelated history is not replayed.
      expect(
        governed.where(
          (b) => b.entry.entity == GovernedEntity.mainTrackProgram,
        ),
        isEmpty,
      );
      final entryIds = {for (final (_, b) in h.store.batches) b.entry.id};
      expect(entryIds, isNot(contains(engineUlid(22))));
      // One user action.
      final actions = {for (final (_, b) in h.store.batches) b.entry.actionId};
      expect(actions, hasLength(1));
    });

    test('sub-tracks get fresh ids; the ended one is created then '
        'tombstoned', () {
      expect(result.subTrackIds.keys, {_liveTrack.id, _endedTrack.id});
      expect(
        result.subTrackIds.values.toSet().intersection({
          _liveTrack.id,
          _endedTrack.id,
        }),
        isEmpty,
      );
      final tracks = {for (final t in h.subTracks.tracksOf(h.scope)) t.id: t};
      final live = tracks[result.subTrackIds[_liveTrack.id]]!;
      final ended = tracks[result.subTrackIds[_endedTrack.id]]!;
      expect(live.isEnded, isFalse);
      expect(live.name, _liveTrack.name);
      expect(ended.endedAt, _endedTrack.endedAt);
      expect(ended.endReason, SubTrackEndReason.ended);
      expect(h.log.where((l) => l == 'subTrack:create'), hasLength(2));
      expect(h.log.where((l) => l == 'subTrack:update'), hasLength(1));
    });

    test('learn events get fresh ids, remapped sources and '
        'original_recorded_at = effectiveAt(old)', () {
      final written = [for (final c in h.events.chunks) ...c.events];
      final learns = {for (final e in written.where((e) => e.isLearn)) e.id: e};
      expect(learns, hasLength(5));
      LearningEvent copyOf(int oldId) =>
          learns[result.eventIds[engineUlid(oldId)]]!;
      expect(copyOf(1).ref, _b11);
      expect(effectiveAt(copyOf(1)), engineAt(10));
      expect(rawRecordedAtForSkewRule(copyOf(1)), h.now);
      expect(copyOf(1).actor, parentActor);
      expect(copyOf(2).source, result.subTrackIds[engineUlid(900)]);
      // An undo copy keeps its original instant.
      expect(effectiveAt(copyOf(4)), engineAt(40));
      // A source absent from the backup keeps its id.
      expect(copyOf(5).source, engineUlid(77));
      expect(
        learns.keys.toSet().intersection({
          for (var i = 1; i <= 5; i++) engineUlid(i),
        }),
        isEmpty,
      );
    });

    test('voids are remapped; a void whose target is unmapped is dropped', () {
      final voids = [
        for (final c in h.events.chunks) ...c.events.where((e) => e.isVoid),
      ];
      expect(voids, hasLength(1));
      expect(voids.single.targetId, result.eventIds[engineUlid(3)]);
      expect(effectiveAt(voids.single), engineAt(60));
      expect(result.eventIds.keys, isNot(contains(engineUlid(11))));
      expect(result.eventIds.keys, isNot(contains(engineUlid(12))));
    });

    test('pts_ entries are re-derived with their events; event entries are '
        'never imported; non-event entries are new', () {
      final awards = [for (final c in h.events.chunks) ...c.awards];
      expect(awards.map((a) => a.eventId).toSet(), {
        result.eventIds[engineUlid(1)],
        result.eventIds[engineUlid(3)],
        result.eventIds[engineUlid(4)],
      });
      for (final c in h.events.chunks) {
        final ids = {for (final e in c.events) e.id};
        expect(c.awards.every((a) => ids.contains(a.eventId)), isTrue);
      }
      expect(awards.every((a) => a.createdAt == h.now), isTrue);

      final records = h.records.docsOf(h.scope);
      expect(records.keys.where((k) => k.contains('pts_')), isEmpty);
      final points = {
        for (final MapEntry(:key, :value) in records.entries)
          if (key.startsWith('points_ledger/')) key: value,
      };
      expect(points, hasLength(2));
      expect(points.keys, isNot(contains('points_ledger/${engineUlid(40)}')));
      final redemption = records.entries.singleWhere(
        (e) => e.key.startsWith('reward_redemptions/'),
      );
      final newRedemptionId = redemption.key.split('/').last;
      expect(newRedemptionId, isNot(engineUlid(41)));
      expect(redemption.value['ulid'], newRedemptionId);
      final debit = points.values.singleWhere(
        (p) => p['entry_kind'] == 'redemption_debit',
      );
      expect(debit['redemption_ulid'], newRedemptionId);
      expect(debit['created_at'], engineAt(400));
      for (final MapEntry(:key, :value) in points.entries) {
        expect(value['ulid'], key.split('/').last);
      }
    });
  });

  group('a fresh destination with seed-only settings (DNI-482)', () {
    // The destination profile doc was restored without settings keys
    // (AD-37), so it holds no settings at all.
    BackupReplayHarness fresh() {
      final h = BackupReplayHarness();
      h.store.seedDoc(h.scope, 'learner_profiles', profileUlid, {
        'display_name': 'Restored',
      });
      return h;
    }

    LearnerSettingsHistory historyOf(BackupReplayHarness h) =>
        LearnerSettingsHistory.reconstruct(
          current: LearnerSettings.fromProfileDoc(
            profileUlid,
            h.store.doc(h.scope, 'learner_profiles', profileUlid)!,
          ),
          entries: [for (final (_, b) in h.store.batches) b.entry],
        );

    test('with no learnerSettings history, the source settings restore as '
        'a leading seed and the record is restored', () async {
      final h = fresh();
      final result = await h.commands.importBackup(
        BackupReplayInput(
          settingsSeed: const {
            'time_zone': 'Asia/Jerusalem',
            'in_israel': true,
            'last_change_id': '01ARZ3NDEKTSV4RRFFQ69G5FAV',
          },
          events: [engineLearn(1, _b11, minutes: 10)],
        ),
      );
      expect(result.saved, isTrue);
      expect(result.steps.first, BackupReplayStep.learnerSettings);
      final seed = h.store.batches.single.$2.entry;
      expect(seed.entity, GovernedEntity.learnerSettings);
      expect(seed.before.values, everyElement(isNull));
      expect(seed.after, {
        _k('learner_profiles', profileUlid, 'time_zone'): 'Asia/Jerusalem',
        _k('learner_profiles', profileUlid, 'in_israel'): true,
      });
      expect(seed.originalAt, isNull);
      expect(historyOf(h).at(engineAt(0)).timeZone, 'Asia/Jerusalem');
      expect(h.events.chunks, hasLength(1));
    });

    test('a history without a seed entry is led by the source\'s initial '
        'settings', () async {
      final h = fresh();
      final result = await h.commands.importBackup(
        BackupReplayInput(
          settingsSeed: const {
            'time_zone': 'America/New_York',
            'latitude': 40.7,
            'longitude': -74.0,
          },
          changeLog: [
            _settings(
              21,
              minutes: 100,
              before: {'time_zone': 'Asia/Jerusalem'},
              after: {'time_zone': 'America/New_York'},
            ),
          ],
        ),
      );
      expect(result.saved, isTrue);
      final entries = [for (final (_, b) in h.store.batches) b.entry];
      expect(entries, hasLength(2));
      expect(entries.first.before.values, everyElement(isNull));
      expect(
        entries.first.after[_k('learner_profiles', profileUlid, 'time_zone')],
        'Asia/Jerusalem',
      );
      expect(entries.last.originalAt, engineAt(100));
      final history = historyOf(h);
      expect(history.at(engineAt(50)).timeZone, 'Asia/Jerusalem');
      expect(history.at(engineAt(50)).latitude, 40.7);
      expect(history.at(engineAt(150)).timeZone, 'America/New_York');
    });

    test('a seeded destination keeps its own settings', () async {
      final h = _destination();
      final result = await h.commands.importBackup(
        BackupReplayInput(settingsSeed: const {'time_zone': 'UTC'}),
      );
      expect(result.saved, isTrue);
      expect(h.store.batches, isEmpty);
    });
  });

  test('an empty learner writes nothing and succeeds', () async {
    final h = BackupReplayHarness();
    final result = await h.commands.importBackup(BackupReplayInput());
    expect(result.saved, isTrue);
    expect(h.log, isEmpty);
  });

  test('a re-import onto an unchanged destination re-writes no governed '
      'field', () async {
    final h = _destination();
    await h.commands.importBackup(_fixture());
    final before = h.store.batches.length;
    h.log.clear();
    await h.commands.importBackup(
      BackupReplayInput(
        changeLog: _fixture().changeLog,
        governed: _fixture().governed,
      ),
    );
    expect(h.store.batches.length, before);
    expect(h.log, isEmpty);
  });

  test('a locked gate writes nothing', () async {
    final lock = LockWindow(engineAt(0), engineAt(10000));
    final h = BackupReplayHarness(gate: FakeCaptureGate.locked(lock));
    final result = await h.commands.importBackup(_fixture());
    expect(result.result, isA<CaptureLocked>());
    expect(result.saved, isFalse);
    expect(h.log, isEmpty);
  });

  group('AC-4: AD-54 chunks and "not saved — retry"', () {
    BackupReplayInput large() => BackupReplayInput(
      events: [
        for (var i = 0; i < 500; i++)
          engineLearn(10 + i, 'leaf $i', minutes: i),
      ],
    );

    test('a large log is chunked at 450 writes with each event and its pts_ '
        'entry together', () async {
      final h = BackupReplayHarness();
      final result = await h.commands.importBackup(large());
      expect(result.saved, isTrue);
      final chunks = h.events.chunks;
      expect(chunks.length, greaterThan(2));
      for (final c in chunks) {
        expect(
          c.events.length + c.awards.length,
          lessThanOrEqualTo(LearningWriteChunk.maxWrites),
        );
        final ids = {for (final e in c.events) e.id};
        expect(c.awards.every((a) => ids.contains(a.eventId)), isTrue);
        expect(c.awards, hasLength(c.events.length));
      }
      expect(chunks.expand((c) => c.events), hasLength(500));
    });

    test('a rejected chunk is "not saved — retry", never reported saved, and '
        'its retry re-sends the same chunk', () async {
      final h = BackupReplayHarness()..writePort.rejectAttempts.add(1);
      final result = await h.commands.importBackup(large());

      final rejected = h.writePort.attempts[1];
      expect(result.saved, isFalse);
      expect(result.result, isA<CaptureSuccess>());
      final failure = result.notSaved.single;
      expect(failure.id, rejected.events.first.id);
      expect(failure.eventIds, [for (final e in rejected.events) e.id]);
      expect(failure.reason, PendingFailureReason.permissionDenied);
      expect(
        (result.result as CaptureSuccess).eventIds.toSet().intersection(
          failure.eventIds.toSet(),
        ),
        isEmpty,
      );
      expect(
        h.failureReporter.reports.single.command,
        LearningCommandKind.backupImport,
      );
      expect(await h.commands.watchPendingFailures().first, [failure]);

      final retried = await h.commands.retry(failure.id);
      expect(retried, isA<CaptureSuccess>());
      expect(identical(h.writePort.attempts.last, rejected), isTrue);
      expect(await h.commands.watchPendingFailures().first, isEmpty);
    });

    test('a rejected governed batch is "not saved — retry" too', () async {
      final h = _destination();
      final input = _fixture();
      // The first planned entry id (the first settings update).
      h.changeLog.fail.add(engineUlid(5000));
      final result = await h.commands.importBackup(input);
      expect(result.saved, isFalse);
      expect(result.notSaved.single.changeIds, [engineUlid(5000)]);
      h.changeLog.fail.clear();
      expect(await h.commands.retry(engineUlid(5000)), isA<CaptureSuccess>());
      expect(await h.commands.watchPendingFailures().first, isEmpty);
    });

    test(
      'a queued event chunk the server rejects after the ack wait is '
      '"not saved — retry", and the import is never reported saved',
      () async {
        final h = BackupReplayHarness();
        h.events.holdNext();
        final result = await h.commands.importBackup(
          BackupReplayInput(events: [engineLearn(1, _b11, minutes: 10)]),
        );
        expect(result.result, isA<CaptureSuccess>());
        expect(result.queued, isTrue);
        expect(result.saved, isFalse);
        expect(result.notSaved, isEmpty);

        final queuedChunk = h.writePort.attempts.single;
        h.events.reject(const PermanentWriteRejection('permission-denied'));
        await result.settled;
        expect(result.isSettled, isTrue);
        expect(result.saved, isFalse);
        expect(result.queued, isFalse);
        final failure = result.notSaved.single;
        expect(failure.id, queuedChunk.events.first.id);

        expect(await h.commands.retry(failure.id), isA<CaptureSuccess>());
        expect(identical(h.writePort.attempts.last, queuedChunk), isTrue);
        expect(result.notSaved, isEmpty);
        expect(result.saved, isTrue);
      },
    );

    test('a queued governed batch the server rejects late is "not saved — '
        'retry" too', () async {
      final h = _destination();
      final held = Completer<void>();
      h.changeLog.hold[engineUlid(5000)] = held;
      final result = await h.commands.importBackup(_fixture());
      expect(result.queued, isTrue);
      expect(result.saved, isFalse);

      held.completeError(const PermanentWriteRejection('permission-denied'));
      await result.settled;
      expect(result.saved, isFalse);
      expect(result.notSaved.single.changeIds, [engineUlid(5000)]);
      expect(await h.commands.retry(engineUlid(5000)), isA<CaptureSuccess>());
      expect(result.saved, isTrue);
    });

    test(
      'a queued write the server later acknowledges settles saved',
      () async {
        final h = BackupReplayHarness();
        h.events.holdNext();
        final result = await h.commands.importBackup(
          BackupReplayInput(events: [engineLearn(1, _b11, minutes: 10)]),
        );
        expect(result.queued, isTrue);
        h.events.release();
        await result.settled;
        expect(result.saved, isTrue);
      },
    );

    test('when every write is rejected the import is not saved', () async {
      final h = BackupReplayHarness()
        ..writePort.rejectAttempts.addAll([0, 1, 2]);
      final result = await h.commands.importBackup(large());
      expect(
        result.result,
        const CaptureResult.rejected(CaptureRejection.notSaved),
      );
      expect(result.notSaved, hasLength(3));
    });

    test('records go out in batches of at most 450', () async {
      final h = BackupReplayHarness();
      await h.commands.importBackup(
        BackupReplayInput(
          pointsEntries: [
            for (var i = 0; i < 451; i++)
              BackupDoc('adj-$i', {'delta': 1, 'entry_kind': 'parent_add'}),
          ],
        ),
      );
      expect(h.records.commits.map((c) => c.length), [450, 1]);
      expect(
        h.records.commits
            .expand((c) => c)
            .every((w) => w.collection == BackupRecordCollection.pointsLedger),
        isTrue,
      );
    });
  });
}
