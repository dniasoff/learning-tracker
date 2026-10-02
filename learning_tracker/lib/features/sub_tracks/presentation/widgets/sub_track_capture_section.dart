/// The Learn-tab sub-track rows under today's tasks (Story 2.10,
/// DNI-501; UX-DR-46).
///
/// DNI-500 SEAM: Story 2.9 (DNI-500) owns this "Also learning" section; it
/// did not land on `integ/sub-tracks`. This minimal section renders one
/// [SubTrackRow] per `onHome` sub-track in hub order and wires *Up to…*
/// (this story) and *+1* (one capture of the position) through
/// `LearningCommands`. With no `onHome` sub-track it is absent; its
/// loading and error stay local (the main tasks are unaffected). On a
/// tutor device every sub-track write control is disabled (Story 2.9
/// AC-9: tutor sub-track writes stay read-only).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/up_to_selection_service.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_row.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/up_to_picker.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The sub-track rows section.
class SubTrackCaptureSection extends ConsumerWidget {
  /// Creates the section.
  const SubTrackCaptureSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(onHomeSubTracksProvider);
    return rows.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Padding(
        key: const Key('subTrackSectionError'),
        padding: const EdgeInsets.only(top: 24),
        child: InlineAsyncError(
          error: error,
          onRetry: () => retryUpToInputs(ref),
        ),
      ),
      data: (items) =>
          items.isEmpty ? const SizedBox.shrink() : _Rows(items: items),
    );
  }
}

class _Rows extends ConsumerWidget {
  const _Rows({required this.items});

  final List<OnHomeSubTrack> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final writable = ref.watch(subTrackWritesAllowedProvider);
    final pending = ref.watch(pendingCapturesProvider);
    return PendingCaptureFailureListener(
      onFailure: (failure) => ref
          .read(pendingCapturesProvider.notifier)
          .dropEvents(failure.eventIds),
      child: Column(
        key: const Key('subTrackSection'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 36),
          Text(
            l10n.subTrackRowsTitle(items.length),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            _row(context, ref, item, writable, pending),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    OnHomeSubTrack item,
    bool writable,
    PendingCaptures pending,
  ) {
    final position = displayedSubTrackPosition(
      item.state,
      pending: pending.refsOf(item.curriculumId, item.id),
    );
    return SubTrackRow(
      item: item,
      position: position,
      onUpTo: writable
          ? () => openUpToAndRecord(
              context,
              ref,
              request: SubTrackUpToRequest(
                subTrackId: item.id,
                curriculumId: item.curriculumId,
                name: item.track.name,
              ),
            )
          : null,
      onPlusOne: writable && position != null
          ? () => captureLeaves(
              context,
              ref,
              curriculumId: item.curriculumId,
              source: item.id,
              refs: [position],
            )
          : null,
    );
  }
}
