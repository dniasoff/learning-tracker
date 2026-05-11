import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';

/// Displays today's English and Hebrew dates at the top of the dashboard.
class DashboardDateHeader extends StatelessWidget {
  const DashboardDateHeader({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gregorian = DateFormat('EEEE, d MMMM y').format(date);
    final hebrew = HebrewCalendarUtils.gregorianToHebrew(date.toUtc());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gregorian,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hebrew,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
