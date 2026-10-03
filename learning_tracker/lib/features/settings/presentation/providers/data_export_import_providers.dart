import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/repositories/backup_firestore_gateway.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/settings/data/repositories/backup_learning_sources.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The backup service is resolved from the active authenticated account.
///
/// The widget consumes this provider rather than reaching into the Firebase
/// handle directly, preserving the presentation/data boundary and leaving a
/// simple override seam for widget tests.
final dataExportImportServiceProvider =
    FutureProvider<DataExportImportService?>((ref) async {
      final session = await ref.watch(backupFirestoreGatewayProvider.future);
      if (session == null) return null;
      final learning = await ref.watch(backupLearningPortProvider.future);
      if (learning == null) return null;
      return DataExportImportService(
        gateway: session.gateway,
        learning: learning,
        uid: session.uid,
        clock: ref.read(localDayClockProvider),
      );
    });

/// The AD-49 learning half of the backup (DNI-482): sub-tracks read
/// through `SubTrackRepository`, and each restored profile replayed
/// through its own owner `LearningCommands`, written as the signed-in
/// parent. Null while the account is not ready.
final backupLearningPortProvider = FutureProvider<BackupLearningPort?>((
  ref,
) async {
  final session = await ref.watch(backupFirestoreGatewayProvider.future);
  final authUid = await ref.watch(activeAuthUidProvider.future);
  final subTracks = await ref.watch(subTrackRepositoryProvider.future);
  final changeLog = await ref.watch(changeLogRepositoryProvider.future);
  final reader = await ref.watch(governedDocReaderProvider.future);
  final settings = await ref.watch(learnerSettingsReaderProvider.future);
  final events = await ref.watch(learningEventRepositoryProvider.future);
  final writePort = await ref.watch(learningWritePortProvider.future);
  final points = await ref.watch(pointsAmountReaderProvider.future);
  if (session == null ||
      authUid == null ||
      subTracks == null ||
      changeLog == null ||
      reader == null ||
      settings == null ||
      events == null ||
      writePort == null ||
      points == null) {
    return null;
  }
  return CommandsBackupLearningPort(
    ownerUid: session.uid,
    // Backup restore lives in the parent settings area: an owner write.
    actor: Actor(uid: authUid, role: ActorRole.parent, displayName: ''),
    subTracks: subTracks,
    changeLog: changeLog,
    reader: reader,
    settings: settings,
    events: events,
    writePort: writePort,
    points: points,
    records: GatewayBackupRecordWritePort(session.gateway),
    failureReporter: ref.watch(learningFailureReporterProvider),
    clock: ref.watch(learningCommandClockProvider),
    newUlid: newUlid,
    gate: ref.watch(captureGateProvider),
  );
}, retry: (retryCount, error) => null);

/// File delivery is separate from JSON generation so export tests can verify
/// the service call without invoking a platform share sheet.
abstract interface class BackupFileDelivery {
  Future<void> share(String json);
}

final backupFileDeliveryProvider = Provider<BackupFileDelivery>(
  (ref) => const _SharePlusBackupFileDelivery(),
);

final class _SharePlusBackupFileDelivery implements BackupFileDelivery {
  const _SharePlusBackupFileDelivery();

  @override
  Future<void> share(String json) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/learning_tracker_backup.json');
    await file.writeAsString(json, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
    );
  }
}
