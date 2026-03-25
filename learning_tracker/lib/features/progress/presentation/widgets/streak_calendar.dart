import 'package:flutter/material.dart';

/// Calendar grid highlighting days with learning activity.
class StreakCalendar extends StatelessWidget {
  final Set<DateTime> activeDates;
  final DateTime startDate;
  final DateTime endDate;

  const StreakCalendar({
    super.key,
    required this.activeDates,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final days = <DateTime>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    // Pad to start on Monday
    final firstWeekday = days.first.weekday; // 1=Mon ... 7=Sun
    final padBefore = firstWeekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day of week headers
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DayLabel('M'),
            _DayLabel('T'),
            _DayLabel('W'),
            _DayLabel('T'),
            _DayLabel('F'),
            _DayLabel('S'),
            _DayLabel('S'),
          ],
        ),
        const SizedBox(height: 4),
        // Calendar grid
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            // Empty padding cells
            for (var i = 0; i < padBefore; i++)
              const SizedBox(width: 28, height: 28),
            // Actual day cells
            for (final day in days)
              _DayCell(
                date: day,
                isActive: activeDates.contains(day),
                isToday: _isToday(day),
              ),
          ],
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _DayLabel extends StatelessWidget {
  final String label;

  const _DayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isActive;
  final bool isToday;

  const _DayCell({
    required this.date,
    required this.isActive,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isActive ? primaryColor : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: isToday ? Border.all(color: primaryColor, width: 2) : null,
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
