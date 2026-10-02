import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// "2026–27" for academic year 2026.
String academicYearLabel(int year) =>
    '$year–${((year + 1) % 100).toString().padLeft(2, '0')}';

/// The academic-year picker (UX-DR-32): a single-select row of year chips,
/// each with a *Used*, *Active* or *Open* state label.
///
/// A *Used* chip is a `Disabled action` (UX-DR-36): it stays in place at
/// full size and 40% opacity, does nothing on tap, and remains in the
/// semantics tree announced as disabled (UX-DR-158). The chips wrap onto
/// more lines instead of clipping at large text (UX-DR-156).
class AcademicYearPicker extends StatelessWidget {
  const AcademicYearPicker({
    required this.years,
    required this.states,
    required this.selected,
    required this.onSelected,
    this.errorText,
    super.key,
  });

  /// The offered years, ascending.
  final List<int> years;

  /// The state of each offered year.
  final Map<int, AcademicYearState> states;

  /// The selected year, if any.
  final int? selected;

  /// Called with a newly selected (non-used) year.
  final ValueChanged<int> onSelected;

  /// The inline error under the row, if any.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final year in years)
              _YearChip(
                label: academicYearLabel(year),
                stateLabel: switch (states[year] ?? AcademicYearState.open) {
                  AcademicYearState.used => l10n.subTrackYearUsed,
                  AcademicYearState.active => l10n.subTrackYearActive,
                  AcademicYearState.open => l10n.subTrackYearOpen,
                },
                used: states[year] == AcademicYearState.used,
                selected: selected == year,
                onSelected: () => onSelected(year),
              ),
          ],
        ),
        if (errorText case final error?)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.label,
    required this.stateLabel,
    required this.used,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String stateLabel;
  final bool used;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final chip = ChoiceChip(
      selected: selected,
      onSelected: used ? null : (_) => onSelected(),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(
        color: selected ? colors.brandBlue : colors.brandOutline,
      ),
      backgroundColor: colors.brandCreamCard,
      selectedColor: colors.brandBlueSoft,
      disabledColor: colors.brandCreamCard,
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: used ? colors.brandInkMuted : colors.brandInk,
            ),
          ),
          Text(
            stateLabel,
            style: textTheme.labelSmall?.copyWith(
              color: used ? colors.brandInkMuted : colors.brandBlueDeep,
            ),
          ),
        ],
      ),
    );
    return used ? Opacity(opacity: 0.4, child: chip) : chip;
  }
}
