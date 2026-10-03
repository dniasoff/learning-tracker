import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/repositories/backup_firestore_gateway.dart';
import 'package:learning_tracker/data/repositories/firestore_change_log_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_points_amount_reader.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_settings_reader.dart';
import 'package:learning_tracker/features/settings/data/repositories/backup_learning_sources.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import 'learner_state/fake_learning_commands.dart';

const testUid = 'backup-test-user';
const testProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const secondTestProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FB0';

/// The fixed instant every backup replay in these tests writes at.
final backupTestNow = DateTime.utc(2026, 9, 1, 10);

/// UTC settings for every profile: the lock gate needs a readable
/// settings history, and the fixture profiles carry none.
final class _UtcSettingsReader implements LearnerSettingsReader {
  const _UtcSettingsReader();

  @override
  Stream<LearnerSettings> watch(LearnerScope scope) => Stream.value(
    LearnerSettings(profileId: scope.profileId, timeZone: 'UTC'),
  );
}

/// The production [CommandsBackupLearningPort] over the real Firestore
/// repositories on [firestore], with an always-open gate and a fixed
/// clock, so a restore replays end to end through `LearningCommands`.
/// The destination's stored settings, read once from its learner profile
/// doc: a profile never seeded (no `time_zone`) fails the read, as the
/// production reader does.
final class StoredSettingsReader implements LearnerSettingsReader {
  /// Reads [firestore].
  const StoredSettingsReader(this.firestore);

  /// The store.
  final FakeFirebaseFirestore firestore;

  @override
  Stream<LearnerSettings> watch(LearnerScope scope) => Stream.fromFuture(
    firestore
        .doc('users/${scope.ownerUid}/learner_profiles/${scope.profileId}')
        .get()
        .then(
          (doc) => LearnerSettings.fromProfileDoc(
            scope.profileId,
            doc.data() ?? const {},
          ),
        ),
  );
}

CommandsBackupLearningPort firestoreBackupLearningPort(
  FakeFirebaseFirestore firestore, {
  String uid = testUid,
  LearnerSettingsReader settings = const _UtcSettingsReader(),
}) {
  final changeLog = FirestoreChangeLogRepository(firestore: firestore);
  final events = FirestoreLearningEventRepository(firestore: firestore);
  return CommandsBackupLearningPort(
    ownerUid: uid,
    actor: Actor(uid: uid, role: ActorRole.parent, displayName: ''),
    subTracks: FirestoreSubTrackRepository(firestore: firestore),
    changeLog: changeLog,
    reader: changeLog,
    settings: settings,
    events: events,
    writePort: events,
    points: FirestorePointsAmountReader(firestore: firestore),
    records: GatewayBackupRecordWritePort(backupFirestoreGatewayFor(firestore)),
    failureReporter: RecordingLearningFailureReporter(),
    clock: () => backupTestNow,
    newUlid: newUlid,
    gate: FakeCaptureGate.open(),
  );
}

DataExportImportService backupService(
  FakeFirebaseFirestore firestore, {
  String uid = testUid,
  String appVersion = '1.0.0-test',
  LearnerSettingsReader settings = const _UtcSettingsReader(),
}) => DataExportImportService(
  firestore: firestore,
  learning: firestoreBackupLearningPort(
    firestore,
    uid: uid,
    settings: settings,
  ),
  uid: uid,
  appVersionFetcher: () async => appVersion,
);

Future<Map<String, dynamic>> exportedMap(
  DataExportImportService service,
) async => jsonDecode(await service.exportData()) as Map<String, dynamic>;

Map<String, dynamic> profileFrom(
  Map<String, dynamic> payload,
  String profileId,
) {
  final profiles = (payload['profiles'] as List).cast<Map<String, dynamic>>();
  return profiles.singleWhere((profile) => profile['id'] == profileId);
}

List<Map<String, dynamic>> collectionDocuments(
  Map<String, dynamic> profile,
  String collectionName,
) => ((profile['collections'] as Map<String, dynamic>)[collectionName] as List)
    .cast<Map<String, dynamic>>();

Map<String, dynamic> documentData(Map<String, dynamic> document) =>
    document['data'] as Map<String, dynamic>;
