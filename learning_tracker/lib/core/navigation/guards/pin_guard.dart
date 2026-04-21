import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/services/pin_service.dart';

/// Abstract base class for PIN-protected route guards.
///
/// Subclasses provide a dialog prompt function. The guard checks whether a
/// parent PIN is set; if no PIN has been configured it pushes the setup
/// screen. Otherwise it prompts the user and allows access only on
/// successful verification.
abstract class PinGuard extends AutoRouteGuard {
  PinGuard({required this.pinService, required this.promptForPin});

  final PinService pinService;

  /// Opens a UI prompt asking the user to enter their PIN.
  ///
  /// Returns the entered PIN string, or `null` if the user cancelled.
  final Future<String?> Function() promptForPin;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final hasPinSet = await pinService.hasParentPin();

    if (!hasPinSet) {
      // No PIN configured — push the setup screen and await result.
      // If setup succeeds (pops with true), re-attempt navigation.
      final result = await router.push<bool>(const PinSetupRoute());
      resolver.next(result ?? false);
      return;
    }

    final enteredPin = await promptForPin();
    if (enteredPin == null) {
      // User cancelled the prompt.
      resolver.next(false);
      return;
    }

    try {
      final verified = await pinService.verifyParentPin(enteredPin);
      resolver.next(verified);
    } on PinLockoutException {
      resolver.next(false);
    }
  }
}
