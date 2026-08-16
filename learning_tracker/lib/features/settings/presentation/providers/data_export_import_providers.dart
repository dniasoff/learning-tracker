import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
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
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return null;
      return DataExportImportService(
        firestore: handles.firestore,
        uid: handles.uid,
        clock: ref.read(localDayClockProvider),
      );
    });

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
