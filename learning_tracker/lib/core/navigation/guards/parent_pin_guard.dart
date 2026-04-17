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

  /// Opens a UI prompt asking the user to enter their PIN. Returns the
  /// entered PIN string, or `null` if the user cancelled.
  final Future<String?> Function() promptForPin;

  /// Resolves the currently active profile id, or `null` if none selected.
  final int? Function() getProfileId;

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

    final hasPinSet = await pinService.hasProfilePin(profileId);
    if (!hasPinSet) {
      final result = await router.push<bool>(const PinSetupRoute());
      resolver.next(result ?? false);
      return;
    }

    final enteredPin = await promptForPin();
    if (enteredPin == null) {
      resolver.next(false);
      return;
    }

    try {
      final verified = await pinService.verifyProfilePin(
        profileId,
        enteredPin,
      );
      resolver.next(verified);
    } on PinLockoutException {
      resolver.next(false);
    }
  }
}
