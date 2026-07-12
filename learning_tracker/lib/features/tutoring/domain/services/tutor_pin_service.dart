// TutorPinService — W4.30
//
// Thin domain wrapper around [PinService]'s tutor-PIN methods.
//
// The PinService (features/profiles/domain/services/pin_service.dart) already
// implements tutor-PIN storage under an independent namespace
// (`profile_{id}_tutor_pin_hash`) that is separate from the parent PIN
// namespace (`profile_{id}_parent_pin_hash`). This service is a domain-layer
// facade that:
//   1. Exposes a typed API specific to tutor auth (no parent PIN methods).
//   2. Returns sealed result types (no thrown exceptions) for UI convenience.
//   3. Keeps tutoring feature isolated from the profiles feature internals.

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';

// ── TutorPin VO ─────────────────────────────────────────────────────────────

/// Value object representing a valid (4-digit numeric) tutor PIN.
///
/// Construction validates the format. To attempt comparison against a stored
/// hash, use [TutorPinService] — this VO does not expose the raw digits
/// outside of construction to avoid accidental logging of PINs.
class TutorPin {
  TutorPin._(this._pin);

  final String _pin;

  /// Creates a [TutorPin] from [raw].
  ///
  /// Returns `null` if [raw] is not exactly 4 numeric digits.
  static TutorPin? tryCreate(String raw) {
    if (raw.length != 4 || !RegExp(r'^\d{4}$').hasMatch(raw)) return null;
    return TutorPin._(raw);
  }

  /// The raw 4-digit string. Only call this to pass to a storage service —
  /// do NOT log this value.
  String get rawDigits => _pin;

  @override
  String toString() => 'TutorPin(****)';
}

// ── Sealed results ──────────────────────────────────────────────────────────

sealed class TutorPinResult {
  const TutorPinResult();
}

final class TutorPinSuccess extends TutorPinResult {
  const TutorPinSuccess();
}

final class TutorPinIncorrect extends TutorPinResult {
  const TutorPinIncorrect();
}

final class TutorPinLockedOut extends TutorPinResult {
  const TutorPinLockedOut({required this.remainingMinutes});
  final int remainingMinutes;
}

/// AUD-tutoring-09 (EH-5): stable failure category for
/// [TutorPinValidationError]. A local format-validation guard must never
/// carry a pre-formatted human-readable message — an English sentence
/// renders raw and un-RTL-shaped to Hebrew-locale users. Presentation
/// resolves the user-facing string for each code through
/// `AppLocalizations`/ARB.
enum TutorPinValidationCode {
  /// The supplied PIN is not exactly 4 numeric digits.
  malformedPin,
}

final class TutorPinValidationError extends TutorPinResult {
  const TutorPinValidationError({required this.code});
  final TutorPinValidationCode code;
}

// ── TutorPinService ─────────────────────────────────────────────────────────

/// Domain service for tutor PIN operations.
///
/// Delegates to [PinService] using the tutor-specific storage namespace.
/// The tutor PIN namespace (`profile_{id}_tutor_pin_hash`) is INDEPENDENT
/// from the parent PIN namespace — authenticating as a tutor does not grant
/// parent access and vice versa.
class TutorPinService {
  const TutorPinService(this._pinService, {AnalyticsService? analytics})
    : _analytics = analytics;

  final PinService _pinService;
  // W7.11: optional analytics — fires tutor_pin_set on successful PIN set.
  final AnalyticsService? _analytics;

  /// Set the tutor PIN for [profileId].
  Future<TutorPinResult> setTutorPin({
    required int profileId,
    required String rawPin,
  }) async {
    final pin = TutorPin.tryCreate(rawPin);
    if (pin == null) {
      return const TutorPinValidationError(
        code: TutorPinValidationCode.malformedPin,
      );
    }
    await _pinService.setTutorPin(profileId, pin.rawDigits);
    // W7.11: fire tutor_pin_set after successful PIN storage.
    // AUD-core-analytics-01 (PV-1): profile_id dropped — the event firing at
    // all is the signal; no per-child identifier belongs in the payload.
    await _analytics?.logEvent(AnalyticsEvent.tutorPinSet);
    return const TutorPinSuccess();
  }

  /// Verify the tutor PIN for [profileId].
  Future<TutorPinResult> verifyTutorPin({
    required int profileId,
    required String rawPin,
  }) async {
    final pin = TutorPin.tryCreate(rawPin);
    if (pin == null) {
      return const TutorPinValidationError(
        code: TutorPinValidationCode.malformedPin,
      );
    }
    try {
      final ok = await _pinService.verifyTutorPin(profileId, pin.rawDigits);
      return ok ? const TutorPinSuccess() : const TutorPinIncorrect();
    } on PinLockoutException catch (e) {
      return TutorPinLockedOut(remainingMinutes: e.remainingMinutes);
    }
  }

  /// Returns true if a tutor PIN is set for [profileId].
  Future<bool> hasTutorPin(int profileId) => _pinService.hasTutorPin(profileId);

  /// Remove the tutor PIN and lockout state for [profileId].
  Future<void> clearTutorPin(int profileId) =>
      _pinService.clearTutorPin(profileId);

  /// Remaining lockout in minutes (0 if not locked).
  Future<int> lockoutRemainingMinutes(int profileId) =>
      _pinService.getTutorLockoutRemainingMinutes(profileId);
}
