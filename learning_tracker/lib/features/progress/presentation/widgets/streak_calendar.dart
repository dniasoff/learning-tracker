import 'package:flutter/material.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

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
    final dates = <DateTime>[];
    var cursor = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).subtract(const Duration(days: 13));
    for (var i = 0; i < 14; i++) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    final today = DateTimeFactory.nowLocal();
    final weekdayLabels = dates
        .take(7)
        .map((d) => _weekdayInitial(d.weekday))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [for (final label in weekdayLabels) _DayLabel(label)],
        ),
        const SizedBox(height: 8),
        _DayRow(
          dates: dates.take(7).toList(growable: false),
          activeDates: activeDates,
          today: today,
        ),
        const SizedBox(height: 8),
        _DayRow(
          dates: dates.skip(7).take(7).toList(growable: false),
          activeDates: activeDates,
          today: today,
        ),
      ],
    );
  }

  String _weekdayInitial(int weekday) => switch (weekday) {
    DateTime.monday => 'M',
    DateTime.tuesday => 'T',
    DateTime.wednesday => 'W',
    DateTime.thursday => 'T',
    DateTime.friday => 'F',
    DateTime.saturday => 'S',
    DateTime.sunday => 'S',
    _ => '',
  };
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.dates,
    required this.activeDates,
    required this.today,
  });

  final List<DateTime> dates;
  final Set<DateTime> activeDates;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final date in dates)
          _DayCell(
            date: date,
            isActive: activeDates.contains(date),
            isToday:
                date.year == today.year &&
                date.month == today.month &&
                date.day == today.day,
          ),
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  final String label;

  const _DayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
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
    const activeColor = Color(0xFF103BAC);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isActive ? activeColor : Colors.transparent,
        shape: BoxShape.circle,
        border: isToday
            ? Border.all(
                color: isActive ? Colors.white : const Color(0xFF9FA8BD),
                width: 1.4,
              )
            : null,
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 12,
            color: isActive
                ? Colors.white
                : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
