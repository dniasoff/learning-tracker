import 'package:flutter/material.dart';
import 'package:learning_tracker/features/settings/domain/services/account_management_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows a dialog that prompts the user to enter their current password
/// to re-authenticate before a destructive operation.
///
/// Returns `true` if re-authentication succeeded, `false` or `null` otherwise.
Future<bool?> showReauthenticateDialog({
  required BuildContext context,
  required String email,
  required AccountManagementService service,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ReauthenticateDialog(email: email, service: service),
  );
}

class _ReauthenticateDialog extends StatefulWidget {
  const _ReauthenticateDialog({required this.email, required this.service});

  final String email;
  final AccountManagementService service;

  @override
  State<_ReauthenticateDialog> createState() => _ReauthenticateDialogState();
}

class _ReauthenticateDialogState extends State<_ReauthenticateDialog> {
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await widget.service.reauthenticateWithEmail(
        widget.email,
        _passwordController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = 'Invalid password. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.reauthDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.reauthDialogBody),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Current Password',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context)!.actionCancel),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)!.reauthVerify),
        ),
      ],
    );
  }
}
