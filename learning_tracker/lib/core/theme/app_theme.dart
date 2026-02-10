import 'package:flutter/material.dart';

/// AppTheme provides Material Design 3 theme for the Torah learning app.
///
/// Design philosophy:
/// - Calm, focused colors appropriate for religious study
/// - High contrast for readability
/// - RTL-friendly layout
/// - No dark mode in v1.0 (light theme only)
class AppTheme {
  AppTheme._();

  /// Primary color: Deep blue-purple, evoking tradition and depth of study
  static const Color _primaryColor = Color(0xFF2E4057);

  /// Secondary color: Warm amber, representing the light of Torah
  static const Color _secondaryColor = Color(0xFFF4A261);

  /// Tertiary color: Soft green, representing growth and learning
  static const Color _tertiaryColor = Color(0xFF6B9080);

  /// Error color: Warm red (not harsh)
  static const Color _errorColor = Color(0xFFD64045);

  /// Surface and background colors
  static const Color _surfaceColor = Color(0xFFFAFAFA);
  static const Color _backgroundColor = Color(0xFFF5F5F5);

  /// Curriculum colors - distinct colors for the 5 curricula
  static const Color curriculumMishna = Color(0xFF4A90E2); // Blue
  static const Color curriculumBavli = Color(0xFF8B4789); // Purple
  static const Color curriculumYerushalmi = Color(0xFF2ECC71); // Green
  static const Color curriculumMishnaBerurah = Color(0xFFE67E22); // Orange
  static const Color curriculumChumash = Color(0xFFE74C3C); // Red

  /// Get curriculum color by curriculum ID
  static Color getCurriculumColor(String curriculumId) {
    switch (curriculumId) {
      case 'mishnayos':
        return curriculumMishna;
      case 'bavli':
        return curriculumBavli;
      case 'yerushalmi':
        return curriculumYerushalmi;
      case 'mishna_berurah':
        return curriculumMishnaBerurah;
      case 'chumash':
        return curriculumChumash;
      default:
        return _primaryColor;
    }
  }

  /// Light theme (only theme in v1.0)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: _primaryColor,
        onPrimary: Colors.white,
        primaryContainer: _primaryColor.withValues(alpha: 0.2),
        onPrimaryContainer: _primaryColor,
        secondary: _secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: _secondaryColor.withValues(alpha: 0.2),
        onSecondaryContainer: _secondaryColor.withValues(alpha: 0.8),
        tertiary: _tertiaryColor,
        onTertiary: Colors.white,
        tertiaryContainer: _tertiaryColor.withValues(alpha: 0.2),
        onTertiaryContainer: _tertiaryColor,
        error: _errorColor,
        onError: Colors.white,
        surface: _surfaceColor,
        onSurface: const Color(0xFF1A1A1A),
        onSurfaceVariant: const Color(0xFF49454F),
        outline: const Color(0xFF79747E),
        shadow: Colors.black.withValues(alpha: 0.1),
      ),
      scaffoldBackgroundColor: _backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: _surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceColor,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Color(0xFF79747E),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
