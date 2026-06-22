import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_mode_dialog_frame.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows the redesigned parent PIN keypad, verifies against [profileId],
/// and returns `true` only when the PIN is correct. Returns `false` on cancel.
///
/// Fires [AnalyticsEvent.parentModeEntered] on success when [analytics] is
/// provided (Story 27.14, DNI-390).
Future<bool> showParentPinVerificationDialog(
  BuildContext context, {
  required int profileId,
  required PinService pinService,
  AnalyticsService? analytics,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _ParentPinVerificationDialog(
      profileId: profileId,
      pinService: pinService,
    ),
  );
  final verified = result ?? false;
  if (verified && analytics != null) {
    // Story 27.14 (DNI-390): fire parent_mode_entered on successful verification.
    unawaited(analytics.logParentModeEntered(profileId: profileId));
  }
  return verified;
}

/// Multi-step change PIN flow in the same modal style as verification.
Future<bool> showParentPinChangeDialog(
  BuildContext context, {
  required int profileId,
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

const Color _pinNavy = AppTheme.brandInk;
const Color _pinKeyFill = AppTheme.brandCreamSoft;
const Color _pinDotEmpty = Color(0xFFE8EBF0);
const Color _pinDotInner = Color(0xFFC9D0DA);

// --- Verification -----------------------------------------------------------

enum _ChangeStep { verifyCurrent, enterNew, confirmNew }

class _ParentPinVerificationDialog extends StatefulWidget {
  const _ParentPinVerificationDialog({
    required this.profileId,
    required this.pinService,
  });

  final int profileId;
  final PinService pinService;

  @override
  State<_ParentPinVerificationDialog> createState() =>
      _ParentPinVerificationDialogState();
}

class _ParentPinVerificationDialogState
    extends State<_ParentPinVerificationDialog> {
  String _digits = '';
  String? _errorMessage;
  bool _busy = false;
  bool _lockedOut = false;
  int _lockoutMinutes = 0;

  Future<void> _submitIfComplete() async {
    if (_digits.length != 4 || _busy || _lockedOut) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final ok = await widget.pinService.verifyProfilePin(
        widget.profileId,
        _digits,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _digits = '';
          _errorMessage = l10n.incorrectPin;
          _busy = false;
        });
      }
    } on PinLockoutException catch (e) {
      if (!mounted) return;
      setState(() {
        _lockedOut = true;
        _lockoutMinutes = e.remainingMinutes;
        _digits = '';
        _busy = false;
        _errorMessage = null;
      });
    }
  }

  void _appendDigit(String d) {
    if (_busy || _lockedOut) return;
    if (_digits.length >= 4) return;
    setState(() {
      _digits += d;
      _errorMessage = null;
    });
    if (_digits.length == 4) {
      _submitIfComplete();
    }
  }

  void _backspace() {
    if (_busy || _lockedOut) return;
    if (_digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _errorMessage = null;
    });
  }

  void _cancel() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PinKeypadDialogFrame(
      title: l10n.enterParentPin,
      subtitle: l10n.enterParentPinSubtitle,
      digits: _digits,
      errorMessage: _errorMessage,
      lockedOut: _lockedOut,
      lockoutMinutes: _lockoutMinutes,
      busy: _busy,
      onClose: _cancel,
      onDigit: _appendDigit,
      onBackspace: _backspace,
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

  final int profileId;
  final PinService pinService;

  @override
  State<_ParentPinChangeDialog> createState() => _ParentPinChangeDialogState();
}

class _ParentPinChangeDialogState extends State<_ParentPinChangeDialog> {
  _ChangeStep _step = _ChangeStep.verifyCurrent;
  String? _newPin;
  String _digits = '';
  String? _errorMessage;
  bool _busy = false;
  bool _lockedOut = false;
  int _lockoutMinutes = 0;

  String _title(AppLocalizations l10n) {
    switch (_step) {
      case _ChangeStep.verifyCurrent:
        return l10n.enterCurrentPin;
      case _ChangeStep.enterNew:
        return l10n.enterNewPin;
      case _ChangeStep.confirmNew:
        return l10n.confirmNewPin;
    }
  }

  String _subtitle(AppLocalizations l10n) {
    switch (_step) {
      case _ChangeStep.verifyCurrent:
        // PP-12 fix: use change-flow subtitle, not the verify-gate subtitle.
        return l10n.enterCurrentPinSubtitle;
      case _ChangeStep.enterNew:
        return l10n.enterNewPinSubtitle;
      case _ChangeStep.confirmNew:
        return l10n.confirmNewPinSubtitle;
    }
  }

  Future<void> _onFourDigits() async {
    if (_digits.length != 4 || _busy || _lockedOut) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final pin = _digits;
    final l10n = AppLocalizations.of(context)!;

    switch (_step) {
      case _ChangeStep.verifyCurrent:
        try {
          final ok = await widget.pinService.verifyProfilePin(
            widget.profileId,
            pin,
          );
          if (!mounted) return;
          if (ok) {
            setState(() {
              _step = _ChangeStep.enterNew;
              _digits = '';
              _busy = false;
            });
          } else {
            setState(() {
              _digits = '';
              _errorMessage = l10n.incorrectPin;
              _busy = false;
            });
          }
        } on PinLockoutException catch (e) {
          if (!mounted) return;
          setState(() {
            _lockedOut = true;
            _lockoutMinutes = e.remainingMinutes;
            _digits = '';
            _busy = false;
          });
        }
        return;

      case _ChangeStep.enterNew:
        setState(() {
          _newPin = pin;
          _step = _ChangeStep.confirmNew;
          _digits = '';
          _busy = false;
        });
        return;

      case _ChangeStep.confirmNew:
        if (pin != _newPin) {
          if (!mounted) return;
          setState(() {
            _errorMessage = l10n.pinsDoNotMatch;
            _step = _ChangeStep.enterNew;
            _newPin = null;
            _digits = '';
            _busy = false;
          });
          return;
        }
        await widget.pinService.setProfilePin(widget.profileId, pin);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pinChangedSuccessfully)));
        Navigator.of(context).pop(true);
    }
  }

  void _appendDigit(String d) {
    if (_busy || _lockedOut) return;
    if (_digits.length >= 4) return;
    setState(() {
      _digits += d;
      _errorMessage = null;
    });
    if (_digits.length == 4) {
      _onFourDigits();
    }
  }

  void _backspace() {
    if (_busy || _lockedOut) return;
    if (_digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _errorMessage = null;
    });
  }

  void _cancel() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PinKeypadDialogFrame(
      title: _title(l10n),
      subtitle: _subtitle(l10n),
      digits: _digits,
      errorMessage: _errorMessage,
      lockedOut: _lockedOut,
      lockoutMinutes: _lockoutMinutes,
      busy: _busy,
      onClose: _cancel,
      onDigit: _appendDigit,
      onBackspace: _backspace,
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
              color: filled ? _pinNavy : _pinDotEmpty,
              border: Border.all(
                color: filled ? _pinNavy : _pinDotInner.withValues(alpha: 0.35),
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
          style: const TextStyle(
            color: _pinNavy,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Column(
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
                    foregroundColor: _pinNavy,
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
                ),
              ),
            ),
          ],
        ),
      ],
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
      color: _pinKeyFill,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(height: 52, child: Center(child: child)),
      ),
    );
  }
}
