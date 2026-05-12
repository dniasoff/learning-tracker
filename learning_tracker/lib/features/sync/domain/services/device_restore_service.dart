import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

/// Orchestrates full data restoration when a user signs in on a new device.
///
/// "New device" is detected via two signals:
///   1. The local database is empty (no completions and no user profile).
///   2. A persisted [restoreStatePrefKey] flag says the previous restore
///      attempt did not finish — even if the database isn't empty, we treat
///      the install as still-needs-restore so a partial pull can never leave
///      the user looking at half-restored data forever.
///
/// On restore() the flag is set to [_kStateInProgress] before any merge runs
/// and only flipped to [_kStateComplete] after every step succeeds. A crash,
/// sign-out, or aborted restore therefore rolls forward into a clean retry
/// on next launch instead of getting silently skipped.
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

  /// SharedPreferences key tracking restore lifecycle. Values: 'in_progress'
  /// while a restore is running and 'complete' on success. Absent when the
  /// device has never attempted a restore (== fresh install).
  static const String restoreStatePrefKey = 'device_restore_state';
  static const String _kStateInProgress = 'in_progress';
  static const String _kStateComplete = 'complete';

  final _statusController = StreamController<RestoreStatus>.broadcast();
  Stream<RestoreStatus> get statusStream => _statusController.stream;

  /// Emits exactly once after a successful restore so app-shell consumers
  /// can `ref.invalidate` the providers that may have rendered stale empty
  /// data while pull-on-launch was running.
  final _restoreCompletedController = StreamController<void>.broadcast();
  Stream<void> get restoreCompletedStream => _restoreCompletedController.stream;

  RestoreStatus _currentStatus = const RestoreStatus.idle();
  RestoreStatus get currentStatus => _currentStatus;

  bool _restoreCompleted = false;

  /// Returns true when the device looks "fresh" — either the database has
  /// no learner data yet OR the last restore attempt didn't reach a clean
  /// "complete" marker (a previous run may have written some rows before
  /// failing, in which case the empty-DB check would otherwise be a false
  /// negative and skip the retry).
  Future<bool> isNewDevice() async {
    final state = await _readRestoreState();
    if (state == _kStateInProgress) return true;

    // Valid Firebase session + no completions = signed in on a clean
    // install. This catches the reinstall case even if stale profile
    // rows exist locally (otherwise the empty-completions check would
    // be hidden by leftover SQLite state).
    User? firebaseUser;
    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase not initialized (e.g. test environment) — treat as no session.
    }
    final completions = await _database.completionDao.getAllCompletions();
    if (firebaseUser != null && completions.isEmpty) return true;

    if (completions.isNotEmpty) return false;

    final profiles = await _database.userProfileDao.getAllUserProfiles();
    return profiles.isEmpty;
  }

  Future<String?> _readRestoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(restoreStatePrefKey);
    } catch (e) {
      _logger.warning('DeviceRestoreService: read restore state failed: $e');
      return null;
    }
  }

  Future<void> _writeRestoreState(String state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(restoreStatePrefKey, state);
    } catch (e) {
      _logger.warning(
        'DeviceRestoreService: write restore state ($state) failed: $e',
      );
    }
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

      // Mark restore as started BEFORE writing any merged data. If we crash,
      // sign out, or close the app between this line and the success marker
      // below, the next launch's isNewDevice() will see 'in_progress' and
      // re-run a clean restore instead of trusting partial state.
      await _writeRestoreState(_kStateInProgress);

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

      // Step 2: Derive active curricula from Firestore curriculum_tracks.
      _updateStatus(
        const RestoreStatus.restoring(
          phase: 'Loading curricula...',
          completedSteps: 1,
          totalSteps: totalSteps,
        ),
      );
      final allTracks = await _firestoreDataSource.fetchCurriculumTracks();
      final activeCurriculaKeys = allTracks
          .where((t) => t['is_active'] == true)
          .map((t) => t['curriculum_id'] as String?)
          .whereType<String>()
          .toSet();

      // Step 3: Re-import bundled content for active curricula
      _updateStatus(
        const RestoreStatus.restoring(
          phase: 'Importing content...',
          completedSteps: 2,
          totalSteps: totalSteps,
        ),
      );

      if (activeCurriculaKeys.isNotEmpty) {
        final curricula = activeCurriculaKeys
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
      await _writeRestoreState(_kStateComplete);
      _updateStatus(
        const RestoreStatus.complete(collectionsRestored: totalSteps),
      );
      // Tell every Riverpod surface that depends on profile/track/completion
      // data to re-fetch from the now-populated DB. Without this the dashboard
      // can render the empty pre-restore snapshot indefinitely.
      if (!_restoreCompletedController.isClosed) {
        _restoreCompletedController.add(null);
      }
      return true;
    } catch (e, stackTrace) {
      _logger.error('DeviceRestoreService: restore failed', e, stackTrace);
      // Leave the in-progress marker in place so the next launch retries.
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
    await _restoreCompletedController.close();
  }
}
