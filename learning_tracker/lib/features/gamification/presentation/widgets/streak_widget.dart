import 'package:flutter/material.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';

/// Displays the current streak count and max streak.
///
/// In child mode, shows an animated fire icon with bounce effect.
/// In adult mode, shows a subtle text-based display.
class StreakWidget extends StatelessWidget {
  final int currentStreak;
  final int maxStreak;
  final ProfileMode userMode;

  const StreakWidget({
    super.key,
    required this.currentStreak,
    required this.maxStreak,
    required this.userMode,
  });

  @override
  Widget build(BuildContext context) {
    return userMode.isChild
        ? _AnimatedStreakDisplay(
            currentStreak: currentStreak,
            maxStreak: maxStreak,
          )
        : _SubtleStreakDisplay(
            currentStreak: currentStreak,
            maxStreak: maxStreak,
          );
  }
}

class _AnimatedStreakDisplay extends StatefulWidget {
  final int currentStreak;
  final int maxStreak;

  const _AnimatedStreakDisplay({
    required this.currentStreak,
    required this.maxStreak,
  });

  @override
  State<_AnimatedStreakDisplay> createState() => _AnimatedStreakDisplayState();
}

class _AnimatedStreakDisplayState extends State<_AnimatedStreakDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 50,
      ),
    ]).animate(_controller);
    if (widget.currentStreak > 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedStreakDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStreak != oldWidget.currentStreak &&
        widget.currentStreak > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.currentStreak} day streak!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Best: ${widget.maxStreak} days',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtleStreakDisplay extends StatelessWidget {
  final int currentStreak;
  final int maxStreak;

  const _SubtleStreakDisplay({
    required this.currentStreak,
    required this.maxStreak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: Colors.orange.withValues(alpha: 0.8),
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$currentStreak',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(best: $maxStreak)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
