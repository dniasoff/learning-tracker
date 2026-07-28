import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Horizontal scrollable filter row for selecting which track's achievements
/// to display. Includes an "All" chip and one chip per track.
class TrackFilterRow extends StatelessWidget {
  const TrackFilterRow({
    super.key,
    required this.l10n,
    required this.options,
    required this.selectedTrackId,
    required this.onSelectAll,
    required this.onSelectTrack,
    required this.labelFor,
  });

  final AppLocalizations l10n;
  final List<AchievementTrackFilterVm> options;
  final int? selectedTrackId;
  final VoidCallback onSelectAll;
  final void Function(int trackId) onSelectTrack;
  final String Function(AchievementTrackFilterVm o) labelFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.achievementsTrackSection,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: context.colors.brandCoral,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AchievementFilterChip(
                label: l10n.achievementsAllTracks,
                selected: selectedTrackId == null,
                onTap: onSelectAll,
              ),
              for (final o in options) ...[
                const SizedBox(width: 8),
                AchievementFilterChip(
                  label: labelFor(o),
                  selected: selectedTrackId == o.trackId,
                  onTap: () => onSelectTrack(o.trackId),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Single selectable filter chip used inside [TrackFilterRow].
class AchievementFilterChip extends StatelessWidget {
  const AchievementFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static Color _kBrandBlue(BuildContext context) => context.colors.brandBlue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            // AUD-darkmode: the unselected chip fill was a hardcoded
            // Colors.white, but its ink (inkSlate) LIGHTENS in dark mode
            // (documented as "text on white cards") -- near-white-on-white,
            // ~1:1 in dark. brandCreamCard is the actual card surface token
            // and darkens correctly, restoring ~15:1.
            color: selected
                ? _kBrandBlue(context)
                : context.colors.brandCreamCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? _kBrandBlue(context)
                  : context.colors.gamifTrackFilterChipUnselected,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.colors.gamifTrackFilterChipShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              // AUD-darkmode: brandBlue lightens in dark mode, so a
              // hardcoded white label on the selected fill measured 2.52:1.
              // colorScheme.onPrimary is the same dynamically-computed
              // contrast-safe ink FilledButton already uses for this exact
              // accent colour.
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : context.colors.inkSlate,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
