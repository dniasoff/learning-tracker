import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';

/// Route guard that redirects to the restore screen on new-device sign-in.
///
/// A "new device" is detected by checking if the local database is empty
/// (no completions and no user profiles). If empty and user is authenticated,
/// the device needs a full data restore from Firestore before proceeding.
class RestoreGuard extends AutoRouteGuard {
  RestoreGuard({required UserDatabase database}) : _database = database;

  final UserDatabase _database;

  /// Cache the result so we only check once per session.
  bool? _isNewDevice;

  /// Mark restore as complete so guard stops redirecting.
  void markRestoreComplete() {
    _isNewDevice = false;
  }

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    if (_isNewDevice == false) {
      resolver.next();
      return;
    }

    final completions = await _database.completionDao.getAllCompletions();
    final profiles = await _database.userProfileDao.getAllUserProfiles();
    _isNewDevice = completions.isEmpty && profiles.isEmpty;

    if (_isNewDevice!) {
      unawaited(router.replace(const DeviceRestoreRoute()));
      resolver.next(false);
    } else {
      resolver.next();
    }
  }
}
