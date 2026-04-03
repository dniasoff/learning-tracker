import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';

/// Stats row showing streak, tasks today, and engagement metric.
class DashboardStatsRow extends StatelessWidget {
  const DashboardStatsRow({
    super.key,
    required this.currentStreak,
    required this.completedTasks,
    required this.totalTasks,
    required this.userMode,
    required this.points,
  });

  final int currentStreak;
  final int completedTasks;
  final int totalTasks;
  final UserMode userMode;
  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDone = completedTasks >= totalTasks && totalTasks > 0;

    return Row(
      children: [
        Expanded(
          child: _StatIndicator(
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            value: '$currentStreak days',
            label: 'Streak',
          ),
        ),
        Expanded(
          child: _StatIndicator(
            icon: Icons.check_circle_outline,
            iconColor: allDone
                ? Colors.green
                : theme.colorScheme.primary,
            value: '$completedTasks/$totalTasks',
            label: 'Today',
            valueColor: allDone ? Colors.green : null,
          ),
        ),
        Expanded(
          child: _StatIndicator(
            icon: userMode == UserMode.child
                ? Icons.stars
                : Icons.done_all,
            iconColor: Colors.deepPurple,
            value: userMode == UserMode.child
                ? '$points Pts'
                : '$completedTasks Done',
            label: userMode == UserMode.child ? 'Points' : 'Done',
          ),
        ),
      ],
    );
  }
}

class _StatIndicator extends StatelessWidget {
  const _StatIndicator({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withValues(alpha: 0.1),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
