import 'package:flutter/material.dart';

/// Recovery action button shown below track card footer.
///
/// Shows a confirmation dialog before executing the action.
/// Used for "Jump to today" and "Reset pace" recovery actions.
class RecoveryActionButton extends StatelessWidget {
  const RecoveryActionButton({
    super.key,
    required this.label,
    required this.dialogText,
    required this.confirmLabel,
    required this.onConfirmed,
  });

  final String label;
  final String dialogText;
  final String confirmLabel;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => _showConfirmDialog(context),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(dialogText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirmed();
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
