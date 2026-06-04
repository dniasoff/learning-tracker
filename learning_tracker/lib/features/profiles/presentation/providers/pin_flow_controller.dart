import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pin_flow_controller.g.dart';

// ---------------------------------------------------------------------------
// PinFlowMode
// ---------------------------------------------------------------------------

/// Which PIN task the user is performing.
enum PinFlowMode {
  /// First-time or post-wipe PIN creation. Two steps: enter → confirm.
  setup,

  /// Change an existing PIN. Three steps: verify current → enter new → confirm.
  change,

  /// Verify the existing PIN to unlock a guarded route.
  verify,
}

// ---------------------------------------------------------------------------
// PinFlowStep
// ---------------------------------------------------------------------------

/// Internal progress through the flow.
enum PinFlowStep {
  /// Verifying the current PIN (change mode only).
  verifyCurrent,

  /// Entering the new PIN (setup and change modes).
  enterNew,

  /// Confirming the new PIN (setup and change modes).
  confirm,

  /// Terminal state — the flow is complete.
  done,
}

// ---------------------------------------------------------------------------
// PinFlowState
// ---------------------------------------------------------------------------

/// Immutable snapshot of [PinFlowController] state.
class PinFlowState {
  const PinFlowState({
    required this.mode,
    required this.step,
    this.digits = '',
    this.firstPin,
    this.errorMessage,
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

  /// Non-null when the last action produced an error.
  final String? errorMessage;

  /// True while an async operation (bcrypt verify/hash) is in flight.
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
    Object? errorMessage = _sentinel,
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
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      busy: busy ?? this.busy,
      lockedOut: lockedOut ?? this.lockedOut,
      lockoutMinutes: lockoutMinutes ?? this.lockoutMinutes,
      completed: completed ?? this.completed,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// PinFlowController
// ---------------------------------------------------------------------------

/// Riverpod notifier that owns state transitions for the unified PIN flow.
///
/// A single instance is shared across the lifetime of [PinFlowScreen]. Call
/// [reset] whenever the screen mounts so that the correct initial [PinFlowStep]
/// is set for the active [PinFlowMode].
///
/// Lockout state is read directly from [PinService] (E25/DNI-339); the
/// controller surfaces `lockedOut` / `lockoutMinutes` into its own state so
/// that the UI can render the lockout panel without touching the service again.
///
/// keepAlive: true — the screen mounts a persistent subscription for the
/// duration of the PIN flow. Auto-dispose would tear down state mid-flow when
/// there is a momentary gap between widget rebuilds.
@Riverpod(keepAlive: true)
class PinFlowController extends _$PinFlowController {
  @override
  PinFlowState build() {
    // Default to verify mode; callers must call reset() on mount.
    return const PinFlowState(
      mode: PinFlowMode.verify,
      step: PinFlowStep.verifyCurrent,
    );
  }

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  /// Identity of the screen mount this controller is currently initialised for,
  /// or `null` when it still holds the default `build()` state and has not yet
  /// been claimed by a mounted screen. Each [PinFlowScreen] mount passes a new
  /// token, so a re-pushed screen always triggers a fresh reset (clearing stale
  /// digits/step from a prior session) while in-progress entry for the CURRENT
  /// mount is never clobbered by a late-draining initState microtask.
  Object? _mountToken;

  /// Reinitialise state for [mode]. Direct reset used by tests and any caller
  /// that does not participate in the mount-token protocol.
  void reset(PinFlowMode mode) {
    _mountToken = null;
    state = PinFlowState(mode: mode, step: _initialStep(mode));
  }

  /// Claim the controller for a screen mount identified by [mountToken],
  /// resetting state for [mode] *exactly once per mount*.
  ///
  /// Both the screen's `initState` (deferred) and its keypad gesture handlers
  /// (synchronous, between frames) call this with the same per-mount [mountToken].
  /// The FIRST call for a given token does the fresh reset; subsequent calls are
  /// no-ops, so:
  ///
  ///  * A re-pushed screen (new token) always starts clean — clearing any stale
  ///    4-digit buffer left in the keepAlive controller (which otherwise tripped
  ///    the `digits.length >= 4` guard and froze the keypad).
  ///  * The first keypress synchronously establishes the correct [mode] even if
  ///    the deferred initState reset has not drained yet — so a setup keypress is
  ///    never routed through the stale default (verify) handler. That mis-routing,
  ///    followed by the late reset reverting the step, is what froze the setup
  ///    screen on "Set Parent PIN" after 4 digits.
  ///  * Because the late initState microtask re-invokes with the SAME token, it
  ///    no longer wipes digits the user has already entered for this mount.
  void initializeForMount(Object mountToken, PinFlowMode mode) {
    if (identical(_mountToken, mountToken)) return;
    _mountToken = mountToken;
    state = PinFlowState(mode: mode, step: _initialStep(mode));
  }

  /// Append a single digit. Submits automatically when 4 digits are entered.
  void appendDigit(String d) {
    if (state.busy || state.lockedOut) return;
    if (state.digits.length >= 4) return;
    state = state.copyWith(digits: state.digits + d, errorMessage: null);
    if (state.digits.length == 4) {
      _onFourDigits();
    }
  }

  /// Remove the last digit.
  void backspace() {
    if (state.busy || state.lockedOut) return;
    if (state.digits.isEmpty) return;
    state = state.copyWith(
      digits: state.digits.substring(0, state.digits.length - 1),
      errorMessage: null,
    );
  }

  // ------------------------------------------------------------------
  // Internal
  // ------------------------------------------------------------------

  static PinFlowStep _initialStep(PinFlowMode mode) {
    switch (mode) {
      case PinFlowMode.setup:
        return PinFlowStep.enterNew;
      case PinFlowMode.change:
        return PinFlowStep.verifyCurrent;
      case PinFlowMode.verify:
        return PinFlowStep.verifyCurrent;
    }
  }

  Future<void> _onFourDigits() async {
    final pin = state.digits;
    final pinService = ref.read(pinServiceProvider);
    final profileId = ref.read(selectedProfileIdProvider);

    switch (state.mode) {
      case PinFlowMode.setup:
        await _handleSetup(pin, profileId, pinService);
      case PinFlowMode.change:
        await _handleChange(pin, profileId, pinService);
      case PinFlowMode.verify:
        await _handleVerify(pin, profileId, pinService);
    }
  }

  // --- Setup (enter → confirm → save) ---

  Future<void> _handleSetup(
    String pin,
    int? profileId,
    PinService pinService,
  ) async {
    if (state.step == PinFlowStep.enterNew) {
      // First entry: store and ask to confirm.
      state = state.copyWith(
        firstPin: pin,
        step: PinFlowStep.confirm,
        digits: '',
      );
      return;
    }

    // Confirm step: validate match then persist.
    if (pin != state.firstPin) {
      state = state.copyWith(
        errorMessage: _pinsDoNotMatch(),
        step: PinFlowStep.enterNew,
        firstPin: null,
        digits: '',
      );
      return;
    }

    if (profileId == null) {
      state = state.copyWith(
        errorMessage: _noActiveProfile(),
        step: PinFlowStep.enterNew,
        firstPin: null,
        digits: '',
      );
      return;
    }

    state = state.copyWith(busy: true, errorMessage: null);
    try {
      await pinService.setProfilePin(profileId, pin);
      state = state.copyWith(
        busy: false,
        completed: true,
        step: PinFlowStep.done,
      );
    } on ArgumentError catch (e) {
      state = state.copyWith(
        busy: false,
        errorMessage: e.message as String?,
        step: PinFlowStep.enterNew,
        firstPin: null,
        digits: '',
      );
    }
  }

  // --- Change (verifyCurrent → enterNew → confirm → save) ---

  Future<void> _handleChange(
    String pin,
    int? profileId,
    PinService pinService,
  ) async {
    if (profileId == null) {
      state = state.copyWith(errorMessage: _noActiveProfile(), digits: '');
      return;
    }

    switch (state.step) {
      case PinFlowStep.verifyCurrent:
        state = state.copyWith(busy: true, errorMessage: null);
        try {
          final ok = await pinService.verifyProfilePin(profileId, pin);
          if (ok) {
            state = state.copyWith(
              busy: false,
              step: PinFlowStep.enterNew,
              digits: '',
            );
          } else {
            state = state.copyWith(
              busy: false,
              errorMessage: _incorrectPin(),
              digits: '',
            );
          }
        } on PinLockoutException catch (e) {
          state = state.copyWith(
            busy: false,
            lockedOut: true,
            lockoutMinutes: e.remainingMinutes,
            digits: '',
          );
        }

      case PinFlowStep.enterNew:
        state = state.copyWith(
          firstPin: pin,
          step: PinFlowStep.confirm,
          digits: '',
        );

      case PinFlowStep.confirm:
        if (pin != state.firstPin) {
          state = state.copyWith(
            errorMessage: _pinsDoNotMatch(),
            step: PinFlowStep.enterNew,
            firstPin: null,
            digits: '',
          );
          return;
        }
        state = state.copyWith(busy: true, errorMessage: null);
        await pinService.setProfilePin(profileId, pin);
        state = state.copyWith(
          busy: false,
          completed: true,
          step: PinFlowStep.done,
        );

      case PinFlowStep.done:
        break;
    }
  }

  // --- Verify (single verify → done) ---

  Future<void> _handleVerify(
    String pin,
    int? profileId,
    PinService pinService,
  ) async {
    if (profileId == null) {
      state = state.copyWith(errorMessage: _noActiveProfile(), digits: '');
      return;
    }

    state = state.copyWith(busy: true, errorMessage: null);
    try {
      final ok = await pinService.verifyProfilePin(profileId, pin);
      if (ok) {
        state = state.copyWith(
          busy: false,
          completed: true,
          step: PinFlowStep.done,
        );
      } else {
        state = state.copyWith(
          busy: false,
          errorMessage: _incorrectPin(),
          digits: '',
        );
      }
    } on PinLockoutException catch (e) {
      state = state.copyWith(
        busy: false,
        lockedOut: true,
        lockoutMinutes: e.remainingMinutes,
        digits: '',
      );
    }
  }

  // ------------------------------------------------------------------
  // Localisation-free fallbacks (controller cannot access BuildContext).
  // The screen passes the l10n values; here we just provide safe defaults
  // that tests can observe without needing a widget tree.
  // ------------------------------------------------------------------

  String _incorrectPin() => 'Incorrect PIN';
  String _pinsDoNotMatch() => 'PINs do not match';
  String _noActiveProfile() => 'No active profile';
}
