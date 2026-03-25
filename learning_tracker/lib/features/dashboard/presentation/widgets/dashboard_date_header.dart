import 'package:flutter/material.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';

/// Displays today's Gregorian and Hebrew dates at the top of the dashboard.
class DashboardDateHeader extends StatelessWidget {
  const DashboardDateHeader({super.key, required this.date});

  final DateTime date;

  static const _weekdays = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gregorian =
        '${_weekdays[date.weekday]}, ${_months[date.month]} ${date.day}, ${date.year}';
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
