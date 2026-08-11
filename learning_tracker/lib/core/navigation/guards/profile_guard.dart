import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';

final _log = AppLogger.instance;

/// Route guard that redirects to the profile picker when 2+ profiles exist
/// and no profile has been selected yet.
///
/// When only 1 profile exists, it auto-selects that profile.
class ProfileGuard extends AutoRouteGuard {
  ProfileGuard({
    required Future<List<LearnerProfileEntity>> Function() getProfiles,
    required String? Function() getSelectedProfileId,
    required void Function(String profileId) setSelectedProfileId,
    required bool Function() isTutoredSession,
    required PageRouteInfo Function() profilePickerRoute,
  }) : _getProfiles = getProfiles,
       _getSelectedProfileId = getSelectedProfileId,
       _setSelectedProfileId = setSelectedProfileId,
       _isTutoredSession = isTutoredSession,
       _profilePickerRoute = profilePickerRoute;

  final Future<List<LearnerProfileEntity>> Function() _getProfiles;
  final String? Function() _getSelectedProfileId;
  final void Function(String profileId) _setSelectedProfileId;
  final bool Function() _isTutoredSession;

  /// Builds the [PageRouteInfo] to redirect to when 2+ profiles exist and
  /// none is selected. Injected by the caller (the app-layer router wiring)
  /// rather than imported here — `core/navigation/` must not depend on
  /// `app/router/` (AUD-core-navigation-01).
  final PageRouteInfo Function() _profilePickerRoute;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    // Fail-safe wrapper (no-lockout invariant): the profile read can throw —
    // a network hiccup, a disposed provider lambda. ProfileGuard is not a
    // security gate (the shell handles the no-profile state by jumping to
    // Settings), so on any unexpected error we fail OPEN.
    try {
      await _resolve(resolver, router);
    } catch (error, stack) {
      _log.error(
        event: 'profile_guard_failed_safe_allow',
        exception: error,
        stackTrace: stack,
      );
      if (!resolver.isResolved) resolver.next();
    }
  }

  Future<void> _resolve(NavigationResolver resolver, StackRouter router) async {
    // Tutored session: the active profile is the talmid's own profile,
    // resolved via the tutored providers — NOT selectedProfileIdProvider
    // (which stays null) and NOT one of the account's own profiles. Without
    // this short-circuit a pure tutor account (zero own profiles) would be
    // bounced to the picker. Allow navigation straight through.
    if (_isTutoredSession()) {
      _log.debug(event: 'profile_guard_tutored_session_allow');
      resolver.next();
      return;
    }

    final profiles = await _getProfiles();

    // If a profile is already selected, only proceed when that id actually
    // exists in the active account's profile list. A stale id that survived
    // an account switch (selectedProfileIdProvider is keepAlive) would
    // otherwise short-circuit the guard and surface the wrong profile.
    final selectedId = _getSelectedProfileId();
    if (selectedId != null) {
      final exists = profiles.any((p) => p.profileId == selectedId);
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
      // No own learner profiles. Allow navigation to AppShell — the shell
      // detects this state and jumps to the Settings tab so the user can
      // manage their account without being forced to create a learner
      // profile. Tutor-only adults in particular need this path.
      _log.info(event: 'profile_guard_no_profiles_allow_to_shell');
      resolver.next();
      return;
    }

    if (profiles.length == 1) {
      final profile = profiles.first;
      _log.info(
        event: 'profile_guard_single_profile_auto_selecting',
        fields: {'profileId': profile.profileId},
      );
      _setSelectedProfileId(profile.profileId);
      resolver.next();
      return;
    }

    // 2+ profiles, none selected → redirect to picker
    _log.info(
      event: 'profile_guard_multiple_profiles_redirecting',
      fields: {'profileCount': profiles.length},
    );
    unawaited(router.replace(_profilePickerRoute()));
    resolver.next(false);
  }
}
