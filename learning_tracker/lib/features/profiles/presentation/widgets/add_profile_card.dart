import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// "Add new profile" card shown as the last item in the profile grid.
class AddProfileCard extends StatelessWidget {
  const AddProfileCard({
    super.key,
    required this.onTap,
    this.isDisabled = false,
  });

  final VoidCallback onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: isDisabled ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(30),
          ),
          child: CustomPaint(
            painter: _DashedRoundedRectPainter(
              color: isDisabled
                  ? AppTheme.brandOutline.withValues(alpha: 0.6)
                  : AppTheme.brandOutline,
              strokeWidth: 1.6,
              dashLength: 6,
              gapLength: 5,
              borderRadius: 30,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              // FittedBox(scaleDown) keeps the fixed-size icon + text from
              // overflowing a short grid cell (the AddProfileCard is taller than
              // a constrained cell at small viewports / dense grids).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      painter: _DashedCirclePainter(
                        color: isDisabled
                            ? AppTheme.brandOutline.withValues(alpha: 0.6)
                            : AppTheme.brandInkMuted,
                      ),
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: Center(
                          child: Icon(
                            Icons.add_rounded,
                            size: 44,
                            color: isDisabled
                                ? AppTheme.brandInkSoft
                                : AppTheme.brandBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDisabled
                          ? l10n.maxProfilesLabel
                          : l10n.addProfileCardTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.brandInk,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDisabled
                          ? l10n.maxProfilesSubtitle
                          : l10n.createNewLearner,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    _drawDashedPath(canvas, path, paint, dashLength, gapLength);
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength ||
        borderRadius != oldDelegate.borderRadius;
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2 - 2,
        ),
      );
    _drawDashedPath(canvas, path, paint, 6, 5);
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

void _drawDashedPath(
  Canvas canvas,
  Path source,
  Paint paint,
  double dashLength,
  double gapLength,
) {
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final next = distance + dashLength;
      canvas.drawPath(
        metric.extractPath(distance, next.clamp(0, metric.length)),
        paint,
      );
      distance = next + gapLength;
    }
  }
}
