// Mirror test for
// `lib/features/settings/data/repositories/backup_learning_sources.dart`
// (DNI-482: the production BackupLearningPort and the record port).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/backup_firestore_gateway.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/backup_record_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/settings/data/repositories/backup_learning_sources.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

ChangeLogEntry _settings(
  int id,
  DateTime at,
  Map<String, Object?> after, {
  Map<String, Object?>? before,
}) => ChangeLogEntry(
  id: engineUlid(id),
  entity: GovernedEntity.learnerSettings,
  entityId: testProfileId,
  actionId: engineUlid(id),
  before: {
    for (final k in after.keys)
      'learner_profiles/$testProfileId.$k': before?[k],
  },
  after: {
    for (final e in after.entries)
      'learner_profiles/$testProfileId.${e.key}': e.value,
  },
  at: at,
  actor: parentActor,
);

void main() {
  test(
    'the record port writes one batch of new docs under the profile',
    () async {
      final firestore = FakeFirebaseFirestore();
      final port = GatewayBackupRecordWritePort(
        backupFirestoreGatewayFor(firestore),
      );
      final scope = c0Scope(ownerUid: testUid);
      await port.commit(scope, [
        BackupRecordWrite(
          collection: BackupRecordCollection.pointsLedger,
          docId: ulidA,
          fields: {'delta': 3, 'created_at': DateTime.utc(2026)},
        ),
        BackupRecordWrite(
          collection: BackupRecordCollection.rewardRedemptions,
          docId: ulidB,
          fields: const {'status': 'fulfilled'},
        ),
      ]);
      final points = await firestore
          .doc('${scope.profilePath}/points_ledger/$ulidA')
          .get();
      expect(points.data()!['delta'], 3);
      expect(
        (await firestore
                .doc('${scope.profilePath}/reward_redemptions/$ulidB')
                .get())
            .exists,
        isTrue,
      );
    },
  );

  test('sub-tracks are one complete repository read; undecodable rows fail '
      'the export', () async {
    final firestore = FakeFirebaseFirestore();
    final port = firestoreBackupLearningPort(firestore);
    expect(await port.readSubTracks(testProfileId), isEmpty);
    await firestore
        .doc('users/$testUid/learner_profiles/$testProfileId/sub_tracks/$ulidA')
        .set({'name': 'broken'});
    await expectLater(
      port.readSubTracks(testProfileId),
      throwsA(isA<StateError>()),
    );
  });

  test('learning events are one complete repository read, learns and voids; '
      'undecodable rows fail the export', () async {
    final firestore = FakeFirebaseFirestore();
    final port = firestoreBackupLearningPort(firestore);
    expect(await port.readLearningEvents(testProfileId), isEmpty);
    final events = FirestoreLearningEventRepository(firestore: firestore);
    final scope = LearnerScope(ownerUid: testUid, profileId: testProfileId);
    final learn = engineLearn(1, 'Mishnah Berakhot 1:1');
    final voided = engineVoid(2, 1);
    await events.create(scope, learn);
    await events.create(scope, voided);
    expect((await port.readLearningEvents(testProfileId)).map((e) => e.id), [
      learn.id,
      voided.id,
    ]);
    await firestore.doc('${scope.profilePath}/learning_events/$ulidA').set({
      'kind': 'learn',
    });
    await expectLater(
      port.readLearningEvents(testProfileId),
      throwsA(isA<StateError>()),
    );
  });

  test('a retry of an unknown failure is targetNotFound', () async {
    final port = firestoreBackupLearningPort(FakeFirebaseFirestore());
    expect(
      await port.retry(testProfileId, ulidA),
      const CaptureResult.rejected(CaptureRejection.targetNotFound),
    );
  });

  group('restoredSettingsHistory', () {
    test('rebuilds the backup\'s own history for the lock gate', () {
      final h = restoredSettingsHistory(testProfileId, [
        _settings(1, DateTime.utc(2026), {
          'time_zone': 'Asia/Jerusalem',
          'in_israel': true,
        }),
        _settings(
          2,
          DateTime.utc(2026, 3),
          {'time_zone': 'America/New_York'},
          before: {'time_zone': 'Asia/Jerusalem'},
        ),
      ])!;
      expect(h.at(DateTime.utc(2026, 2)).timeZone, 'Asia/Jerusalem');
      expect(h.at(DateTime.utc(2026, 4)).timeZone, 'America/New_York');
    });

    test('a seed-only source (no settings history) holds its seed for all '
        'time', () {
      final h = restoredSettingsHistory(
        testProfileId,
        const [],
        seed: const {'time_zone': 'Asia/Jerusalem', 'in_israel': true},
      )!;
      expect(h.spans, hasLength(1));
      expect(h.at(DateTime.utc(2020)).timeZone, 'Asia/Jerusalem');
    });

    test('the seed is the state the history ends in', () {
      final h = restoredSettingsHistory(
        testProfileId,
        [
          _settings(1, DateTime.utc(2026), {'time_zone': 'Asia/Jerusalem'}),
          _settings(
            2,
            DateTime.utc(2026, 3),
            {'time_zone': 'America/New_York'},
            before: {'time_zone': 'Asia/Jerusalem'},
          ),
        ],
        seed: const {
          'time_zone': 'America/New_York',
          'latitude': 40.7,
          'longitude': -74.0,
        },
      )!;
      expect(h.at(DateTime.utc(2026, 2)).timeZone, 'Asia/Jerusalem');
      expect(h.at(DateTime.utc(2026, 4)).timeZone, 'America/New_York');
      // A field the history never logged is the seed's.
      expect(h.at(DateTime.utc(2026, 4)).latitude, 40.7);
    });

    test('is null without a time zone', () {
      expect(restoredSettingsHistory(testProfileId, const []), isNull);
    });
  });

  test('CompleteReadReady.isClean is what the port checks', () {
    expect(CompleteReadReady<int>(const []).isClean, isTrue);
  });
}
