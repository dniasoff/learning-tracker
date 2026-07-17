import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/logging/logger.dart';

final _log = AppLogger.instance;

/// Route guard that redirects to the restore screen on new-device sign-in.
///
/// A "new device" is detected by checking if the local database is empty
/// (no completions and no user profiles). If empty and user is authenticated,
/// the device needs a full data restore from Firestore before proceeding.
///
/// **DNI-190**: Skips entirely for local-only users (no cloud account).
/// Only activates when a Firebase account exists AND the local DB appears
/// empty, indicating a new-device scenario.
class RestoreGuard extends AutoRouteGuard {
  RestoreGuard({
    required UserDatabase Function() getDatabase,
    required bool Function() hasCloudAccount,
  }) : _getDatabase = getDatabase,
       _hasCloudAccount = hasCloudAccount;

  final UserDatabase Function() _getDatabase;
  final bool Function() _hasCloudAccount;

  /// Cache the result so we only check once per session.
  bool? _isNewDevice;

  /// Mark restore as complete so guard stops redirecting.
  void markRestoreComplete() {
    _isNewDevice = false;
  }

  /// Reset the new-device cache so the guard re-evaluates on the next
  /// navigation. Must be called on every account switch: after
  /// `markRestoreComplete()` sets `_isNewDevice = false`, a subsequent
  /// sign-in under a DIFFERENT cloud account (whose local DB is empty)
  /// would be silently skipped — never redirected to DeviceRestoreRoute.
  ///
  /// RESTORE-01: account-switch path in [AccountPickerScreen] calls this so
  /// each incoming account gets its own fresh restore check.
  void resetForNewSession() {
    _isNewDevice = null;
  }

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    // Fail-safe wrapper (no-lockout invariant): an unhandled throw from the DB
    // read (or the hasCloudAccount closure) would escape onNavigation and leave
    // AutoRoute's resolver completer un-completed forever — a navigation hang.
    // Restore is an optimisation (the user can also restore from Settings), so
    // on any unexpected error we fail OPEN and let navigation proceed.
    try {
      if (_isNewDevice == false) {
        _log.debug(event: 'restore_guard_already_checked_proceeding');
        resolver.next();
        return;
      }

      // Skip for local-only users — no cloud account means nothing to restore.
      if (!_hasCloudAccount()) {
        _log.debug(event: 'restore_guard_no_cloud_account_skipping');
        _isNewDevice = false;
        resolver.next();
        return;
      }

      final db = _getDatabase();
      final analytics = ParentAnalyticsRepositoryImpl(db);
      final completions = await analytics.getAllCompletions(
        scope: CrossProfileScope.syncRestore,
      );
      final profiles = await db.userProfileDao.getAllUserProfiles();
      _isNewDevice = completions.isEmpty && profiles.isEmpty;

      _log.info(
        event: 'restore_guard_new_device_check',
        fields: {
          'completionCount': completions.length,
          'userProfileCount': profiles.length,
          'isNewDevice': _isNewDevice,
        },
      );

      if (_isNewDevice!) {
        _log.info(event: 'restore_guard_redirecting_to_device_restore');
        unawaited(router.replace(const DeviceRestoreRoute()));
        resolver.next(false);
      } else {
        resolver.next();
      }
    } catch (error, stack) {
      _log.error(
        event: 'restore_guard_failed_safe_allow',
        exception: error,
        stackTrace: stack,
      );
      if (!resolver.isResolved) resolver.next();
    }
  }
}
