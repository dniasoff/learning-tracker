import 'package:learning_tracker/features/profiles/domain/services/pin_entry_machine.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Re-export so existing importers of this file keep seeing PinFlowMode /
// PinFlowStep / PinFlowState / PinFlowError without an extra import (AG-4
// dedup — these types have exactly one definition now: pin_entry_machine.dart's
// pure domain layer, AUD-profiles-06).
export 'package:learning_tracker/features/profiles/domain/services/pin_entry_machine.dart'
    show PinFlowError, PinFlowMode, PinFlowState, PinFlowStep;

part 'pin_flow_controller.g.dart';

// ---------------------------------------------------------------------------
// PinFlowController
// ---------------------------------------------------------------------------

/// Riverpod adapter around [PinEntryMachine] — owns state transitions for the
/// unified PIN flow.
///
/// AUD-profiles-06: this controller no longer implements the digit-buffer/
/// busy/lockout transitions itself. [PinEntryMachine] is the single shared
/// implementation; every setup/verify/change PIN-entry UI (this controller
/// behind the routed PinFlowScreen, and the three modal dialogs in
/// `presentation/widgets/`) constructs its own instance and forwards keypad
/// gestures into it, so a transition fix lands once and protects every
/// surface.
///
/// A single instance is shared across the lifetime of [PinFlowScreen]. Call
/// [reset] whenever the screen mounts so that the correct initial [PinFlowStep]
/// is set for the active [PinFlowMode].
///
/// Lockout state is read directly from [PinService] (E25/DNI-339) via the
/// machine; the controller surfaces `lockedOut` / `lockoutMinutes` into its
/// own state so that the UI can render the lockout panel without touching the
/// service again.
///
/// keepAlive: true — the screen mounts a persistent subscription for the
/// duration of the PIN flow. Auto-dispose would tear down state mid-flow when
/// there is a momentary gap between widget rebuilds.
// keepAlive: must survive momentary widget-tree gaps mid-flow, see the doc comment above.
@Riverpod(keepAlive: true)
class PinFlowController extends _$PinFlowController {
  late final PinEntryMachine _machine = PinEntryMachine(
    pinService: () => ref.read(pinServiceProvider),
    profileId: () => ref.read(selectedProfileIdProvider),
    onStateChanged: (s) => state = s,
    isActive: () => ref.mounted,
  );

  @override
  PinFlowState build() {
    // Default to verify mode; callers must call reset() on mount.
    // Reading _machine here (rather than lazily on first use) pins its
    // construction to this build() call, matching the state below.
    return _machine.state;
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
    _machine.reset(mode);
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
    _machine.reset(mode);
  }

  /// Append a single digit. Submits automatically when 4 digits are entered.
  void appendDigit(String d) => _machine.appendDigit(d);

  /// Remove the last digit.
  void backspace() => _machine.backspace();
}
