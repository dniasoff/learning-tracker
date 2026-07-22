import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/stat_card.dart';

/// Reusable stat box for [TrackStatGrid]. Becomes a no-op (greyed-out) when
/// [onTap] is null — the parent decides whether the count makes the box
/// actionable.
///
/// Delegates to [StatCard] (compact variant — no icon) for its rendering so
/// that all stat-card family widgets share one primitive (DNI-359 / 26.16).
class TaskCategoryStatBox extends StatelessWidget {
  const TaskCategoryStatBox({
    super.key,
    required this.count,
    required this.label,
    required this.valueColor,
    required this.valueBg,
    this.countMutedWhenZero = false,
    this.onTap,
  });

  final int count;
  final String label;
  final Color valueColor;
  final Color valueBg;
  final bool countMutedWhenZero;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayColor = countMutedWhenZero && count == 0
        ? context.colors.brandInk
        : valueColor;

    // Forward to the StatCard compact variant (no icon).
    return StatCard(
      // No icon → compact layout
      value: '$count',
      label: label,
      cardColor: valueBg,
      valueColor: displayColor,
      labelColor: context.colors.brandInkMuted,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      onTap: onTap,
    );
  }
}
