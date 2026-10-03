import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_type_chooser.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The Sub-tracks group under one curriculum's main-track card in Settings →
/// Manage tracks (Story 2.4 / DNI-495, screens.md #04).
///
/// - Parent session only (AC-3): a child without the parent PIN sees no
///   group, row or *Add sub-track* at all. It also stays inert (absent)
///   while the Story 2.1 commands are not available for the learner.
/// - Absent on a calendar-program curriculum (AC-2, AD-45).
/// - Header "Sub-tracks · {n} active", the helper, one outlined row per
///   non-ended sub-track, the recomputed daily target and *Add sub-track*
///   (AC-1). With no sub-tracks, only the header and *Add sub-track*
///   (UX-DR-117).
/// - A load error shows the shared [AppErrorView] with retry (UX-DR-118),
///   inside the group, so the main-track list keeps working.
/// - Tapping a row opens the sub-track detail (Story 2.6 / DNI-497 AC-1,
///   UX-DR-53): pushed on a phone; inside the >=840dp split the row is
///   selected and the detail pane updates in place. Metadata *Edit* is in
///   the detail's ⋮.
class SubTrackHubSection extends ConsumerWidget {
  const SubTrackHubSection({required this.curriculumId, super.key});

  /// The curriculum (storage key) whose sub-tracks this group lists.
  final String curriculumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(subTrackParentSessionProvider).value != true) {
      return const SizedBox.shrink();
    }
    // Inert until the Story 2.1 commands are live for this learner (ruling:
    // "the sub-track entry point stays inert until 2.1 commands are live").
    if (ref.watch(learningCommandsProvider).value == null) {
      return const SizedBox.shrink();
    }
    final intent = ref.watch(subTrackCurriculumIntentProvider(curriculumId));
    final tracks = ref.watch(learnerSubTracksProvider);
    // No main track for this curriculum in the governed intent: no group
    // (fail closed; nothing to add a sub-track to).
    if (intent.error is SubTrackMainTrackNotFoundException) {
      return const SizedBox.shrink();
    }
    final failed = intent.hasError ? intent : (tracks.hasError ? tracks : null);
    if (failed != null) {
      return AppErrorView(
        error: failed.error!,
        stackTrace: failed.stackTrace,
        onRetry: () {
          ref
            ..invalidate(subTrackCurriculumIntentProvider(curriculumId))
            ..invalidate(learnerSubTracksProvider);
        },
      );
    }
    final intentValue = intent.value;
    final all = tracks.value;
    // Loading: render nothing rather than flash Add on a calendar curriculum.
    if (intentValue == null || all == null) return const SizedBox.shrink();
    if (intentValue.followsCalendarProgram) return const SizedBox.shrink();

    final live = [
      for (final s in all)
        if (s.curriculumId == curriculumId && !s.isEnded) s,
    ];
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final selected = ref.watch(subTrackHubSelectionProvider);
    final dailyTarget = ref
        .watch(activeLearnerStateProvider)
        .value?[curriculumId]
        ?.dailyTarget;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.subTrackHubHeader(live.length),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.brandInk,
            ),
          ),
          if (live.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.subTrackHubHelper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.brandInkMuted,
              ),
            ),
            const SizedBox(height: 8),
            for (final s in live)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: SubTrackHubRow(
                  track: s,
                  selected: s.id == selected,
                  onTap: () => openSubTrackDetail(context, ref, s.id),
                ),
              ),
            if (dailyTarget != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 4),
                child: Text(
                  l10n.subTrackHubDailyTarget(
                    dailyTarget,
                    subTrackLeafUnitLabel(ref, curriculumId).toLowerCase(),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.brandBlueDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => SubTrackTypeChooser.show(
              context,
              onSchoolYear: () => context.router.push(
                SchoolYearSubTrackFormRoute(curriculumId: curriculumId),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(l10n.subTrackHubAdd),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: const StadiumBorder(),
              side: BorderSide(color: colors.brandOutline),
            ),
          ),
        ],
      ),
    );
  }
}

/// One sub-track row: a flat card with a 1px outline at elevation 0
/// (UX-DR-15, UX-DR-150), its name and a type/window/rate subtitle.
///
/// [selected] marks the sub-track whose detail the >=840dp split shows
/// (UX-DR-163, UX-DR-164); the chevron follows the text direction, so it
/// mirrors in RTL (UX-DR-161).
class SubTrackHubRow extends StatelessWidget {
  const SubTrackHubRow({
    required this.track,
    this.onTap,
    this.selected = false,
    super.key,
  });

  /// The sub-track.
  final SubTrack track;

  /// Opens the sub-track's detail; null renders the row inert.
  final VoidCallback? onTap;

  /// Whether this row is the hub's selected sub-track.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final rate = formatFormNumber(track.ratePerWeek);
    final String subtitle;
    if (track.type == SubTrackType.schoolYear) {
      final months = DateFormat.MMM(
        Localizations.localeOf(context).toLanguageTag(),
      );
      String month(String date) => months.format(DateTime.parse(date));
      subtitle = l10n.subTrackRowSchoolYearSubtitle(
        month(track.windowStart),
        month(track.windowEnd ?? track.windowStart),
        rate,
      );
    } else {
      subtitle = l10n.subTrackRowOngoingSubtitle(rate);
    }
    return Card(
      elevation: 0,
      margin: EdgeInsetsDirectional.zero,
      color: colors.brandCreamCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.brandOutline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('subTrackHubRow:${track.id}'),
        minTileHeight: 56,
        selected: selected,
        selectedTileColor: colors.brandBlue.withValues(alpha: 0.12),
        onTap: onTap,
        leading: Icon(
          track.type == SubTrackType.schoolYear
              ? Icons.school_outlined
              : Icons.repeat,
          color: colors.brandBlueDeep,
        ),
        title: Text(
          track.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.brandInk,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.brandInkMuted,
          ),
        ),
        trailing: onTap == null
            ? null
            : Icon(Icons.chevron_right, color: colors.brandInkMuted),
      ),
    );
  }
}

/// Shows "Your change couldn't be saved." once per sub-track batch the
/// server permanently refuses after it was queued (UX-DR-119, UX-DR-121).
/// The refused row itself disappears because the local cache rolls the
/// write back; this only reports it. Mount it once per Manage tracks hub.
class SubTrackSyncRejectionListener extends ConsumerStatefulWidget {
  const SubTrackSyncRejectionListener({
    this.child = const SizedBox.shrink(),
    super.key,
  });

  /// What it wraps; by default nothing (it can sit in a list as a
  /// zero-size listener).
  final Widget child;

  @override
  ConsumerState<SubTrackSyncRejectionListener> createState() =>
      _SubTrackSyncRejectionListenerState();
}

class _SubTrackSyncRejectionListenerState
    extends ConsumerState<SubTrackSyncRejectionListener> {
  final _reported = <String>{};

  @override
  Widget build(BuildContext context) {
    ref.listen(subTrackPendingFailuresProvider, (_, next) {
      final failures = next.value ?? const [];
      final fresh = [
        for (final f in failures)
          if (_reported.add(f.id)) f,
      ];
      if (fresh.isEmpty || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.subTrackSyncRejected),
        ),
      );
    });
    return widget.child;
  }
}
