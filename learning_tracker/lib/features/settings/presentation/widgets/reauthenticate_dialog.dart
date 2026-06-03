import 'package:flutter/material.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
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
  // Route through the shared, overflow-safe dialog shell: its body is always
  // wrapped in a height-constrained SingleChildScrollView and the card is
  // clamped to the viewport minus the keyboard inset, so the text field +
  // body never overflow on a small screen / large text / open keyboard.
  return showAppDialog<bool>(
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
    final l10n = AppLocalizations.of(context)!;
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
        _error = l10n.invalidPasswordError;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Body for the shared [showAppDialog] shell — title, prompt, field, then
    // the action row. The shell wraps this in a scrollable, keyboard-aware,
    // height-clamped card, so a bare Column here is overflow-safe.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.reauthDialogTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(l10n.reauthDialogBody),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          inputFormatters: const [NoSpaceFormatter()],
          decoration: InputDecoration(
            labelText: l10n.currentPasswordLabel,
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        // OverflowBar (the same widget AlertDialog uses for its actions) lays
        // the buttons out in a row but wraps them to a new line when they don't
        // fit the width — avoiding a horizontal RenderFlex overflow on a narrow
        // screen / large text.
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowAlignment: OverflowBarAlignment.end,
          children: [
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context, false),
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
                  : Text(l10n.reauthVerify),
            ),
          ],
        ),
      ],
    );
  }
}
