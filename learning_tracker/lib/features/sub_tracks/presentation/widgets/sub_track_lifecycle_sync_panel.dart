/// The queued lifecycle writes, visibly pending (Story 2.8 / DNI-499;
/// AD-54 Recovery): one row per End, Delete or *Add next year* the server
/// has not accepted yet ("waiting to sync") or refused for good ("not
/// saved", with Retry and Close).
///
/// When a queued write is accepted, the first mounted panel shows its
/// success confirmation (the same snackbar as an acknowledged write) once
/// and forgets it. The panel sits on the hub and on the sub-track detail,
/// so it is seen wherever the parent is after the action.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_sync_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The pending lifecycle writes; nothing while there are none.
class SubTrackLifecycleSyncPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const SubTrackLifecycleSyncPanel({super.key});

  @override
  ConsumerState<SubTrackLifecycleSyncPanel> createState() =>
      _SubTrackLifecycleSyncPanelState();
}

class _SubTrackLifecycleSyncPanelState
    extends ConsumerState<SubTrackLifecycleSyncPanel> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<Map<String, SubTrackLifecycleSync>>(
      subTrackLifecycleSyncProvider,
      (_, next) => _confirmSaved(next),
      fireImmediately: true,
    );
  }

  /// Shows each accepted write's confirmation after this frame (the state
  /// cannot change while the tree builds); a write another panel already
  /// confirmed is gone by then.
  void _confirmSaved(Map<String, SubTrackLifecycleSync> writes) {
    final saved = [
      for (final w in writes.values)
        if (w.status == SubTrackLifecycleSyncStatus.saved) w.changeId,
    ];
    if (saved.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(subTrackLifecycleSyncProvider.notifier);
      final messenger = ScaffoldMessenger.maybeOf(context);
      final l10n = AppLocalizations.of(context)!;
      for (final id in saved) {
        final write = ref.read(subTrackLifecycleSyncProvider)[id];
        if (write == null ||
            write.status != SubTrackLifecycleSyncStatus.saved) {
          continue;
        }
        notifier.remove(write);
        // Supersedes a showing "saved on this device" notice.
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_savedCopy(l10n, write))));
      }
    });
  }

  static String _savedCopy(AppLocalizations l10n, SubTrackLifecycleSync w) =>
      switch (w.write) {
        SubTrackLifecycleWrite.end => l10n.subTrackLifecycleEnded(w.name),
        SubTrackLifecycleWrite.delete => l10n.subTrackLifecycleDeleted(w.name),
        SubTrackLifecycleWrite.addNextYear =>
          l10n.subTrackLifecycleNextYearSaved(w.name, w.yearLabel ?? ''),
      };

  static String _actionCopy(AppLocalizations l10n, SubTrackLifecycleSync w) =>
      switch (w.write) {
        SubTrackLifecycleWrite.end => l10n.subTrackLifecycleSyncEnd(w.name),
        SubTrackLifecycleWrite.delete => l10n.subTrackLifecycleSyncDelete(
          w.name,
        ),
        SubTrackLifecycleWrite.addNextYear =>
          l10n.subTrackLifecycleSyncAddNextYear(w.name, w.yearLabel ?? ''),
      };

  @override
  Widget build(BuildContext context) {
    final writes = [
      for (final w in ref.watch(subTrackLifecycleSyncProvider).values)
        if (w.status != SubTrackLifecycleSyncStatus.saved) w,
    ];
    if (writes.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final notifier = ref.read(subTrackLifecycleSyncProvider.notifier);
    return Column(
      key: const ValueKey('subTrackLifecycleSyncPanel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in writes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: colors.brandCreamCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.brandOutline),
                ),
                child: ListTile(
                  key: ValueKey('subTrackSync:${w.changeId}'),
                  leading: Icon(
                    w.status == SubTrackLifecycleSyncStatus.waiting
                        ? Icons.cloud_upload_outlined
                        : Icons.error_outline,
                    color: w.status == SubTrackLifecycleSyncStatus.waiting
                        ? colors.brandInkMuted
                        : colors.warningSnackbarFill,
                  ),
                  title: Text(
                    w.status == SubTrackLifecycleSyncStatus.waiting
                        ? l10n.subTrackLifecycleSyncWaiting(
                            _actionCopy(l10n, w),
                          )
                        : l10n.subTrackLifecycleSyncNotSaved(
                            _actionCopy(l10n, w),
                          ),
                    style: TextStyle(color: colors.brandInk),
                  ),
                  trailing: w.status == SubTrackLifecycleSyncStatus.notSaved
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              key: ValueKey('subTrackSyncRetry:${w.changeId}'),
                              onPressed: () => unawaited(notifier.retry(w)),
                              child: Text(l10n.actionRetry),
                            ),
                            IconButton(
                              key: ValueKey('subTrackSyncClose:${w.changeId}'),
                              tooltip: l10n.actionClose,
                              icon: const Icon(Icons.close),
                              onPressed: () => notifier.remove(w),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
