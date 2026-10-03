/// The Dashboard's track summaries: the main track and the sub-track
/// summary cards (Story 2.11, DNI-502 AC-9; DESIGN.md tablet composition,
/// screen #03).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_sub_track_card.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';

/// The width from which the main track and the sub-track summary cards sit
/// side by side (#03: main track 7 columns, sub-tracks 5), the Material
/// expanded window class the Manage tracks split also uses.
const double kDashboardSummaryGridMinWidth = 840;

/// The gap between the two grid columns.
const double kDashboardSummaryGridGap = 24;

/// Lays out [mainTrack] and the [DashboardSubTracksSection].
///
/// Narrower than [kDashboardSummaryGridMinWidth], or while the sub-track
/// section has nothing to show (no on-home sub-track, still loading), the
/// two stack and the main track keeps the full width. From that width, once
/// the section has cards or its inline error, they form the #03 grid: the
/// main track in 7 of 12 columns and the sub-tracks in 5, top aligned. The
/// section reads its own data; this widget only asks whether it renders.
class DashboardTrackSummaryGrid extends ConsumerWidget {
  /// Creates the grid.
  const DashboardTrackSummaryGrid({super.key, required this.mainTrack});

  /// The main-track summary (the active tracks carousel).
  final Widget mainTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subTracks = ref.watch(homeSubTracksProvider);
    final sectionShows =
        subTracks.hasError || (subTracks.asData?.value.isNotEmpty ?? false);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!sectionShows ||
            constraints.maxWidth < kDashboardSummaryGridMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mainTrack,
              const DashboardSubTracksSection(topSpacing: 30),
            ],
          );
        }
        return Row(
          key: const Key('dashboardTrackSummaryGrid'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: mainTrack),
            const SizedBox(width: kDashboardSummaryGridGap),
            const Expanded(flex: 5, child: DashboardSubTracksSection()),
          ],
        );
      },
    );
  }
}
