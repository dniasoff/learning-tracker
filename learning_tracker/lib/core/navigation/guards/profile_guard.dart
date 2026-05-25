import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';

final _log = AppLogger.instance;

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
    // Check how many profiles exist (we need this list both to validate an
    // already-selected id and to auto-select / redirect when nothing is
    // selected). Per-account autoincrement IDs collide across DBs, so a
    // selected id from a previous account can point at a *different* profile
    // (or nothing) in the now-active DB. Always validate against the current
    // DB before short-circuiting on a non-null selection (R1o-C2).
    final profiles = await _getDatabase().profileDao.getProfilesByAccount(
      _getAccountId(),
    );

    // If a profile is already selected, only proceed when that id actually
    // exists in the current account's DB. A stale id that survived an account
    // switch (selectedProfileIdProvider is keepAlive) would otherwise short-
    // circuit the guard and surface the wrong profile.
    final selectedId = _getSelectedProfileId();
    if (selectedId != null) {
      final exists = profiles.any((p) => p.id == selectedId);
      if (exists) {
        _log.debug(
          event: 'profile_guard_already_selected',
          fields: {'profileId': selectedId},
        );
        resolver.next();
        return;
      }
      // Stale selection — fall through to re-resolve (auto-select single,
      // or redirect to the picker).
      _log.info(
        event: 'profile_guard_stale_selection_revalidating',
        fields: {'staleProfileId': selectedId, 'profileCount': profiles.length},
      );
    }

    _log.info(
      event: 'profile_guard_profiles_fetched',
      fields: {'profileCount': profiles.length},
    );

    if (profiles.isEmpty) {
      // An account must always have at least one profile. Zero profiles
      // means either a fresh cloud sign-in where sync hasn't populated
      // yet, or a user whose profiles were removed — route them to the
      // picker so they can add one, never let them into AppShell.
      _log.info(event: 'profile_guard_no_profiles_redirecting');
      unawaited(router.replace(const ProfilePickerRoute()));
      resolver.next(false);
      return;
    }

    if (profiles.length == 1) {
      // Auto-select the single profile
      _log.info(
        event: 'profile_guard_single_profile_auto_selecting',
        fields: {'profileId': profiles.first.id},
      );
      _setSelectedProfileId(profiles.first.id);
      resolver.next();
      return;
    }

    // 2+ profiles, none selected → redirect to picker
    _log.info(
      event: 'profile_guard_multiple_profiles_redirecting',
      fields: {'profileCount': profiles.length},
    );
    unawaited(router.replace(const ProfilePickerRoute()));
    resolver.next(false);
  }
}
