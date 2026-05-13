import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// Reusable stat box for [TrackStatGrid]. Becomes a no-op (greyed-out) when
/// [onTap] is null — the parent decides whether the count makes the box
/// actionable.
class TaskCategoryStatBox extends StatelessWidget {
  const TaskCategoryStatBox({
    super.key,
    required this.count,
    required this.label,
    required this.valueColor,
    required this.valueBg,
    required this.labelStyle,
    this.countMutedWhenZero = false,
    this.onTap,
  });

  final int count;
  final String label;
  final Color valueColor;
  final Color valueBg;
  final TextStyle? labelStyle;
  final bool countMutedWhenZero;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor = countMutedWhenZero && count == 0
        ? AppTheme.brandInk
        : valueColor;
    return Material(
      color: valueBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Column(
            children: [
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: displayColor,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: labelStyle?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                  height: 1.1,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
