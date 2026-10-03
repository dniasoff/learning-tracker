import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_validation.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The *Add sub-track* type chooser (screens.md #04): *School year* and
/// *Ongoing*.
///
/// A separate widget so later sub-track stories plug their form in without
/// touching the hub section (orchestrator merge-hotspot ruling): Story 2.5
/// (DNI-496) passes [onOngoing]. An option without a handler stays visible
/// but disabled and announced as disabled (UX-DR-36, UX-DR-158).
///
/// [ongoingInUse] is the curriculum's count of ongoing sub-tracks that
/// count toward the AD-45 cap (non-ended, on Home or future-start; ended
/// and expired ones are not counted, UX-DR-82). When given, the chooser
/// shows "You can have up to 5 ongoing sub-tracks. {n} in use." and, at
/// five, keeps Ongoing visible but disabled (DNI-496 AC-5, UX-DR-103). The
/// authoritative check stays in `LearningCommands` and
/// `writeWithChangeLog` (AD-45).
class SubTrackTypeChooser extends StatelessWidget {
  const SubTrackTypeChooser({
    required this.onSchoolYear,
    this.onOngoing,
    this.ongoingInUse,
    super.key,
  });

  /// Opens the school-year form.
  final VoidCallback onSchoolYear;

  /// Opens the ongoing form, once it exists (DNI-496).
  final VoidCallback? onOngoing;

  /// Counting ongoing sub-tracks of the curriculum, or null when unknown
  /// (no usage line).
  final int? ongoingInUse;

  /// Shows the chooser as a bottom sheet over [context].
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSchoolYear,
    VoidCallback? onOngoing,
    int? ongoingInUse,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SubTrackTypeChooser(
        onSchoolYear: () {
          Navigator.of(sheetContext).pop();
          onSchoolYear();
        },
        onOngoing: onOngoing == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onOngoing();
              },
        ongoingInUse: ongoingInUse,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final inUse = ongoingInUse;
    final ongoingAllowed = inUse == null || ongoingCreateAllowed(inUse);
    Widget option(IconData icon, String label, VoidCallback? onTap) {
      final tile = ListTile(
        minTileHeight: 56,
        leading: Icon(icon, color: colors.brandBlueDeep),
        title: Text(label),
        enabled: onTap != null,
        onTap: onTap,
      );
      return onTap == null ? Opacity(opacity: 0.4, child: tile) : tile;
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            Icons.school_outlined,
            l10n.subTrackTypeSchoolYear,
            onSchoolYear,
          ),
          option(
            Icons.repeat,
            l10n.subTrackTypeOngoing,
            ongoingAllowed ? onOngoing : null,
          ),
          if (inUse != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Text(
                l10n.ongoingSubTrackLimitLine(inUse),
                key: const ValueKey('subTrackChooserOngoingLimitLine'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.brandInkMuted),
              ),
            ),
        ],
      ),
    );
  }
}
