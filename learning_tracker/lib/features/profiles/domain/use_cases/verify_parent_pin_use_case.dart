// VerifyParentPinUseCase — W4.11
//
// Pure domain use case for verifying the parent PIN for a learner profile.
// Delegates to [PinService] for bcrypt comparison and lockout management.
//
// The use case surfaces the result as a sealed type so callers do not need
// to catch exceptions.

import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';

/// Result of a verify-parent-pin operation.
sealed class VerifyPinResult {
  const VerifyPinResult();
}

/// The PIN was verified successfully.
final class VerifyPinSuccess extends VerifyPinResult {
  const VerifyPinSuccess();
}

/// The PIN was incorrect (no PIN is set, or hash mismatch).
final class VerifyPinIncorrect extends VerifyPinResult {
  const VerifyPinIncorrect();
}

/// The account is locked out due to excessive failed attempts.
final class VerifyPinLockedOut extends VerifyPinResult {
  const VerifyPinLockedOut({required this.remainingMinutes});

  /// Rounded-up remaining lockout time in minutes.
  final int remainingMinutes;
}

/// Use case: verify the parent PIN for a learner profile.
///
/// Returns a [VerifyPinResult] rather than throwing — callers can pattern-match
/// the sealed result without catching exceptions.
class VerifyParentPinUseCase {
  const VerifyParentPinUseCase(this._pinService);

  final PinService _pinService;

  /// Verify that [pin] matches the stored parent PIN for [profileId].
  ///
  /// Returns:
  ///   [VerifyPinSuccess]   — PIN is correct and the account is not locked out.
  ///   [VerifyPinIncorrect] — PIN is wrong (or no PIN has been set yet).
  ///   [VerifyPinLockedOut] — Too many failed attempts; [remainingMinutes] is
  ///                          the time until the lockout clears.
  Future<VerifyPinResult> call({
    required int profileId,
    required String pin,
  }) async {
    try {
      final ok = await _pinService.verifyProfilePin(profileId, pin);
      return ok ? const VerifyPinSuccess() : const VerifyPinIncorrect();
    } on PinLockoutException catch (e) {
      return VerifyPinLockedOut(remainingMinutes: e.remainingMinutes);
    }
  }
}
