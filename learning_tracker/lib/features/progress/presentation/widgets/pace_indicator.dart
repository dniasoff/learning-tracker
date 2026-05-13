import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// Shows behind/on-track/ahead status badge for a curriculum goal.
class PaceIndicator extends StatelessWidget {
  const PaceIndicator({super.key, required this.paceStatus});

  final PaceStatus paceStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deltaLabel = switch (paceStatus.delta) {
      DateScheduleDelta(:final value) =>
        paceStatus.status == PaceStatusType.ahead
            ? 'Ahead by ${value.days} days'
            : 'Behind by ${value.days.abs()} days',
      PaceScheduleDelta(:final value) =>
        paceStatus.status == PaceStatusType.ahead
            ? 'Ahead by ${value.itemsPerWeek} items/week'
            : 'Behind by ${value.itemsPerWeek.abs()} items/week',
    };
    final (label, color, icon) = switch (paceStatus.status) {
      PaceStatusType.ahead => (
        deltaLabel,
        AppTheme.brandGold,
        Icons.trending_up_rounded,
      ),
      PaceStatusType.onPace => (
        'On pace',
        AppTheme.brandBlue,
        Icons.check_circle_outline_rounded,
      ),
      PaceStatusType.behind => (
        deltaLabel,
        AppTheme.brandCoralDeep,
        Icons.trending_down_rounded,
      ),
    };

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
      child: Row(
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
    );
  }
}
