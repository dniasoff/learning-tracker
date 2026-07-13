import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_flow_machine.dart'
    show PinFlowMode, PinFlowStep;
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Re-export so existing importers of this file keep seeing PinFlowMode /
// PinFlowStep without an extra import (AG-4 dedup — these enums have exactly
// one definition now: pin_flow_machine.dart's pure domain layer).
export 'package:learning_tracker/features/profiles/domain/services/pin_flow_machine.dart'
    show PinFlowMode, PinFlowStep;

part 'pin_flow_controller.g.dart';

// ---------------------------------------------------------------------------
// PinFlowError
// ---------------------------------------------------------------------------

/// Closed set of user-facing error conditions the PIN flow can surface.
///
/// AUD-profiles-09 (EH-5/AX-2): replaces the previous free-text
/// `errorMessage: String?` field on [PinFlowState]. The old field carried raw
/// English sentinels (e.g. `'Incorrect PIN'`) that [PinFlowScreen] mapped back
/// to ARB strings via exact string matching with a silent fallback arm — a
/// coupling that had already drifted undetected once (a case matched a string
/// this controller never actually produced). Every value here MUST be
/// resolved to localized text via an EXHAUSTIVE switch in the presentation
/// layer (compiler-enforced, no default/fallback arm) so a new value here is
/// a compile error everywhere it isn't handled, not a silent raw-text leak.
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

/// Immutable snapshot of [PinFlowController] state.
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
    state = state.copyWith(digits: state.digits + d, error: null);
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
      error: null,
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
        error: _pinsDoNotMatch(),
        step: PinFlowStep.enterNew,
        firstPin: null,
        digits: '',
      );
      return;
    }

    if (profileId == null) {
      state = state.copyWith(
        error: _noActiveProfile(),
        step: PinFlowStep.enterNew,
        firstPin: null,
        digits: '',
      );
      return;
    }

    state = state.copyWith(busy: true, error: null);
    try {
      await pinService.setProfilePin(profileId, pin);
      // Clear digits immediately so the completion frame shows an empty
      // keypad instead of 4 filled dots while maybePop() is in-flight.
      state = state.copyWith(
        busy: false,
        completed: true,
        step: PinFlowStep.done,
        digits: '',
      );
    } on InvalidPinFormatException {
      // AUD-profiles-09: PinService's typed validation failure (see
      // AUD-onboarding-16) maps to a closed PinFlowError; the screen resolves
      // the user-facing text via AppLocalizations through an exhaustive
      // switch — the exception's dev-facing .message is never surfaced.
      state = state.copyWith(
        busy: false,
        error: PinFlowError.invalidPinFormat,
        step: PinFlowStep.enterNew,
        firstPin: null,
        digits: '',
      );
    } on ArgumentError catch (e, st) {
      // AUD-profiles-20: ArgumentError.message is typed Object? (dynamic),
      // not String — reading it with an unchecked `as String?` cast (the
      // previous code here) would throw a TypeError the moment any caller
      // constructed one with a non-String message (e.g.
      // ArgumentError.value(42, 'pin', 99)). Read it null-safely via
      // `?.toString()` purely for diagnostics; the user-facing state is the
      // typed, generic PinFlowError.unexpected — never the raw message.
      AppLogger.instance.warning(
        event: 'pin_flow_setup_unexpected_argument_error',
        fields: {'detail': e.message?.toString() ?? 'no message'},
        exception: e,
        stackTrace: st,
      );
      state = state.copyWith(
        busy: false,
        error: PinFlowError.unexpected,
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
      state = state.copyWith(error: _noActiveProfile(), digits: '');
      return;
    }

    switch (state.step) {
      case PinFlowStep.verifyCurrent:
        state = state.copyWith(busy: true, error: null);
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
              error: _incorrectPin(),
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
            error: _pinsDoNotMatch(),
            step: PinFlowStep.enterNew,
            firstPin: null,
            digits: '',
          );
          return;
        }
        state = state.copyWith(busy: true, error: null);
        await pinService.setProfilePin(profileId, pin);
        // Clear digits so the completion frame shows an empty keypad while
        // maybePop() is in-flight (same fix as _handleSetup).
        state = state.copyWith(
          busy: false,
          completed: true,
          step: PinFlowStep.done,
          digits: '',
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
      state = state.copyWith(error: _noActiveProfile(), digits: '');
      return;
    }

    state = state.copyWith(busy: true, error: null);
    try {
      final ok = await pinService.verifyProfilePin(profileId, pin);
      if (ok) {
        // Clear digits so the completion frame shows an empty keypad while
        // maybePop() is in-flight.
        state = state.copyWith(
          busy: false,
          completed: true,
          step: PinFlowStep.done,
          digits: '',
        );
      } else {
        state = state.copyWith(busy: false, error: _incorrectPin(), digits: '');
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
  // Error-code selectors (AUD-profiles-09).
  //
  // The controller has no BuildContext, so it can only select a typed
  // PinFlowError — never localized text. PinFlowScreen (which has
  // AppLocalizations) resolves each code to text via an exhaustive switch.
  // Tests can assert on these codes directly without needing a widget tree.
  // ------------------------------------------------------------------

  PinFlowError _incorrectPin() => PinFlowError.incorrectPin;
  PinFlowError _pinsDoNotMatch() => PinFlowError.pinsDoNotMatch;
  PinFlowError _noActiveProfile() => PinFlowError.noActiveProfile;
}
