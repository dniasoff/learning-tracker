import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_route.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_start_status.dart';
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
/// - Tapping a school-year row opens its edit form, an ongoing row the
///   ongoing edit form (Story 2.5 / DNI-496 AC-6; Story 2.6 later routes
///   rows to the detail screen).
/// - *Add sub-track* → *Ongoing* opens the ongoing form (DNI-496 AC-1). The
///   chooser shows the curriculum's AD-45 ongoing usage and disables
///   Ongoing at five (AC-5); until that count has loaded, Ongoing stays
///   disabled (fail closed).
/// - An ongoing row that has not started yet reads "Starts {date}"
///   (DNI-496 AC-4, UX-DR-89), judged on the learner's civil today.
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
    final dailyTarget = ref
        .watch(activeLearnerStateProvider)
        .value?[curriculumId]
        ?.dailyTarget;
    // The ongoing usage and the learner's civil today (AD-41), as the
    // ongoing form reads them (DNI-496).
    final ongoing = ref.watch(ongoingSubTrackContextProvider(curriculumId));
    final ongoingRead = ongoing.hasError ? null : ongoing.value;

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
                  today: ongoingRead?.today,
                  onTap: switch (s.type) {
                    SubTrackType.schoolYear => () => context.router.push(
                      SchoolYearSubTrackFormRoute(
                        curriculumId: curriculumId,
                        subTrackId: s.id,
                      ),
                    ),
                    SubTrackType.ongoing => () => unawaited(
                      openOngoingSubTrackForm(
                        context,
                        curriculumId: curriculumId,
                        subTrackId: s.id,
                      ),
                    ),
                  },
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
              onOngoing: ongoingRead == null
                  ? null
                  : () => unawaited(
                      openOngoingSubTrackForm(
                        context,
                        curriculumId: curriculumId,
                      ),
                    ),
              ongoingInUse: ongoingRead?.ongoingInUse(),
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
/// (UX-DR-15, UX-DR-150), its name and a type/window/rate subtitle. An
/// ongoing row that starts after [today] reads "Starts {date}" instead
/// (DNI-496 AC-4, UX-DR-89).
class SubTrackHubRow extends StatelessWidget {
  const SubTrackHubRow({
    required this.track,
    this.onTap,
    this.today,
    super.key,
  });

  /// The sub-track.
  final SubTrack track;

  /// The learner's civil today, or null while it is unknown (no "Starts"
  /// status then).
  final CivilDate? today;

  /// Opens the sub-track; null when its form is not available yet.
  final VoidCallback? onTap;

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
      final day = today;
      subtitle =
          (day == null ? null : subTrackStartsLabel(context, track, day)) ??
          l10n.subTrackRowOngoingSubtitle(rate);
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
        minTileHeight: 56,
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
