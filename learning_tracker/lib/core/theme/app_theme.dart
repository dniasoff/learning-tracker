import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

/// Material 3 theme for the Torah learning app.
///
/// App-wide palette:
/// - Primary: Techelet Blue (#0038A8)
/// - Secondary background: Stone White (#F9F9FB)
/// - Accent: Silver Slate (#708090)
/// - Success: Olive Grove (#6B8E23)
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Canonical palette
  // ---------------------------------------------------------------------------

  /// Primary brand blue (Techelet Blue).
  static const Color brandBlue = Color(0xFF0038A8);
  static const Color brandBlueBright = Color(0xFF1A57C2);
  static const Color brandBlueDeep = Color(0xFF002A80);
  static const Color brandBlueSoft = Color(0xFFD9E2F4);

  /// Neutral accent (Silver Slate) for secondary text and iconography.
  static const Color brandCoral = Color(0xFF708090);
  static const Color brandCoralSoft = Color(0xFFD8DEE3);
  static const Color brandCoralDeep = Color(0xFF4E5E70);

  /// Success color (Olive Grove) for progress and streaks.
  static const Color brandGold = Color(0xFF6B8E23);
  static const Color brandGoldSoft = Color(0xFFDCE7C7);
  static const Color brandGoldDeep = Color(0xFF4F6E1A);

  /// Secondary background and neutral surfaces.
  static const Color brandCream = Color(0xFFF9F9FB);
  static const Color brandCreamCard = Color(0xFFFFFFFF);
  static const Color brandCreamSoft = Color(0xFFF1F3F7);
  static const Color brandOutline = Color(0xFFC3CBD3);
  static const Color brandOutlineMuted = Color(0xFFA4AFBA);

  /// Ink/text tones.
  static const Color brandInk = Color(0xFF1B2330);
  static const Color brandInkMuted = Color(0xFF708090);
  static const Color brandInkSoft = Color(0xFF95A1AE);
  static const Color transparent = Color(0x00000000);

  static const Color _errorColor = Color(0xFFB00020);

  /// Default accent kept for backward compatibility with existing call sites.
  static const Color defaultAccentColor = brandBlue;

  // ---------------------------------------------------------------------------
  // Legacy aliases — kept for compatibility with existing widgets that
  // reference older names. All map to the new light palette.
  // ---------------------------------------------------------------------------

  static const Color heritageGold = brandGold;
  static const Color heritageGoldMuted = brandGoldDeep;
  static const Color heritageGoldSoft = brandGoldSoft;

  static const Color heritageNavy = brandCream;
  static const Color heritageNavySurface = brandCreamSoft;
  static const Color heritageNavyCard = brandCreamCard;
  static const Color heritageNavyOutline = brandOutline;

  static const Color heritageParchment = brandCream;
  static const Color heritageParchmentSurface = brandCreamSoft;
  static const Color heritageParchmentCard = brandCreamCard;
  static const Color heritageParchmentOutline = brandOutline;

  static const Color heritageInk = brandInk;
  static const Color heritageInkMuted = brandInkMuted;

  static const Color heritageDarkInk = brandInk;
  static const Color heritageDarkInkMuted = brandInkMuted;

  /// Child mode aliases — reuse brand palette so UI stays consistent.
  static const Color childBackground = brandCream;
  static const Color childSurface = brandCreamSoft;
  static const Color childCard = brandCreamCard;
  static const Color childOutline = brandOutline;
  static const Color childPrimary = brandBlue;
  static const Color childStreakAccent = brandGold;
  static const Color childPointsAccent = brandBlueBright;
  static const Color childTrophyAccent = brandGold;
  static const Color childText = brandInk;
  static const Color childTextMuted = brandInkMuted;

  // ---------------------------------------------------------------------------
  // Curriculum / track colors
  // ---------------------------------------------------------------------------

  static const Color curriculumMishna = Color(0xFF2D8C46);
  static const Color curriculumBavli = Color(0xFF1B6B5A);
  static const Color curriculumYerushalmi = brandBlueBright;
  static const Color curriculumMishnaBerurah = brandGold;
  static const Color curriculumChumash = brandCoral;
  static const Color curriculumNach = Color(0xFF0EA5A0);
  static const Color curriculumMussar = Color(0xFF7C3AED);

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
        return const Color(0xFF7C3AED);
      case CurriculumId.tanach:
        return const Color(0xFF0EA5A0);
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

  static const Color trackPersonal = brandBlue;

  static Color getTrackColor(TrackType trackType) {
    switch (trackType) {
      case TrackType.personal:
        return trackPersonal;
    }
  }

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  static TextTheme _buildTextTheme() {
    final sans = GoogleFonts.plusJakartaSansTextTheme();

    TextStyle? head(TextStyle? base) =>
        base?.copyWith(color: brandInk, fontWeight: FontWeight.w700);
    TextStyle? body(TextStyle? base) => base?.copyWith(color: brandInk);
    TextStyle? subtle(TextStyle? base) => base?.copyWith(color: brandInkMuted);

    return TextTheme(
      displayLarge: head(sans.displayLarge),
      displayMedium: head(sans.displayMedium),
      displaySmall: head(sans.displaySmall),
      headlineLarge: head(sans.headlineLarge),
      headlineMedium: head(sans.headlineMedium),
      headlineSmall: head(sans.headlineSmall),
      titleLarge: head(sans.titleLarge),
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
  // Public factory
  // ---------------------------------------------------------------------------

  static ThemeData themeFor({
    Brightness brightness = Brightness.light,
    bool isChildMode = false,
    Color accent = brandBlue,
  }) {
    return _lightTheme(accent: accent);
  }

  /// Back-compat entry points.
  static ThemeData lightTheme([Color accent = brandBlue]) =>
      _lightTheme(accent: accent);
  static ThemeData darkTheme([Color accent = brandBlue]) =>
      _lightTheme(accent: accent);

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------

  static ThemeData _lightTheme({required Color accent}) {
    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: brandBlueSoft,
        onPrimaryContainer: brandBlueDeep,
        secondary: brandCoral,
        onSecondary: brandCream,
        secondaryContainer: brandCoralSoft,
        onSecondaryContainer: brandCoralDeep,
        tertiary: brandGold,
        onTertiary: brandCream,
        tertiaryContainer: brandGoldSoft,
        onTertiaryContainer: brandGoldDeep,
        error: _errorColor,
        onError: Colors.white,
        surface: brandCreamCard,
        onSurface: brandInk,
        onSurfaceVariant: brandInkMuted,
        outline: brandOutline,
        outlineVariant: brandOutlineMuted,
        shadow: Colors.black.withValues(alpha: 0.08),
      ),
      scaffoldBackgroundColor: brandCream,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: brandCream,
        foregroundColor: brandInk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: brandInk,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: brandInk),
      ),
      cardTheme: CardThemeData(
        color: brandCreamCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: brandOutline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandInk,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          side: const BorderSide(color: brandOutline),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brandCreamCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorColor),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: brandInkMuted),
        hintStyle: GoogleFonts.plusJakartaSans(color: brandInkSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: brandCreamCard,
        selectedItemColor: accent,
        unselectedItemColor: brandInkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: transparent,
        indicatorColor: brandBlue.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return const IconThemeData(color: brandCoral);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.plusJakartaSans(
            fontSize: 12,
            letterSpacing: 0.2,
          );
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: accent, fontWeight: FontWeight.w700);
          }
          return base.copyWith(color: brandCoral, fontWeight: FontWeight.w500);
        }),
        surfaceTintColor: transparent,
        elevation: 0,
      ),
      dividerColor: brandOutline,
      chipTheme: ChipThemeData(
        backgroundColor: brandCreamSoft,
        selectedColor: accent,
        labelStyle: GoogleFonts.plusJakartaSans(color: brandInk, fontSize: 13),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: brandOutline),
        ),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return brandCreamCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return brandInk;
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: brandInkMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return brandInkMuted;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return brandInkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.3);
          }
          return brandOutline;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandGold,
        linearTrackColor: brandOutline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: brandCreamCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: brandOutline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: brandCreamCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brandInk,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: brandCream),
    );
  }
}
