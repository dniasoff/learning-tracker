import 'package:flutter/material.dart';
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
/// [schoolYearAvailable] is false while the Story 2.4 (DNI-495) school-year
/// form is not on the branch: the option is then left out rather than
/// offered and broken.
Future<AddSubTrackChoice?> showAddSubTrackChooser(
  BuildContext context, {
  bool schoolYearAvailable = false,
}) => showModalBottomSheet<AddSubTrackChoice>(
  context: context,
  showDragHandle: true,
  builder: (_) => AddSubTrackChooser(schoolYearAvailable: schoolYearAvailable),
);

/// The *Add sub-track* chooser: School year and Ongoing (screens.md #04).
class AddSubTrackChooser extends StatelessWidget {
  const AddSubTrackChooser({super.key, this.schoolYearAvailable = false});

  /// Whether the school-year option is offered (see
  /// [showAddSubTrackChooser]).
  final bool schoolYearAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
          ListTile(
            key: const ValueKey('addSubTrackOngoing'),
            minTileHeight: 56,
            leading: const Icon(Icons.all_inclusive),
            title: Text(l10n.ongoingSubTrackChooserOngoing),
            subtitle: Text(l10n.ongoingSubTrackChooserOngoingHelper),
            onTap: () => Navigator.of(context).pop(AddSubTrackChoice.ongoing),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
