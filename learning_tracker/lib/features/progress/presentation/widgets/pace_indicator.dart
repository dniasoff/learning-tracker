import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows behind/on-track/ahead/graceWindow status badge for a curriculum goal.
///
/// Accepts a [PaceCalculator] from the progress domain so that the grace-window
/// state (day 0 / day 1) can be surfaced correctly without showing a phantom
/// "Ahead by 0 days" or "Behind by 0 days" on the first day.
///
/// Optional [subtitleCaption] renders a small disambiguating line under the
/// badge — used by the Curriculum Progress screen to clarify that pace only
/// reflects live (engagement-tier) learning, not bulk-mark / lifetime imports.
class PaceIndicator extends StatelessWidget {
  const PaceIndicator({super.key, required this.pace, this.subtitleCaption});

  final PaceCalculator pace;
  final String? subtitleCaption;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Derive label and visual style from the canonical PaceStatus enum.
    final String label;
    final Color color;
    final IconData icon;

    switch (pace.paceStatus) {
      case PaceStatus.graceWindow:
        label = l10n.paceOnTrack;
        color = AppTheme.brandBlue;
        icon = Icons.check_circle_outline_rounded;
      case PaceStatus.onTrack:
        label = l10n.paceOnTrack;
        color = AppTheme.brandBlue;
        icon = Icons.check_circle_outline_rounded;
      case PaceStatus.ahead:
        final days = pace.paceVarianceInDays.abs().round();
        label = l10n.paceAheadByDays(days);
        color = AppTheme.brandGold;
        icon = Icons.trending_up_rounded;
      case PaceStatus.behind:
        final days = pace.paceVarianceInDays.abs().round();
        label = l10n.paceBehindByDays(days);
        color = AppTheme.brandCoralDeep;
        icon = Icons.trending_down_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.brandOutline.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.flag_outlined,
                size: 20,
                color: color.withValues(alpha: 0.85),
              ),
            ],
          ),
          if (subtitleCaption != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 58),
              child: Text(
                subtitleCaption!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
