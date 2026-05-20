import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Confirmation dialog shown before a content-order reorder when the learner
/// has outstanding overdue items.
///
/// If [overdueCount] is 0 the dialog is skipped — callers should check before
/// showing it ([showIfNeeded] handles this automatically).
///
/// Returns `true` when the user chooses to continue with the reorder, `false`
/// when they cancel.
class ReorderConfirmDialog extends StatelessWidget {
  const ReorderConfirmDialog({super.key, required this.overdueCount});

  final int overdueCount;

  /// Show the dialog only when [overdueCount] > 0.
  ///
  /// Returns `true` immediately (no dialog shown) when [overdueCount] == 0,
  /// and returns the user's choice otherwise.
  static Future<bool> showIfNeeded(
    BuildContext context, {
    required int overdueCount,
  }) async {
    if (overdueCount == 0) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ReorderConfirmDialog(overdueCount: overdueCount),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.reorderConfirmTitle),
      content: Text(l10n.reorderConfirmBody(overdueCount)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.actionContinue),
        ),
      ],
    );
  }
}
