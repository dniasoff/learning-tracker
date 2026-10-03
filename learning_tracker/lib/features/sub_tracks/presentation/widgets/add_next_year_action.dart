/// *Add next year* (Story 2.8 / DNI-499, AC-1, AC-2; UX-DR-28, UX-DR-36,
/// UX-DR-158): the outlined pill at the foot of a school-year sub-track
/// detail. When the next academic year is used or past the picker it stays
/// in place at full size, muted, without a ripple, and is announced as
/// disabled with the reason as its hint.
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/academic_year_picker.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The *Add next year ({Y+1}–{Y+2 short})* pill.
class AddNextYearAction extends StatelessWidget {
  /// Creates the pill for rolling a school year into [nextAcademicYear].
  const AddNextYearAction({
    super.key,
    required this.nextAcademicYear,
    required this.availability,
    required this.onPressed,
  });

  /// The academic year the copy is for (`academic_year + 1`).
  final int nextAcademicYear;

  /// Whether the pill is enabled, and why not.
  final NextYearAvailability availability;

  /// Opens the prefilled school-year form.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final yearLabel = academicYearLabel(nextAcademicYear);
    final enabled = availability == NextYearAvailability.available;
    final reason = switch (availability) {
      NextYearAvailability.yearUsed => l10n.subTrackLifecycleAddNextYearUsed(
        yearLabel,
      ),
      NextYearAvailability.beyondPickerRange =>
        l10n.subTrackLifecycleAddNextYearOutOfRange(yearLabel),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          hint: reason,
          child: Opacity(
            // DESIGN.md "Disabled action": 40% opacity, same size.
            opacity: enabled ? 1 : 0.4,
            child: OutlinedButton.icon(
              key: const ValueKey('subTrackAddNextYear'),
              onPressed: enabled ? onPressed : null,
              icon: const Icon(Icons.add),
              label: Text(l10n.subTrackLifecycleAddNextYear(yearLabel)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                foregroundColor: colors.brandBlueDeep,
                disabledForegroundColor: colors.brandInkMuted,
                side: BorderSide(color: colors.brandOutline),
                splashFactory: enabled ? null : NoSplash.splashFactory,
              ),
            ),
          ),
        ),
        if (reason != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
            child: ExcludeSemantics(
              child: Text(
                reason,
                key: const ValueKey('subTrackAddNextYearReason'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.brandInkMuted),
              ),
            ),
          ),
      ],
    );
  }
}
