/// The sub-track detail's ⋮ lifecycle actions (Story 2.8 / DNI-499, AC-3,
/// AC-4; UX-DR-29, UX-DR-81): *End sub-track now* and *Delete track*, each
/// behind the shared `showAppConfirmDialog`.
///
/// Confirmed actions go through `LearningCommands.endSubTrack` /
/// `deleteSubTrack`, the only writers: an `ended_at` + `end_reason`
/// tombstone and one `change_log` entry. No document is deleted and no
/// `learning_events` doc is touched. Cancel, a barrier tap and back are the
/// same no-op. On success the detail returns to the hub and a snackbar
/// confirms; the schedule and target recompute from the stored tombstone.
///
/// A write the server has not acknowledged yet (`success(queued: true)`,
/// AD-54) is not reported as done: the detail still returns to the hub,
/// which now shows the local tombstone, but the snackbar says it is saved
/// on this device only, and the write is handed to
/// `subTrackLifecycleSyncProvider`, which keeps it visibly pending and
/// shows the confirmation only once the server accepts it, or "not saved"
/// with Retry when the server refuses it.
///
/// [subTrackLifecycleMenuActions] is registry-ready for DNI-497's detail
/// overflow registry (`subTrackMenu:{id}` keys); [SubTrackLifecycleMenu]
/// renders the same actions as a stand-alone ⋮ until that lands.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_sync_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// One explicit lifecycle action of the parent's ⋮ menu.
enum SubTrackLifecycleMenuAction {
  /// *End sub-track now*: `end_reason = ended` (AC-4; menu placement is the
  /// story's `[ASSUMPTION: entry point]`, ruling B13.7).
  end('end', Icons.event_busy_outlined),

  /// *Delete track*: `end_reason = deleted` (AC-3).
  delete('delete', Icons.delete_outline);

  const SubTrackLifecycleMenuAction(this.id, this.icon);

  /// Stable id; the menu item key is `subTrackMenu:{id}`.
  final String id;

  /// Leading icon.
  final IconData icon;

  /// The localized menu label.
  String label(AppLocalizations l10n) => switch (this) {
    end => l10n.subTrackLifecycleEndAction,
    delete => l10n.subTrackLifecycleDeleteAction,
  };
}

/// The ⋮ actions, in menu order.
const subTrackLifecycleMenuActions = SubTrackLifecycleMenuAction.values;

/// Confirms and runs [action] on [track]. Returns true when the command
/// succeeded (written, or queued offline per AD-54); [onReturnToHub] then
/// runs before the snackbar, which confirms an acknowledged write and says
/// a queued one is saved on this device only (it stays pending in
/// `subTrackLifecycleSyncProvider`). A cancelled or dismissed dialog
/// issues no command.
Future<bool> runSubTrackLifecycleAction(
  BuildContext context,
  WidgetRef ref,
  SubTrack track,
  SubTrackLifecycleMenuAction action, {
  required VoidCallback onReturnToHub,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final delete = action == SubTrackLifecycleMenuAction.delete;
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: delete
        ? l10n.subTrackLifecycleDeleteTitle(track.name)
        : l10n.subTrackLifecycleEndTitle(track.name),
    message: delete
        ? l10n.subTrackLifecycleDeleteBody
        : l10n.subTrackLifecycleEndBody,
    confirmLabel: delete
        ? l10n.subTrackLifecycleDeleteConfirm
        : l10n.subTrackLifecycleEndConfirm,
    cancelLabel: l10n.actionCancel,
    icon: Icons.warning_amber_rounded,
    destructive: delete,
  );
  if (!confirmed || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  CaptureResult? result;
  LearningCommands? commands;
  try {
    commands = await ref.read(learningCommandsProvider.future);
    result = await switch (action) {
      SubTrackLifecycleMenuAction.end => commands?.endSubTrack(track.id),
      SubTrackLifecycleMenuAction.delete => commands?.deleteSubTrack(track.id),
    };
  } on Object {
    result = null;
  }
  if (result is! CaptureSuccess) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.subTrackLifecycleActionFailed)),
    );
    return false;
  }
  if (result.queued && result.changeIds.isNotEmpty && commands != null) {
    ref
        .read(subTrackLifecycleSyncProvider.notifier)
        .track(
          SubTrackLifecycleSync(
            changeId: result.changeIds.first,
            write: delete
                ? SubTrackLifecycleWrite.delete
                : SubTrackLifecycleWrite.end,
            name: track.name,
          ),
          commands,
        );
    onReturnToHub();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.subTrackLifecycleQueued)),
    );
    return true;
  }
  onReturnToHub();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        delete
            ? l10n.subTrackLifecycleDeleted(track.name)
            : l10n.subTrackLifecycleEnded(track.name),
      ),
    ),
  );
  return true;
}

/// The parent's ⋮ on a live sub-track's detail. The host shows it only for
/// the parent on a sub-track that is not ended (AC-5 read-only).
class SubTrackLifecycleMenu extends ConsumerStatefulWidget {
  /// Creates the menu for [track].
  const SubTrackLifecycleMenu({
    super.key,
    required this.track,
    required this.onReturnToHub,
  });

  /// The detail's sub-track.
  final SubTrack track;

  /// Leaves the detail for the hub after a successful action.
  final VoidCallback onReturnToHub;

  @override
  ConsumerState<SubTrackLifecycleMenu> createState() =>
      _SubTrackLifecycleMenuState();
}

class _SubTrackLifecycleMenuState extends ConsumerState<SubTrackLifecycleMenu> {
  bool _running = false;

  Future<void> _run(SubTrackLifecycleMenuAction action) async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await runSubTrackLifecycleAction(
        context,
        ref,
        widget.track,
        action,
        onReturnToHub: widget.onReturnToHub,
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<SubTrackLifecycleMenuAction>(
      key: const ValueKey('subTrackLifecycleMenu'),
      enabled: !_running,
      tooltip: l10n.subTrackLifecycleMoreOptions,
      icon: const Icon(Icons.more_vert),
      onSelected: _run,
      itemBuilder: (context) => [
        for (final action in subTrackLifecycleMenuActions)
          PopupMenuItem(
            key: ValueKey('subTrackMenu:${action.id}'),
            value: action,
            child: Row(
              children: [
                Icon(action.icon, size: 20),
                const SizedBox(width: 12),
                Text(action.label(l10n)),
              ],
            ),
          ),
      ],
    );
  }
}
