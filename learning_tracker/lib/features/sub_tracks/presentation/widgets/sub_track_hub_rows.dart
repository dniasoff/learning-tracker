/// The Manage tracks hub's sub-track rows (Story 2.6 / DNI-497, AC-1,
/// AC-8; UX-DR-53, UX-DR-163, UX-DR-164).
///
/// A row opens the sub-track's detail through [openSubTrackDetail]: on a
/// phone it pushes the detail route; inside the tablet split
/// (`SubTrackListDetailLayout`) it selects in place and the row shows as
/// selected while the detail pane updates.
///
/// Interim seam: DNI-495 (Story 2.4) owns the full hub section (header
/// count, daily target, add button). Until it lands on `integ/sub-tracks`
/// these rows are the only production entry to the detail; DNI-495's
/// section replaces them and keeps the same row action (bead
/// learning-tracker-fyh.161).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_detail_sources.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The active learner's non-ended sub-tracks in document (creation) order,
/// from the complete read; loading until it is complete. Ended sub-tracks
/// are not hub rows (Story 2.8 lists them).
final subTrackHubRowsProvider =
    Provider.autoDispose<AsyncValue<List<SubTrack>>>((ref) {
      final scope = ref.watch(activeLearnerScopeProvider);
      if (scope case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!scope.hasValue) return const AsyncLoading();
      final active = scope.requireValue;
      if (active == null) return const AsyncData([]);
      return ref
          .watch(subTrackDetailTracksProvider(active))
          .whenData(
            (read) => [
              for (final track in read.items)
                if (track.endedAt == null) track,
            ],
          );
    });

/// The hub's sub-track rows, or nothing while there are none, they are
/// loading, or they cannot be read (the hub's curriculum list stays
/// usable; the detail itself shows the retryable error).
class SubTrackHubRows extends ConsumerWidget {
  /// Creates the rows.
  const SubTrackHubRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(subTrackHubRowsProvider).value;
    if (tracks == null || tracks.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(subTrackHubSelectionProvider);
    final colors = context.colors;
    return Column(
      key: const ValueKey('subTrackHubRows'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8, bottom: 10),
          child: Semantics(
            header: true,
            child: Text(
              l10n.subTrackDetailHubTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.brandInk,
              ),
            ),
          ),
        ),
        for (final track in tracks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: colors.brandCreamCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.brandOutline),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: ValueKey('subTrackHubRow:${track.id}'),
                selected: track.id == selected,
                selectedTileColor: colors.brandBlue.withValues(alpha: 0.12),
                title: Text(
                  track.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.brandInk,
                  ),
                ),
                // chevron_right matches the text direction, so it mirrors
                // in RTL (UX-DR-161).
                trailing: Icon(
                  Icons.chevron_right,
                  color: colors.brandInkMuted,
                ),
                onTap: () => openSubTrackDetail(context, ref, track.id),
              ),
            ),
          ),
      ],
    );
  }
}
