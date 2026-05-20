// PinFlowMachine — W4.11 pure domain state machine
//
// This file provides the pure domain state machine for PIN flows.
// It carries no Flutter or Riverpod dependencies — only Dart core.
//
// The thin Riverpod adapter (PinFlowController) in
// `features/profiles/presentation/providers/pin_flow_controller.dart`
// wraps this machine and exposes it as a StateNotifier.
//
// Export [PinService] so callers can import the whole domain layer from
// this single library entry point.

library pin_flow_machine;

export 'pin_service.dart';

// ── Machine states ──────────────────────────────────────────────────────────

/// Which PIN task the user is performing.
enum PinFlowMode {
  /// First-time or post-wipe PIN creation. Two steps: enter → confirm.
  setup,

  /// Change an existing PIN. Three steps: verify current → enter new → confirm.
  change,

  /// Verify the existing PIN to unlock a guarded route.
  verify,
}

/// Internal progress through the PIN flow.
enum PinFlowStep {
  /// Verifying the current PIN (change/verify modes).
  verifyCurrent,

  /// Entering the new PIN (setup and change modes).
  enterNew,

  /// Confirming the new PIN (setup and change modes).
  confirm,

  /// Terminal state — the flow is complete.
  done,
}

// ── Pure domain events ──────────────────────────────────────────────────────

/// Events dispatched into the machine.
sealed class PinFlowEvent {
  const PinFlowEvent();
}

/// User tapped a digit key.
final class PinDigitAdded extends PinFlowEvent {
  const PinDigitAdded(this.digit);
  final String digit;
}

/// User tapped the backspace key.
final class PinBackspace extends PinFlowEvent {
  const PinBackspace();
}

/// Caller requests a clean slate for [mode].
final class PinFlowReset extends PinFlowEvent {
  const PinFlowReset(this.mode);
  final PinFlowMode mode;
}

// ── Pure domain snapshot ────────────────────────────────────────────────────

/// Immutable snapshot of the PIN flow state machine.
///
/// The Riverpod adapter extends this with async fields (busy, lockedOut)
/// but the core state — mode, step, digits, firstPin, errorMessage — is
/// managed here in pure Dart.
class PinFlowSnapshot {
  const PinFlowSnapshot({
    required this.mode,
    required this.step,
    this.digits = '',
    this.firstPin,
    this.errorMessage,
  });

  final PinFlowMode mode;
  final PinFlowStep step;

  /// Digits accumulated so far for the current step (max 4).
  final String digits;

  /// The PIN entered in the first step of setup/change (held in memory until
  /// the confirm step; never persisted).
  final String? firstPin;

  /// Non-null when the last synchronous transition produced a user-visible error.
  final String? errorMessage;

  /// True when the machine is in its terminal state.
  bool get isDone => step == PinFlowStep.done;

  PinFlowSnapshot copyWith({
    PinFlowMode? mode,
    PinFlowStep? step,
    String? digits,
    Object? firstPin = _sentinel,
    Object? errorMessage = _sentinel,
  }) =>
      PinFlowSnapshot(
        mode: mode ?? this.mode,
        step: step ?? this.step,
        digits: digits ?? this.digits,
        firstPin: firstPin == _sentinel ? this.firstPin : firstPin as String?,
        errorMessage: errorMessage == _sentinel
            ? this.errorMessage
            : errorMessage as String?,
      );
}

const _sentinel = Object();

// ── Pure domain machine ─────────────────────────────────────────────────────

/// Pure domain state machine for the PIN entry flow.
///
/// Transitions are synchronous and deterministic. Async side-effects (bcrypt
/// verify / hash, secure storage writes) are the responsibility of the
/// Riverpod adapter ([PinFlowController]).
///
/// Usage:
///   1. Call [reset] to initialise the machine for a given [PinFlowMode].
///   2. Call [addDigit] / [backspace] for each key press.
///   3. When the machine signals [PinFlowStep.done], check [needsAsyncConfirm]:
///      - `needsAsyncConfirm == true` → four digits are ready; the adapter
///        must call the appropriate [PinService] method and then call
///        [transitionAfterAsync] with the result.
///      - `needsAsyncConfirm == false` → transition was purely synchronous
///        (mismatch, reset, etc.); read the new snapshot directly.
class PinFlowMachine {
  PinFlowSnapshot _state = const PinFlowSnapshot(
    mode: PinFlowMode.verify,
    step: PinFlowStep.verifyCurrent,
  );

  PinFlowSnapshot get state => _state;

  /// True immediately after four digits are entered and an async side-effect
  /// (bcrypt verify/hash) must run before the next transition.
  bool get needsAsyncConfirm => _pendingPin != null;

  /// The four-digit PIN awaiting async confirmation (non-null only when
  /// [needsAsyncConfirm] is true).
  String? get pendingPin => _pendingPin;

  String? _pendingPin;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Reset the machine for [mode].
  void reset(PinFlowMode mode) {
    _pendingPin = null;
    _state = PinFlowSnapshot(mode: mode, step: _initialStep(mode));
  }

  /// Append [digit] (0-9). Calling this when [needsAsyncConfirm] is true
  /// or the state is [PinFlowStep.done] is a no-op.
  void addDigit(String digit) {
    if (_pendingPin != null || _state.isDone) return;
    if (_state.digits.length >= 4) return;
    _state = _state.copyWith(
      digits: _state.digits + digit,
      errorMessage: null,
    );
    if (_state.digits.length == 4) {
      _onFourDigits();
    }
  }

  /// Remove the last digit. No-op when [needsAsyncConfirm] is true or the
  /// machine is done.
  void backspace() {
    if (_pendingPin != null || _state.isDone) return;
    if (_state.digits.isEmpty) return;
    _state = _state.copyWith(
      digits: _state.digits.substring(0, _state.digits.length - 1),
      errorMessage: null,
    );
  }

  /// Called by the adapter after the async side-effect completes.
  ///
  /// [success]: whether the async operation succeeded (bcrypt check returned
  ///   true; bcrypt hash + store succeeded).
  /// [errorMessage]: non-null on failure, null on success.
  void transitionAfterAsync({
    required bool success,
    String? errorMessage,
    bool lockedOut = false,
  }) {
    final pin = _pendingPin;
    _pendingPin = null;
    if (pin == null) return; // guard

    if (lockedOut) {
      _state = _state.copyWith(digits: '');
      return; // adapter will set its own lockedOut/lockoutMinutes state
    }

    switch (_state.mode) {
      case PinFlowMode.setup:
        _afterSetupAsync(pin, success, errorMessage);
      case PinFlowMode.change:
        _afterChangeAsync(pin, success, errorMessage);
      case PinFlowMode.verify:
        _afterVerifyAsync(success, errorMessage);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static PinFlowStep _initialStep(PinFlowMode mode) => switch (mode) {
        PinFlowMode.setup => PinFlowStep.enterNew,
        PinFlowMode.change || PinFlowMode.verify => PinFlowStep.verifyCurrent,
      };

  void _onFourDigits() {
    final pin = _state.digits;
    switch (_state.mode) {
      case PinFlowMode.setup:
        _onSetupFourDigits(pin);
      case PinFlowMode.change:
        _onChangeFourDigits(pin);
      case PinFlowMode.verify:
        // Needs async bcrypt verify.
        _pendingPin = pin;
        _state = _state.copyWith(digits: '');
    }
  }

  // Setup: enterNew → confirm (sync) or confirm + async save.
  void _onSetupFourDigits(String pin) {
    if (_state.step == PinFlowStep.enterNew) {
      // First entry: store and request confirmation.
      _state = _state.copyWith(
        firstPin: pin,
        step: PinFlowStep.confirm,
        digits: '',
      );
      return;
    }
    // Confirm step: validate match synchronously.
    if (pin != _state.firstPin) {
      _state = _state.copyWith(
        errorMessage: 'PINs do not match',
        step: PinFlowStep.enterNew,
        firstPin: null,
        digits: '',
      );
      return;
    }
    // Match confirmed — signal adapter to async-save.
    _pendingPin = pin;
    _state = _state.copyWith(digits: '');
  }

  // Change: verifyCurrent (async) → enterNew → confirm (async save).
  void _onChangeFourDigits(String pin) {
    switch (_state.step) {
      case PinFlowStep.verifyCurrent:
        _pendingPin = pin;
        _state = _state.copyWith(digits: '');
      case PinFlowStep.enterNew:
        _state = _state.copyWith(
          firstPin: pin,
          step: PinFlowStep.confirm,
          digits: '',
        );
      case PinFlowStep.confirm:
        if (pin != _state.firstPin) {
          _state = _state.copyWith(
            errorMessage: 'PINs do not match',
            step: PinFlowStep.enterNew,
            firstPin: null,
            digits: '',
          );
          return;
        }
        _pendingPin = pin;
        _state = _state.copyWith(digits: '');
      case PinFlowStep.done:
        break;
    }
  }

  void _afterSetupAsync(String pin, bool success, String? errorMessage) {
    if (!success) {
      _state = _state.copyWith(
        errorMessage: errorMessage ?? 'Failed to save PIN',
        step: PinFlowStep.enterNew,
        firstPin: null,
        digits: '',
      );
      return;
    }
    _state = _state.copyWith(step: PinFlowStep.done);
  }

  void _afterChangeAsync(String pin, bool success, String? errorMessage) {
    if (!success) {
      // Could be verify-current failure OR save failure.
      if (_state.step == PinFlowStep.verifyCurrent) {
        _state = _state.copyWith(
          errorMessage: errorMessage ?? 'Incorrect PIN',
          digits: '',
        );
      } else {
        _state = _state.copyWith(
          errorMessage: errorMessage ?? 'Failed to save PIN',
          step: PinFlowStep.enterNew,
          firstPin: null,
          digits: '',
        );
      }
      return;
    }
    // Success:
    if (_state.step == PinFlowStep.verifyCurrent) {
      _state = _state.copyWith(step: PinFlowStep.enterNew, digits: '');
    } else {
      _state = _state.copyWith(step: PinFlowStep.done);
    }
  }

  void _afterVerifyAsync(bool success, String? errorMessage) {
    if (!success) {
      _state = _state.copyWith(
        errorMessage: errorMessage ?? 'Incorrect PIN',
        digits: '',
      );
      return;
    }
    _state = _state.copyWith(step: PinFlowStep.done);
  }
}
