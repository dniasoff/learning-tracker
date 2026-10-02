/// The trailing Undo affordance of a Change history row (DNI-514 / Story
/// 4.6): it runs the row's undo through `LearningCommands` and shows the
/// outcome (AC-1, AC-3, AC-8, AC-9).
///
/// Presentation only: what an undo writes, what is eligible and what is
/// final lives in `LearningCommands`; the row's [HistoryUndoStatus] comes
/// from `HistoryUndoIndex` (persisted `reverts_action_id`, never local
/// state). The Story 4.5 (DNI-513) timeline places [ChangeHistoryUndoButton]
/// at the end of each row, inside a `PendingCaptureFailureListener`, which
/// announces a rejected undo ("The undo couldn't be saved", Retry) once the
/// SDK has rolled the optimistic write back (AC-9).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/change_history/domain/undo/history_undo_status.dart';
import 'package:learning_tracker/features/change_history/presentation/undo/change_history_undo_text.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/undo_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// What a history row undoes.
sealed class ChangeHistoryUndoTarget {
  const ChangeHistoryUndoTarget();
}

/// A governed action, by its `action_id`.
final class GovernedUndoTarget extends ChangeHistoryUndoTarget {
  /// Targets the action [actionId].
  const GovernedUndoTarget(this.actionId);

  /// The action to undo.
  final String actionId;
}

/// A learning capture (or a void / un-learn), by its event ids.
final class CaptureUndoTarget extends ChangeHistoryUndoTarget {
  /// Targets the events [eventIds].
  const CaptureUndoTarget(this.eventIds);

  /// The events of the row.
  final List<String> eventIds;
}

/// Runs the undo of [target] through [commands]; null when the command
/// threw (nothing is known to be written).
Future<UndoResult?> runChangeHistoryUndo(
  LearningCommands commands,
  ChangeHistoryUndoTarget target,
) async {
  try {
    final result = switch (target) {
      GovernedUndoTarget(:final actionId) => await commands.undoAction(
        actionId,
      ),
      CaptureUndoTarget(:final eventIds) => await commands.undoEvents(eventIds),
    };
    return UndoResult.of(result);
  } on Exception {
    return null;
  }
}

/// Shows the snackbar of an undo's [result] (null: the command failed).
/// A [UndoNotSaved] shows nothing here: the pending-failure listener
/// announces it once, with Retry (AC-9).
void showChangeHistoryUndoOutcome(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  UndoResult? result, {
  required Color warningFill,
}) {
  if (!messenger.mounted) return;
  if (result == null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.changeHistoryUndoNotSaved),
        backgroundColor: warningFill,
      ),
    );
    return;
  }
  final message = undoOutcomeMessage(l10n, result);
  if (message == null) return;
  final details = undoOutcomeDetails(l10n, result);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: details.isEmpty
            ? Text(message)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  for (final line in details) Text(line),
                ],
              ),
        backgroundColor: switch (result) {
          UndoApplied() => null,
          _ => warningFill,
        },
      ),
    );
}

/// The Undo affordance for a row with [status]: an Undo button (48dp),
/// disabled with "Online required" when the undo [needsOnline] and the
/// device is offline (AC-8), a muted *Undone* tag (AC-1), or nothing for a
/// revert, a settings seed or a lock-ignored record (AC-2, AC-7).
class ChangeHistoryUndoAction extends StatelessWidget {
  /// Creates the affordance.
  const ChangeHistoryUndoAction({
    super.key,
    required this.status,
    required this.onUndo,
    this.needsOnline = false,
    this.isOnline = true,
    this.busy = false,
  });

  /// The row's undo status.
  final HistoryUndoStatus status;

  /// Runs the undo.
  final VoidCallback onUndo;

  /// Whether the undo is online-only (over 10 docs, AC-8).
  final bool needsOnline;

  /// Whether the device is online.
  final bool isOnline;

  /// Whether an undo of this row is running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = context.colors.brandInkMuted;
    switch (status) {
      case HistoryUndoStatus.revert || HistoryUndoStatus.notOffered:
        return const SizedBox.shrink();
      case HistoryUndoStatus.undone:
        return Semantics(
          label: l10n.changeHistoryUndoUndoneTag,
          excludeSemantics: true,
          child: Text(
            l10n.changeHistoryUndoUndoneTag,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: muted),
          ),
        );
      case HistoryUndoStatus.offered:
        final offline = needsOnline && !isOnline;
        final button = TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: offline || busy ? null : onUndo,
          child: Text(l10n.undoLabel),
        );
        if (!offline) return button;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            button,
            Text(
              l10n.changeHistoryUndoOnlineRequired,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        );
    }
  }
}

/// [ChangeHistoryUndoAction] wired to the active learner's
/// `LearningCommands`: a tap runs the undo of [target] once and shows its
/// outcome; [onResult] receives it.
class ChangeHistoryUndoButton extends ConsumerStatefulWidget {
  /// Creates the button.
  const ChangeHistoryUndoButton({
    super.key,
    required this.status,
    required this.target,
    this.needsOnline = false,
    this.isOnline = true,
    this.onResult,
  });

  /// The row's undo status.
  final HistoryUndoStatus status;

  /// What the row undoes.
  final ChangeHistoryUndoTarget target;

  /// Whether the undo is online-only (AC-8).
  final bool needsOnline;

  /// Whether the device is online.
  final bool isOnline;

  /// The outcome of a finished undo (null: the command failed).
  final void Function(UndoResult? result)? onResult;

  @override
  ConsumerState<ChangeHistoryUndoButton> createState() =>
      _ChangeHistoryUndoButtonState();
}

class _ChangeHistoryUndoButtonState
    extends ConsumerState<ChangeHistoryUndoButton> {
  bool _busy = false;

  Future<void> _undo() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final warningFill = context.colors.warningSnackbarFill;
    setState(() => _busy = true);
    UndoResult? result;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      result = commands == null
          ? null
          : await runChangeHistoryUndo(commands, widget.target);
    } on Exception {
      result = null;
    }
    if (mounted) setState(() => _busy = false);
    showChangeHistoryUndoOutcome(
      messenger,
      l10n,
      result,
      warningFill: warningFill,
    );
    widget.onResult?.call(result);
  }

  @override
  Widget build(BuildContext context) => ChangeHistoryUndoAction(
    status: widget.status,
    needsOnline: widget.needsOnline,
    isOnline: widget.isOnline,
    busy: _busy,
    onUndo: () => unawaited(_undo()),
  );
}
