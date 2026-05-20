import 'package:flutter/material.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Calendar grid highlighting days with learning activity.
///
/// Renders every day in [startDate]..[endDate] (inclusive) as a row of 7
/// day-cells. Rows are laid out top-to-bottom, oldest first, so callers can
/// pass 7-day, 29-day, or all-time ranges and the grid expands to fit.
class StreakCalendar extends StatelessWidget {
  final Set<DateTime> activeDates;

  /// First day (local, time-zeroed) of the range to display.
  final DateTime startDate;

  /// Last day (local, time-zeroed) of the range to display.
  final DateTime endDate;

  const StreakCalendar({
    super.key,
    required this.activeDates,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    // Build the ordered list of local dates from startDate through endDate.
    final dates = <DateTime>[];
    var cursor = DateTime(startDate.year, startDate.month, startDate.day);
    final last = DateTime(endDate.year, endDate.month, endDate.day);
    while (!cursor.isAfter(last)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    if (dates.isEmpty) return const SizedBox.shrink();

    final today = DateTimeFactory.nowLocal();
    final todayNorm = DateTime(today.year, today.month, today.day);

    // Split into rows of 7.
    final rows = <List<DateTime>>[];
    for (var i = 0; i < dates.length; i += 7) {
      rows.add(dates.sublist(i, i + 7 > dates.length ? dates.length : i + 7));
    }

    // Weekday labels derived from the first 7 (or fewer) dates.
    final labelDates = rows.first;
    final weekdayLabels = labelDates
        .map((d) => _weekdayInitial(d.weekday))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [for (final label in weekdayLabels) _DayLabel(label)],
        ),
        for (final row in rows) ...[
          const SizedBox(height: 8),
          _DayRow(dates: row, activeDates: activeDates, today: todayNorm),
        ],
      ],
    );
  }

  static String _weekdayInitial(int weekday) => switch (weekday) {
    DateTime.monday => 'Mon',
    DateTime.tuesday => 'Tue',
    DateTime.wednesday => 'Wed',
    DateTime.thursday => 'Thu',
    DateTime.friday => 'Fri',
    DateTime.saturday => 'Sat',
    DateTime.sunday => 'Sun',
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

  /// Midnight-normalised local "today" for isToday comparisons.
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
            isToday: date == today,
          ),
        // Pad incomplete rows so alignment stays consistent.
        for (var i = dates.length; i < 7; i++) const SizedBox(width: 34),
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
            fontSize: 10,
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
