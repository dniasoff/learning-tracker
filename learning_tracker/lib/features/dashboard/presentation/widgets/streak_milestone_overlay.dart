import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';

/// Milestone thresholds that trigger celebrations.
const milestoneThresholds = [7, 14, 30, 50, 100, 180, 365];

/// Checks if a streak count is a milestone.
bool isMilestone(int streak) => milestoneThresholds.contains(streak);

/// Overlay celebrating a streak milestone (AC-3).
///
/// Child mode: bouncing trophy + confetti-like dots.
/// Adult mode: subtle warm banner.
/// Auto-dismisses after 4 seconds or on tap.
class StreakMilestoneOverlay extends StatefulWidget {
  const StreakMilestoneOverlay({
    super.key,
    required this.streak,
    required this.userMode,
    required this.onDismiss,
  });

  final int streak;
  final UserMode userMode;
  final VoidCallback onDismiss;

  @override
  State<StreakMilestoneOverlay> createState() => _StreakMilestoneOverlayState();
}

class _StreakMilestoneOverlayState extends State<StreakMilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _autoDismiss = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: GestureDetector(
        onTap: _dismiss,
        child: widget.userMode == UserMode.child
            ? _ChildCelebration(streak: widget.streak)
            : _AdultCelebration(streak: widget.streak),
      ),
    );
  }
}

class _ChildCelebration extends StatelessWidget {
  const _ChildCelebration({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.2),
            Colors.amber.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.bounceOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: const Text('🏆', style: TextStyle(fontSize: 36)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$streak Day Streak!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amazing! Keep up the great work!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdultCelebration extends StatelessWidget {
  const _AdultCelebration({required this.streak});
  final int streak;

  String get _message => switch (streak) {
    7 => 'One week of consistent learning',
    14 => 'Two weeks of dedication',
    30 => '30 days of consistent learning',
    50 => 'Half a century of daily commitment',
    100 => '100 days — remarkable dedication',
    180 => 'Six months of steady growth',
    365 => 'A full year of Torah learning',
    _ => '$streak days of consistent learning',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
