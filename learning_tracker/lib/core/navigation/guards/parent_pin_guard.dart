import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';

/// Route guard that protects parent-mode routes with a PIN.
///
/// Delegates all guard logic to [PinGuard].  If no parent PIN has been
/// configured, access is allowed so the user can set one in settings.
class ParentPinGuard extends PinGuard {
  ParentPinGuard({
    required super.pinService,
    required super.promptForPin,
  });

  @override
  String get pinType => 'parent';
}
