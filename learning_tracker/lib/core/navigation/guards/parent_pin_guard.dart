import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/services/pin_service.dart';

/// Route guard that protects parent-mode routes with a per-profile PIN.
///
/// Each child profile has its own 4-digit parent PIN — the guard resolves
/// the currently active profile via [getProfileId] and verifies against
/// that profile's stored hash. If no PIN is configured yet, the guard
/// pushes [PinSetupRoute] so the parent can set one and then re-attempts
/// navigation. If no active profile is selected, access is denied.
class ParentPinGuard extends AutoRouteGuard {
  ParentPinGuard({
    required this.pinService,
    required this.promptForPin,
    required this.getProfileId,
  });

  final PinService pinService;

  /// Opens a UI prompt where the user enters and verifies their PIN.
  /// Returns `true` if the PIN was correct, `false` if cancelled or wrong.
  final Future<bool> Function() promptForPin;

  /// Resolves the currently active profile id, or `null` if none selected.
  final int? Function() getProfileId;

  /// Profile id that successfully entered its PIN in the current session.
  /// Subsequent navigations to parent-mode routes for the same profile skip
  /// the prompt. Cleared via [lock] (e.g. on sign-out or leaving parent mode).
  int? _authenticatedProfileId;

  /// Invalidates the cached parent-mode session, forcing the next guarded
  /// navigation to prompt for the PIN again.
  void lock() {
    _authenticatedProfileId = null;
  }

  /// Marks [profileId] as authenticated for the current session. Call this
  /// from flows that verify the PIN outside the guard (e.g. PIN entry route)
  /// so subsequent guarded navigations don't re-prompt.
  void markAuthenticated(int profileId) {
    _authenticatedProfileId = profileId;
  }

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final profileId = getProfileId();
    if (profileId == null) {
      resolver.next(false);
      return;
    }

    if (_authenticatedProfileId == profileId) {
      resolver.next(true);
      return;
    }

    final hasPinSet = await pinService.hasProfilePin(profileId);
    if (!hasPinSet) {
      final result = await router.push<bool>(const PinSetupRoute());
      final ok = result ?? false;
      if (ok) _authenticatedProfileId = profileId;
      resolver.next(ok);
      return;
    }

    final verified = await promptForPin();
    if (verified) _authenticatedProfileId = profileId;
    resolver.next(verified);
  }
}
