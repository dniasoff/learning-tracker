/// Dashboard "Sub-tracks ({n})": one summary card per `onHome` sub-track
/// (Story 2.9, DNI-500 T5; DESIGN.md "Sub-track summary card", UX-DR-25/
/// 49/77/114/115).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The Dashboard's sub-track section.
///
/// Absent (zero size) while loading, when no learner is active and when no
/// sub-track is `onHome` (UX-DR-114); a load error stays inside it as an
/// [InlineAsyncError] with retry (UX-DR-115). *Manage* opens the hub and is
/// shown to the parent only (not the child, and not a tutor device, whose
/// sub-track surfaces are read-only with one note, AC-9). [topSpacing] is
/// added above it only when it renders.
class DashboardSubTracksSection extends ConsumerWidget {
  /// Creates the section.
  const DashboardSubTracksSection({super.key, this.topSpacing = 0});

  /// Space above the section when it is visible.
  final double topSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(homeSubTracksProvider);
    if (itemsAsync.hasError) {
      return Padding(
        padding: EdgeInsets.only(top: topSpacing),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: InlineAsyncError(
            key: const Key('dashboardSubTracksError'),
            error: itemsAsync.error!,
            onRetry: () => retryHomeSubTracks(ref),
          ),
        ),
      );
    }
    final items = itemsAsync.asData?.value ?? const <SubTrackHomeItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final role = ref.watch(subTrackViewerRoleProvider);
    final navigator = ref.watch(subTrackNavigatorProvider);

    return Padding(
      key: const Key('dashboardSubTracksSection'),
      padding: EdgeInsets.only(top: topSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.subTrackDashboardTitle(items.length),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: context.colors.brandInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // Story 4.2 (DNI-510): the tutor manages the talmid's tracks
              // from the same hub.
              if (role != SubTrackViewerRole.child)
                TextButton(
                  key: const Key('dashboardSubTracksManage'),
                  onPressed: () => navigator.openHub(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: context.colors.brandBlue,
                  ),
                  child: Text(l10n.subTrackDashboardManage),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            DashboardSubTrackCard(
              key: ValueKey('dashboardSubTrack-${item.subTrackId}'),
              item: item,
              onOpen: navigator.canOpen(SubTrackDestination.detail)
                  ? () => navigator.openDetail(context, item)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// One neutral summary card: name, "Next: …", "{ticked} ticked" and a 6dp
/// [AnimatedProgressBar] of ticked ÷ (ticked + remaining path), all from
/// the engine projection. No sub-track-level status (UX-DR-25).
class DashboardSubTrackCard extends ConsumerWidget {
  /// Creates the card.
  const DashboardSubTrackCard({
    super.key,
    required this.item,
    required this.onOpen,
  });

  /// The engine projection of the track.
  final SubTrackHomeItem item;

  /// Opens the detail; null while the detail destination is not wired, and
  /// the card is then not tappable.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final position = item.position;
    final line = switch (item.kind) {
      SubTrackRowKind.active => l10n.subTrackHomeNext(
        subTrackPositionLabel(ref, position!),
      ),
      SubTrackRowKind.groundless => l10n.subTrackHomeNoGround,
      SubTrackRowKind.allRecorded => l10n.subTrackHomeAllRecorded,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('dashboardSubTrackCard-${item.subTrackId}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.brandCreamCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.brandOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.brandInkMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.subTrackDashboardTicked(item.ticked),
                key: Key('dashboardSubTrackTicked-${item.subTrackId}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.brandInkMuted,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedProgressBar(
                key: Key('dashboardSubTrackProgress-${item.subTrackId}'),
                value: item.progress,
                color: colors.brandBlue,
                backgroundColor: colors.brandOutline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
