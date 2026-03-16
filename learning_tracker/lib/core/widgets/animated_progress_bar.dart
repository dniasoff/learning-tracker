import 'package:flutter/material.dart';

/// A progress bar that animates smoothly between value changes.
///
/// Uses implicit animation via [AnimatedContainer] approach with
/// [TweenAnimationBuilder] for smooth value transitions.
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onAnimationComplete;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 6.0,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeInOut,
    this.onAnimationComplete,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? Theme.of(context).colorScheme.primary;
    final bgColor = backgroundColor ?? Colors.grey[200]!;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: curve,
      onEnd: onAnimationComplete,
      builder: (context, animatedValue, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Container(color: bgColor),
                FractionallySizedBox(
                  widthFactor: animatedValue,
                  child: Container(color: barColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
