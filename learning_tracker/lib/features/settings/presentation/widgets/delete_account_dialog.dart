import 'package:flutter/material.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows a dialog requiring the user to type "DELETE" to confirm account deletion.
///
/// [needsReauth] adds a note that a sign-in prompt will follow.
/// [reauthProvider] names the provider ("Google", etc.) in that note.
///
/// Returns `true` if the user confirmed, `false` or `null` otherwise.
Future<bool?> showDeleteAccountDialog({
  required BuildContext context,
  bool needsReauth = false,
  String? reauthProvider,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _DeleteAccountDialog(
      needsReauth: needsReauth,
      reauthProvider: reauthProvider,
    ),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({this.needsReauth = false, this.reauthProvider});

  final bool needsReauth;
  final String? reauthProvider;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches = _controller.text == 'DELETE';
      if (matches != _canDelete) {
        setState(() => _canDelete = matches);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reauthNote = widget.needsReauth
        ? widget.reauthProvider != null
              ? '\n\n${l10n.deleteAccountReauthProvider(widget.reauthProvider!)}'
              : '\n\n${l10n.deleteAccountReauthPassword}'
        : '';

    return AlertDialog(
      title: Text(l10n.deleteAccountDialogTitle),
      // SingleChildScrollView lets the content scroll up when the soft keyboard
      // appears, preventing the RenderFlex overflow on the TextField.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${l10n.deleteAccountWarningBody}$reauthNote',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(l10n.deleteAccountTypeConfirm),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              inputFormatters: const [TrimLeadingSpaceFormatter()],
              decoration: InputDecoration(hintText: l10n.deleteAccountHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          child: Text(
            l10n.deleteAccountDialogTitle,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
