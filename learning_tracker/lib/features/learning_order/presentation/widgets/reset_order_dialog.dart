import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.resetToDefaultOrderDialogTitle),
      content: Text(l10n.resetToDefaultOrderDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.actionReset),
        ),
      ],
    );
  }
}
