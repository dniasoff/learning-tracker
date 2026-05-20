// SetParentPinUseCase — W4.11
//
// Pure domain use case for setting the parent PIN for a learner profile.
// Delegates to [PinService] for bcrypt hashing and secure storage.
//
// The use case enforces the invariant that a PIN must be exactly 4 numeric
// digits before dispatching to the service.  It does NOT own bcrypt or storage
// — those belong to [PinService].

import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';

/// Result of a set-parent-pin operation.
sealed class SetPinResult {
  const SetPinResult();
}

/// The PIN was persisted successfully.
final class SetPinSuccess extends SetPinResult {
  const SetPinSuccess();
}

/// The supplied PIN failed validation (wrong length or non-numeric).
final class SetPinValidationFailure extends SetPinResult {
  const SetPinValidationFailure({required this.message});
  final String message;
}

/// Use case: set (or replace) the parent PIN for a learner profile.
///
/// The caller supplies the [profileId] for per-profile PIN storage. The
/// global (non-profile) parent PIN path is used for accounts that have not
/// migrated to per-profile PINs; new paths always use profile-scoped storage.
class SetParentPinUseCase {
  const SetParentPinUseCase(this._pinService);

  final PinService _pinService;

  /// Set the parent PIN for [profileId] to [pin].
  ///
  /// Returns [SetPinSuccess] on success or [SetPinValidationFailure] if the
  /// PIN does not satisfy the 4-digit numeric invariant.
  Future<SetPinResult> call({
    required int profileId,
    required String pin,
  }) async {
    if (pin.length != 4 || !_isNumeric(pin)) {
      return const SetPinValidationFailure(
        message: 'PIN must be exactly 4 numeric digits.',
      );
    }
    await _pinService.setProfilePin(profileId, pin);
    return const SetPinSuccess();
  }

  bool _isNumeric(String s) => RegExp(r'^\d{4}$').hasMatch(s);
}
