/// The sub-track detail's lifecycle surface (Story 2.8 / DNI-499):
/// *Add next year* on a school year (AC-1, AC-2), the parent's ⋮ End /
/// Delete (AC-3, AC-4) and the read-only mode of an ended sub-track (AC-5).
///
/// INTERIM (DNI-499 seam): Story 2.6 / DNI-497 owns the sub-track detail
/// screen (window, Up next, capacity, ordered ground) with an overflow
/// action registry, and it is not on `integ/sub-tracks` yet. Until it is,
/// this screen hosts the lifecycle actions so they are reachable and
/// testable. When DNI-497 lands: register `subTrackLifecycleMenuActions`
/// in its ⋮ registry, mount [SubTrackLifecycleFooter] at the foot of its
/// body, route its hub rows there and delete this screen (bead
/// learning-tracker-fyh.208).
///
/// Read-only is decided from the stored row and the learner's today, never
/// from how the screen was reached, so a stale or deep link to an ended
/// sub-track shows no mutating action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/next_year_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_next_year_action.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_actions.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Pushes the lifecycle detail of [subTrackId].
Future<void> openSubTrackLifecycleDetail(
  BuildContext context,
  String subTrackId,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => SubTrackLifecycleDetailScreen(subTrackId: subTrackId),
  ),
);

/// The lifecycle detail of sub-track [subTrackId].
class SubTrackLifecycleDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubTrackLifecycleDetailScreen({super.key, required this.subTrackId});

  /// The sub-track ULID.
  final String subTrackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final groups = ref.watch(subTrackLifecycleGroupsProvider);
    final value = groups.value;
    SubTrack? track;
    var ended = false;
    if (value != null) {
      for (final t in value.all) {
        if (t.id == subTrackId) track = t;
      }
      ended = track != null && value.ended.contains(track);
    }
    final parent =
        ref.watch(subTrackLifecycleViewerProvider) ==
        SubTrackLifecycleViewer.parent;
    final found = track;
    return Scaffold(
      backgroundColor: colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: colors.surfaceF5,
        elevation: 0,
        title: Text(
          found?.name ?? '',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.brandBlueDeep,
          ),
        ),
        actions: [
          // AC-3, AC-4: the parent's ⋮ on a live sub-track only (AC-5).
          if (found != null && parent && !ended)
            SubTrackLifecycleMenu(
              track: found,
              onReturnToHub: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
      body: switch (groups) {
        AsyncValue(:final error?, :final stackTrace) when value == null =>
          AppErrorView(
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(subTrackLifecycleTracksProvider),
          ),
        _ when value == null => const Center(
          child: CircularProgressIndicator(),
        ),
        _ when found == null => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.subTrackLifecycleNotFound,
              key: const ValueKey('subTrackLifecycleNotFound'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => ListView(
          key: ValueKey('subTrackLifecycleDetail:$subTrackId'),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
          children: [
            if (ended) const _ReadOnlyNote(),
            _Summary(track: found),
            const SizedBox(height: 20),
            if (parent) SubTrackLifecycleFooter(track: found),
          ],
        ),
      },
    );
  }
}

/// The parent-only foot of a school-year detail: *Add next year*. Absent
/// for an ongoing or tombstoned sub-track.
class SubTrackLifecycleFooter extends ConsumerWidget {
  /// Creates the footer for [track].
  const SubTrackLifecycleFooter({super.key, required this.track});

  /// The detail's sub-track.
  final SubTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = track.academicYear;
    if (track.type != SubTrackType.schoolYear || year == null) {
      return const SizedBox.shrink();
    }
    final siblings = ref.watch(subTrackLifecycleTracksProvider).value;
    final availability = siblings == null
        ? NextYearAvailability.notOffered
        : nextYearAvailability(
            source: track,
            siblings: siblings,
            today: ref.watch(subTrackLifecycleTodayProvider),
            deadline: ref
                .watch(subTrackCurriculumDeadlineProvider(track.curriculumId))
                .value,
          );
    if (availability == NextYearAvailability.notOffered) {
      return const SizedBox.shrink();
    }
    return AddNextYearAction(
      nextAcademicYear: year + 1,
      availability: availability,
      onPressed: () => ref.read(subTrackNextYearFormProvider)(context, track),
    );
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: colors.brandInkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.subTrackLifecycleReadOnlyNote,
              key: const ValueKey('subTrackLifecycleReadOnly'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.brandInkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The academic year (school year) and the window.
class _Summary extends StatelessWidget {
  const _Summary({required this.track});

  final SubTrack track;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final format = DateFormat.yMMM(Localizations.localeOf(context).toString());
    final start = format.format(DateTime.parse(track.windowStart));
    final end = track.windowEnd;
    final window = end == null
        ? l10n.subTrackLifecycleWindowOpen(start)
        : l10n.subTrackLifecycleWindow(
            start,
            format.format(DateTime.parse(end)),
          );
    final year = track.academicYear;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.brandInk);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.brandCreamCard,
        border: Border.all(color: colors.brandOutline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (year != null)
            Text(
              subTrackAcademicYearLabel(year),
              key: const ValueKey('subTrackLifecycleYear'),
              style: style?.copyWith(fontWeight: FontWeight.w700),
            ),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: colors.brandBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  window,
                  key: const ValueKey('subTrackLifecycleWindow'),
                  style: style,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
