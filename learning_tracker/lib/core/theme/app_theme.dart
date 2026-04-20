import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

/// Material 3 theme for the Torah learning app — "Mesorah Heritage" palette.
///
/// Two axes:
/// - Brightness: light / dark (user preference, via ThemeMode)
/// - Audience: adult (scholarly navy+gold) / child (warm parchment)
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Mesorah Heritage palette
  // ---------------------------------------------------------------------------

  /// Primary gold — accents, CTAs, highlights. Used in both adult and child.
  static const Color heritageGold = Color(0xFFC9A961);
  static const Color heritageGoldMuted = Color(0xFFA88A4A);
  static const Color heritageGoldSoft = Color(0xFFE8C519);

  /// Deep scholarly navy — adult dark-mode base.
  static const Color heritageNavy = Color(0xFF0B1A2E);
  static const Color heritageNavySurface = Color(0xFF12243D);
  static const Color heritageNavyCard = Color(0xFF172A44);
  static const Color heritageNavyOutline = Color(0xFF22385A);

  /// Warm parchment — child-mode base and adult light-mode base.
  static const Color heritageParchment = Color(0xFFF5EBD5);
  static const Color heritageParchmentSurface = Color(0xFFFBF4E3);
  static const Color heritageParchmentCard = Color(0xFFFFFDF6);
  static const Color heritageParchmentOutline = Color(0xFFE3D4AE);

  /// Off-white on navy for body copy that's easy on the eye.
  static const Color heritageInk = Color(0xFFF5EDD8);
  static const Color heritageInkMuted = Color(0xFFB8AC8C);

  /// Dark ink for use on parchment.
  static const Color heritageDarkInk = Color(0xFF1F1A10);
  static const Color heritageDarkInkMuted = Color(0xFF6A5F48);

  static const Color _errorColor = Color(0xFFD64045);

  /// Default accent kept for backward compatibility with existing call sites.
  static const Color defaultAccentColor = heritageGold;

  /// Child mode exclusive colors
  static const Color childBackground = Color(0xFF1A1F3E);
  static const Color childSurface = Color(0xFF232849);
  static const Color childCard = Color(0xFF2A3060);
  static const Color childOutline = Color(0xFF3A4080);
  static const Color childPrimary = Color(0xFF4A6CF7);
  static const Color childStreakAccent = Color(0xFFE8445A);
  static const Color childPointsAccent = Color(0xFF2D5BE3);
  static const Color childTrophyAccent = Color(0xFFF5A623);
  static const Color childText = Color(0xFFF5EDD8);
  static const Color childTextMuted = Color(0xFFB8AC8C);

  // ---------------------------------------------------------------------------
  // Curriculum / track colors (unchanged — domain-level semantic colors)
  // ---------------------------------------------------------------------------

  static const Color curriculumMishna = Color(0xFF2D8C46);
  static const Color curriculumBavli = Color(0xFF1B6B5A);
  static const Color curriculumYerushalmi = Color(0xFF2980B9);
  static const Color curriculumMishnaBerurah = Color(0xFFE67E22);
  static const Color curriculumChumash = Color(0xFF5A7A2E);
  static const Color curriculumNach = Color(0xFF1ABC9C);
  static const Color curriculumMussar = Color(0xFF9B59B6);

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
        return curriculumChumash;
      case CurriculumId.mishnehTorah:
        return const Color(0xFF8E44AD);
      case CurriculumId.tanach:
        return const Color(0xFF1ABC9C);
      case CurriculumId.nach:
        return curriculumNach;
      case CurriculumId.mussar:
        return curriculumMussar;
    }
  }

  static Color getCurriculumColorByKey(String storageKey) {
    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == storageKey)
        .firstOrNull;
    return curriculum != null
        ? getCurriculumColor(curriculum)
        : defaultAccentColor;
  }

  static const Color trackPersonal = Color(0xFF4A90E2);

  static Color getTrackColor(TrackType trackType) {
    switch (trackType) {
      case TrackType.personal:
        return trackPersonal;
    }
  }

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  /// Serif display/headline for the heritage feel. Falls back gracefully.
  static TextTheme _buildTextTheme(Color onSurface, Color onSurfaceMuted) {
    final serif = GoogleFonts.playfairDisplayTextTheme();
    final sans = GoogleFonts.interTextTheme();

    TextStyle? head(TextStyle? base) =>
        base?.copyWith(color: onSurface, fontWeight: FontWeight.w700);
    TextStyle? body(TextStyle? base) => base?.copyWith(color: onSurface);
    TextStyle? subtle(TextStyle? base) => base?.copyWith(color: onSurfaceMuted);

    return TextTheme(
      displayLarge: head(serif.displayLarge),
      displayMedium: head(serif.displayMedium),
      displaySmall: head(serif.displaySmall),
      headlineLarge: head(serif.headlineLarge),
      headlineMedium: head(serif.headlineMedium),
      headlineSmall: head(serif.headlineSmall),
      titleLarge: head(serif.titleLarge),
      titleMedium: body(
        sans.titleMedium,
      )?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: body(sans.titleSmall)?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body(sans.bodyLarge),
      bodyMedium: body(sans.bodyMedium),
      bodySmall: subtle(sans.bodySmall),
      labelLarge: body(sans.labelLarge)?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: subtle(sans.labelMedium),
      labelSmall: subtle(sans.labelSmall),
    );
  }

  // ---------------------------------------------------------------------------
  // Public factory: pick a theme by (brightness, audience).
  // ---------------------------------------------------------------------------

  static ThemeData themeFor({
    required Brightness brightness,
    required bool isChildMode,
    Color accent = heritageGold,
  }) {
    if (isChildMode) {
      return _childTheme(accent: accent);
    }
    return _navyTheme(accent: accent);
  }

  /// Back-compat: keep old entry points working.
  static ThemeData darkTheme([Color accent = heritageGold]) =>
      _navyTheme(accent: accent);
  static ThemeData lightTheme([Color accent = heritageGold]) =>
      _navyTheme(accent: accent);

  // ---------------------------------------------------------------------------
  // Child (playful, gamified) theme — vibrant colors, animated feedback
  // ---------------------------------------------------------------------------

  static ThemeData _childTheme({required Color accent}) {
    final textTheme = _buildTextTheme(childText, childTextMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: childPrimary,
        onPrimary: childBackground,
        primaryContainer: childPrimary.withValues(alpha: 0.18),
        onPrimaryContainer: childPrimary,
        secondary: childStreakAccent,
        onSecondary: childBackground,
        secondaryContainer: childStreakAccent.withValues(alpha: 0.15),
        onSecondaryContainer: childStreakAccent,
        tertiary: childText,
        onTertiary: childBackground,
        tertiaryContainer: childCard,
        onTertiaryContainer: childText,
        error: _errorColor,
        onError: Colors.white,
        surface: childSurface,
        onSurface: childText,
        onSurfaceVariant: childTextMuted,
        outline: childOutline,
        shadow: Colors.black.withValues(alpha: 0.6),
      ),
      scaffoldBackgroundColor: childBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: childBackground,
        foregroundColor: childText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: childText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: childText),
      ),
      cardTheme: CardThemeData(
        color: childCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: childOutline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: childPrimary,
          foregroundColor: childBackground,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: childPrimary,
          foregroundColor: childBackground,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: childPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: childText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: childOutline),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: childCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: childOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: childOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: childPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _errorColor),
        ),
        labelStyle: GoogleFonts.inter(color: childTextMuted),
        hintStyle: GoogleFonts.inter(
          color: childTextMuted.withValues(alpha: 0.7),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: childSurface,
        selectedItemColor: childPrimary,
        unselectedItemColor: childTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: childSurface,
        indicatorColor: childPrimary.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: childPrimary);
          }
          return const IconThemeData(color: childTextMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.inter(fontSize: 12, letterSpacing: 0.2);
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(
              color: childPrimary,
              fontWeight: FontWeight.w600,
            );
          }
          return base.copyWith(color: childTextMuted);
        }),
        elevation: 0,
      ),
      dividerColor: childOutline,
      chipTheme: ChipThemeData(
        backgroundColor: childCard,
        selectedColor: childPrimary,
        labelStyle: GoogleFonts.inter(color: childText, fontSize: 13),
        secondaryLabelStyle: GoogleFonts.inter(
          color: childBackground,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: childOutline),
        ),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return childPrimary;
            return childCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return childBackground;
            return childText;
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return childPrimary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(childBackground),
        side: const BorderSide(color: childTextMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return childPrimary;
          return childTextMuted;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return childPrimary;
          return childTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return childPrimary.withValues(alpha: 0.3);
          }
          return childOutline;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: childPrimary,
        linearTrackColor: childOutline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: childSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: childOutline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: childSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: childCard,
        contentTextStyle: GoogleFonts.inter(color: childText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: childBackground),
    );
  }

  // ---------------------------------------------------------------------------
  // Navy (scholarly dark) theme — used by adult + dark brightness.
  // ---------------------------------------------------------------------------

  static ThemeData _navyTheme({required Color accent}) {
    final textTheme = _buildTextTheme(heritageInk, heritageInkMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: heritageNavy,
        primaryContainer: accent.withValues(alpha: 0.18),
        onPrimaryContainer: accent,
        secondary: heritageGoldMuted,
        onSecondary: heritageNavy,
        secondaryContainer: heritageGoldMuted.withValues(alpha: 0.15),
        onSecondaryContainer: heritageGoldMuted,
        tertiary: heritageInk,
        onTertiary: heritageNavy,
        tertiaryContainer: heritageNavyCard,
        onTertiaryContainer: heritageInk,
        error: _errorColor,
        onError: Colors.white,
        surface: heritageNavySurface,
        onSurface: heritageInk,
        onSurfaceVariant: heritageInkMuted,
        outline: heritageNavyOutline,
        shadow: Colors.black.withValues(alpha: 0.6),
      ),
      scaffoldBackgroundColor: heritageNavy,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: heritageNavy,
        foregroundColor: heritageInk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: heritageInk,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: heritageInk),
      ),
      cardTheme: CardThemeData(
        color: heritageNavyCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: heritageNavyOutline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: heritageNavy,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: heritageNavy,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: heritageInk,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: heritageNavyOutline),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: heritageNavyCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: heritageNavyOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: heritageNavyOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _errorColor),
        ),
        labelStyle: GoogleFonts.inter(color: heritageInkMuted),
        hintStyle: GoogleFonts.inter(
          color: heritageInkMuted.withValues(alpha: 0.7),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: heritageNavySurface,
        selectedItemColor: accent,
        unselectedItemColor: heritageInkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: heritageNavySurface,
        indicatorColor: accent.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return const IconThemeData(color: heritageInkMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.inter(fontSize: 12, letterSpacing: 0.2);
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: accent, fontWeight: FontWeight.w600);
          }
          return base.copyWith(color: heritageInkMuted);
        }),
        elevation: 0,
      ),
      dividerColor: heritageNavyOutline,
      chipTheme: ChipThemeData(
        backgroundColor: heritageNavyCard,
        selectedColor: accent,
        labelStyle: GoogleFonts.inter(color: heritageInk, fontSize: 13),
        secondaryLabelStyle: GoogleFonts.inter(
          color: heritageNavy,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: heritageNavyOutline),
        ),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return heritageNavyCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return heritageNavy;
            return heritageInk;
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(heritageNavy),
        side: const BorderSide(color: heritageInkMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return heritageInkMuted;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return heritageInkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.3);
          }
          return heritageNavyOutline;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: heritageNavyOutline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: heritageNavySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: heritageNavyOutline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: heritageNavySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: heritageNavyCard,
        contentTextStyle: GoogleFonts.inter(color: heritageInk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: heritageNavy),
    );
  }
}
