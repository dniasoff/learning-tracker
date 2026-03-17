import 'package:flutter/material.dart';

/// Shows a dialog requiring the user to type "DELETE" to confirm account deletion.
///
/// Returns `true` if the user confirmed, `false` or `null` otherwise.
Future<bool?> showDeleteAccountDialog({required BuildContext context}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

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
    return AlertDialog(
      title: const Text('Delete Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This action is permanent and cannot be undone. '
            'All your data will be deleted.',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text('Type DELETE to confirm:'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'DELETE',
            ),
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
