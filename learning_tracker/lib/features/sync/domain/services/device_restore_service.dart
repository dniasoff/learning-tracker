import 'dart:async';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:talker/talker.dart';

/// Orchestrates full data restoration when a user signs in on a new device.
///
/// A "new device" is detected by checking whether the local database is empty
/// (no completions and no profile). When detected, this service:
/// 1. Pulls all user data from Firestore via [SyncEngine.pullOnLaunch]
/// 2. Fetches active curricula from Firestore
/// 3. Re-imports bundled content for each active curriculum
///
/// PINs are NOT restored — they are device-local only (FR99).
class DeviceRestoreService {
  DeviceRestoreService({
    required UserDatabase database,
    required SyncEngine syncEngine,
    required FirestoreDataSource firestoreDataSource,
    required CurriculumImportService curriculumImportService,
    required Talker logger,
  }) : _database = database,
       _syncEngine = syncEngine,
       _firestoreDataSource = firestoreDataSource,
       _curriculumImportService = curriculumImportService,
       _logger = logger;

  final UserDatabase _database;
  final SyncEngine _syncEngine;
  final FirestoreDataSource _firestoreDataSource;
  final CurriculumImportService _curriculumImportService;
  final Talker _logger;

  final _statusController = StreamController<RestoreStatus>.broadcast();
  Stream<RestoreStatus> get statusStream => _statusController.stream;

  RestoreStatus _currentStatus = const RestoreStatus.idle();
  RestoreStatus get currentStatus => _currentStatus;

  bool _restoreCompleted = false;

  /// Check if this is a new device (empty local database).
  Future<bool> isNewDevice() async {
    final completions = await _database.completionDao.getAllCompletions();
    if (completions.isNotEmpty) return false;

    final profiles = await _database.userProfileDao.getAllUserProfiles();
    return profiles.isEmpty;
  }

  /// Run the full restore process. Returns true if restore completed
  /// successfully, false if it failed or was not needed.
  ///
  /// When [bypassNewDeviceCheck] is true, skips the [isNewDevice] check.
  /// This is used by [retry] to avoid false negatives when a prior attempt
  /// partially wrote data to the database before failing.
  Future<bool> restore({bool bypassNewDeviceCheck = false}) async {
    const totalSteps = 3; // 1: pull data, 2: fetch curricula, 3: import content

    if (_restoreCompleted) return true;

    _updateStatus(const RestoreStatus.checking());

    try {
      if (!bypassNewDeviceCheck) {
        final needsRestore = await isNewDevice();
        if (!needsRestore) {
          _logger.info(
            'DeviceRestoreService: not a new device, skipping restore',
          );
          _updateStatus(const RestoreStatus.idle());
          return false;
        }
      }

      _logger.info(
        'DeviceRestoreService: new device detected, starting restore',
      );

      // Step 1: Pull all user data from Firestore
      _updateStatus(
        const RestoreStatus.restoring(
          phase: 'Restoring your data...',
          completedSteps: 0,
          totalSteps: totalSteps,
        ),
      );
      await _syncEngine.pullOnLaunch();

      // Check if pullOnLaunch failed (it catches errors internally)
      if (_syncEngine.currentStatus case SyncStatusError(:final message)) {
        throw Exception('Data pull failed: $message');
      }

      // Step 2: Fetch active curricula from Firestore
      _updateStatus(
        const RestoreStatus.restoring(
          phase: 'Loading curricula...',
          completedSteps: 1,
          totalSteps: totalSteps,
        ),
      );
      final activeCurricula = await _firestoreDataSource.fetchActiveCurricula();

      // Step 3: Re-import bundled content for active curricula
      _updateStatus(
        const RestoreStatus.restoring(
          phase: 'Importing content...',
          completedSteps: 2,
          totalSteps: totalSteps,
        ),
      );

      if (activeCurricula.isNotEmpty) {
        final curricula = activeCurricula
            .map(
              (key) => CurriculumId.values.cast<CurriculumId?>().firstWhere(
                (c) => c!.storageKey == key,
                orElse: () => null,
              ),
            )
            .whereType<CurriculumId>()
            .toList();

        if (curricula.isNotEmpty) {
          await for (final _ in _curriculumImportService.importAll(curricula)) {
            // Progress is tracked internally by CurriculumImportService
          }
        }
      }

      _logger.info('DeviceRestoreService: restore completed successfully');
      _restoreCompleted = true;
      _updateStatus(
        const RestoreStatus.complete(collectionsRestored: totalSteps),
      );
      return true;
    } catch (e, stackTrace) {
      _logger.error('DeviceRestoreService: restore failed', e, stackTrace);
      _updateStatus(RestoreStatus.error(message: e.toString()));
      return false;
    }
  }

  /// Retry a failed restore, bypassing the [isNewDevice] check to avoid
  /// false negatives from partially-written data.
  Future<bool> retry() => restore(bypassNewDeviceCheck: true);

  void _updateStatus(RestoreStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<void> dispose() async {
    await _statusController.close();
  }
}
