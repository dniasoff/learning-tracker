import 'dart:async' show unawaited;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/pin_flow_controller.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

export 'package:learning_tracker/features/profiles/presentation/providers/pin_flow_controller.dart'
    show PinFlowMode;

// ---------------------------------------------------------------------------
// Route
// ---------------------------------------------------------------------------

/// Unified PIN screen — one widget, three modes.
///
/// Replaces the former [PinSetupScreen], [PinChangeScreen], and
/// [PinEntryScreen] (deleted in DNI-364).
///
/// The [mode] parameter drives copy and logic:
/// - [PinFlowMode.setup]  — first-time or post-wipe PIN creation.
/// - [PinFlowMode.change] — verify current PIN, then choose a new one.
/// - [PinFlowMode.verify] — verify PIN and mark the guard session.
@RoutePage()
class PinFlowScreen extends ConsumerStatefulWidget {
  const PinFlowScreen({super.key, required this.mode});

  final PinFlowMode mode;

  @override
  ConsumerState<PinFlowScreen> createState() => _PinFlowScreenState();
}

class _PinFlowScreenState extends ConsumerState<PinFlowScreen> {
  /// Per-mount identity. A fresh object every time the screen mounts, so the
  /// keepAlive controller resets exactly once per mount (clearing any stale
  /// state from a prior session) without clobbering in-progress entry. See
  /// [PinFlowController.initializeForMount].
  final Object _mountToken = Object();

  @override
  void initState() {
    super.initState();
    // Reset the keepAlive controller for this mount so a re-pushed screen does
    // not carry stale step/digit state. The controller is keepAlive: true, so
    // without this the next mount would inherit the prior `digits` — and if
    // those were at the 4-digit cap, the `digits.length >= 4` guard in
    // appendDigit would swallow every keypress, freezing the keypad.
    //
    // This is scheduled as a microtask because Riverpod forbids mutating a
    // provider synchronously inside initState (it builds the tree). The
    // microtask is NOT guaranteed to drain before the user's first keypress on
    // device, so the keypad handlers also call initializeForMount synchronously
    // (see _onDigit). Passing the same _mountToken makes both paths idempotent:
    // whichever fires first does the reset; the other is a no-op and will not
    // wipe digits already entered for this mount.
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(pinFlowControllerProvider.notifier)
          .initializeForMount(_mountToken, widget.mode);
    });
  }

  // ------------------------------------------------------------------
  // Keypad callbacks — forwarded to the controller
  // ------------------------------------------------------------------

  void _onDigit(String d) {
    final controller = ref.read(pinFlowControllerProvider.notifier);
    // Synchronously guarantee the keepAlive controller is initialised for THIS
    // mount/mode before the digit is appended. The deferred initState reset is
    // not guaranteed to have drained before the first keypress on device;
    // without this, the first digits were routed through the stale default
    // (verify) mode and the setup screen froze on "Set Parent PIN". Gesture
    // callbacks run between frames, so this provider mutation is allowed.
    controller.initializeForMount(_mountToken, widget.mode);
    controller.appendDigit(d);
  }

  void _onBackspace() {
    final controller = ref.read(pinFlowControllerProvider.notifier);
    controller.initializeForMount(_mountToken, widget.mode);
    controller.backspace();
  }

  void _onCancel() => _popResult(false);

  // ------------------------------------------------------------------
  // Navigation helpers
  // ------------------------------------------------------------------

  Future<void> _popResult(bool ok) async {
    if (!mounted) return;
    // Use pop(result), NOT maybePop(result). The parent-mode pinGuard sets up a
    // first-time PIN by `await router.push<bool>(PinFlowSetupRoute)`, and that
    // future only resolves when the pushed route's RESULT completer is completed.
    // maybePop() removed the route (returned true) WITHOUT completing that
    // completer, so the guard hung: resolver.next() never fired, the parent hub
    // never showed, and the setup screen looped back to "Set Parent PIN" (the PIN
    // was saved, but the user was trapped). pop() completes the result completer.
    // (P1 found by on-device E2E audit, 2026-06.)
    context.router.pop(ok);
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(pinFlowControllerProvider);

    // React to side-effects that require navigation/auth.
    ref.listen(pinFlowControllerProvider, (prev, next) {
      if (next.completed && !(prev?.completed ?? false)) {
        // Defer completion to post-frame: _handleCompletion mutates another
        // provider (pinGuard.markAuthenticated) and pops this route, and doing
        // that synchronously inside the controller's state-change notification
        // navigates during a build/notify cycle. Post-frame lets the frame
        // settle first. (The pop itself uses pop() — see _popResult — which is
        // what actually delivers the result back to the guard's push<bool>().)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleCompletion(next);
        });
      }
    });

    // For setup mode show a full Scaffold with an info banner.
    if (widget.mode == PinFlowMode.setup) {
      return _SetupScaffold(
        state: state,
        l10n: l10n,
        onDigit: _onDigit,
        onBackspace: _onBackspace,
      );
    }

    // For change/verify modes: bare Scaffold that hosts the keypad dialog
    // frame inline (matches the previous full-screen modal behaviour).
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: widget.mode == PinFlowMode.change
              ? l10n.changeParentPin
              : l10n.enterParentPin,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: PinKeypadDialogFrame(
              title: _resolveTitle(state, l10n),
              subtitle: _resolveSubtitle(state, l10n),
              digits: state.digits,
              errorMessage: _resolveError(state.errorMessage, l10n),
              lockedOut: state.lockedOut,
              lockoutMinutes: state.lockoutMinutes,
              busy: state.busy,
              onClose: _onCancel,
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onCancel: _onCancel,
              showCloseButton: true,
              showKeypadCancel: true,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Copy helpers
  // ------------------------------------------------------------------

  /// Localizes the controller's error message. The PinFlowController is a
  /// Riverpod notifier with no BuildContext, so it emits stable English
  /// sentinels as fallbacks (see its `_incorrectPin`/`_pinsDoNotMatch`/… and
  /// PinFlowMachine's defaults). The screen — which HAS l10n — maps those
  /// sentinels to the localized string so a Hebrew device shows Hebrew (not raw
  /// English). Anything unrecognized (already-localized lockout copy, etc.) is
  /// passed through unchanged.
  String? _resolveError(String? raw, AppLocalizations l10n) => switch (raw) {
    null => null,
    'Incorrect PIN' => l10n.incorrectPin,
    'PINs do not match' => l10n.pinsDoNotMatch,
    'Failed to save PIN' => l10n.pinFailedToSave,
    'No active profile' => l10n.pinNoActiveProfile,
    _ => raw,
  };

  String _resolveTitle(PinFlowState state, AppLocalizations l10n) {
    switch (widget.mode) {
      case PinFlowMode.setup:
        return state.step == PinFlowStep.confirm
            ? l10n.confirmNewPin
            : l10n.setParentPinDialogTitle;
      case PinFlowMode.change:
        switch (state.step) {
          case PinFlowStep.verifyCurrent:
            return l10n.enterCurrentPin;
          case PinFlowStep.enterNew:
            return l10n.enterNewPin;
          case PinFlowStep.confirm:
            return l10n.confirmNewPin;
          case PinFlowStep.done:
            return l10n.changeParentPin;
        }
      case PinFlowMode.verify:
        return l10n.enterParentPin;
    }
  }

  String _resolveSubtitle(PinFlowState state, AppLocalizations l10n) {
    switch (widget.mode) {
      case PinFlowMode.setup:
        return state.step == PinFlowStep.confirm
            ? l10n.confirmNewPinSubtitle
            : l10n.pinFlowSetupSubtitle;
      case PinFlowMode.change:
        switch (state.step) {
          case PinFlowStep.verifyCurrent:
            return l10n.enterParentPinSubtitle;
          case PinFlowStep.enterNew:
            return l10n.enterNewPinSubtitle;
          case PinFlowStep.confirm:
            return l10n.confirmNewPinSubtitle;
          case PinFlowStep.done:
            return '';
        }
      case PinFlowMode.verify:
        return l10n.enterParentPinSubtitle;
    }
  }

  // ------------------------------------------------------------------
  // Completion side-effect
  // ------------------------------------------------------------------

  void _handleCompletion(PinFlowState state) {
    switch (widget.mode) {
      case PinFlowMode.setup:
        // Prime the guard session BEFORE popping so that ParentSettingsRoute's
        // pinGuard evaluation short-circuits on the re-evaluation triggered by
        // resolver.next(true). Without this, the guard sees _authenticatedScope
        // as null during the synchronous re-evaluation window and re-pushes the
        // setup screen, causing an infinite loop.
        final setupProfileId = ref.read(selectedProfileIdProvider);
        if (setupProfileId != null) {
          ref.read(routerProvider).pinGuard.markAuthenticated(setupProfileId);
        }
        unawaited(_popResult(true));
      case PinFlowMode.change:
        unawaited(_popResult(true));
      case PinFlowMode.verify:
        // Mark the guard session then pop.
        final profileId = ref.read(selectedProfileIdProvider);
        if (profileId != null) {
          ref.read(routerProvider).pinGuard.markAuthenticated(profileId);
        }
        unawaited(_popResult(true));
    }
  }
}

// ---------------------------------------------------------------------------
// Setup-mode full Scaffold (with device-local banner)
// ---------------------------------------------------------------------------

class _SetupScaffold extends StatelessWidget {
  const _SetupScaffold({
    required this.state,
    required this.l10n,
    required this.onDigit,
    required this.onBackspace,
  });

  final PinFlowState state;
  final AppLocalizations l10n;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: l10n.setParentPinDialogTitle)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Device-local PIN banner.
                  Container(
                    padding: const EdgeInsetsDirectional.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.pinFlowSetupDeviceLocalBanner,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PinKeypadDialogFrame(
                    title: state.step == PinFlowStep.confirm
                        ? l10n.confirmNewPin
                        : l10n.setParentPinDialogTitle,
                    subtitle: state.step == PinFlowStep.confirm
                        ? l10n.confirmNewPinSubtitle
                        : l10n.pinFlowSetupSubtitle,
                    digits: state.digits,
                    errorMessage: state.errorMessage,
                    lockedOut: false,
                    lockoutMinutes: 0,
                    busy: state.busy,
                    onClose: () {},
                    onDigit: onDigit,
                    onBackspace: onBackspace,
                    onCancel: () {},
                    showCloseButton: false,
                    showKeypadCancel: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route wrappers — three named routes that resolve to PinFlowScreen.
//
// AutoRoute requires a separate @RoutePage class per route name. These thin
// wrappers pass the correct [PinFlowMode] down so that the same UI drives
// setup, change, and verify flows.
// ---------------------------------------------------------------------------

/// Route for setting up a parent PIN for the first time (or after a wipe).
/// Path: /parent-mode/pin-setup
@RoutePage(name: 'PinFlowSetupRoute')
class PinFlowSetupScreen extends StatelessWidget {
  const PinFlowSetupScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PinFlowScreen(mode: PinFlowMode.setup);
}

/// Route for verifying the parent PIN to unlock a guarded route.
/// Path: /parent-mode/pin-entry
@RoutePage(name: 'PinFlowVerifyRoute')
class PinFlowVerifyScreen extends StatelessWidget {
  const PinFlowVerifyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PinFlowScreen(mode: PinFlowMode.verify);
}

/// Route for changing an existing parent PIN.
/// Path: /parent-mode/pin-change
@RoutePage(name: 'PinFlowChangeRoute')
class PinFlowChangeScreen extends StatelessWidget {
  const PinFlowChangeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PinFlowScreen(mode: PinFlowMode.change);
}
