/// Sub-track detail (Story 2.6 / DNI-497; screens.md #07): the window,
/// "Up next", "{n} ticked", capacity vs path and the ordered ground.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_capacity_bar.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_ground_tree.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The routed detail of sub-track [subTrackId]: opened from a hub row on a
/// phone. Any role may open it; only the parent gets edit controls.
@RoutePage()
class SubTrackDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubTrackDetailScreen({
    super.key,
    @PathParam('subTrackId') required this.subTrackId,
  });

  /// The sub-track ULID.
  final String subTrackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(subTrackDetailProvider(subTrackId)).value;
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: colors.surfaceF5,
        elevation: 0,
        title: Text(
          detail?.track.name ?? '',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.brandBlueDeep,
          ),
        ),
        actions: [if (detail != null) SubTrackDetailMenu(detail: detail)],
      ),
      body: SubTrackDetailView(subTrackId: subTrackId),
    );
  }
}

/// The detail body for [subTrackId]: the routed screen's body, and the
/// detail pane of the tablet list-detail split ([showTitle] adds the name
/// and ⋮ there, since the pane has no app bar).
class SubTrackDetailView extends ConsumerWidget {
  /// Creates the view.
  const SubTrackDetailView({
    super.key,
    required this.subTrackId,
    this.showTitle = false,
  });

  /// The sub-track ULID.
  final String subTrackId;

  /// Whether to render the name and ⋮ above the body.
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(subTrackDetailProvider(subTrackId))) {
      AsyncValue(:final error?, :final stackTrace) => AppErrorView(
        error: error,
        stackTrace: stackTrace,
        onRetry: () => retrySubTrackDetail(ref),
      ),
      AsyncValue(:final value?) => _DetailBody(
        detail: value,
        showTitle: showTitle,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.showTitle});

  final SubTrackDetail detail;
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final setup = ref.watch(subTrackDeadlineSetupProvider);
    final track = detail.track;
    return ListView(
      key: ValueKey('subTrackDetail:${track.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
      children: [
        if (showTitle)
          Row(
            children: [
              Expanded(
                child: Text(
                  track.name,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.brandBlueDeep,
                  ),
                ),
              ),
              SubTrackDetailMenu(detail: detail),
            ],
          ),
        _SummaryCard(detail: detail),
        const SizedBox(height: 12),
        _UpNextCard(detail: detail),
        const SizedBox(height: 12),
        SubTrackCapacityBar(
          detail: detail,
          onSetDeadline: setup == null
              ? null
              : () => setup(context, track.curriculumId),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            l10n.subTrackDetailGroundTitle,
            style: text.titleMedium?.copyWith(
              color: colors.brandInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SubTrackGroundTree(
          detail: detail,
          onOpenLeaf: (leaf) => context.router.push(
            MishnaHistoryRoute(curriculumId: track.curriculumId, leafRef: leaf),
          ),
        ),
      ],
    );
  }
}

/// The window and the distinct ticked count.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail});

  final SubTrackDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.brandInk);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: colors.brandBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subTrackWindowLabel(context, detail.track),
                  key: const ValueKey('subTrackDetailWindow'),
                  style: style,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: colors.brandBlue),
              const SizedBox(width: 8),
              Text(
                l10n.subTrackDetailTicked(detail.ticked),
                key: const ValueKey('subTrackDetailTicked'),
                style: style,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "{start} – {end}" (or "From {start}") in month-and-year form.
String subTrackWindowLabel(BuildContext context, SubTrack track) {
  final l10n = AppLocalizations.of(context)!;
  final format = DateFormat.yMMM(Localizations.localeOf(context).toString());
  final start = format.format(DateTime.parse(track.windowStart));
  final end = track.windowEnd;
  return end == null
      ? l10n.subTrackDetailWindowOpen(start)
      : l10n.subTrackDetailWindow(start, format.format(DateTime.parse(end)));
}

/// "Up next" with the engine position, or none.
class _UpNextCard extends ConsumerWidget {
  const _UpNextCard({required this.detail});

  final SubTrackDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final position = detail.upNext;
    final value = position != null
        ? ref.watch(subTrackRefLabelProvider(position))
        : detail.state.groundExhausted
        ? l10n.subTrackDetailAllTicked
        : l10n.subTrackDetailGroundEmpty;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.subTrackDetailUpNext,
            style: text.labelLarge?.copyWith(color: colors.brandInkMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            key: const ValueKey('subTrackDetailUpNextValue'),
            style: text.titleMedium?.copyWith(
              color: colors.brandInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.brandCreamCard,
        border: Border.all(color: colors.brandOutline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// The detail's ⋮ menu over [subTrackDetailMenuActionsProvider]; hidden
/// when no action is visible for [detail] (the child and tutor have none).
class SubTrackDetailMenu extends ConsumerWidget {
  /// Creates the menu.
  const SubTrackDetailMenu({super.key, required this.detail});

  /// The detail the actions act on.
  final SubTrackDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      for (final a in ref.watch(subTrackDetailMenuActionsProvider))
        if (a.visibleFor(detail)) a,
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<SubTrackDetailMenuAction>(
      key: const ValueKey('subTrackDetailMenu'),
      tooltip: l10n.subTrackDetailMoreOptions,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => action.onSelected(context, detail),
      itemBuilder: (context) => [
        for (final a in actions)
          PopupMenuItem(
            key: ValueKey('subTrackMenu:${a.id}'),
            value: a,
            child: Row(
              children: [
                Icon(a.icon, size: 20),
                const SizedBox(width: 12),
                Text(a.label(l10n)),
              ],
            ),
          ),
      ],
    );
  }
}
