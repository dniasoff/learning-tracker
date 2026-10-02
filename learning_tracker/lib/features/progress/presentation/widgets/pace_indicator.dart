import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows the engine's finish projection for a curriculum goal (AD-35,
/// DNI-474): on pace, behind pace, or too early to tell (under 14 days of
/// tracked history). The status is text, never colour alone.
///
/// Optional [subtitleCaption] renders a small disambiguating line under the
/// badge.
class ProgressPaceIndicator extends StatelessWidget {
  const ProgressPaceIndicator({
    super.key,
    required this.projection,
    this.subtitleCaption,
  });

  final Projection projection;
  final String? subtitleCaption;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final (
      String label,
      Color color,
      IconData icon,
    ) = switch (projection.status) {
      ProjectionStatus.onTrack || ProjectionStatus.noDeadline => (
        l10n.paceOnTrack,
        context.colors.brandBlue,
        Icons.check_circle_outline_rounded,
      ),
      ProjectionStatus.behindPace => (
        l10n.learnerProgressPaceBehind,
        context.colors.brandCoralDeep,
        Icons.trending_down_rounded,
      ),
      ProjectionStatus.tooEarly => (
        l10n.learnerProgressPaceTooEarly,
        context.colors.brandBlue,
        Icons.hourglass_empty_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.brandOutline.withValues(alpha: 0.35),
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
                    color: context.colors.brandInk,
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
                  color: context.colors.brandInkMuted,
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
