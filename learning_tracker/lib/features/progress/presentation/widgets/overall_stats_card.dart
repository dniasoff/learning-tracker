import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Card displaying overall curriculum statistics (brand blue surface).
///
/// W5-A: adds a [DualStatsRow] header — "Track progress" (current-cycle
/// achievement) and "Lifetime" (% of items ever touched, including
/// lifetimeOnly imports). The legacy total/completed/in-progress/not-started
/// breakdown remains below. When [trackProgressFraction] or
/// [lifetimeFraction] is null (e.g. while data is loading) the row is
/// omitted so the card never renders a placeholder percentage.
class OverallStatsCard extends ConsumerWidget {
  const OverallStatsCard({
    super.key,
    required this.stats,
    this.trackProgressFraction,
    this.lifetimeFraction,
  });

  final OverallCurriculumStats stats;

  /// Current-cycle achievement: completedAllStages / totalItems. Rendered as
  /// "Track progress: X%" — null hides the row.
  final double? trackProgressFraction;

  /// Lifetime tier: distinct items ever touched / totalItems (includes bulk
  /// + lifetimeOnly + live). Rendered as "Lifetime: Y%" — null hides the row.
  final double? lifetimeFraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final showDualStats =
        trackProgressFraction != null || lifetimeFraction != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.brandBlueDeep,
            context.colors.brandBlue,
            context.colors.brandBlueBright,
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandBlue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.overallProgressCardTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (showDualStats) ...[
            const SizedBox(height: 12),
            DualStatsRow(
              trackLabel: l10n.trackProgress,
              trackFraction: trackProgressFraction,
              lifetimeLabel: l10n.lifetimeLabel,
              lifetimeFraction: lifetimeFraction,
            ),
            const SizedBox(height: 6),
            Divider(
              color: Colors.white.withValues(alpha: 0.22),
              height: 12,
              thickness: 1,
            ),
          ],
          const SizedBox(height: 8),
          _StatRow(
            label: l10n.overallProgressStatTotalItems,
            value: stats.totalItems,
          ),
          _StatRow(
            label: l10n.overallProgressStatCompletedAllStages,
            value: stats.completedAllStages,
            leadingDot: true,
          ),
          _StatRow(
            label: l10n.overallProgressStatInProgress,
            value: stats.inProgress,
            leadingDot: true,
          ),
          _StatRow(
            label: l10n.overallProgressStatNotStarted,
            value: stats.notStarted,
            leadingDot: true,
          ),
        ],
      ),
    );
  }
}

/// Two-column row of headline percentages.
///
/// Used inside [OverallStatsCard] to surface the two B1 lenses side-by-side:
/// **Track progress** (current cycle, achievement tier) and **Lifetime**
/// (% of items ever touched, lifetime tier). Either side may be `null` while
/// the underlying data is loading — those columns render an em-dash so the
/// row layout stays stable.
class DualStatsRow extends StatelessWidget {
  const DualStatsRow({
    super.key,
    required this.trackLabel,
    required this.trackFraction,
    required this.lifetimeLabel,
    required this.lifetimeFraction,
  });

  final String trackLabel;
  final double? trackFraction;
  final String lifetimeLabel;
  final double? lifetimeFraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DualStatCell(label: trackLabel, fraction: trackFraction),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DualStatCell(
            label: lifetimeLabel,
            fraction: lifetimeFraction,
          ),
        ),
      ],
    );
  }
}

class _DualStatCell extends StatelessWidget {
  const _DualStatCell({required this.label, required this.fraction});

  final String label;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Adaptive precision (matches the Lifetime Knowledge curriculum
    // breakdown): small non-zero fractions render "0.1%" instead of being
    // floored to "0%", so the same fraction reads consistently across the
    // Progress hub, track-detail and Lifetime Knowledge surfaces (Bug 3).
    final value = fraction == null ? '—' : formatFractionAsPercent(fraction!);
    // W5-A layout fix: stack the label above the percentage. Previously both
    // were a single inline "Label: 0%" string inside an equal-width Expanded
    // cell, so the longer "Track progress" headline wrapped to three cramped
    // lines beside the single-line "Lifetime: N%" cell. Separating the label
    // (which may wrap onto its own lines) from the big percentage value gives
    // the headline room and keeps the two cells visually balanced.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.leadingDot = false,
  });

  final String label;
  final int value;
  final bool leadingDot;

  static final _dotColor = Colors.white.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (leadingDot) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$value',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
