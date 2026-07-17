import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_phase.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    required SyncOrchestrator syncOrchestrator,
    // Retained for call-site/API compatibility but intentionally unused:
    // restore runs before any profile is selected, so the active profile id is
    // the sentinel 0 here. Content re-import is therefore derived across ALL
    // restored profiles via [TrackDao.getAllActiveTracks], never scoped to a
    // single (possibly-0) profile id.
    // ignore: avoid_unused_constructor_parameters
    required int profileId,
    required bool isAuthenticated,
    required CurriculumImportService curriculumImportService,
    required AppLogger logger,
    AnalyticsService? analytics,
    // AUD-core-navigation-04 (SM-7): optional so tests can substitute a fake
    // [ParentAnalyticsRepository] without also faking the whole Drift
    // database it reads, mirroring the `local_data_upload_service.dart`
    // seam (AUD-sync-05). Production callers (restore_providers.dart) omit
    // this and get the real DB-backed implementation.
    ParentAnalyticsRepository? analyticsRepository,
  }) : _database = database,
       _syncOrchestrator = syncOrchestrator,
       _isAuthenticated = isAuthenticated,
       _curriculumImportService = curriculumImportService,
       _logger = logger,
       _analytics = analytics ?? const NullAnalyticsService(),
       _analyticsRepository =
           analyticsRepository ?? ParentAnalyticsRepositoryImpl(database);

  final UserDatabase _database;
  final SyncOrchestrator _syncOrchestrator;
  final bool _isAuthenticated;
  final CurriculumImportService _curriculumImportService;
  final AppLogger _logger;
  final AnalyticsService _analytics;
  final ParentAnalyticsRepository _analyticsRepository;

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
    // Already completed a restore — not a new device.
    if (state == _kStateComplete) return false;

    // Unauthenticated sessions cannot perform a cloud restore.
    if (!_isAuthenticated) return false;

    // Valid Firebase session + no completions = signed in on a clean
    // install. This catches the reinstall case even if stale profile
    // rows exist locally (otherwise the empty-completions check would
    // be hidden by leftover SQLite state).
    final completions = await _analyticsRepository.getAllCompletions(
      scope: CrossProfileScope.syncRestore,
    );
    if (completions.isEmpty) return true;

    return false;
  }

  Future<String?> _readRestoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(restoreStatePrefKey);
    } catch (e) {
      _logger.warning(event: 'device_restore_read_state_failed', exception: e);
      return null;
    }
  }

  Future<void> _writeRestoreState(String state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(restoreStatePrefKey, state);
    } catch (e) {
      _logger.warning(
        event: 'device_restore_write_state_failed',
        fields: {'state': state},
        exception: e,
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
          _logger.info(event: 'device_restore_skipped_not_new_device');
          _updateStatus(const RestoreStatus.idle());
          return false;
        }
      }

      _logger.info(event: 'device_restore_starting');

      // Mark restore as started BEFORE writing any merged data. If we crash,
      // sign out, or close the app between this line and the success marker
      // below, the next launch's isNewDevice() will see 'in_progress' and
      // re-run a clean restore instead of trusting partial state.
      await _writeRestoreState(_kStateInProgress);

      // Step 1: Pull all user data from Firestore
      _updateStatus(
        const RestoreStatus.restoring(
          phase: RestorePhase.pullingData,
          completedSteps: 0,
          totalSteps: totalSteps,
        ),
      );
      await _syncOrchestrator.pullOnLaunch();

      // Check if pullOnLaunch failed (it catches errors internally).
      // AUD-sync-01 (EH-5): propagate the orchestrator's own stable code
      // directly instead of formatting it into an Exception's text and
      // re-classifying it in the catch block below — that round trip is
      // exactly the "pre-formatted human message" EH-5 forbids.
      if (_syncOrchestrator.currentStatus case SyncStatusError(:final code)) {
        _updateStatus(RestoreStatus.error(code: code));
        return false;
      }

      // Step 2: Derive active curricula from the just-pulled local DB.
      //
      // `pullOnLaunch` above merged `curriculum_tracks` into Drift, so the
      // active set is already in `_database.trackDao`. Issuing a second
      // `fetchAll('curriculum_tracks')` against Firestore here would duplicate
      // a read that already landed on the wire.
      //
      // Read active tracks across ALL restored profiles, NOT just the active
      // profile id. Restore runs before any profile is selected, so the active
      // profile id is the sentinel 0 here (active_profile_provider returns 0
      // with no selection). Restored profiles keep their original non-zero ids,
      // so scoping to profile 0 would return an empty set and silently skip
      // content import for every restored profile.
      _updateStatus(
        const RestoreStatus.restoring(
          phase: RestorePhase.loadingCurricula,
          completedSteps: 1,
          totalSteps: totalSteps,
        ),
      );
      final localActiveTracks = await _database.trackDao.getAllActiveTracks();
      final activeCurriculaKeys = localActiveTracks
          .map((t) => t.curriculumId)
          .toSet();

      // Step 3: Re-import bundled content for active curricula
      _updateStatus(
        const RestoreStatus.restoring(
          phase: RestorePhase.importingContent,
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

      _logger.info(event: 'device_restore_completed');
      _restoreCompleted = true;
      await _writeRestoreState(_kStateComplete);
      _updateStatus(
        const RestoreStatus.complete(collectionsRestored: totalSteps),
      );
      // Story 27.14 (DNI-390): fire analytics event after successful restore.
      unawaited(_analytics.logCloudRestoreCompleted(stepsRestored: totalSteps));
      // Tell every Riverpod surface that depends on profile/track/completion
      // data to re-fetch from the now-populated DB. Without this the dashboard
      // can render the empty pre-restore snapshot indefinitely.
      if (!_restoreCompletedController.isClosed) {
        _restoreCompletedController.add(null);
      }
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        event: 'device_restore_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      // Leave the in-progress marker in place so the next launch retries.
      // AUD-sync-01 (EH-5): classify into a stable code — never a
      // pre-formatted human message. `pullOnLaunch` rethrows its original
      // (typed) exception, so this catch may see the same types the
      // orchestrator itself classifies; any other failure (e.g. content
      // re-import) falls back to `unknown`. `debugDetail` is retained for
      // logs/diagnostics only — it must never be rendered to the user.
      final code = switch (e) {
        TimeoutException() => SyncErrorCode.timeout,
        FirestorePermissionDeniedException() => SyncErrorCode.permissionDenied,
        _ => SyncErrorCode.unknown,
      };
      _updateStatus(RestoreStatus.error(code: code, debugDetail: e.toString()));
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
