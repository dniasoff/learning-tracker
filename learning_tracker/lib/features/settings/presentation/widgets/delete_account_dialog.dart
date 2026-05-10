import 'package:flutter/material.dart';

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
    final reauthNote = widget.needsReauth
        ? widget.reauthProvider != null
              ? '\n\nYou will be asked to sign in with ${widget.reauthProvider} to confirm your identity.'
              : '\n\nYou will be asked to re-enter your password to confirm your identity.'
        : '';

    return AlertDialog(
      title: const Text('Delete Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This action is permanent and cannot be undone. '
            'All your data will be deleted.$reauthNote',
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text('Type DELETE to confirm:'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          child: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
