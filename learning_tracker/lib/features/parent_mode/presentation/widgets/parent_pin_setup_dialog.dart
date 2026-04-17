import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';

/// Shows a modal dialog that walks the parent through setting a 4-digit
/// parent PIN for [profileId]. The PIN is hashed and persisted via
/// [PinService.setProfilePin]. Setting a PIN is mandatory for child
/// profiles — the dialog has no cancel or skip action and cannot be
/// dismissed by tapping outside or pressing back.
///
/// Resolves to `true` once a PIN has been saved.
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

  void _onFirstPinEntered(String pin) {
    setState(() {
      _firstPin = pin;
      _isConfirmStep = true;
      _errorMessage = null;
    });
  }

  Future<void> _onConfirmPinEntered(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _errorMessage = 'PINs do not match — please try again';
        _isConfirmStep = false;
        _firstPin = null;
      });
      return;
    }

    try {
      await ref.read(pinServiceProvider).setProfilePin(widget.profileId, pin);
      if (mounted) Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      setState(() {
        _errorMessage = e.message as String?;
        _isConfirmStep = false;
        _firstPin = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final childName = widget.profileName ?? 'this child';
    final subtitle = _isConfirmStep
        ? 'Re-enter the same 4-digit PIN to confirm'
        : 'Set a 4-digit PIN to access parent controls for $childName. '
              'The PIN is stored only on this device.';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Set Parent PIN', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                PinEntryWidget(
                  title: _isConfirmStep ? 'Confirm PIN' : 'Enter New PIN',
                  errorMessage: _errorMessage,
                  onPinComplete: _isConfirmStep
                      ? _onConfirmPinEntered
                      : _onFirstPinEntered,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
