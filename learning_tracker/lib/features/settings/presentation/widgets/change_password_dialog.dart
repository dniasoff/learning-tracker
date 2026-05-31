import 'package:flutter/material.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows a dialog for changing the user's password.
///
/// Returns `true` if the password was changed, `false` or `null` otherwise.
Future<bool?> showChangePasswordDialog({
  required BuildContext context,
  required AccountManagementService service,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ChangePasswordDialog(service: service),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.service});

  final AccountManagementService service;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await widget.service.changePassword(_newPasswordController.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = l10n.changePasswordFailedError;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.changePasswordDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              inputFormatters: const [NoSpaceFormatter()],
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.newPasswordLabel,
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return AppLocalizations.of(context)!.passwordMinLengthError;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              inputFormatters: const [NoSpaceFormatter()],
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                )!.confirmNewPasswordLabel,
              ),
              validator: (value) {
                if (value != _newPasswordController.text) {
                  return AppLocalizations.of(context)!.passwordsDoNotMatchError;
                }
                return null;
              },
            ),
          ],
        ),
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
              : Text(AppLocalizations.of(context)!.changePasswordButton),
        ),
      ],
    );
  }
}
