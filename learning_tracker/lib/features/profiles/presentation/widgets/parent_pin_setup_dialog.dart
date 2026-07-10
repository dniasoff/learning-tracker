import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows a modal that walks the parent through setting a 4-digit parent PIN
/// for [profileId], using the same keypad UI as “Enter parent PIN”.
/// [PinService.setProfilePin] persists the hash. Required for child profiles.
///
/// Resolves to `true` once a PIN has been saved. No skip, no outside tap.
Future<bool> showParentPinSetupDialog(
  BuildContext context,
  WidgetRef ref, {
  required int profileId,
  String? profileName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: _ParentPinSetupDialog(
        profileId: profileId,
        profileName: profileName,
      ),
    ),
  );
  return result ?? false;
}

class _ParentPinSetupDialog extends ConsumerStatefulWidget {
  const _ParentPinSetupDialog({required this.profileId, this.profileName});

  final int profileId;
  final String? profileName;

  @override
  ConsumerState<_ParentPinSetupDialog> createState() =>
      _ParentPinSetupDialogState();
}

class _ParentPinSetupDialogState extends ConsumerState<_ParentPinSetupDialog> {
  String? _firstPin;
  String? _errorMessage;
  bool _isConfirmStep = false;
  String _digits = '';
  bool _busy = false;

  void _appendDigit(String d) {
    if (_busy) return;
    if (_digits.length >= 4) return;
    setState(() {
      _digits += d;
      _errorMessage = null;
    });
    if (_digits.length == 4) {
      unawaited(_onFourDigits());
    }
  }

  Future<void> _onFourDigits() async {
    if (_busy) return;
    if (_digits.length != 4) return;

    final l10n = AppLocalizations.of(context)!;
    final pin = _digits;

    if (!_isConfirmStep) {
      if (!mounted) return;
      // PP-1 fix: raise _busy synchronously BEFORE resetting _digits so that
      // any 5th+ digit queued by a rapid tap is swallowed by the `_busy` guard
      // in _appendDigit. Without this, a queued digit lands as digit-1 of the
      // confirm PIN and produces either a spurious mismatch or an unintended
      // leading digit.
      //
      // The transition lock: set _busy=true so _appendDigit immediately
      // returns for any queued tap, then perform the step flip, then release
      // _busy after yielding one microtask so the confirm keypad is
      // interactive on the next frame.
      setState(() {
        _busy = true;
        _firstPin = pin;
        _isConfirmStep = true;
        _digits = '';
      });
      // Release the lock after yielding — any taps queued BEFORE this await
      // are rejected by _busy; taps after are welcome into the fresh confirm
      // buffer (digits == '', length < 4, _busy == false).
      await Future<void>.microtask(() {
        if (mounted) setState(() => _busy = false);
      });
      return;
    }

    if (pin != _firstPin) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.pinsDoNotMatch;
        _isConfirmStep = false;
        _firstPin = null;
        _digits = '';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await ref.read(pinServiceProvider).setProfilePin(widget.profileId, pin);
      if (mounted) Navigator.of(context).pop(true);
    } on InvalidPinFormatException catch (e) {
      // AUD-onboarding-16: PinService now throws a typed
      // InvalidPinFormatException instead of ArgumentError (whose
      // Object?-typed .message required an unsafe cast here). This dialog's
      // own l10n resolution of PIN-service errors is tracked separately
      // (AUD-profiles-20) — kept behavior-neutral (same message text)
      // pending that fix.
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isConfirmStep = false;
        _firstPin = null;
        _digits = '';
        _busy = false;
      });
    }
  }

  void _backspace() {
    if (_busy) return;
    if (_digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.profileName ?? l10n.userFallbackDisplayName;

    final title = _isConfirmStep
        ? l10n.confirmNewPin
        : l10n.setParentPinDialogTitle;
    final subtitle = _isConfirmStep
        ? l10n.confirmNewPinSubtitle
        : l10n.setParentPinDialogSubtitle(name);

    return PinKeypadDialogFrame(
      title: title,
      subtitle: subtitle,
      digits: _digits,
      errorMessage: _errorMessage,
      lockedOut: false,
      lockoutMinutes: 0,
      busy: _busy,
      onClose: () {},
      onDigit: _appendDigit,
      onBackspace: _backspace,
      onCancel: () {},
      showCloseButton: false,
      showKeypadCancel: false,
    );
  }
}
