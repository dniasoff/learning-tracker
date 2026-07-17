// PinEntryMachine — the single implementation of the PIN-entry
// digit-buffer/busy/lockout transition logic (AUD-profiles-06).
//
// Before this file existed, the same 4-digit-entry + busy-lock + lockout
// state machine was hand-rolled independently in FOUR places:
//   - PinFlowController (setup mode) — presentation/providers/pin_flow_controller.dart
//   - _ParentPinSetupDialog          — presentation/widgets/parent_pin_setup_dialog.dart
//   - _ParentPinVerificationDialog   — presentation/widgets/parent_pin_keypad_dialog.dart
//   - _ParentPinChangeDialog         — presentation/widgets/parent_pin_keypad_dialog.dart
// A confirmed device bug (PP-1: rapid 5th-digit tap racing the enterNew ->
// confirm reset) was fixed in _ParentPinSetupDialog's specific ordering, but
// because the other copies re-derived the same transitions independently,
// the fix had no guarantee of applying to them — PinFlowController's own
// setup mode and every change-mode copy still carried the race.
//
// [PinEntryMachine] is the one place these transitions are implemented now.
// [PinFlowController] (the Riverpod adapter behind the routed PinFlowScreen)
// and the three modal PIN dialogs each construct their own instance and
// forward every keypad gesture into it, so a transition fix lands once and
// protects every surface.
//
// Pure Dart — no Flutter, no Riverpod. Callers own the widget/Riverpod
// lifecycle glue (setState / `state = ...`) via the [onStateChanged]
// callback and the [isActive] guard (SM-4: checked after every `await`
// before touching anything derived from the call site's lifecycle).
library pin_entry_machine;

import 'dart:async';

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_flow_machine.dart'
    show PinFlowMode, PinFlowStep;
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';

export 'package:learning_tracker/features/profiles/domain/services/pin_flow_machine.dart'
    show PinFlowMode, PinFlowStep;

/// The [PinFlowStep] a fresh [PinEntryMachine]/[PinFlowState] starts on for
/// [mode]. Single source of truth for every `reset`/initial-state call site.
PinFlowStep initialPinFlowStep(PinFlowMode mode) => switch (mode) {
  PinFlowMode.setup => PinFlowStep.enterNew,
  PinFlowMode.change => PinFlowStep.verifyCurrent,
  PinFlowMode.verify => PinFlowStep.verifyCurrent,
};

// ---------------------------------------------------------------------------
// PinFlowError
// ---------------------------------------------------------------------------

/// Closed set of user-facing error conditions the PIN flow can surface.
///
/// AUD-profiles-09 (EH-5/AX-2): every value here MUST be resolved to
/// localized text via an EXHAUSTIVE switch in the presentation layer
/// (`resolvePinFlowErrorText`, `pin_flow_error_text.dart`) — never surfaced
/// as a raw dev-facing exception message.
enum PinFlowError {
  /// The entered PIN did not match the stored hash.
  incorrectPin,

  /// The confirm-step PIN did not match the first entry.
  pinsDoNotMatch,

  /// No profile was selected/active when the flow needed one.
  noActiveProfile,

  /// [PinService] rejected the PIN as not exactly 4 numeric digits
  /// ([InvalidPinFormatException]). Not reachable via the keypad today (which
  /// only ever emits 4 numeric digits) but mapped explicitly rather than
  /// falling through, per the exhaustive-switch contract above.
  invalidPinFormat,

  /// Any other exception surfaced while saving/verifying a PIN — e.g. a stray
  /// [ArgumentError] (AUD-profiles-20's defensive catch). Kept distinct from
  /// [invalidPinFormat] because it is not an expected/typed PinService
  /// failure, just a "something unexpected happened, don't crash" fallback.
  unexpected,
}

// ---------------------------------------------------------------------------
// PinFlowState
// ---------------------------------------------------------------------------

/// Immutable snapshot of [PinEntryMachine] state.
class PinFlowState {
  const PinFlowState({
    required this.mode,
    required this.step,
    this.digits = '',
    this.firstPin,
    this.error,
    this.busy = false,
    this.lockedOut = false,
    this.lockoutMinutes = 0,
    this.completed = false,
  });

  final PinFlowMode mode;
  final PinFlowStep step;

  /// Digits accumulated so far for the current step (max 4).
  final String digits;

  /// The PIN entered in the first step of setup/change (held for confirm).
  final String? firstPin;

  /// Non-null when the last action produced an error. A closed enum
  /// (AUD-profiles-09) — presentation resolves it to text via
  /// `AppLocalizations` through an exhaustive switch; never free text.
  final PinFlowError? error;

  /// True while an async operation (bcrypt verify/hash) is in flight, OR
  /// (AUD-profiles-06 / PP-1) while a synchronous enterNew -> confirm digit
  /// -buffer reset is in its one-microtask settle window.
  final bool busy;

  /// True when the lockout threshold has been exceeded.
  final bool lockedOut;

  /// Remaining minutes of the active lockout (0 when not locked out).
  final int lockoutMinutes;

  /// True once the flow has successfully completed.
  final bool completed;

  PinFlowState copyWith({
    PinFlowMode? mode,
    PinFlowStep? step,
    String? digits,
    Object? firstPin = _sentinel,
    Object? error = _sentinel,
    bool? busy,
    bool? lockedOut,
    int? lockoutMinutes,
    bool? completed,
  }) {
    return PinFlowState(
      mode: mode ?? this.mode,
      step: step ?? this.step,
      digits: digits ?? this.digits,
      firstPin: firstPin == _sentinel ? this.firstPin : firstPin as String?,
      error: error == _sentinel ? this.error : error as PinFlowError?,
      busy: busy ?? this.busy,
      lockedOut: lockedOut ?? this.lockedOut,
      lockoutMinutes: lockoutMinutes ?? this.lockoutMinutes,
      completed: completed ?? this.completed,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// PinEntryMachine
// ---------------------------------------------------------------------------

bool _alwaysActive() => true;

/// Owns state transitions for one PIN-entry flow (setup, change, or verify).
///
/// Construct one instance per UI surface (a dialog's `State`, or the
/// Riverpod-backed [PinFlowController] behind the routed PinFlowScreen) and
/// forward every keypad gesture ([appendDigit] / [backspace]) into it. The
/// surface supplies:
///
///  * [pinService] — the backing bcrypt/secure-storage service.
///  * [profileId] — resolved fresh on every 4th-digit submit (a closure, not
///    a fixed value, so a Riverpod caller can read a possibly-changed
///    provider each time; a dialog closure simply returns its fixed
///    `widget.profileId`).
///  * [onStateChanged] — invoked synchronously with the new [PinFlowState]
///    on every transition; the caller republishes it (`setState`, Riverpod
///    `state = ...`).
///  * [isActive] — checked after every `await` before the machine emits
///    another state change (SM-4: mirrors `mounted` / `ref.mounted`) so a
///    disposed caller is never touched.
class PinEntryMachine {
  PinEntryMachine({
    required PinService Function() pinService,
    required int? Function() profileId,
    required void Function(PinFlowState state) onStateChanged,
    bool Function() isActive = _alwaysActive,
    PinFlowMode initialMode = PinFlowMode.verify,
  }) : _pinService = pinService,
       _profileId = profileId,
       _onStateChanged = onStateChanged,
       _isActive = isActive,
       _state = PinFlowState(
         mode: initialMode,
         step: initialPinFlowStep(initialMode),
       );

  /// Resolved fresh on every 4th-digit submit (not cached at construction) —
  /// a Riverpod caller passes `() => ref.read(pinServiceProvider)` so a
  /// long-lived (keepAlive) machine always uses the current provider value;
  /// a dialog closure simply returns its fixed `widget.pinService`.
  final PinService Function() _pinService;
  final int? Function() _profileId;
  final void Function(PinFlowState state) _onStateChanged;
  final bool Function() _isActive;

  PinFlowState _state;

  /// Current snapshot.
  PinFlowState get state => _state;

  void _emit(PinFlowState next) {
    _state = next;
    _onStateChanged(_state);
  }

  /// Reinitialises the machine for [mode], discarding any in-progress entry.
  void reset(PinFlowMode mode) {
    _emit(PinFlowState(mode: mode, step: initialPinFlowStep(mode)));
  }

  /// Append a single digit. Submits automatically when 4 digits are entered.
  void appendDigit(String d) {
    if (_state.busy || _state.lockedOut) return;
    if (_state.digits.length >= 4) return;
    _emit(_state.copyWith(digits: _state.digits + d, error: null));
    if (_state.digits.length == 4) {
      unawaited(_onFourDigits());
    }
  }

  /// Remove the last digit.
  void backspace() {
    if (_state.busy || _state.lockedOut) return;
    if (_state.digits.isEmpty) return;
    _emit(
      _state.copyWith(
        digits: _state.digits.substring(0, _state.digits.length - 1),
        error: null,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Internal — dispatch
  // ------------------------------------------------------------------

  Future<void> _onFourDigits() async {
    final pin = _state.digits;
    final profileId = _profileId();
    switch (_state.mode) {
      case PinFlowMode.setup:
        await _handleSetup(pin, profileId);
      case PinFlowMode.change:
        await _handleChange(pin, profileId);
      case PinFlowMode.verify:
        await _handleVerify(pin, profileId);
    }
  }

  /// Synchronous enterNew -> confirm advance, shared by setup and change.
  ///
  /// PP-1 fix (generalised — AUD-profiles-06): freezes the keypad
  /// (`busy: true`) for one microtask around the digit-buffer reset so a
  /// rapid extra tap queued right after the 4th digit cannot land as digit 1
  /// of the confirm buffer (it would otherwise see `digits == ''` and
  /// `busy == false` and be accepted). Released only after yielding one
  /// microtask, not immediately, so any tap already queued when the reset
  /// happened is guaranteed to observe `busy == true` and be swallowed by
  /// [appendDigit]'s guard.
  Future<void> _advanceToConfirm(String firstPin) async {
    _emit(
      _state.copyWith(
        busy: true,
        firstPin: firstPin,
        step: PinFlowStep.confirm,
        digits: '',
      ),
    );
    await Future<void>.microtask(() {});
    if (!_isActive()) return;
    _emit(_state.copyWith(busy: false));
  }

  // --- Setup (enter -> confirm -> save) ---

  Future<void> _handleSetup(String pin, int? profileId) async {
    if (_state.step == PinFlowStep.enterNew) {
      await _advanceToConfirm(pin);
      return;
    }
    await _handleConfirmAndSave(pin, profileId);
  }

  // --- Change (verifyCurrent -> enterNew -> confirm -> save) ---

  Future<void> _handleChange(String pin, int? profileId) async {
    if (profileId == null) {
      _emit(_state.copyWith(error: PinFlowError.noActiveProfile, digits: ''));
      return;
    }

    switch (_state.step) {
      case PinFlowStep.verifyCurrent:
        await _handleVerifyCurrentForChange(pin, profileId);
      case PinFlowStep.enterNew:
        await _advanceToConfirm(pin);
      case PinFlowStep.confirm:
        await _handleConfirmAndSave(pin, profileId);
      case PinFlowStep.done:
        break;
    }
  }

  Future<void> _handleVerifyCurrentForChange(String pin, int profileId) async {
    _emit(_state.copyWith(busy: true, error: null));
    try {
      final ok = await _pinService().verifyProfilePin(profileId, pin);
      // SM-4: the container/widget behind this machine can be disposed while
      // the verify call above is in flight.
      if (!_isActive()) return;
      if (ok) {
        _emit(
          _state.copyWith(busy: false, step: PinFlowStep.enterNew, digits: ''),
        );
      } else {
        _emit(
          _state.copyWith(
            busy: false,
            error: PinFlowError.incorrectPin,
            digits: '',
          ),
        );
      }
    } on PinLockoutException catch (e) {
      // SM-4: the await above may have raced a disposal.
      if (!_isActive()) return;
      _emit(
        _state.copyWith(
          busy: false,
          lockedOut: true,
          lockoutMinutes: e.remainingMinutes,
          digits: '',
        ),
      );
    }
  }

  /// Shared confirm-step validate+save for setup and change: a mismatched
  /// confirm resets to enterNew with an error; a match persists via
  /// [PinService.setProfilePin] and completes the flow.
  Future<void> _handleConfirmAndSave(String pin, int? profileId) async {
    if (pin != _state.firstPin) {
      _emit(
        _state.copyWith(
          error: PinFlowError.pinsDoNotMatch,
          step: PinFlowStep.enterNew,
          firstPin: null,
          digits: '',
        ),
      );
      return;
    }

    if (profileId == null) {
      _emit(
        _state.copyWith(
          error: PinFlowError.noActiveProfile,
          step: PinFlowStep.enterNew,
          firstPin: null,
          digits: '',
        ),
      );
      return;
    }

    _emit(_state.copyWith(busy: true, error: null));
    try {
      await _pinService().setProfilePin(profileId, pin);
      // SM-4: the container/widget behind this machine can be disposed while
      // the bcrypt/secure-storage write above is in flight (e.g. teardown).
      if (!_isActive()) return;
      // Clear digits immediately so the completion frame shows an empty
      // keypad instead of 4 filled dots while the caller's pop/dismiss is
      // in-flight.
      _emit(
        _state.copyWith(
          busy: false,
          completed: true,
          step: PinFlowStep.done,
          digits: '',
        ),
      );
    } on InvalidPinFormatException {
      // AUD-profiles-09: PinService's typed validation failure maps to a
      // closed PinFlowError; the presentation layer resolves the
      // user-facing text via AppLocalizations through an exhaustive switch —
      // the exception's dev-facing .message is never surfaced.
      if (!_isActive()) return;
      _emit(
        _state.copyWith(
          busy: false,
          error: PinFlowError.invalidPinFormat,
          step: PinFlowStep.enterNew,
          firstPin: null,
          digits: '',
        ),
      );
    } on ArgumentError catch (e, st) {
      // AUD-profiles-20: ArgumentError.message is typed Object? (dynamic),
      // not String — reading it with an unchecked `as String?` cast would
      // throw a TypeError the moment any caller constructed one with a
      // non-String message (e.g. ArgumentError.value(42, 'pin', 99)). Read it
      // null-safely via `?.toString()` purely for diagnostics; the
      // user-facing state is the typed, generic PinFlowError.unexpected —
      // never the raw message.
      AppLogger.instance.warning(
        event: 'pin_entry_${_state.mode.name}_unexpected_argument_error',
        fields: {'detail': e.message?.toString() ?? 'no message'},
        exception: e,
        stackTrace: st,
      );
      if (!_isActive()) return;
      _emit(
        _state.copyWith(
          busy: false,
          error: PinFlowError.unexpected,
          step: PinFlowStep.enterNew,
          firstPin: null,
          digits: '',
        ),
      );
    }
  }

  // --- Verify (single verify -> done) ---

  Future<void> _handleVerify(String pin, int? profileId) async {
    if (profileId == null) {
      _emit(_state.copyWith(error: PinFlowError.noActiveProfile, digits: ''));
      return;
    }

    _emit(_state.copyWith(busy: true, error: null));
    try {
      final ok = await _pinService().verifyProfilePin(profileId, pin);
      // SM-4: the container/widget behind this machine can be disposed while
      // the verify call above is in flight.
      if (!_isActive()) return;
      if (ok) {
        _emit(
          _state.copyWith(
            busy: false,
            completed: true,
            step: PinFlowStep.done,
            digits: '',
          ),
        );
      } else {
        _emit(
          _state.copyWith(
            busy: false,
            error: PinFlowError.incorrectPin,
            digits: '',
          ),
        );
      }
    } on PinLockoutException catch (e) {
      // SM-4: the await above may have raced a disposal.
      if (!_isActive()) return;
      _emit(
        _state.copyWith(
          busy: false,
          lockedOut: true,
          lockoutMinutes: e.remainingMinutes,
          digits: '',
        ),
      );
    }
  }
}
