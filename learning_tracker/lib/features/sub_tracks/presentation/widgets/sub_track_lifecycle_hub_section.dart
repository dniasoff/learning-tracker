/// The Manage tracks hub's sub-track rows, split into active rows and the
/// collapsed *Ended sub-tracks* group (Story 2.8 / DNI-499, AC-5, AC-6).
///
/// The split is the learner's civil today (AD-41): an explicitly ended
/// sub-track and one whose window passed are both absent from the active
/// rows, with no write for the passed window (AD-33).
///
/// INTERIM (DNI-499 seam): Story 2.4 / DNI-495 owns the hub's sub-track
/// section (header count, daily target, Add sub-track) and Story 2.6 /
/// DNI-497 its row → detail routing; neither is on `integ/sub-tracks` yet.
/// Until they are, these minimal active rows open the lifecycle detail.
/// When they land, their section keeps its active rows over
/// `subTrackLifecycleGroupsProvider.active` and mounts
/// [EndedSubTracksSection] at its foot; this widget is then deleted (bead
/// learning-tracker-fyh.208).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_lifecycle_detail_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ended_sub_tracks_section.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_sync_panel.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The hub's sub-track rows, under the lifecycle writes still waiting for
/// the server ([SubTrackLifecycleSyncPanel]); no rows while there are
/// none, while loading, or when the read fails (the curriculum list stays
/// usable).
class SubTrackLifecycleHubSection extends ConsumerWidget {
  /// Creates the section.
  const SubTrackLifecycleHubSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(subTrackLifecycleGroupsProvider).value;
    if (groups == null || (groups.active.isEmpty && groups.ended.isEmpty)) {
      return const SubTrackLifecycleSyncPanel();
    }
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Column(
      key: const ValueKey('subTrackLifecycleHubSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SubTrackLifecycleSyncPanel(),
        if (groups.active.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8, bottom: 10),
            child: Semantics(
              header: true,
              child: Text(
                l10n.subTrackLifecycleActiveGroup,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.brandInk,
                ),
              ),
            ),
          ),
          for (final track in groups.active)
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
                  key: ValueKey('activeSubTrackRow:${track.id}'),
                  title: Text(
                    track.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.brandInk,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colors.brandInkMuted,
                  ),
                  onTap: () => openSubTrackLifecycleDetail(context, track.id),
                ),
              ),
            ),
        ],
        EndedSubTracksSection(
          tracks: groups.ended,
          onOpen: (track) => openSubTrackLifecycleDetail(context, track.id),
        ),
      ],
    );
  }
}
