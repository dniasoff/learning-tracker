import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';

final _log = AppLogger.instance;

/// Route guard that redirects to the profile picker when 2+ profiles exist
/// and no profile has been selected yet.
///
/// When only 1 profile exists, it auto-selects that profile.
class ProfileGuard extends AutoRouteGuard {
  ProfileGuard({
    required UserDatabase Function() getDatabase,
    required int? Function() getSelectedProfileId,
    required void Function(int, {required String ulid}) setSelectedProfileId,
    required int Function() getAccountId,
    required bool Function() isTutoredSession,
    required PageRouteInfo Function() profilePickerRoute,
  }) : _getDatabase = getDatabase,
       _getSelectedProfileId = getSelectedProfileId,
       _setSelectedProfileId = setSelectedProfileId,
       _getAccountId = getAccountId,
       _isTutoredSession = isTutoredSession,
       _profilePickerRoute = profilePickerRoute;

  final UserDatabase Function() _getDatabase;
  final int? Function() _getSelectedProfileId;
  // P2-2: carries the auto-selected profile's ULID synchronously — this
  // guard already holds the full Drift row (`profiles.first`, with its
  // `.ulid`) at the call site below, so passing it through here keeps the
  // whole redirect decision synchronous (no extra DB round-trip, no
  // reintroducing the async gap `SelectedProfileId.select`'s own doc
  // comment specifically warns against for a route-guard caller).
  //
  // P2-10: `required String ulid`, not `String? ulid` — this closes the
  // seam a mid-phase review found: the raw Drift row's `ulid` column stays
  // nullable (`learner_profiles.dart`), so this class itself still resolves
  // a possibly-null value below, but the CALLBACK it hands that value to
  // can no longer accept null — the compiler now enforces that every
  // caller of `_setSelectedProfileId` has already turned a nullable Drift
  // read into a proven `String` before calling it, the same guarantee
  // `SelectedProfileId.select`'s own `required String ulid` gives its
  // callers. (This is a plain function-type assignment, not an `@override`,
  // so a closure that still *declares* `ulid` optional — e.g. an unused
  // no-op in a test double — remains assignable here: Dart only requires
  // the closure accept every call this field's type permits, and this
  // type's calls always supply `ulid`.)
  final void Function(int, {required String ulid}) _setSelectedProfileId;
  final int Function() _getAccountId;
  final bool Function() _isTutoredSession;

  /// Builds the [PageRouteInfo] to redirect to when 2+ profiles exist and
  /// none is selected. Injected by the caller (the app-layer router wiring)
  /// rather than imported here — `core/navigation/` must not depend on
  /// `app/router/` (AUD-core-navigation-01: this guard used to import
  /// `core/navigation/app_router.dart`, a re-export shim for
  /// `app/router/app_router.dart`, which itself imports this file — a real
  /// app→core→app import cycle).
  final PageRouteInfo Function() _profilePickerRoute;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    // Fail-safe wrapper (no-lockout invariant): the profile DB read
    // (getProfilesByAccount) can throw — a corrupt/locked DB, a disposed
    // provider lambda. An unhandled throw would escape onNavigation and leave
    // AutoRoute's resolver completer un-completed forever — a navigation hang.
    // ProfileGuard is not a security gate (the shell handles the no-profile
    // state by jumping to Settings), so on any unexpected error we fail OPEN.
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
    // Tutored session: the active profile is the synthetic talmid mirror,
    // resolved via the tutored providers — NOT selectedProfileIdProvider (which
    // stays null) and NOT one of the account's own profiles (the mirror is
    // excluded from getProfilesByAccount). Without this short-circuit a pure
    // tutor account (zero own profiles) would be bounced to the picker, and a
    // tutor with own profiles would be forced onto an own profile instead of
    // the talmid. Allow navigation straight through.
    if (_isTutoredSession()) {
      _log.debug(event: 'profile_guard_tutored_session_allow');
      resolver.next();
      return;
    }

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
      // No own learner profiles. Allow navigation to AppShell — the shell
      // detects this state and jumps to the Settings tab so the user can
      // manage their account (sign out, delete, device settings, etc.) without
      // being forced to create a learner profile.  Tutor-only adults in
      // particular need this path.
      _log.info(event: 'profile_guard_no_profiles_allow_to_shell');
      resolver.next();
      return;
    }

    if (profiles.length == 1) {
      // Auto-select the single profile.
      final profile = profiles.first;
      // P2-10: resolve-or-throw HERE, at the source of the nullability (the
      // raw Drift row), rather than deferring the check into whatever
      // closure `router_provider.dart` happens to wire up — mirrors
      // [ProfileModel.fromDriftRow]'s own enforcement (same message shape:
      // pre-P2-2 row, wipe and reseed) so both places a Drift row's `ulid`
      // gets trusted as an identity agree on what "not ready" means. A
      // throw here is caught by [onNavigation]'s own fail-open wrapper
      // above — this guard is explicitly not a security gate, so a legacy
      // null-ulid row fails OPEN (navigation proceeds, logged) rather than
      // crashing the app.
      final ulid = profile.ulid;
      if (ulid == null) {
        throw StateError(
          'ProfileGuard: profile ${profile.id} has no ulid — pre-P2-2 '
          'profile row with no ULID — wipe and reseed the device',
        );
      }
      _log.info(
        event: 'profile_guard_single_profile_auto_selecting',
        fields: {'profileId': profile.id},
      );
      _setSelectedProfileId(profile.id, ulid: ulid);
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
