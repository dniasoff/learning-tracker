import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_entry_machine.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/pin_flow_error_text.dart';
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
  // AUD-profiles-06: the digit-buffer/busy/lockout transitions (including the
  // PP-1 busy-lock-before-reset fix) now live in one place — PinEntryMachine —
  // shared with PinFlowController and the verify/change dialogs, instead of
  // being hand-rolled again here.
  late final PinEntryMachine _machine = PinEntryMachine(
    pinService: () => ref.read(pinServiceProvider),
    profileId: () => widget.profileId,
    onStateChanged: _onMachineStateChanged,
    isActive: () => mounted,
    initialMode: PinFlowMode.setup,
  );

  void _onMachineStateChanged(PinFlowState state) {
    if (!mounted) return;
    if (state.completed) {
      // Success — dismiss the dialog. No intermediate rebuild needed; the
      // dialog is leaving the tree.
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = _machine.state;
    final name = widget.profileName ?? l10n.userFallbackDisplayName;
    final isConfirmStep = state.step == PinFlowStep.confirm;

    final title = isConfirmStep
        ? l10n.confirmNewPin
        : l10n.setParentPinDialogTitle;
    final subtitle = isConfirmStep
        ? l10n.confirmNewPinSubtitle
        : l10n.setParentPinDialogSubtitle(name);

    return PinKeypadDialogFrame(
      title: title,
      subtitle: subtitle,
      digits: state.digits,
      errorMessage: resolvePinFlowErrorText(state.error, l10n),
      lockedOut: false,
      lockoutMinutes: 0,
      busy: state.busy,
      onClose: () {},
      onDigit: _machine.appendDigit,
      onBackspace: _machine.backspace,
      onCancel: () {},
      showCloseButton: false,
      showKeypadCancel: false,
    );
  }
}
