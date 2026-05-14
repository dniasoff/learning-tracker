import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// A tappable overlay that blurs and dims [child] when the goal option it
/// represents is not the currently active mode, showing [hint] instead.
class BlurInactiveGoalOption extends StatelessWidget {
  const BlurInactiveGoalOption({
    required this.hint,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String hint;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: hint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: Opacity(
                    opacity: 0.4,
                    child: AbsorbPointer(child: child),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.94),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandBlueDeep,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pace target card — lets the user pick a unit, cadence and numeric value.
class PaceGoalCard extends StatelessWidget {
  const PaceGoalCard({
    required this.isActive,
    required this.paceValue,
    required this.pacePeriod,
    required this.unitSingular,
    required this.unitPlural,
    required this.hasUnitChoice,
    required this.coarseKey,
    required this.coarseLabel,
    required this.fineKey,
    required this.fineLabel,
    required this.paceGranularity,
    required this.projectedFinishLabel,
    required this.onPaceDecrease,
    required this.onPaceIncrease,
    required this.onPaceUnitChanged,
    required this.onPaceGranularityChanged,
    super.key,
  });

  final bool isActive;
  final int paceValue;
  final String pacePeriod;
  final String unitSingular;
  final String unitPlural;
  final bool hasUnitChoice;
  final String coarseKey;
  final String coarseLabel;
  final String? fineKey;
  final String? fineLabel;
  final String paceGranularity;
  final String projectedFinishLabel;
  final VoidCallback onPaceDecrease;
  final VoidCallback onPaceIncrease;
  final ValueChanged<String> onPaceUnitChanged;
  final ValueChanged<String> onPaceGranularityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? AppTheme.brandBlueBright : const Color(0xFFE9ECF2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFE5E9FF),
                  child: Icon(
                    Icons.speed_rounded,
                    size: 16,
                    color: AppTheme.brandBlueDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.goalTargetPace,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.goalPaceDescriptionLine(
                unitPlural,
                pacePeriod == 'per_day' ? l10n.pacePerDay : l10n.pacePerWeek,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.brandInkMuted,
              ),
            ),
            if (hasUnitChoice && fineKey != null && fineLabel != null) ...[
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: coarseKey, label: Text(coarseLabel)),
                  ButtonSegment(value: fineKey!, label: Text(fineLabel!)),
                ],
                selected: {paceGranularity},
                onSelectionChanged: (v) => onPaceGranularityChanged(v.first),
              ),
            ],
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'per_day', label: Text(l10n.pacePerDay)),
                ButtonSegment(value: 'per_week', label: Text(l10n.pacePerWeek)),
              ],
              selected: {pacePeriod},
              onSelectionChanged: (v) => onPaceUnitChanged(v.first),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: onPaceDecrease,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$paceValue',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onPaceIncrease,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            Text(
              l10n.goalEstimatedFinish(projectedFinishLabel),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.brandInkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deadline card — lets the user pick a target date and shows pace estimate.
class DeadlineGoalCard extends StatelessWidget {
  const DeadlineGoalCard({
    required this.isActive,
    required this.deadline,
    required this.dateLabel,
    required this.useHebrew,
    required this.studyDaysInWindow,
    required this.itemsPerStudyDay,
    required this.totalScopeItems,
    required this.scopeIsLoading,
    required this.unitLabel,
    required this.onTapDate,
    required this.l10n,
    super.key,
  });

  final bool isActive;
  final DateTime? deadline;
  final String dateLabel;
  final bool useHebrew;
  final int studyDaysInWindow;
  final int itemsPerStudyDay;
  final int totalScopeItems;
  final bool scopeIsLoading;
  final String unitLabel;
  final VoidCallback onTapDate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? AppTheme.brandBlueBright : const Color(0xFFE9ECF2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFF9E4C8),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: Color(0xFF7D5411),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.goalSetDeadline,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: onTapDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      dateLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isActive
                            ? AppTheme.brandInk
                            : AppTheme.brandInkMuted,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 17,
                      color: AppTheme.brandInkMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (deadline != null) ...[
              const SizedBox(height: 8),
              if (scopeIsLoading)
                Text(
                  l10n.addTrackGoalDeadlinePaceLineLoading,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (studyDaysInWindow <= 0)
                Text(
                  l10n.addTrackGoalDeadlineNoStudyDaysInWindow,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  l10n.addTrackGoalDeadlinePaceLine(
                    itemsPerStudyDay,
                    unitLabel,
                    studyDaysInWindow,
                    totalScopeItems,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
