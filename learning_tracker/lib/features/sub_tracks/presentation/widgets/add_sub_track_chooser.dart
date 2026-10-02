import 'package:flutter/material.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_validation.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The type the parent picked in the *Add sub-track* chooser.
enum AddSubTrackChoice {
  /// A school-year sub-track (Story 2.4 form).
  schoolYear,

  /// An ongoing sub-track (Story 2.5 form).
  ongoing,
}

/// Shows the *Add sub-track* type chooser as a bottom sheet and resolves to
/// the picked type, or null when dismissed.
///
/// [ongoingInUse] is the curriculum's count of ongoing sub-tracks that
/// count toward the AD-45 cap; at the cap Ongoing stays visible but is
/// disabled (DNI-496 AC-5). [schoolYearAvailable] is false while the
/// Story 2.4 (DNI-495) school-year form is not on the branch: the option
/// is then left out rather than offered and broken.
Future<AddSubTrackChoice?> showAddSubTrackChooser(
  BuildContext context, {
  required int ongoingInUse,
  bool schoolYearAvailable = false,
}) => showModalBottomSheet<AddSubTrackChoice>(
  context: context,
  showDragHandle: true,
  builder: (_) => AddSubTrackChooser(
    ongoingInUse: ongoingInUse,
    schoolYearAvailable: schoolYearAvailable,
  ),
);

/// The *Add sub-track* chooser: School year and Ongoing (screens.md #04).
///
/// At five counting ongoing sub-tracks, Ongoing is disabled but kept: 40%
/// opacity, no ripple, full touch size, still in the semantics tree and
/// announced "disabled", with "You can have up to 5 ongoing sub-tracks.
/// 5 in use." (UX-DR-36, UX-DR-103, UX-DR-158). Ended and expired
/// sub-tracks are not in [ongoingInUse] (UX-DR-82). The authoritative
/// check stays in `LearningCommands` and `writeWithChangeLog` (AD-45).
class AddSubTrackChooser extends StatelessWidget {
  const AddSubTrackChooser({
    super.key,
    required this.ongoingInUse,
    this.schoolYearAvailable = false,
  });

  /// Counting ongoing sub-tracks of the curriculum.
  final int ongoingInUse;

  /// Whether the school-year option is offered (see
  /// [showAddSubTrackChooser]).
  final bool schoolYearAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ongoingEnabled = ongoingCreateAllowed(ongoingInUse);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
            child: Text(
              l10n.ongoingSubTrackChooserTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (schoolYearAvailable)
            ListTile(
              key: const ValueKey('addSubTrackSchoolYear'),
              minTileHeight: 56,
              leading: const Icon(Icons.school_outlined),
              title: Text(l10n.ongoingSubTrackChooserSchoolYear),
              onTap: () =>
                  Navigator.of(context).pop(AddSubTrackChoice.schoolYear),
            ),
          Semantics(
            enabled: ongoingEnabled,
            child: Opacity(
              opacity: ongoingEnabled ? 1 : 0.4,
              child: ListTile(
                key: const ValueKey('addSubTrackOngoing'),
                minTileHeight: 56,
                enabled: ongoingEnabled,
                leading: const Icon(Icons.all_inclusive),
                title: Text(l10n.ongoingSubTrackChooserOngoing),
                subtitle: Text(l10n.ongoingSubTrackChooserOngoingHelper),
                onTap: ongoingEnabled
                    ? () => Navigator.of(context).pop(AddSubTrackChoice.ongoing)
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 24, 16),
            child: Text(
              l10n.ongoingSubTrackLimitLine(ongoingInUse),
              key: const ValueKey('addSubTrackOngoingLimitLine'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
