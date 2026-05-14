import 'package:flutter/material.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// A dialog that lets users pick a Hebrew date and returns the Gregorian UTC
/// equivalent.
///
/// Chrome matches the app’s parent-mode / add-track modals: white rounded
/// card, brand blue actions, soft filled fields.
class HebrewDatePicker extends StatefulWidget {
  const HebrewDatePicker({super.key, this.initialDate});

  final DateTime? initialDate;

  /// Shows the Hebrew date picker dialog and returns the selected date as
  /// Gregorian UTC, or null if cancelled.
  static Future<DateTime?> show(BuildContext context, {DateTime? initialDate}) {
    return showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.46),
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
    final initial = widget.initialDate ?? DateTimeFactory.nowLocal();
    final jewishDate = HebrewCalendarUtils.gregorianToJewishDate(initial);
    _hebrewYear = jewishDate.getJewishYear();
    _hebrewMonth = jewishDate.getJewishMonth();
    _hebrewDay = jewishDate.getJewishDayOfMonth();
  }

  List<int> _getMonths() {
    final isLeap = HebrewCalendarUtils.isHebrewLeapYear(_hebrewYear);
    final months = <int>[];
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

  void _clampDayToMonth() {
    final maxDay = _daysInMonth();
    if (_hebrewDay > maxDay) {
      _hebrewDay = maxDay;
    }
  }

  static const _fieldFill = Color(0xFFF2F4F7);

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppTheme.brandInkMuted,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      filled: true,
      fillColor: _fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.brandBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = _getMonths();
    final maxDay = _daysInMonth();
    final effectiveDay = _hebrewDay > maxDay ? maxDay : _hebrewDay;
    final gregorian = HebrewCalendarUtils.hebrewToGregorian(
      year: _hebrewYear,
      month: _hebrewMonth,
      day: effectiveDay,
    );

    return Dialog(
      backgroundColor: AppTheme.brandCreamCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select Hebrew date',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.brandInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.brandInkMuted,
                      size: 22,
                    ),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Year
              Text(
                'Hebrew year',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: IconButton(
                        onPressed: () => setState(() {
                          _hebrewYear--;
                          _clampDayToMonth();
                        }),
                        icon: const Icon(
                          Icons.remove_rounded,
                          color: AppTheme.brandBlue,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$_hebrewYear',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandBlueDeep,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: IconButton(
                        onPressed: () => setState(() {
                          _hebrewYear++;
                          _clampDayToMonth();
                        }),
                        icon: const Icon(
                          Icons.add_rounded,
                          color: AppTheme.brandBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      // Controlled selection when year changes month list; keep
                      // `value` (initialValue is one-shot per FormField key).
                      // ignore: deprecated_member_use
                      value: months.contains(_hebrewMonth)
                          ? _hebrewMonth
                          : months.first,
                      decoration: _fieldDecoration('Month'),
                      items: months.map((m) {
                        final name = HebrewCalendarUtils.getHebrewMonthName(
                          m,
                          hebrewYear: _hebrewYear,
                        );
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.brandInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() {
                        _hebrewMonth = v!;
                        _clampDayToMonth();
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 108,
                    child: DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: effectiveDay,
                      decoration: _fieldDecoration('Day'),
                      items: List.generate(
                        maxDay,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: AppTheme.brandInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        _hebrewDay = v!;
                        _clampDayToMonth();
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.brandCreamSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.brandOutline.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      size: 20,
                      color: AppTheme.brandInkMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'English: ${HebrewCalendarUtils.formatEnglishDate(gregorian, locale: Localizations.localeOf(context).toString())}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.brandInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.brandInkMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(AppLocalizations.of(context)!.actionCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          HebrewCalendarUtils.hebrewToGregorian(
                            year: _hebrewYear,
                            month: _hebrewMonth,
                            day: effectiveDay,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.schedulerSelectDate,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
