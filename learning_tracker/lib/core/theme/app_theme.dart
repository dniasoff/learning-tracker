import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

/// AppTheme provides Material Design 3 theme for the Torah learning app.
///
/// Design philosophy:
/// - Dark mode with yellow/gold accent for focused study
/// - High contrast for readability
/// - RTL-friendly layout
class AppTheme {
  AppTheme._();

  /// Primary color: Yellow/gold accent
  static const Color _primaryColor = Color(0xFFE8C519);

  /// Secondary color: Bright green for success states
  static const Color _secondaryColor = Color(0xFF4ADE80);

  /// Tertiary color: Soft green, representing growth and learning
  static const Color _tertiaryColor = Color(0xFF6B9080);

  /// Error color: Warm red (not harsh)
  static const Color _errorColor = Color(0xFFD64045);

  /// Dark surface and background colors
  static const Color _surfaceColor = Color(0xFF141414);
  static const Color _backgroundColor = Color(0xFF0A0A0A);
  static const Color _cardColor = Color(0xFF1A1A1A);

  /// Curriculum colors - distinct, rich colors for each curriculum
  static const Color curriculumMishna = Color(0xFF2D8C46); // Green
  static const Color curriculumBavli = Color(0xFF1B6B5A); // Teal
  static const Color curriculumYerushalmi = Color(0xFF2980B9); // Blue
  static const Color curriculumMishnaBerurah = Color(0xFFE67E22); // Orange
  static const Color curriculumChumash = Color(0xFF5A7A2E); // Olive green
  static const Color curriculumNach = Color(0xFF1ABC9C); // Teal
  static const Color curriculumMussar = Color(0xFF9B59B6); // Violet

  /// Get curriculum color by [CurriculumId] enum value.
  static Color getCurriculumColor(CurriculumId curriculum) {
    switch (curriculum) {
      case CurriculumId.mishnayos:
        return curriculumMishna;
      case CurriculumId.bavli:
        return curriculumBavli;
      case CurriculumId.yerushalmi:
        return curriculumYerushalmi;
      case CurriculumId.mishnaBerurah:
        return curriculumMishnaBerurah;
      case CurriculumId.chumash:
      case CurriculumId.torah:
        return curriculumChumash;
      case CurriculumId.tanach:
        return const Color(0xFF1ABC9C); // Teal
      case CurriculumId.nach:
        return curriculumNach;
      case CurriculumId.mussar:
        return curriculumMussar;
    }
  }

  /// Get curriculum color by storage-key string.
  ///
  /// Prefer [getCurriculumColor] with a [CurriculumId] value. This helper
  /// exists for call sites that receive a raw string from routing params.
  static Color getCurriculumColorByKey(String storageKey) {
    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == storageKey)
        .firstOrNull;
    return curriculum != null ? getCurriculumColor(curriculum) : _primaryColor;
  }

  /// Track colors - distinct colors for the 3 track types
  static const Color trackPersonal = Color(0xFF4A90E2); // Blue
  static const Color trackSchool = Color(0xFF2ECC71); // Green
  static const Color trackTutor = Color(0xFFE67E22); // Orange

  /// Get track color by TrackType
  static Color getTrackColor(TrackType trackType) {
    switch (trackType) {
      case TrackType.personal:
        return trackPersonal;
      case TrackType.school:
        return trackSchool;
      case TrackType.tutor:
        return trackTutor;
    }
  }

  /// Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _primaryColor,
        onPrimary: Colors.black,
        primaryContainer: _primaryColor.withValues(alpha: 0.15),
        onPrimaryContainer: _primaryColor,
        secondary: _secondaryColor,
        onSecondary: Colors.black,
        secondaryContainer: _secondaryColor.withValues(alpha: 0.15),
        onSecondaryContainer: _secondaryColor,
        tertiary: _tertiaryColor,
        onTertiary: Colors.black,
        tertiaryContainer: _tertiaryColor.withValues(alpha: 0.15),
        onTertiaryContainer: _tertiaryColor,
        error: _errorColor,
        onError: Colors.white,
        surface: _surfaceColor,
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFF8A8A8A),
        outline: const Color(0xFF2A2A2A),
        shadow: Colors.black.withValues(alpha: 0.4),
      ),
      scaffoldBackgroundColor: _backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: _cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primaryColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorColor),
        ),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceColor,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Color(0xFF5A5A5A),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceColor,
        indicatorColor: _primaryColor.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primaryColor);
          }
          return const IconThemeData(color: Color(0xFF5A5A5A));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: Color(0xFF5A5A5A),
            fontWeight: FontWeight.normal,
            fontSize: 12,
          );
        }),
        elevation: 0,
      ),
      dividerColor: Colors.white.withValues(alpha: 0.06),
      chipTheme: ChipThemeData(
        backgroundColor: _primaryColor.withValues(alpha: 0.15),
        selectedColor: _primaryColor,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.black, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _primaryColor;
            }
            return _cardColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return Colors.white.withValues(alpha: 0.7);
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primaryColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primaryColor;
          return Colors.white.withValues(alpha: 0.3);
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primaryColor;
          return Colors.white.withValues(alpha: 0.5);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor.withValues(alpha: 0.3);
          }
          return Colors.white.withValues(alpha: 0.1);
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primaryColor,
        linearTrackColor: Color(0xFF2A2A2A),
      ),
    );
  }

  /// Light theme (kept for reference)
  static ThemeData get lightTheme => darkTheme;
}
