import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Material 3 theme for the Torah learning app.
///
/// Palette sourced from the Orvex Design System (orvex-ds.css):
///   Light: near-white canvas (#FAFAFB), indigo brand (#5658D6), terracotta CTA.
///   Dark:  near-black canvas (#08090C), lifted indigo (#8385EE), translucent
///          surfaces approximated as solid values for Flutter's Material layer.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Light palette — Orvex Design System (light tokens)
  // ---------------------------------------------------------------------------

  /// Primary brand indigo (Orvex --brand).
  static const Color brandBlue = Color(0xFF5658D6);
  static const Color brandBlueBright = Color(0xFF6F6BD8);
  static const Color brandBlueDeep = Color(0xFF3F41AB);
  static const Color brandBlueSoft = Color(0xFFECEDF9); // --brand-tint

  /// Neutral accent — Orvex --muted (warm grey, replaces legacy SlateGray).
  static const Color brandCoral = Color(0xFF6A6A76);
  static const Color brandCoralSoft = Color(0xFFF3F3F5);
  static const Color brandCoralDeep = Color(0xFF3F3F48);

  /// Warning / CTA palette — Orvex --cta terracotta-coral.
  static const Color brandWarning = Color(0xFFC8593B); // --cta
  static const Color brandWarningSoft = Color(0xFFFBEEE8); // --cta-tint
  static const Color brandWarningDeep = Color(0xFFB04D32); // --cta-600

  /// Success / progress (Olive Grove — kept for curriculum identity).
  static const Color brandGold = Color(0xFF6B8E23);
  static const Color brandGoldSoft = Color(0xFFDCE7C7);
  static const Color brandGoldDeep = Color(0xFF4F6E1A);

  /// Canvas & surface (Orvex --bg / --surface).
  static const Color brandCream = Color(0xFFFAFAFB); // --bg
  static const Color brandCreamCard = Color(0xFFFFFFFF); // --surface
  static const Color brandCreamSoft = Color(0xFFF3F3F5); // --bg-soft
  static const Color brandOutline = Color(0xFFECECEF); // --line
  static const Color brandOutlineMuted = Color(0xFFE0E0E5); // --line-2

  /// Ink / text tones (Orvex --ink / --muted / --faint).
  static const Color brandInk = Color(0xFF18181D); // --ink
  static const Color brandInk2 = Color(0xFF3F3F48); // --ink-2 (body)
  static const Color brandInkMuted = Color(0xFF6A6A76); // --muted
  static const Color brandInkSoft = Color(0xFF84848F); // --faint
  static const Color transparent = Color(0x00000000);

  static const Color _errorColor = Color(0xFFB42318); // Orvex --status-danger

  // ---------------------------------------------------------------------------
  // Dark palette — Orvex Design System (dark tokens)
  // Translucent web values (rgba) approximated as solid colours on #08090C.
  // ---------------------------------------------------------------------------

  /// Primary indigo on dark (Orvex dark --brand).
  static const Color brandBlueDark = Color(0xFF8385EE);
  static const Color brandBlueDarkContainer = Color(
    0xFF1C1D30,
  ); // dark --brand-tint
  static const Color brandBlueOnContainerDark = Color(
    0xFFBCBDF9,
  ); // dark --brand-700

  static const Color brandCoralDark = Color(0xFF888F99); // dark --muted
  static const Color brandCoralDarkContainer = Color(0xFF1E2026);
  static const Color brandCoralOnContainerDark = Color(0xFFBCC2CB);

  static const Color brandGoldDark = Color(
    0xFF5CC790,
  ); // Orvex dark --status-success
  static const Color brandGoldDarkContainer = Color(0xFF0D2B1A);
  static const Color brandGoldOnContainerDark = Color(0xFFB6E8CE);

  /// Dark canvas and surfaces.
  /// rgba(21,23,28,.72) on #08090C ≈ #15171C (solid).
  /// rgba(29,31,37,.62) on #08090C ≈ #1D1F25 (solid).
  static const Color darkSurface = Color(0xFF08090C); // --bg
  static const Color darkSurfaceCard = Color(0xFF15171C); // --surface (solid)
  static const Color darkSurfaceSoft = Color(0xFF1D1F25); // --surface-2 (solid)

  /// rgba(255,255,255,.09) on #08090C ≈ #1E1F22.
  /// rgba(255,255,255,.15) on #08090C ≈ #2D2E30.
  static const Color darkOutline = Color(0xFF1E1F22); // --line (solid)
  static const Color darkOutlineMuted = Color(0xFF2D2E30); // --line-2 (solid)

  /// Ink on dark surfaces (Orvex dark --ink / --ink-2 / --muted).
  static const Color darkInk = Color(0xFFE9EDF2); // --ink
  static const Color darkInkMuted = Color(0xFFBCC2CB); // --ink-2
  static const Color darkInkSoft = Color(0xFF888F99); // --muted

  static const Color _errorColorDark = Color(
    0xFFE59690,
  ); // dark --status-danger

  // ---------------------------------------------------------------------------
  // Curriculum / track colours (domain identity — same in both themes)
  // ---------------------------------------------------------------------------

  static const Color curriculumMishna = Color(0xFF2D8C46);
  static const Color curriculumBavli = Color(0xFF1B6B5A);
  static const Color curriculumYerushalmi = Color(0xFF1A57C2);
  static const Color curriculumMishnaBerurah = brandGold;
  static const Color curriculumChumash = Color(0xFF9C6B21);
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
    return curriculum != null ? getCurriculumColor(curriculum) : brandBlue;
  }

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  static TextTheme _buildTextTheme({required Brightness brightness}) {
    final sans = GoogleFonts.plusJakartaSansTextTheme();
    final ink = brightness == Brightness.dark ? darkInk : brandInk;
    final inkMuted = brightness == Brightness.dark
        ? darkInkMuted
        : brandInkMuted;

    TextStyle? head(TextStyle? base) =>
        base?.copyWith(color: ink, fontWeight: FontWeight.w700);
    TextStyle? body(TextStyle? base) => base?.copyWith(color: ink);
    TextStyle? subtle(TextStyle? base) => base?.copyWith(color: inkMuted);

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
    return brightness == Brightness.dark
        ? _darkTheme(accent: brandBlueDark)
        : _lightTheme(accent: accent);
  }

  static ThemeData lightTheme([Color accent = brandBlue]) =>
      _lightTheme(accent: accent);
  static ThemeData darkTheme([Color accent = brandBlueDark]) =>
      _darkTheme(accent: accent);

  // ---------------------------------------------------------------------------
  // Light theme — Orvex light palette
  // ---------------------------------------------------------------------------

  static ThemeData _lightTheme({required Color accent}) {
    final textTheme = _buildTextTheme(brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: brandBlueSoft,
        onPrimaryContainer: brandBlueDeep,
        secondary: brandCoral,
        onSecondary: Colors.white,
        secondaryContainer: brandCoralSoft,
        onSecondaryContainer: brandCoralDeep,
        tertiary: brandGold,
        onTertiary: Colors.white,
        tertiaryContainer: brandGoldSoft,
        onTertiaryContainer: brandGoldDeep,
        error: _errorColor,
        onError: Colors.white,
        surface: brandCreamCard,
        onSurface: brandInk,
        onSurfaceVariant: brandInkMuted,
        outline: brandOutline,
        outlineVariant: brandOutlineMuted,
        shadow: Colors.black.withValues(alpha: 0.07),
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
        indicatorColor: accent.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return const IconThemeData(color: brandInkMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.plusJakartaSans(
            fontSize: 12,
            letterSpacing: 0.2,
          );
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: accent, fontWeight: FontWeight.w700);
          }
          return base.copyWith(
            color: brandInkMuted,
            fontWeight: FontWeight.w500,
          );
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

  // ---------------------------------------------------------------------------
  // Dark theme — Orvex dark palette
  // ---------------------------------------------------------------------------

  static ThemeData _darkTheme({required Color accent}) {
    final textTheme = _buildTextTheme(brightness: Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: brandBlueDarkContainer,
        onPrimaryContainer: brandBlueOnContainerDark,
        secondary: brandCoralDark,
        onSecondary: darkSurface,
        secondaryContainer: brandCoralDarkContainer,
        onSecondaryContainer: brandCoralOnContainerDark,
        tertiary: brandGoldDark,
        onTertiary: darkSurface,
        tertiaryContainer: brandGoldDarkContainer,
        onTertiaryContainer: brandGoldOnContainerDark,
        error: _errorColorDark,
        onError: darkSurface,
        surface: darkSurfaceCard,
        onSurface: darkInk,
        onSurfaceVariant: darkInkMuted,
        outline: darkOutline,
        outlineVariant: darkOutlineMuted,
        shadow: Colors.black.withValues(alpha: 0.5),
      ),
      scaffoldBackgroundColor: darkSurface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkInk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: darkInk,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: darkInk),
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkOutline, width: 1),
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
          foregroundColor: darkInk,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          side: const BorderSide(color: darkOutline),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorColorDark),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: darkInkMuted),
        hintStyle: GoogleFonts.plusJakartaSans(color: darkInkSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurfaceCard,
        selectedItemColor: accent,
        unselectedItemColor: darkInkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return const IconThemeData(color: darkInkMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.plusJakartaSans(
            fontSize: 12,
            letterSpacing: 0.2,
          );
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: accent, fontWeight: FontWeight.w700);
          }
          return base.copyWith(
            color: darkInkMuted,
            fontWeight: FontWeight.w500,
          );
        }),
        surfaceTintColor: transparent,
        elevation: 0,
      ),
      dividerColor: darkOutline,
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceSoft,
        selectedColor: accent,
        labelStyle: GoogleFonts.plusJakartaSans(color: darkInk, fontSize: 13),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkOutline),
        ),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return darkSurfaceCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return darkInk;
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: darkInkMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return darkInkMuted;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return darkInkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.3);
          }
          return darkOutline;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandGoldDark,
        linearTrackColor: darkOutline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkOutline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceSoft,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: darkInk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: darkSurface),
    );
  }
}
