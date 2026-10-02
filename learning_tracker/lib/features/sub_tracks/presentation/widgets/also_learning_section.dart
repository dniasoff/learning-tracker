/// "Also learning · {n} sub-tracks" under today's main-track tasks
/// (Story 2.9, DNI-500 T3/T4; UX-DR-46/71/87/105/106).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/controllers/sub_track_capture_controller.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_home_row.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_read_only.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The Learn tab's sub-track section.
///
/// Independent of the main-track list above it: it is absent (zero size)
/// while loading, while no learner is active and when no sub-track is
/// `onHome` — nothing invites creating one (FR-4a) — and a load error stays
/// inside it as an [InlineAsyncError] with retry (AC-6). [topSpacing] is
/// added above it only when it renders.
///
/// A queued *+1* or *Undo* the server later refuses for good replaces any
/// "Recorded 1 · Undo" snackbar with a "not saved" one, and stays listed in
/// the section with *Retry* until it is re-sent (AD-30, UX-DR-107/147). An
/// *Undo* that does not go through says so; a retryable one offers *Retry*.
class AlsoLearningSection extends ConsumerWidget {
  /// Creates the section.
  const AlsoLearningSection({super.key, this.topSpacing = 0});

  /// Space above the section when it is visible.
  final double topSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AC-5: a capture the engine later finds lock-stamped is kept, not
    // counted, and the learner is told once, after sync.
    ref.listen(activeLearnerStateProvider, (_, next) {
      final engine = next.asData?.value;
      if (engine == null) return;
      final lockIgnored = ref
          .read(subTrackCaptureControllerProvider.notifier)
          .reconcile(engine);
      if (lockIgnored.isEmpty || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.subTrackHomeKeptNotCounted,
            ),
          ),
        );
    });

    // AD-30: a queued write the server refused for good is announced once,
    // replacing a "Recorded 1 · Undo" snackbar that no longer holds.
    ref.listen(subTrackCaptureControllerProvider.select((s) => s.notSaved), (
      previous,
      next,
    ) {
      final seen = {
        for (final n in previous ?? const <SubTrackNotSaved>[]) n.failureId,
      };
      final fresh = next.where((n) => !seen.contains(n.failureId)).toList();
      if (fresh.isEmpty || !context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final entry = fresh.last;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_notSavedText(l10n, entry)),
            action: SnackBarAction(
              label: l10n.retry,
              onPressed: () => _retryNotSaved(context, ref, entry),
            ),
          ),
        );
    });
    final notSaved = ref.watch(
      subTrackCaptureControllerProvider.select((s) => s.notSaved),
    );

    final itemsAsync = ref.watch(homeSubTracksProvider);
    if (itemsAsync.hasError) {
      return Padding(
        padding: EdgeInsets.only(top: topSpacing),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: InlineAsyncError(
            key: const Key('alsoLearningError'),
            error: itemsAsync.error!,
            onRetry: () => retryHomeSubTracks(ref),
          ),
        ),
      );
    }
    final items = itemsAsync.asData?.value ?? const <SubTrackHomeItem>[];
    if (items.isEmpty && notSaved.isEmpty) return const SizedBox.shrink();
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topSpacing),
        child: _NotSavedList(entries: notSaved, onRetry: _retryNotSaved),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final role = ref.watch(subTrackViewerRoleProvider);
    final inFlight = ref.watch(
      subTrackCaptureControllerProvider.select((s) => s.inFlight),
    );
    final navigator = ref.watch(subTrackNavigatorProvider);

    return Padding(
      key: const Key('alsoLearningSection'),
      padding: EdgeInsets.only(top: topSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.subTrackHomeSectionTitle(items.length),
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.colors.brandInkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (role == SubTrackViewerRole.tutor) ...[
            const SubTrackTutorReadOnlyNote(),
            const SizedBox(height: 12),
          ],
          if (notSaved.isNotEmpty) ...[
            _NotSavedList(entries: notSaved, onRetry: _retryNotSaved),
            const SizedBox(height: 12),
          ],
          for (final item in items) ...[
            SubTrackHomeRow(
              key: ValueKey('alsoLearning-${item.subTrackId}'),
              item: item,
              role: role,
              capturing: inFlight.contains(item.subTrackId),
              onOpen: navigator.canOpen(SubTrackDestination.detail)
                  ? () => navigator.openDetail(context, item)
                  : null,
              onUpTo: navigator.canOpen(SubTrackDestination.upTo)
                  ? () => navigator.openUpTo(context, item)
                  : null,
              onAddGround: navigator.canOpen(SubTrackDestination.groundPicker)
                  ? () => navigator.openGroundPicker(context, item)
                  : null,
              onPlusOne: () => _plusOne(context, ref, item),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _plusOne(
    BuildContext context,
    WidgetRef ref,
    SubTrackHomeItem item,
  ) async {
    final controller = ref.read(subTrackCaptureControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final outcome = await controller.plusOne(item);
    switch (outcome) {
      case PlusOneRecorded(:final eventIds):
        // The engine may already have decided (a synced lock-stamped
        // write): no undo is offered for a lock-ignored event (AD-36).
        final engine = ref.read(activeLearnerStateProvider).asData?.value;
        final lockIgnored = engine == null
            ? const <String>[]
            : controller.reconcile(engine);
        if (lockIgnored.any(eventIds.contains)) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(l10n.subTrackHomeKeptNotCounted)),
            );
          return;
        }
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.subTrackHomeRecorded),
              action: SnackBarAction(
                label: l10n.undoLabel,
                onPressed: () =>
                    _undo(messenger, l10n, controller, item, eventIds),
              ),
            ),
          );
      case PlusOneFailed():
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.subTrackHomeCaptureFailed)),
          );
      case PlusOneLocked() || PlusOneIgnored():
        break;
    }
  }

  /// Runs *Undo*; a void that does not go through is reported, never shown
  /// as done, and a retryable one offers *Retry*.
  static Future<void> _undo(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    SubTrackCaptureController controller,
    SubTrackHomeItem item,
    List<String> eventIds,
  ) async {
    final outcome = await controller.undo(item, eventIds);
    switch (outcome) {
      case UndoOutcome.undone || UndoOutcome.locked:
        return;
      case UndoOutcome.refused:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.subTrackHomeUndoFailed)));
      case UndoOutcome.failed:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.subTrackHomeUndoFailed),
              action: SnackBarAction(
                label: l10n.retry,
                onPressed: () =>
                    _undo(messenger, l10n, controller, item, eventIds),
              ),
            ),
          );
    }
  }

  static Future<void> _retryNotSaved(
    BuildContext context,
    WidgetRef ref,
    SubTrackNotSaved entry,
  ) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(subTrackCaptureControllerProvider.notifier)
        .retryNotSaved(entry.failureId);
    if (ok) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            entry.kind == SubTrackWriteKind.undo
                ? l10n.subTrackHomeUndoFailed
                : l10n.subTrackHomeCaptureFailed,
          ),
        ),
      );
  }
}

String _notSavedText(
  AppLocalizations l10n,
  SubTrackNotSaved entry,
) => switch (entry.kind) {
  SubTrackWriteKind.plusOne => l10n.subTrackHomeNotSaved(entry.subTrackName),
  SubTrackWriteKind.undo => l10n.subTrackHomeUndoNotSaved(entry.subTrackName),
};

/// The section's "not saved — retry" entries, one per refused write.
class _NotSavedList extends ConsumerWidget {
  const _NotSavedList({required this.entries, required this.onRetry});

  final List<SubTrackNotSaved> entries;
  final Future<void> Function(BuildContext, WidgetRef, SubTrackNotSaved)
  onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Row(
            key: ValueKey('subTrackNotSaved-${entry.failureId}'),
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _notSavedText(l10n, entry),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => onRetry(context, ref, entry),
                child: Text(l10n.retry),
              ),
            ],
          ),
      ],
    );
  }
}
