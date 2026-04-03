import 'package:flutter/material.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/status_line.dart';

/// Program Calendar variant content for track cards.
class ProgramCalendarContent extends StatelessWidget {
  const ProgramCalendarContent({super.key, required this.calendarPos});

  final CalendarPosition calendarPos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Today's content ref (Hebrew, RTL)
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            calendarPos.todayDisplayHe,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
          ),
        ),
        const SizedBox(height: 4),
        // Day position
        Text(
          'Day ${calendarPos.currentDay} / ${calendarPos.totalDays}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        // Status
        _buildStatusLine(theme),
      ],
    );
  }

  Widget _buildStatusLine(ThemeData theme) {
    switch (calendarPos.status) {
      case CalendarStatus.caughtUp:
        return const StatusLine(
          icon: Icons.check_circle_outline,
          text: 'Caught up',
          color: Colors.green,
        );
      case CalendarStatus.ahead:
        return StatusLine(
          icon: Icons.arrow_upward,
          text: '${calendarPos.delta} ahead',
          color: Colors.green,
        );
      case CalendarStatus.behind:
        final absDelta = calendarPos.delta.abs();
        final color = absDelta >= 5 ? theme.colorScheme.error : Colors.amber;
        return StatusLine(
          icon: Icons.warning_amber_rounded,
          text: '$absDelta behind',
          color: color,
        );
    }
  }
}
