import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashed_rounded_border_painter.dart';

class CompactMissionCard extends StatelessWidget {
  const CompactMissionCard({
    super.key,
    required this.label,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.labelColor,
    this.titleColor,
    this.dashedBorder = false,
  });

  final String label;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? labelColor;
  final Color? titleColor;
  final bool dashedBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = Ink(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(20),
        border: dashedBorder
            ? null
            : Border.all(
                color:
                    borderColor ??
                    AppTheme.brandOutline.withValues(alpha: 0.45),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: labelColor ?? AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 36,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (dashedBorder) {
      content = CustomPaint(
        painter: DashedRoundedBorderPainter(
          color: borderColor ?? theme.colorScheme.error,
          borderRadius: 20,
          strokeWidth: 1.3,
        ),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
