import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_entry_machine.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_mode_dialog_frame.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/pin_flow_error_text.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows the redesigned parent PIN keypad, verifies against [profileId],
/// and returns `true` only when the PIN is correct. Returns `false` on cancel.
///
/// Fires [AnalyticsEvent.parentModeEntered] on success when [analytics] is
/// provided (Story 27.14, DNI-390).
///
/// [subtitle] overrides the default subtitle copy. Pass a context-appropriate
/// string (e.g. `l10n.pinDialogSubtitleSwitchProfile`) when the action is
/// something other than accessing parent settings.
Future<bool> showParentPinVerificationDialog(
  BuildContext context, {
  required String profileId,
  required PinService pinService,
  AnalyticsService? analytics,
  String? subtitle,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _ParentPinVerificationDialog(
      profileId: profileId,
      pinService: pinService,
      subtitle: subtitle,
    ),
  );
  final verified = result ?? false;
  if (verified && analytics != null) {
    // Story 27.14 (DNI-390): fire parent_mode_entered on successful
    // verification. PV-1: no profileId parameter — never a per-child
    // identifier in an analytics payload.
    unawaited(analytics.logParentModeEntered());
  }
  return verified;
}

/// Multi-step change PIN flow in the same modal style as verification.
Future<bool> showParentPinChangeDialog(
  BuildContext context, {
  required String profileId,
  required PinService pinService,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) =>
        _ParentPinChangeDialog(profileId: profileId, pinService: pinService),
  );
  return result ?? false;
}

// --- Design tokens (match product spec: navy, gray, light surfaces) ---------

Color _pinNavy(BuildContext context) => context.colors.brandInk;
Color _pinKeyFill(BuildContext context) => context.colors.brandCreamSoft;
const Color _pinDotEmpty = Color(0xFFE8EBF0);
const Color _pinDotInner = Color(0xFFC9D0DA);

// --- Verification -----------------------------------------------------------

class _ParentPinVerificationDialog extends StatefulWidget {
  const _ParentPinVerificationDialog({
    required this.profileId,
    required this.pinService,
    this.subtitle,
  });

  final String profileId;
  final PinService pinService;

  /// Overrides the default subtitle copy. When null, falls back to
  /// [AppLocalizations.enterParentPinSubtitle].
  final String? subtitle;

  @override
  State<_ParentPinVerificationDialog> createState() =>
      _ParentPinVerificationDialogState();
}

class _ParentPinVerificationDialogState
    extends State<_ParentPinVerificationDialog> {
  // AUD-profiles-06: digit-buffer/busy/lockout transitions now live in one
  // shared implementation (PinEntryMachine) instead of being hand-rolled
  // again in this dialog.
  late final PinEntryMachine _machine = PinEntryMachine(
    pinService: () => widget.pinService,
    profileId: () => widget.profileId,
    onStateChanged: _onMachineStateChanged,
    isActive: () => mounted,
    initialMode: PinFlowMode.verify,
  );

  void _onMachineStateChanged(PinFlowState state) {
    if (!mounted) return;
    if (state.completed) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {});
  }

  void _cancel() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = _machine.state;
    return PinKeypadDialogFrame(
      title: l10n.enterParentPin,
      subtitle: widget.subtitle ?? l10n.enterParentPinSubtitle,
      digits: state.digits,
      errorMessage: resolvePinFlowErrorText(state.error, l10n),
      lockedOut: state.lockedOut,
      lockoutMinutes: state.lockoutMinutes,
      busy: state.busy,
      onClose: _cancel,
      onDigit: _machine.appendDigit,
      onBackspace: _machine.backspace,
      onCancel: _cancel,
    );
  }
}

// --- Change PIN --------------------------------------------------------------

class _ParentPinChangeDialog extends StatefulWidget {
  const _ParentPinChangeDialog({
    required this.profileId,
    required this.pinService,
  });

  final String profileId;
  final PinService pinService;

  @override
  State<_ParentPinChangeDialog> createState() => _ParentPinChangeDialogState();
}

class _ParentPinChangeDialogState extends State<_ParentPinChangeDialog> {
  // AUD-profiles-06: same shared PinEntryMachine as verification/setup —
  // this dialog's confirm-step save previously had NO try/catch at all
  // around setProfilePin (an uncaught InvalidPinFormatException/ArgumentError
  // would have escaped as an unhandled Future error); it now gets the same
  // guarded save as every other mode for free.
  late final PinEntryMachine _machine = PinEntryMachine(
    pinService: () => widget.pinService,
    profileId: () => widget.profileId,
    onStateChanged: _onMachineStateChanged,
    isActive: () => mounted,
    initialMode: PinFlowMode.change,
  );

  void _onMachineStateChanged(PinFlowState state) {
    if (!mounted) return;
    if (state.completed) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pinChangedSuccessfully)));
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {});
  }

  String _title(PinFlowStep step, AppLocalizations l10n) => switch (step) {
    PinFlowStep.verifyCurrent => l10n.enterCurrentPin,
    PinFlowStep.enterNew => l10n.enterNewPin,
    PinFlowStep.confirm => l10n.confirmNewPin,
    PinFlowStep.done => l10n.changeParentPin,
  };

  String _subtitle(PinFlowStep step, AppLocalizations l10n) => switch (step) {
    // PP-12 fix: use change-flow subtitle, not the verify-gate subtitle.
    PinFlowStep.verifyCurrent => l10n.enterCurrentPinSubtitle,
    PinFlowStep.enterNew => l10n.enterNewPinSubtitle,
    PinFlowStep.confirm => l10n.confirmNewPinSubtitle,
    PinFlowStep.done => '',
  };

  void _cancel() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = _machine.state;
    return PinKeypadDialogFrame(
      title: _title(state.step, l10n),
      subtitle: _subtitle(state.step, l10n),
      digits: state.digits,
      errorMessage: resolvePinFlowErrorText(state.error, l10n),
      lockedOut: state.lockedOut,
      lockoutMinutes: state.lockoutMinutes,
      busy: state.busy,
      onClose: _cancel,
      onDigit: _machine.appendDigit,
      onBackspace: _machine.backspace,
      onCancel: _cancel,
    );
  }
}

// --- Keypad + dots (re-exported for parent PIN setup) ----------------------

/// Keypad and dot row in the same modal style as [parent_mode_dialog_frame].
class PinKeypadDialogFrame extends StatelessWidget {
  const PinKeypadDialogFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.digits,
    required this.errorMessage,
    required this.lockedOut,
    required this.lockoutMinutes,
    required this.busy,
    required this.onClose,
    required this.onDigit,
    required this.onBackspace,
    required this.onCancel,
    this.showCloseButton = true,
    this.showKeypadCancel = true,
  });

  final String title;
  final String subtitle;
  final String digits;
  final String? errorMessage;
  final bool lockedOut;
  final int lockoutMinutes;
  final bool busy;
  final VoidCallback onClose;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onCancel;
  final bool showCloseButton;
  final bool showKeypadCancel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onClose();
      },
      child: ParentModeDialogFrame(
        showCloseButton: showCloseButton,
        onClose: onClose,
        title: title,
        subtitle: subtitle,
        child: lockedOut
            ? _LockoutPanel(minutes: lockoutMinutes)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PinDotsRow(length: digits.length),
                  const SizedBox(height: 12),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (errorMessage != null) const SizedBox(height: 8),
                  _PinKeypad(
                    onDigit: onDigit,
                    onBackspace: onBackspace,
                    onCancel: onCancel,
                    busy: busy,
                    showCancel: showKeypadCancel,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PinDotsRow extends StatelessWidget {
  const _PinDotsRow({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? _pinNavy(context) : _pinDotEmpty,
              border: Border.all(
                color: filled
                    ? _pinNavy(context)
                    : _pinDotInner.withValues(alpha: 0.35),
              ),
            ),
            child: filled
                ? null
                : Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pinDotInner,
                      ),
                    ),
                  ),
          ),
        );
      }),
    );
  }
}

class _LockoutPanel extends StatelessWidget {
  const _LockoutPanel({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_clock, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            l10n.parentPinLockoutTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.parentPinLockoutBody(minutes),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onCancel,
    required this.busy,
    this.showCancel = true,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onCancel;
  final bool busy;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const spacing = 10.0;

    Widget digitBtn(String d) => Expanded(
      child: _KeypadChip(
        onTap: busy ? null : () => onDigit(d),
        child: Text(
          d,
          style: TextStyle(
            color: _pinNavy(context),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Row(
            children: [
              digitBtn('1'),
              const SizedBox(width: spacing),
              digitBtn('2'),
              const SizedBox(width: spacing),
              digitBtn('3'),
            ],
          ),
          const SizedBox(height: spacing),
          Row(
            children: [
              digitBtn('4'),
              const SizedBox(width: spacing),
              digitBtn('5'),
              const SizedBox(width: spacing),
              digitBtn('6'),
            ],
          ),
          const SizedBox(height: spacing),
          Row(
            children: [
              digitBtn('7'),
              const SizedBox(width: spacing),
              digitBtn('8'),
              const SizedBox(width: spacing),
              digitBtn('9'),
            ],
          ),
          const SizedBox(height: spacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showCancel)
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: _pinNavy(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              if (showCancel) const SizedBox(width: spacing),
              digitBtn('0'),
              const SizedBox(width: spacing),
              Expanded(
                child: _KeypadChip(
                  onTap: busy ? null : onBackspace,
                  child: Icon(
                    Icons.backspace_outlined,
                    color: Theme.of(context).colorScheme.error,
                    size: 24,
                    semanticLabel: l10n.pinBackspace,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadChip extends StatelessWidget {
  const _KeypadChip({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _pinKeyFill(context),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Register the key on tap-DOWN, not tap-up. `InkWell.onTap` only fires
        // when the pointer lifts within `kTouchSlop` (~18 logical px) of where
        // it landed; a fast keypad press on a real device routinely drifts past
        // that, so `onTap` silently rejects it (the tap recognizer treats the
        // drift as a drag) and the digit is dropped. On the Set/Confirm parent-
        // PIN keypad that surfaced as a false "PINs do not match" — the user's
        // first entry lost a digit, so the confirm entry could never match
        // (device-audit run-8, R3/input, device 5560). Firing on tap-down makes
        // each press drift-immune, the way a hardware/dialer keypad behaves,
        // while `InkWell` still owns the splash + enabled lifecycle (its
        // internal tap recognizer is wired whenever any tap callback — here
        // `onTapDown` — is non-null). `onTapDown: null` when [onTap] is null
        // keeps the busy/lockout disable behaviour identical.
        onTapDown: onTap == null ? null : (_) => onTap!(),
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(height: 52, child: Center(child: child)),
      ),
    );
  }
}
