import 'package:flutter/material.dart';

/// Displays contextual encouragement for adult mode users (AC-5).
///
/// Message changes based on streak length. Hidden when streak is 0.
class SatisfactionCueWidget extends StatelessWidget {
  const SatisfactionCueWidget({super.key, required this.currentStreak});

  final int currentStreak;

  String get _message {
    if (currentStreak <= 0) return '';
    if (currentStreak == 1) return 'Great start!';
    if (currentStreak < 7) return 'Building momentum';
    if (currentStreak < 14) return 'Consistent learner';
    if (currentStreak < 30) return 'Strong commitment';
    if (currentStreak < 100) return 'Remarkable dedication';
    return 'Truly inspiring';
  }

  @override
  Widget build(BuildContext context) {
    if (currentStreak <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Icon(
              Icons.check_circle,
              size: 14,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
