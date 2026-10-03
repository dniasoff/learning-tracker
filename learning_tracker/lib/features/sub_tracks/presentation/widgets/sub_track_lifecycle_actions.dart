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
/// [subTrackLifecycleDetailMenuActions] are the two entries DNI-499 adds to
/// DNI-497's detail ⋮ registry (`subTrackDetailMenuActionsProvider`; keys
/// `subTrackMenu:{id}`), shown only to the parent on a sub-track that is
/// not ended (AC-5 read-only).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
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

/// DNI-499's entries in DNI-497's detail ⋮ registry: *End sub-track now*
/// and *Delete track* for the parent on a sub-track that is not ended
/// (tombstoned or past its window, [SubTrackDetail.isEnded]). The child and
/// the tutor never see them (tutor sub-track writes are Epic 4).
List<SubTrackDetailMenuAction> get subTrackLifecycleDetailMenuActions => [
  for (final action in subTrackLifecycleMenuActions)
    SubTrackDetailMenuAction(
      id: action.id,
      icon: action.icon,
      label: action.label,
      visibleFor: (detail) =>
          detail.role == SubTrackDetailRole.parent && !detail.isEnded,
      onSelected: (context, detail) async {
        final read = ProviderScope.containerOf(context, listen: false).read;
        await runSubTrackLifecycleAction(
          context,
          read,
          detail.track,
          action,
          onReturnToHub: subTrackHubReturn(context, read),
        );
      },
    ),
];

/// What "return to the hub" means from the detail at [context], resolved
/// now (the menu that ran the action may be gone by the time it is called):
/// inside the tablet list-detail split the hub is already on screen, so the
/// selection clears; on a phone the pushed detail pops.
VoidCallback subTrackHubReturn(
  BuildContext context,
  SubTrackLifecycleReader read,
) {
  if (SubTrackSplitScope.of(context)) {
    return () => read(subTrackHubSelectionProvider.notifier).clear();
  }
  final navigator = Navigator.of(context);
  return () => unawaited(navigator.maybePop());
}

/// Confirms and runs [action] on [track]. Returns true when the command
/// succeeded (written, or queued offline per AD-54); [onReturnToHub] then
/// runs before the snackbar, which confirms an acknowledged write and says
/// a queued one is saved on this device only (it stays pending in
/// `subTrackLifecycleSyncProvider`). A cancelled or dismissed dialog
/// issues no command.
Future<bool> runSubTrackLifecycleAction(
  BuildContext context,
  SubTrackLifecycleReader read,
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
  SubTrackLifecycleOrigin? origin;
  try {
    // The learner and its commands are captured before the command runs,
    // so a queued result tracks under that learner even if the parent
    // switches learners while it awaits the server.
    origin = await resolveSubTrackLifecycleOrigin(read);
    final commands = origin?.commands;
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
  if (result.queued && result.changeIds.isNotEmpty && origin != null) {
    read(subTrackLifecycleSyncProvider.notifier).track(
      SubTrackLifecycleSync(
        changeId: result.changeIds.first,
        write: delete
            ? SubTrackLifecycleWrite.delete
            : SubTrackLifecycleWrite.end,
        name: track.name,
      ),
      origin,
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
