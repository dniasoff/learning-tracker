import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

/// A [BackupLearningPort] whose events and sub-tracks are scripted per
/// profile and
/// which records every replay.
final class _ScriptedLearningPort implements BackupLearningPort {
  final Map<String, List<SubTrack>> subTracks = {};
  final Map<String, List<LearningEvent>> events = {};
  final List<String> reads = [];
  final List<String> eventReads = [];
  final Map<String, BackupReplayInput> replays = {};

  @override
  Future<List<LearningEvent>> readLearningEvents(String profileId) async {
    eventReads.add(profileId);
    return events[profileId] ?? const [];
  }

  @override
  Future<List<SubTrack>> readSubTracks(String profileId) async {
    reads.add(profileId);
    return subTracks[profileId] ?? const [];
  }

  @override
  Future<BackupReplayResult> replay(
    String profileId,
    BackupReplayInput input,
  ) async {
    replays[profileId] = input;
    return const BackupReplayResult(result: CaptureResult.success());
  }

  @override
  Future<CaptureResult> retry(String profileId, String id) async =>
      const CaptureResult.success();
}

DataExportImportService _service(
  FakeFirebaseFirestore firestore,
  _ScriptedLearningPort learning,
) => DataExportImportService(
  firestore: firestore,
  learning: learning,
  uid: testUid,
  appVersionFetcher: () async => '1.0.0-test',
);

final _ended = SubTrack(
  id: engineUlid(901),
  curriculumId: 'mishnayos',
  name: 'Summer',
  type: SubTrackType.ongoing,
  windowStart: '2026-07-01',
  ratePerWeek: 3,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [],
  endedAt: DateTime.utc(2026, 8, 1),
  endReason: SubTrackEndReason.ended,
  lastChangeId: engineUlid(902),
);

void main() {
  test(
    'validateAndPreview reports backup metadata and document counts',
    () async {
      final firestore = FakeFirebaseFirestore();
      await seedAccount(firestore, uid: testUid);
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      final service = backupService(firestore, appVersion: '1.2.3');

      final preview = service.validateAndPreview(await service.exportData());
      expect(preview.userProfileCount, 1);
      expect(preview.appVersion, '1.2.3');
      expect(preview.exportedAt, isNot('unknown'));
      expect(preview.totalRecords, greaterThanOrEqualTo(2));
    },
  );

  test(
    'validation rejects missing document data and invalid profile ULIDs',
    () async {
      final service = backupService(FakeFirebaseFirestore());
      final invalid = {
        'version': DataExportImportService.formatVersion,
        'uid': testUid,
        'account': {'id': testUid, 'data': null},
        'profileSnapshot': <dynamic>[],
        'diagnosticLogs': <dynamic>[],
        'profiles': [
          {
            'id': 'too-short',
            'data': <String, dynamic>{},
            'collections': <String, dynamic>{},
          },
        ],
      };
      expect(
        () => service.validateAndPreview(jsonEncode(invalid)),
        throwsA(isA<ImportValidationException>()),
      );
    },
  );

  group('AC-1: the export is the AD-49 backup set', () {
    test('learning_events via LearningEventRepository, sub_tracks via '
        'SubTrackRepository, change_log, governed collections, non-event '
        'points and redemptions; no pts_ entry', () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      final profile = firestore
          .collection('users')
          .doc(testUid)
          .collection('learner_profiles')
          .doc(testProfileId);
      final event = engineLearn(1, 'Mishnah Berakhot 1:1');
      // Only the repository read is exported (AD-35 "Reads"): a raw row it
      // does not return never enters the backup.
      await profile.collection('learning_events').doc(ulidE).set({
        'kind': 'learn',
        'curriculum_id': 'mishnayos',
        'ref': 'Mishnah Berakhot 1:1',
        'source': 'main',
        'date_state': 'dated',
        'learned_on': '2026-09-01',
        'recorded_at': DateTime.utc(2026, 9, 1),
        'actor': parentActorMap,
      });
      await profile.collection('change_log').doc(ulidA).set({'x': 1});
      for (final governed in [
        'goals',
        'curriculum_tracks',
        'track_learning_order',
        'profile_programs',
        'study_day_configs',
        'stage_definitions',
        'curriculum_scopes',
      ]) {
        await profile.collection(governed).doc('mishnayos').set({'v': 1});
      }
      await profile.collection('points_ledger').doc('pts_${event.id}').set({
        'event_id': event.id,
        'delta': 10,
      });
      await profile.collection('points_ledger').doc(ulidB).set({
        'entry_kind': 'redemption_debit',
        'delta': -5,
      });
      // A legacy row carrying event_id under a ULID id is event-linked too.
      await profile.collection('points_ledger').doc(ulidC).set({
        'event_id': ulidD,
        'delta': 10,
      });
      await profile.collection('reward_redemptions').doc(ulidE).set({
        'status': 'fulfilled',
      });
      // Only the repository read is exported: a raw row it does not
      // return never enters the backup.
      await profile.collection('sub_tracks').doc(ulidA).set({'raw': true});

      final learning = _ScriptedLearningPort()
        ..events[testProfileId] = [event]
        ..subTracks[testProfileId] = [c0SubTrack(id: engineUlid(900)), _ended];
      final exported = profileFrom(
        jsonDecode(await _service(firestore, learning).exportData())
            as Map<String, dynamic>,
        testProfileId,
      );
      expect(learning.reads, [testProfileId]);
      expect(learning.eventReads, [testProfileId]);
      final exportedEvent = collectionDocuments(
        exported,
        'learning_events',
      ).single;
      expect(exportedEvent['id'], event.id);
      expect(documentData(exportedEvent)['ref'], event.ref);
      final subTracks = collectionDocuments(exported, 'sub_tracks');
      expect(subTracks.map((d) => d['id']), [engineUlid(900), engineUlid(901)]);
      expect(
        documentData(subTracks.last)['ended_at'],
        containsPair('__firestore_type', 'timestamp'),
      );
      expect(collectionDocuments(exported, 'change_log'), hasLength(1));
      for (final governed in DataExportImportService.governedCollections.keys) {
        expect(collectionDocuments(exported, governed), hasLength(1));
      }
      final points = collectionDocuments(exported, 'points_ledger');
      expect(points.map((d) => d['id']), [ulidB]);
      expect(collectionDocuments(exported, 'reward_redemptions'), hasLength(1));
      expect(jsonEncode(exported), isNot(contains('pts_')));
    });

    test('an empty learner exports every AD-49 collection empty', () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      final exported = profileFrom(
        jsonDecode(
              await _service(firestore, _ScriptedLearningPort()).exportData(),
            )
            as Map<String, dynamic>,
        testProfileId,
      );
      for (final name in DataExportImportService.profileCollectionNames) {
        expect(collectionDocuments(exported, name), isEmpty, reason: name);
      }
    });

    test('each profile exports its own sub-tracks, and a restore hands each '
        'profile its decoded record', () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      await seedProfile(
        firestore,
        uid: testUid,
        profileId: secondTestProfileId,
      );
      final learning = _ScriptedLearningPort()
        ..subTracks[testProfileId] = [_ended]
        ..subTracks[secondTestProfileId] = [c0SubTrack(id: engineUlid(900))];
      final service = _service(firestore, learning);
      final payload = await service.exportData();
      expect(learning.reads.toSet(), {testProfileId, secondTestProfileId});

      final report = await service.importData(payload);
      expect(report.saved, isTrue);
      expect(learning.replays[testProfileId]!.subTracks.single, _ended);
      expect(
        learning.replays[secondTestProfileId]!.subTracks.single.id,
        engineUlid(900),
      );
      expect(service.validateAndPreview(payload).subTrackCount, 2);
    });

    test(
      'a learner profile restore never writes governed settings keys',
      () async {
        final firestore = FakeFirebaseFirestore();
        await seedProfile(firestore, uid: testUid, profileId: testProfileId);
        final payload =
            jsonDecode(
                  await _service(
                    firestore,
                    _ScriptedLearningPort(),
                  ).exportData(),
                )
                as Map<String, dynamic>;
        final profile = profileFrom(payload, testProfileId);
        (profile['data'] as Map<String, dynamic>)
          ..['time_zone'] = 'Asia/Jerusalem'
          ..['last_change_id'] = ulidA;

        final target = FakeFirebaseFirestore();
        await target
            .collection('users')
            .doc(testUid)
            .collection('learner_profiles')
            .doc(testProfileId)
            .set({'time_zone': 'UTC', 'last_change_id': ulidB});
        await _service(
          target,
          _ScriptedLearningPort(),
        ).importData(jsonEncode(payload));
        final restored =
            (await target
                    .collection('users')
                    .doc(testUid)
                    .collection('learner_profiles')
                    .doc(testProfileId)
                    .get())
                .data()!;
        expect(restored['time_zone'], 'UTC');
        expect(restored['last_change_id'], ulidB);
        expect(restored['display_name'], 'Test User');
      },
    );

    test('an undecodable learning record fails validation', () async {
      final firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: testUid, profileId: testProfileId);
      final service = _service(firestore, _ScriptedLearningPort());
      final payload = jsonDecode(await service.exportData()) as Map;
      final profile = profileFrom(
        payload as Map<String, dynamic>,
        testProfileId,
      );
      (profile['collections'] as Map<String, dynamic>)['learning_events'] = [
        {
          'id': ulidA,
          'data': {'kind': 'learn'},
        },
      ];
      expect(
        () => service.validateAndPreview(jsonEncode(payload)),
        throwsA(isA<ImportValidationException>()),
      );
    });
  });
}
