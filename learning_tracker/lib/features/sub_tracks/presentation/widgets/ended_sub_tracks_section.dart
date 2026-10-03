/// The collapsed *Ended sub-tracks ({n})* group at the foot of the Manage
/// tracks sub-track list (Story 2.8 / DNI-499, AC-5; UX-DR-44, UX-DR-70,
/// UX-DR-82, UX-DR-90).
///
/// Lists tombstoned and elapsed-window sub-tracks as muted rows, labelled
/// "Ended", never "Completed" (ground may remain). It starts collapsed and
/// is absent while there is none. A row opens the read-only detail.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/academic_year_picker.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The ended group over [tracks] (already split by the learner's today).
class EndedSubTracksSection extends StatelessWidget {
  /// Creates the group.
  const EndedSubTracksSection({
    super.key,
    required this.tracks,
    required this.onOpen,
  });

  /// The ended sub-tracks, in hub order.
  final List<SubTrack> tracks;

  /// Opens [track]'s read-only detail.
  final void Function(SubTrack track) onOpen;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final month = DateFormat.yMMM(Localizations.localeOf(context).toString());
    String endedOn(SubTrack t) {
      final at = t.endedAt;
      final end = t.windowEnd;
      // A tombstone ended when it was stamped; an elapsed window on its
      // inclusive window_end.
      final date = at != null
          ? at.toLocal()
          : DateTime.parse(end ?? t.windowStart);
      return l10n.subTrackLifecycleEndedOn(month.format(date));
    }

    return Theme(
      // No divider lines around the expansion tile.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('endedSubTracksGroup'),
        tilePadding: const EdgeInsetsDirectional.only(start: 4, end: 4),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          l10n.subTrackLifecycleEndedGroup(tracks.length),
          style: text.titleSmall?.copyWith(
            color: colors.brandInkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          for (final track in tracks)
            Semantics(
              button: true,
              label: l10n.subTrackLifecycleEndedRowLabel(track.name),
              excludeSemantics: true,
              onTap: () => onOpen(track),
              child: ListTile(
                key: ValueKey('endedSubTrackRow:${track.id}'),
                minTileHeight: 48,
                title: Text(
                  switch (track.academicYear) {
                    final year? => '${track.name} ${academicYearLabel(year)}',
                    null => track.name,
                  },
                  style: text.bodyLarge?.copyWith(color: colors.brandInkMuted),
                ),
                subtitle: Text(
                  endedOn(track),
                  style: text.bodySmall?.copyWith(color: colors.brandInkMuted),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colors.brandInkMuted,
                ),
                onTap: () => onOpen(track),
              ),
            ),
        ],
      ),
    );
  }
}
