import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';

/// Calendar grid highlighting days with learning activity.
///
/// Renders every day in [startDate]..[endDate] (inclusive) as a row of 7
/// day-cells. Rows are laid out top-to-bottom, oldest first, so callers can
/// pass 7-day, 29-day, or all-time ranges and the grid expands to fit.
///
/// Honors the Calendar Preference ([useHebrewDateProvider]): when the
/// Hebrew-date setting is on, both the day numbers and the weekday header
/// labels render in Hebrew (gematriya day-of-month, Hebrew weekday initials)
/// so this calendar matches the rest of the app's date rendering instead of
/// always using Gregorian/English labels.
class StreakCalendar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final useHebrewDate = ref.watch(useHebrewDateProvider);
    // The weekday HEADER follows the UI locale, not just the date-system
    // preference: on a Hebrew device the day-of-week letters (א..ש) must render
    // in Hebrew even when the Gregorian date system is selected, so they don't
    // leak English "Mon/Tue" into an otherwise-Hebrew screen. (Day-of-MONTH
    // gematriya below stays tied to useHebrewDate — that IS a Hebrew-calendar
    // concept, not just script.)
    final headerUsesHebrewScript =
        useHebrewDate ||
        ref.watch(currentAppLocaleProvider).languageCode == 'he';

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

    // Weekday labels derived from the first 7 (or fewer) dates. The weekday is
    // calendar-system-independent (the Gregorian weekday IS the Hebrew weekday
    // for the same civil day), so we only swap the *script* of the label.
    final labelDates = rows.first;
    final weekdayLabels = labelDates
        .map(
          (d) =>
              _weekdayInitial(d.weekday, useHebrewDate: headerUsesHebrewScript),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(child: Center(child: _DayLabel(label))),
          ],
        ),
        for (final row in rows) ...[
          const SizedBox(height: 8),
          _DayRow(
            dates: row,
            activeDates: activeDates,
            today: todayNorm,
            useHebrewDate: useHebrewDate,
          ),
        ],
      ],
    );
  }

  /// Weekday header initial. Gregorian/English ("Mon".."Sun") by default;
  /// when [useHebrewDate] is on returns the short Hebrew weekday letter
  /// ("א".."ש") so the header matches a Hebrew-calendar display.
  static String _weekdayInitial(int weekday, {required bool useHebrewDate}) {
    if (useHebrewDate) {
      return switch (weekday) {
        DateTime.sunday => 'א',
        DateTime.monday => 'ב',
        DateTime.tuesday => 'ג',
        DateTime.wednesday => 'ד',
        DateTime.thursday => 'ה',
        DateTime.friday => 'ו',
        DateTime.saturday => 'ש',
        _ => '',
      };
    }
    return switch (weekday) {
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
}

/// Formats a single day-of-month cell label, honoring the Calendar Preference.
///
/// Gregorian ("1".."31") by default; Hebrew gematriya day-of-month
/// (e.g. "י״א") when [useHebrewDate] is on.
String formatStreakDayLabel(DateTime date, {required bool useHebrewDate}) {
  if (!useHebrewDate) return '${date.day}';
  final jewishDate = HebrewCalendarUtils.gregorianToJewishDate(date);
  final formatter = HebrewDateFormatter()..hebrewFormat = true;
  return formatter.formatHebrewNumber(jewishDate.getJewishDayOfMonth());
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.dates,
    required this.activeDates,
    required this.today,
    required this.useHebrewDate,
  });

  final List<DateTime> dates;
  final Set<DateTime> activeDates;

  /// Midnight-normalised local "today" for isToday comparisons.
  final DateTime today;

  final bool useHebrewDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final date in dates)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 44, maxHeight: 44),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _DayCell(
                    date: date,
                    isActive: activeDates.contains(date),
                    isToday: date == today,
                    useHebrewDate: useHebrewDate,
                  ),
                ),
              ),
            ),
          ),
        // Pad incomplete rows so alignment stays consistent.
        for (var i = dates.length; i < 7; i++)
          const Expanded(child: SizedBox()),
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  final String label;

  const _DayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isActive;
  final bool isToday;
  final bool useHebrewDate;

  const _DayCell({
    required this.date,
    required this.isActive,
    required this.isToday,
    required this.useHebrewDate,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF103BAC);
    final label = formatStreakDayLabel(date, useHebrewDate: useHebrewDate);

    return DecoratedBox(
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
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
      ),
    );
  }
}
