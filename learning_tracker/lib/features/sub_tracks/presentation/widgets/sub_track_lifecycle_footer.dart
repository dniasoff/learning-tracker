/// Story 2.8 (DNI-499) pieces of DNI-497's sub-track detail body: the
/// parent's *Add next year* footer on a school year (AC-1, AC-2) and the
/// read-only note of an ended sub-track (AC-5).
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_next_year_action.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Opens the *Add next year* form for [source]; completes with true when a
/// new sub-track was saved.
typedef SubTrackNextYearForm =
    Future<bool> Function(BuildContext context, SubTrack source);

/// The form behind *Add next year*: Story 2.4's (DNI-495) school-year form
/// in its next-year mode, prefilled from [nextYearSubTrackDraft] and saving
/// a new sub-track through `createSubTrack(addNextYear: true)`. A seam so
/// the detail tests can observe the pill without the whole form.
final subTrackNextYearFormProvider = Provider<SubTrackNextYearForm>(
  (ref) => openNextYearSubTrackForm,
);

/// Pushes the school-year form for the year after [source].
Future<bool> openNextYearSubTrackForm(
  BuildContext context,
  SubTrack source,
) async =>
    await context.router.push<bool>(
      SchoolYearSubTrackFormRoute(
        curriculumId: source.curriculumId,
        nextYearOf: source.id,
      ),
    ) ??
    false;

/// The parent-only foot of a school-year detail: *Add next year*. Absent
/// for an ongoing or tombstoned sub-track; the host mounts it for the
/// parent only.
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
    // Story 2.4's complete read and governed intent (DNI-495). Until both
    // are in (or when either failed) there is no pill: fail closed.
    final siblings = ref.watch(learnerSubTracksProvider).value;
    final intent = ref
        .watch(subTrackCurriculumIntentProvider(track.curriculumId))
        .value;
    final availability = siblings == null || intent == null
        ? NextYearAvailability.notOffered
        : nextYearAvailability(
            source: track,
            siblings: siblings,
            today: ref.watch(subTrackLifecycleTodayProvider),
            deadline: intent.deadline,
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

/// "This sub-track has ended. It can't be changed." above an ended
/// sub-track's detail (AC-5, UX-DR-82).
class SubTrackEndedNote extends StatelessWidget {
  /// Creates the note.
  const SubTrackEndedNote({super.key});

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
