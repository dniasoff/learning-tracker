import 'dart:async' show unawaited;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/pin_flow_controller.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
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
  @override
  void initState() {
    super.initState();
    // Reset controller state whenever the screen first mounts so that
    // switching between modes doesn't carry stale step state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(pinFlowControllerProvider.notifier).reset(widget.mode);
    });
  }

  // ------------------------------------------------------------------
  // Keypad callbacks — forwarded to the controller
  // ------------------------------------------------------------------

  void _onDigit(String d) =>
      ref.read(pinFlowControllerProvider.notifier).appendDigit(d);

  void _onBackspace() =>
      ref.read(pinFlowControllerProvider.notifier).backspace();

  void _onCancel() => _popResult(false);

  // ------------------------------------------------------------------
  // Navigation helpers
  // ------------------------------------------------------------------

  Future<void> _popResult(bool ok) async {
    if (!mounted) return;
    await context.router.maybePop(ok);
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
        _handleCompletion(next);
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
              errorMessage: state.errorMessage,
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
