import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

/// Theme + builder for [showDatePicker] to match app surfaces (white card,
/// Techelet primary, no M3 surface tint haze).
ThemeData _learningDatePickerTheme(BuildContext context, ThemeData base) {
  final scheme = base.colorScheme;
  return base.copyWith(
    colorScheme: scheme.copyWith(
      primary: context.colors.brandBlue,
      onPrimary: Colors.white,
      surface: context.colors.brandCreamCard,
      onSurface: context.colors.brandInk,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: context.colors.brandCreamCard,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black26,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      dayStyle: TextStyle(
        color: context.colors.brandInk,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      yearStyle: TextStyle(
        color: context.colors.brandBlueDeep,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
      headerForegroundColor: context.colors.brandInk,
      headerHeadlineStyle: TextStyle(
        color: context.colors.brandInk,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.5,
      ),
      headerHelpStyle: TextStyle(
        color: context.colors.brandInkMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      weekdayStyle: TextStyle(
        color: context.colors.brandInkMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return context.colors.brandInkSoft;
        }
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return context.colors.brandInk;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return context.colors.brandBlue;
        }
        return null;
      }),
      todayBorder: BorderSide(color: context.colors.brandBlue, width: 1.2),
      todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
      todayForegroundColor: WidgetStateProperty.all(context.colors.brandBlue),
      rangeSelectionBackgroundColor: context.colors.brandBlueSoft,
    ),
  );
}

/// Use as [showDatePicker] `builder` to apply [learning date picker] styling.
Widget learningDatePickerThemeBuilder(BuildContext context, Widget? child) {
  if (child == null) return const SizedBox.shrink();
  return Theme(
    data: _learningDatePickerTheme(context, Theme.of(context)),
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
