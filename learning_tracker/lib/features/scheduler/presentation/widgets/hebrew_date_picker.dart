import 'package:flutter/material.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
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
  late JewishDate _minimumJewishDate;
  late int _hebrewYear;
  late int _hebrewMonth;
  late int _hebrewDay;

  @override
  void initState() {
    super.initState();
    final today = DateTimeFactory.nowLocal();
    _minimumJewishDate = HebrewCalendarUtils.gregorianToJewishDate(today);
    final initial = widget.initialDate ?? today;
    final jewishDate = HebrewCalendarUtils.gregorianToJewishDate(initial);
    _hebrewYear = jewishDate.getJewishYear();
    _hebrewMonth = jewishDate.getJewishMonth();
    _hebrewDay = jewishDate.getJewishDayOfMonth();
    _clampToMinimumDate();
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
    return _daysInMonthFor(_hebrewYear, _hebrewMonth);
  }

  int _daysInMonthFor(int year, int month) {
    final jewishDate = JewishDate.initDate(
      jewishYear: year,
      jewishMonth: month,
      jewishDayOfMonth: 1,
    );
    return jewishDate.getDaysInJewishMonth();
  }

  bool _isBeforeMinimum(int year, int month, int day) {
    final candidate = JewishDate.initDate(
      jewishYear: year,
      jewishMonth: month,
      jewishDayOfMonth: day,
    );
    return candidate.compareTo(_minimumJewishDate) < 0;
  }

  void _clampToMinimumDate() {
    if (_isBeforeMinimum(_hebrewYear, _hebrewMonth, _hebrewDay)) {
      _hebrewYear = _minimumJewishDate.getJewishYear();
      _hebrewMonth = _minimumJewishDate.getJewishMonth();
      _hebrewDay = _minimumJewishDate.getJewishDayOfMonth();
    } else {
      _clampDayToMonth();
    }
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
      labelStyle: TextStyle(
        color: context.colors.brandInkMuted,
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
        borderSide: BorderSide(color: context.colors.brandBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context)!;
    final months = _getMonths();
    final maxDay = _daysInMonth();
    final effectiveDay = _hebrewDay > maxDay ? maxDay : _hebrewDay;
    final gregorian = HebrewCalendarUtils.hebrewToGregorian(
      year: _hebrewYear,
      month: _hebrewMonth,
      day: effectiveDay,
    );

    // Available height = full screen minus the system safe-area insets and the
    // on-screen keyboard, minus a small breathing-room margin. When the screen
    // is short or large text is in use, the picker content scrolls instead of
    // overflowing — mirrors the clamp/scroll contract in [showAppDialog].
    final maxHeight =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        media.viewInsets.bottom -
        48;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: maxHeight > 0 ? maxHeight : media.size.height,
        ),
        child: SingleChildScrollView(
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
                        l10n.schedulerHebrewDatePickerTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: context.colors.brandInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: context.colors.brandInkMuted,
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
                  l10n.schedulerHebrewYearLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.colors.brandInkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _fieldFill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: IconButton(
                          onPressed:
                              _hebrewYear > _minimumJewishDate.getJewishYear()
                              ? () => setState(() {
                                  _hebrewYear--;
                                  _clampToMinimumDate();
                                })
                              : null,
                          icon: Icon(
                            Icons.remove_rounded,
                            color: context.colors.brandBlue,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '$_hebrewYear',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.colors.brandBlueDeep,
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
                          icon: Icon(
                            Icons.add_rounded,
                            color: context.colors.brandBlue,
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
                        decoration: _fieldDecoration(
                          l10n.schedulerHebrewMonthFieldLabel,
                        ),
                        items: months.map((m) {
                          final name = HebrewCalendarUtils.getHebrewMonthName(
                            m,
                            hebrewYear: _hebrewYear,
                          );
                          return DropdownMenuItem(
                            value: m,
                            enabled: !_isBeforeMinimum(
                              _hebrewYear,
                              m,
                              _daysInMonthFor(_hebrewYear, m),
                            ),
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.brandInk,
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
                        decoration: _fieldDecoration(
                          l10n.schedulerHebrewDayFieldLabel,
                        ),
                        items: List.generate(
                          maxDay,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            enabled: !_isBeforeMinimum(
                              _hebrewYear,
                              _hebrewMonth,
                              i + 1,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: context.colors.brandInk,
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
                    color: context.colors.brandCreamSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.colors.brandOutline.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 20,
                        color: context.colors.brandInkMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.schedulerHebrewDateEnglishPreview(
                            HebrewCalendarUtils.formatEnglishDate(
                              gregorian,
                              locale: Localizations.localeOf(
                                context,
                              ).toString(),
                            ),
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.colors.brandInk,
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
                          foregroundColor: context.colors.brandInkMuted,
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
                          backgroundColor: context.colors.brandBlue,
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
      ),
    );
  }
}
