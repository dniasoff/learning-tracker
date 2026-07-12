// Tutor PIN verification dialog (C2).
//
// Scope-aware PIN prompt used by the route [PinGuard] when a tutor navigates
// to a tutor-scoped guarded route (e.g. the talmid view or a tutor-permitted
// edit screen). Verifies against the Tutor PIN namespace keyed on the tutor's
// OWN profile id — the SAME namespace the TutorPinEntryGate uses (C1) — so a
// tutor who passed the gate is not re-prompted under a mismatched namespace.
//
// Reuses [PinKeypadDialogFrame] for visual parity with the parent PIN dialog.

import 'package:flutter/material.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows the Tutor PIN keypad, verifies against [tutorOwnProfileId] via
/// [tutorPinService], and returns `true` only when the PIN is correct.
/// Returns `false` on cancel.
Future<bool> showTutorPinVerificationDialog(
  BuildContext context, {
  required int tutorOwnProfileId,
  required TutorPinService tutorPinService,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _TutorPinVerificationDialog(
      tutorOwnProfileId: tutorOwnProfileId,
      tutorPinService: tutorPinService,
    ),
  );
  return result ?? false;
}

class _TutorPinVerificationDialog extends StatefulWidget {
  const _TutorPinVerificationDialog({
    required this.tutorOwnProfileId,
    required this.tutorPinService,
  });

  final int tutorOwnProfileId;
  final TutorPinService tutorPinService;

  @override
  State<_TutorPinVerificationDialog> createState() =>
      _TutorPinVerificationDialogState();
}

class _TutorPinVerificationDialogState
    extends State<_TutorPinVerificationDialog> {
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
    final result = await widget.tutorPinService.verifyTutorPin(
      profileId: widget.tutorOwnProfileId,
      rawPin: _digits,
    );
    if (!mounted) return;
    switch (result) {
      case TutorPinSuccess():
        Navigator.of(context).pop(true);
      case TutorPinIncorrect():
        setState(() {
          _digits = '';
          _errorMessage = AppLocalizations.of(context)!.tutorPinIncorrect;
          _busy = false;
        });
      case TutorPinLockedOut(:final remainingMinutes):
        setState(() {
          _lockedOut = true;
          _lockoutMinutes = remainingMinutes;
          _digits = '';
          _busy = false;
        });
      case TutorPinValidationError(:final code):
        // AUD-tutoring-09 (EH-5): the service carries a stable code, never a
        // pre-formatted message — resolve it through AppLocalizations/ARB.
        setState(() {
          _digits = '';
          _errorMessage = _validationErrorMessage(
            code,
            AppLocalizations.of(context)!,
          );
          _busy = false;
        });
    }
  }

  /// AUD-tutoring-09 (EH-5): resolve a [TutorPinValidationCode] to a
  /// localized, user-facing message. [TutorPinValidationError] carries a
  /// stable code, never a pre-formatted message — this exhaustive switch is
  /// the single place that maps each code to user-facing text.
  String _validationErrorMessage(
    TutorPinValidationCode code,
    AppLocalizations l10n,
  ) {
    return switch (code) {
      TutorPinValidationCode.malformedPin => l10n.tutorPinValidationMalformed,
    };
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
      title: l10n.tutorPinEntryHeading,
      subtitle: l10n.tutorPinEntryBody,
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
