import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

/// Material 3 themes for the Torah learning app.
///
/// Every colour comes from [AppPalette], the single brightness-aware token
/// layer, which is registered on both themes as a [ThemeExtension]. Widgets
/// read tokens through `context.colors.<token>` and therefore always get the
/// value that matches the ambient brightness.
///
/// This class intentionally exposes NO colour constants. It previously held
/// ~40 light-only `static const Color`s that feature code referenced directly
/// (775 call sites); under `ThemeMode.system` those painted light-mode values
/// onto dark surfaces. Keeping the surface empty means the analyzer catches
/// any attempt to reintroduce a brightness-blind colour.
///
/// Palette direction: deep royal blue primary with a warm terracotta accent,
/// on a cool near-white canvas (light) and a deep navy-black canvas (dark).
/// Layout, spacing, radii and typography scale are unchanged from the previous
/// theme — this is a colour-only redefinition.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  static TextTheme _buildTextTheme(AppPalette c) {
    final sans = GoogleFonts.plusJakartaSansTextTheme();

    TextStyle? head(TextStyle? base) =>
        base?.copyWith(color: c.brandInk, fontWeight: FontWeight.w700);
    TextStyle? body(TextStyle? base) => base?.copyWith(color: c.brandInk2);
    TextStyle? subtle(TextStyle? base) =>
        base?.copyWith(color: c.brandInkMuted);

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
      )?.copyWith(color: c.brandInk, fontWeight: FontWeight.w600),
      titleSmall: body(
        sans.titleSmall,
      )?.copyWith(color: c.brandInk, fontWeight: FontWeight.w600),
      bodyLarge: body(sans.bodyLarge),
      bodyMedium: body(sans.bodyMedium),
      bodySmall: subtle(sans.bodySmall),
      labelLarge: body(
        sans.labelLarge,
      )?.copyWith(color: c.brandInk, fontWeight: FontWeight.w600),
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
    Color? accent,
  }) => brightness == Brightness.dark ? darkTheme(accent) : lightTheme(accent);

  static ThemeData lightTheme([Color? accent]) =>
      _build(AppPalette.light, accent ?? AppPalette.light.brandBlue);

  static ThemeData darkTheme([Color? accent]) =>
      _build(AppPalette.dark, accent ?? AppPalette.dark.brandBlue);

  // ---------------------------------------------------------------------------
  // Shared builder — one definition drives both brightnesses, so a component
  // can never be styled in one mode and forgotten in the other.
  // ---------------------------------------------------------------------------

  static ThemeData _build(AppPalette c, Color accent) {
    final isDark = c.brightness == Brightness.dark;
    final textTheme = _buildTextTheme(c);
    // Text sitting ON a filled accent. Rather than assume white, pick
    // whichever of near-black / white actually contrasts better with the
    // fill: in dark mode the primary is a LIFTED (light) blue where
    // white-on-primary is only 2.5:1, and even in light mode the warm
    // accent is a mid-tone that white does not clear AA against.
    Color onFill(Color fill) {
      const white = Color(0xFFFFFFFF);
      const nearBlack = Color(0xFF0B0F1A);
      double ratio(Color a, Color b) {
        final la = a.computeLuminance();
        final lb = b.computeLuminance();
        final hi = la > lb ? la : lb;
        final lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      return ratio(white, fill) >= ratio(nearBlack, fill) ? white : nearBlack;
    }

    final onAccent = onFill(accent);

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      extensions: <ThemeExtension<dynamic>>[c],
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: accent,
        onPrimary: onAccent,
        primaryContainer: c.brandBlueSoft,
        onPrimaryContainer: c.brandBlueDeep,
        secondary: c.brandCoral,
        onSecondary: onFill(c.brandCoral),
        secondaryContainer: c.brandCoralSoft,
        onSecondaryContainer: c.brandCoralDeep,
        tertiary: c.brandGold,
        onTertiary: onFill(c.brandGold),
        tertiaryContainer: c.brandGoldSoft,
        onTertiaryContainer: c.brandGoldDeep,
        error: c.brandError,
        onError: onFill(c.brandError),
        errorContainer: c.brandErrorSoft,
        onErrorContainer: c.brandError,
        surface: c.brandCreamCard,
        onSurface: c.brandInk,
        surfaceContainerLowest: c.brandCreamCard,
        surfaceContainerLow: c.brandCream,
        surfaceContainer: c.brandCreamSoft,
        surfaceContainerHigh: c.brandCreamSoft,
        surfaceContainerHighest: c.brandCreamSoft,
        onSurfaceVariant: c.brandInkMuted,
        outline: c.brandOutline,
        outlineVariant: c.brandOutlineMuted,
        shadow: Color.fromRGBO(0, 0, 0, isDark ? 0.5 : 0.07),
      ),
      scaffoldBackgroundColor: c.brandCream,
      canvasColor: c.brandCream,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: c.brandInkMuted),
      appBarTheme: AppBarTheme(
        backgroundColor: c.brandCream,
        foregroundColor: c.brandInk,
        surfaceTintColor: c.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: c.brandInk,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: c.brandInk),
      ),
      cardTheme: CardThemeData(
        color: c.brandCreamCard,
        surfaceTintColor: c.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.brandOutline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: c.brandCreamSoft,
          disabledForegroundColor: c.brandInkSoft,
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
          foregroundColor: onAccent,
          disabledBackgroundColor: c.brandCreamSoft,
          disabledForegroundColor: c.brandInkSoft,
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
          disabledForegroundColor: c.brandInkSoft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brandInk,
          disabledForegroundColor: c.brandInkSoft,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          side: BorderSide(color: c.brandOutlineMuted),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? c.brandCreamSoft : c.brandCreamCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brandOutlineMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brandOutlineMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brandError),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: c.brandInkMuted),
        hintStyle: GoogleFonts.plusJakartaSans(color: c.brandInkSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.brandCreamCard,
        selectedItemColor: accent,
        unselectedItemColor: c.brandInkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.transparent,
        indicatorColor: Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.22 : 0.14),
          c.brandCreamCard,
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return IconThemeData(color: c.brandInkMuted);
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
            color: c.brandInkMuted,
            fontWeight: FontWeight.w500,
          );
        }),
        surfaceTintColor: c.transparent,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: c.brandOutline, space: 1),
      dividerColor: c.brandOutline,
      chipTheme: ChipThemeData(
        backgroundColor: c.brandCreamSoft,
        selectedColor: accent,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: c.brandInk,
          fontSize: 13,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          color: onAccent,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.brandOutline),
        ),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return c.brandCreamCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return onAccent;
            return c.brandInk;
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return c.transparent;
        }),
        checkColor: WidgetStateProperty.all(onAccent),
        side: BorderSide(color: c.brandInkMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return c.brandInkMuted;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return c.brandInkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Color.alphaBlend(
              accent.withValues(alpha: 0.35),
              c.brandCreamCard,
            );
          }
          return c.brandCreamSoft;
        }),
        trackOutlineColor: WidgetStateProperty.all(c.brandOutlineMuted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: c.brandCreamSoft,
        circularTrackColor: c.brandCreamSoft,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.brandCreamCard,
        surfaceTintColor: c.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.brandOutline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.brandCreamCard,
        surfaceTintColor: c.transparent,
        // Scrim strong enough to isolate the sheet from the page behind it.
        modalBarrierColor: Color.fromRGBO(0, 0, 0, isDark ? 0.62 : 0.45),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.brandCreamSoft : c.brandInk,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? c.brandInk : c.brandCreamCard,
        ),
        actionTextColor: isDark ? c.brandBlueBright : c.brandBlueSoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.brandCreamSoft : c.brandInk,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? c.brandInk : c.brandCreamCard,
          fontSize: 12,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.brandInkMuted,
        textColor: c.brandInk,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: c.brandCream),
    );
  }
}
