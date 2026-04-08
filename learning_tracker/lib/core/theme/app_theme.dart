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

  /// Default primary color: Green accent
  static const Color defaultAccentColor = Color(0xFF2ECC71);

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
    return curriculum != null
        ? getCurriculumColor(curriculum)
        : defaultAccentColor;
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
  static ThemeData darkTheme([Color accent = defaultAccentColor]) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.black,
        primaryContainer: accent.withValues(alpha: 0.15),
        onPrimaryContainer: accent,
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
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
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
          borderSide: BorderSide(color: accent, width: 2),
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surfaceColor,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF5A5A5A),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceColor,
        indicatorColor: accent.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return const IconThemeData(color: Color(0xFF5A5A5A));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: accent,
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
        backgroundColor: accent.withValues(alpha: 0.15),
        selectedColor: accent,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.black, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accent;
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
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.white.withValues(alpha: 0.3);
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.white.withValues(alpha: 0.5);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.3);
          }
          return Colors.white.withValues(alpha: 0.1);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: const Color(0xFF2A2A2A),
      ),
    );
  }

  /// Light theme colors
  static const Color _lightSurfaceColor = Color(0xFFF5F5F0);
  static const Color _lightBackgroundColor = Color(0xFFFAFAF7);
  static const Color _lightCardColor = Colors.white;

  /// Light theme
  static ThemeData lightTheme([Color accent = defaultAccentColor]) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.black,
        primaryContainer: accent.withValues(alpha: 0.15),
        onPrimaryContainer: const Color(0xFF5A4A00),
        secondary: _secondaryColor,
        onSecondary: Colors.black,
        secondaryContainer: _secondaryColor.withValues(alpha: 0.15),
        onSecondaryContainer: const Color(0xFF005A1E),
        tertiary: _tertiaryColor,
        onTertiary: Colors.white,
        tertiaryContainer: _tertiaryColor.withValues(alpha: 0.15),
        onTertiaryContainer: const Color(0xFF2A4A3A),
        error: _errorColor,
        onError: Colors.white,
        surface: _lightSurfaceColor,
        onSurface: const Color(0xFF1A1A1A),
        onSurfaceVariant: const Color(0xFF6A6A6A),
        outline: const Color(0xFFD0D0D0),
        shadow: Colors.black.withValues(alpha: 0.08),
      ),
      scaffoldBackgroundColor: _lightBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackgroundColor,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: _lightCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF5A4A00),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          side: BorderSide(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.2),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightCardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorColor),
        ),
        labelStyle: TextStyle(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
        ),
        hintStyle: TextStyle(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightCardColor,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF9A9A9A),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightCardColor,
        indicatorColor: accent.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return const IconThemeData(color: Color(0xFF9A9A9A));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: accent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: Color(0xFF9A9A9A),
            fontWeight: FontWeight.normal,
            fontSize: 12,
          );
        }),
        elevation: 0,
      ),
      dividerColor: const Color(0xFF1A1A1A).withValues(alpha: 0.08),
      chipTheme: ChipThemeData(
        backgroundColor: accent.withValues(alpha: 0.12),
        selectedColor: accent,
        labelStyle: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.black, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accent;
            }
            return _lightCardColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return const Color(0xFF1A1A1A).withValues(alpha: 0.7);
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: BorderSide(color: const Color(0xFF1A1A1A).withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return const Color(0xFF1A1A1A).withValues(alpha: 0.3);
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return const Color(0xFF1A1A1A).withValues(alpha: 0.4);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.3);
          }
          return const Color(0xFF1A1A1A).withValues(alpha: 0.1);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: const Color(0xFFE0E0E0),
      ),
    );
  }
}

