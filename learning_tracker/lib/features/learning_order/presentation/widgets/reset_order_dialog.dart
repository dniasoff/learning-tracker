import 'package:flutter/material.dart';

/// Confirmation dialog for resetting learning order to default.
class ResetOrderDialog extends StatelessWidget {
  const ResetOrderDialog({super.key});

  /// Shows the dialog and returns true if the user confirmed, false otherwise.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ResetOrderDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset to Default Order'),
      content: const Text(
        'This will restore the natural Sefaria order for this curriculum. '
        'Your custom ordering will be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}
