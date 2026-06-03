import 'package:flutter/material.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows a dialog for changing the user's password.
///
/// Returns `true` if the password was changed, `false` or `null` otherwise.
Future<bool?> showChangePasswordDialog({
  required BuildContext context,
  required AccountManagementService service,
}) {
  // Route through the shared, overflow-safe dialog shell: its body is always
  // wrapped in a height-constrained SingleChildScrollView and the card is
  // clamped to the viewport minus the keyboard inset, so the two password
  // fields + error text never overflow on a small screen / large text / open
  // keyboard.
  return showAppDialog<bool>(
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Body for the shared [showAppDialog] shell — title, form fields, then the
    // action row. The shell wraps this in a scrollable, keyboard-aware,
    // height-clamped card, so a bare Form/Column here is overflow-safe.
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.changePasswordDialogTitle,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            inputFormatters: const [NoSpaceFormatter()],
            decoration: InputDecoration(labelText: l10n.newPasswordLabel),
            validator: (value) {
              if (value == null || value.length < 6) {
                return l10n.passwordMinLengthError;
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
              labelText: l10n.confirmNewPasswordLabel,
            ),
            validator: (value) {
              if (value != _newPasswordController.text) {
                return l10n.passwordsDoNotMatchError;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // OverflowBar (the same widget AlertDialog uses for its actions) lays
          // the buttons out in a row but wraps them to a new line when they
          // don't fit the width — avoiding a horizontal RenderFlex overflow on
          // a narrow screen / large text.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.pop(context, false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.changePasswordButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
