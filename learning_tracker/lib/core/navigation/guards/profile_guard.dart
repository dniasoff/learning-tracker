import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';

/// Route guard that redirects to the profile picker when 2+ profiles exist
/// and no profile has been selected yet.
///
/// When only 1 profile exists, it auto-selects that profile.
class ProfileGuard extends AutoRouteGuard {
  ProfileGuard({
    required UserDatabase Function() getDatabase,
    required int? Function() getSelectedProfileId,
    required void Function(int) setSelectedProfileId,
    required int Function() getAccountId,
  }) : _getDatabase = getDatabase,
       _getSelectedProfileId = getSelectedProfileId,
       _setSelectedProfileId = setSelectedProfileId,
       _getAccountId = getAccountId;

  final UserDatabase Function() _getDatabase;
  final int? Function() _getSelectedProfileId;
  final void Function(int) _setSelectedProfileId;
  final int Function() _getAccountId;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    // If a profile is already selected, proceed
    if (_getSelectedProfileId() != null) {
      resolver.next();
      return;
    }

    // Check how many profiles exist
    final profiles = await _getDatabase().profileDao.getProfilesByAccount(
      _getAccountId(),
    );

    if (profiles.isEmpty) {
      // An account must always have at least one profile. Zero profiles
      // means either a fresh cloud sign-in where sync hasn't populated
      // yet, or a user whose profiles were removed — route them to the
      // picker so they can add one, never let them into AppShell.
      unawaited(router.replace(const ProfilePickerRoute()));
      resolver.next(false);
      return;
    }

    if (profiles.length == 1) {
      // Auto-select the single profile
      _setSelectedProfileId(profiles.first.id);
      resolver.next();
      return;
    }

    // 2+ profiles, none selected → redirect to picker
    unawaited(router.replace(const ProfilePickerRoute()));
    resolver.next(false);
  }
}
