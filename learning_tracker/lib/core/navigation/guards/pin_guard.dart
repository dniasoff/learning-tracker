import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/services/pin_service.dart';

/// Abstract base class for PIN-protected route guards.
///
/// Subclasses provide the specific [pinType] ('parent' or 'tutor') and a
/// dialog prompt function.  The guard checks whether a PIN is set; if no PIN
/// has been configured it allows access (the user should set one in settings).
/// Otherwise it prompts the user and allows access only on successful
/// verification.
abstract class PinGuard extends AutoRouteGuard {
  PinGuard({required this.pinService, required this.promptForPin});

  final PinService pinService;

  /// Opens a UI prompt asking the user to enter their PIN.
  ///
  /// Returns the entered PIN string, or `null` if the user cancelled.
  final Future<String?> Function() promptForPin;

  /// Identifies which PIN type this guard protects ('parent' or 'tutor').
  String get pinType;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final hasPinSet = pinType == 'parent'
        ? await pinService.hasParentPin()
        : await pinService.hasTutorPin();

    if (!hasPinSet) {
      // No PIN configured — redirect to the appropriate setup screen.
      final setupRoute = pinType == 'tutor'
          ? const TutorPinSetupRoute()
          : const PinSetupRoute();
      unawaited(router.replace(setupRoute));
      resolver.next(false);
      return;
    }

    final enteredPin = await promptForPin();
    if (enteredPin == null) {
      // User cancelled the prompt.
      resolver.next(false);
      return;
    }

    try {
      final verified = pinType == 'parent'
          ? await pinService.verifyParentPin(enteredPin)
          : await pinService.verifyTutorPin(enteredPin);
      resolver.next(verified);
    } on PinLockoutException {
      resolver.next(false);
    }
  }
}
