import 'package:flutter/material.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';

/// A dialog that lets users pick a Hebrew date and returns the Gregorian UTC
/// equivalent.
///
/// Displays Hebrew month names and converts the selection to Gregorian for
/// confirmation before returning.
class HebrewDatePicker extends StatefulWidget {
  final DateTime? initialDate;

  const HebrewDatePicker({super.key, this.initialDate});

  /// Shows the Hebrew date picker dialog and returns the selected date as
  /// Gregorian UTC, or null if cancelled.
  static Future<DateTime?> show(BuildContext context, {DateTime? initialDate}) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => HebrewDatePicker(initialDate: initialDate),
    );
  }

  @override
  State<HebrewDatePicker> createState() => _HebrewDatePickerState();
}

class _HebrewDatePickerState extends State<HebrewDatePicker> {
  late int _hebrewYear;
  late int _hebrewMonth;
  late int _hebrewDay;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    final jewishDate = HebrewCalendarUtils.gregorianToJewishDate(initial);
    _hebrewYear = jewishDate.getJewishYear();
    _hebrewMonth = jewishDate.getJewishMonth();
    _hebrewDay = jewishDate.getJewishDayOfMonth();
  }

  List<int> _getMonths() {
    final isLeap = HebrewCalendarUtils.isHebrewLeapYear(_hebrewYear);
    final months = <int>[];
    // Hebrew months: Nissan(1) through Adar_II(13)
    // Display in calendar order: Tishrei(7)..Adar/Adar_II, then Nissan(1)..Elul(6)
    for (var m = JewishDate.TISHREI; m <= JewishDate.ADAR_II; m++) {
      if (m == JewishDate.ADAR_II && !isLeap) continue;
      months.add(m);
    }
    for (var m = JewishDate.NISSAN; m <= JewishDate.ELUL; m++) {
      months.add(m);
    }
    return months;
  }

  int _daysInMonth() {
    final jewishDate = JewishDate.initDate(
      jewishYear: _hebrewYear,
      jewishMonth: _hebrewMonth,
      jewishDayOfMonth: 1,
    );
    return jewishDate.getDaysInJewishMonth();
  }

  DateTime _toGregorian() {
    return HebrewCalendarUtils.hebrewToGregorian(
      year: _hebrewYear,
      month: _hebrewMonth,
      day: _hebrewDay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gregorian = _toGregorian();
    final months = _getMonths();
    final maxDay = _daysInMonth();
    if (_hebrewDay > maxDay) {
      _hebrewDay = maxDay;
    }

    return AlertDialog(
      title: const Text('Select Hebrew Date'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Year selector
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => setState(() => _hebrewYear--),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_hebrewYear',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _hebrewYear++),
              ),
            ],
          ),
          // Month selector
          DropdownButton<int>(
            value: months.contains(_hebrewMonth) ? _hebrewMonth : months.first,
            isExpanded: true,
            items: months.map((m) {
              final name = HebrewCalendarUtils.getHebrewMonthName(
                m,
                hebrewYear: _hebrewYear,
              );
              return DropdownMenuItem(value: m, child: Text(name));
            }).toList(),
            onChanged: (v) => setState(() => _hebrewMonth = v!),
          ),
          // Day selector
          DropdownButton<int>(
            value: _hebrewDay,
            isExpanded: true,
            items: List.generate(
              maxDay,
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
            ),
            onChanged: (v) => setState(() => _hebrewDay = v!),
          ),
          const SizedBox(height: 16),
          // Gregorian confirmation
          Text(
            'Gregorian: ${gregorian.year}-${gregorian.month.toString().padLeft(2, '0')}-${gregorian.day.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_toGregorian()),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
