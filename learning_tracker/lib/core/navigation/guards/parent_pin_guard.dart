import 'package:auto_route/auto_route.dart';

typedef PinVerificationChecker = bool Function();
typedef PinPromptTrigger = Future<bool> Function();

class ParentPinGuard extends AutoRouteGuard {
  final PinVerificationChecker _isPinVerified;
  final PinPromptTrigger _promptForPin;

  ParentPinGuard({
    required PinVerificationChecker isPinVerified,
    required PinPromptTrigger promptForPin,
  }) : _isPinVerified = isPinVerified,
       _promptForPin = promptForPin;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    if (_isPinVerified()) {
      resolver.next(true);
      return;
    }

    final verified = await _promptForPin();
    resolver.next(verified);
  }
}
