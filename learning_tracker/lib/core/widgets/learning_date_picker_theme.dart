import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// Theme + builder for [showDatePicker] to match app surfaces (white card,
/// Techelet primary, no M3 surface tint haze).
ThemeData _learningDatePickerTheme(ThemeData base) {
  final scheme = base.colorScheme;
  return base.copyWith(
    colorScheme: scheme.copyWith(
      primary: AppTheme.brandBlue,
      onPrimary: Colors.white,
      surface: AppTheme.brandCreamCard,
      onSurface: AppTheme.brandInk,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppTheme.brandCreamCard,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black26,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      dayStyle: const TextStyle(
        color: AppTheme.brandInk,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      yearStyle: const TextStyle(
        color: AppTheme.brandBlueDeep,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
      headerForegroundColor: AppTheme.brandInk,
      headerHeadlineStyle: const TextStyle(
        color: AppTheme.brandInk,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.5,
      ),
      headerHelpStyle: const TextStyle(
        color: AppTheme.brandInkMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      weekdayStyle: const TextStyle(
        color: AppTheme.brandInkMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppTheme.brandInkSoft;
        }
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return AppTheme.brandInk;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTheme.brandBlue;
        }
        return null;
      }),
      todayBorder: const BorderSide(color: AppTheme.brandBlue, width: 1.2),
      todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
      todayForegroundColor: WidgetStateProperty.all(AppTheme.brandBlue),
      rangeSelectionBackgroundColor: AppTheme.brandBlueSoft,
    ),
  );
}

/// Use as [showDatePicker] `builder` to apply [learning date picker] styling.
Widget learningDatePickerThemeBuilder(BuildContext context, Widget? child) {
  if (child == null) return const SizedBox.shrink();
  return Theme(
    data: _learningDatePickerTheme(Theme.of(context)),
    child: child,
  );
}

/// Same visual treatment as the add-track / parent-mode modals, for Gregorian.
Future<DateTime?> showLearningAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: learningDatePickerThemeBuilder,
  );
}
