import 'package:flutter/material.dart';

/// A progress bar that animates smoothly between value changes.
///
/// Uses implicit animation via [TweenAnimationBuilder] for smooth
/// value transitions. Tracks the previous value so updates animate
/// from the old value to the new value (not from 0).
class AnimatedProgressBar extends StatefulWidget {
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
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> {
  double _previousValue = 0;

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value.clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? Theme.of(context).colorScheme.primary;
    final bgColor = widget.backgroundColor ?? Colors.grey[200]!;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _previousValue,
        end: widget.value.clamp(0.0, 1.0),
      ),
      duration: widget.duration,
      curve: widget.curve,
      onEnd: widget.onAnimationComplete,
      builder: (context, animatedValue, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: SizedBox(
            height: widget.height,
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
