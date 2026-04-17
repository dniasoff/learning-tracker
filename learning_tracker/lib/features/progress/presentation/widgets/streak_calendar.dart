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

  static const _monthNames = [
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
    final months = <_MonthBucket>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      if (months.isEmpty ||
          months.last.year != current.year ||
          months.last.month != current.month) {
        months.add(_MonthBucket(current.year, current.month));
      }
      months.last.days.add(current);
      current = current.add(const Duration(days: 1));
    }

    final theme = Theme.of(context);
    final showYear = months.isNotEmpty && months.first.year != months.last.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day of week headers (shown once at top)
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
        for (var i = 0; i < months.length; i++) ...[
          SizedBox(height: i == 0 ? 8 : 16),
          Text(
            showYear
                ? '${_monthNames[months[i].month - 1]} ${months[i].year}'
                : _monthNames[months[i].month - 1],
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          _MonthGrid(bucket: months[i], activeDates: activeDates),
        ],
      ],
    );
  }
}

class _MonthBucket {
  final int year;
  final int month;
  final List<DateTime> days = [];

  _MonthBucket(this.year, this.month);
}

class _MonthGrid extends StatelessWidget {
  final _MonthBucket bucket;
  final Set<DateTime> activeDates;

  const _MonthGrid({required this.bucket, required this.activeDates});

  @override
  Widget build(BuildContext context) {
    final firstWeekday = bucket.days.first.weekday; // 1=Mon ... 7=Sun
    final padBefore = firstWeekday - 1;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < padBefore; i++)
          const SizedBox(width: 28, height: 28),
        for (final day in bucket.days)
          _DayCell(
            date: day,
            isActive: activeDates.contains(day),
            isToday: _isToday(day),
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
            color: isActive
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
