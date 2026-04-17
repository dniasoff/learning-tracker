import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';

/// Shows a modal dialog that walks the parent through setting a 4-digit
/// parent PIN for [profileId]. The PIN is hashed and persisted via
/// [PinService.setProfilePin]. The dialog cannot be dismissed with the
/// system back gesture, but a Skip action is provided so adults who
/// accidentally reach this screen can bail out.
///
/// Resolves to `true` when a PIN was saved, `false` otherwise.
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
    builder: (ctx) =>
        _ParentPinSetupDialog(profileId: profileId, profileName: profileName),
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
        _errorMessage = 'PINs do not match';
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
        ? 'Re-enter the PIN to confirm'
        : 'Set a 4-digit PIN to access parent controls for $childName. '
              'The PIN is stored only on this device.';

    return AlertDialog(
      title: const Text('Set Parent PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
      ],
    );
  }
}
