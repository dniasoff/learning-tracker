import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';

/// Route guard that protects tutor-mode routes with a PIN.
///
/// Delegates all guard logic to [PinGuard].  If no tutor PIN has been
/// configured, access is allowed so the user can set one in settings.
class TutorPinGuard extends PinGuard {
  TutorPinGuard({
    required super.pinService,
    required super.promptForPin,
  });

  @override
  String get pinType => 'tutor';
}
