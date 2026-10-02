import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';

final _log = AppLogger.instance;

/// Route guard of the city picker (`/sacred-time/city`, DNI-481 AC-3).
///
/// The picker writes the active learner's location, zone and Israel flag —
/// the account's future lock schedule — so opening it is an escalating
/// action from a child context (AUD-sacred_time-08). The Settings card and
/// the after-lock prompt challenge the Parent PIN before they push the
/// route, but the route is also reachable directly (a deep link), so the
/// gate lives here too:
///  * the device holder ([getSelectedProfileId]) is resolved; none, or an
///    unknown profile, is refused (fail closed);
///  * an adult holder, or a child holder with no Parent PIN, passes — the
///    same rule as the card's `sacredTimeLocationPinGuardRequiredProvider`;
///  * a child holder with a Parent PIN passes on a pending one-shot pass
///    for that profile ([consumeAccess], granted by the in-app flows that
///    just verified the PIN) or on a correct PIN now ([promptForPin]);
///    anything else is refused.
/// Any unexpected error refuses the navigation (no-lockout invariant: the
/// resolver is always completed).
class SacredTimeLocationGuard extends AutoRouteGuard {
  /// Creates the guard over its seams.
  SacredTimeLocationGuard({
    required String? Function() getSelectedProfileId,
    required Future<LearnerProfileEntity?> Function(String profileId)
    getProfileById,
    required Future<bool> Function(String profileId) hasProfilePin,
    required bool Function(String? profileId) consumeAccess,
    required Future<bool> Function(String profileId) promptForPin,
  }) : _getSelectedProfileId = getSelectedProfileId,
       _getProfileById = getProfileById,
       _hasProfilePin = hasProfilePin,
       _consumeAccess = consumeAccess,
       _promptForPin = promptForPin;

  final String? Function() _getSelectedProfileId;
  final Future<LearnerProfileEntity?> Function(String profileId)
  _getProfileById;
  final Future<bool> Function(String profileId) _hasProfilePin;
  final bool Function(String? profileId) _consumeAccess;
  final Future<bool> Function(String profileId) _promptForPin;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    try {
      final profileId = _getSelectedProfileId();
      // Used up on every navigation, allowed or not: a pass opens the
      // picker once.
      final passed = _consumeAccess(profileId);
      if (profileId == null) {
        resolver.next(false);
        return;
      }
      final profile = await _getProfileById(profileId);
      if (profile == null) {
        resolver.next(false);
        return;
      }
      if (profile.mode != ProfileMode.child ||
          !await _hasProfilePin(profileId)) {
        resolver.next(true);
        return;
      }
      if (passed) {
        resolver.next(true);
        return;
      }
      resolver.next(await _promptForPin(profileId));
    } catch (error, stack) {
      _log.error(
        event: 'sacred_time_location_guard_failed_closed',
        exception: error,
        stackTrace: stack,
      );
      if (!resolver.isResolved) resolver.next(false);
    }
  }
}
