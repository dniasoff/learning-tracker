import 'package:shared_preferences/shared_preferences.dart';

/// Font size options for text display.
enum FontSize {
  small,
  medium,
  large;

  /// Font size multiplier relative to base size.
  double get multiplier {
    switch (this) {
      case FontSize.small:
        return 0.85;
      case FontSize.medium:
        return 1.0;
      case FontSize.large:
        return 1.2;
    }
  }

  /// Display label for UI.
  String get label {
    switch (this) {
      case FontSize.small:
        return 'Small';
      case FontSize.medium:
        return 'Medium';
      case FontSize.large:
        return 'Large';
    }
  }
}

/// Preferences for text display screen.
/// Persists font size and nikud preferences via SharedPreferences.
class TextDisplayPreferences {
  TextDisplayPreferences._();

  static final TextDisplayPreferences instance = TextDisplayPreferences._();

  static const _fontSizeKey = 'text_display_font_size';
  static const _showNikudKey = 'text_display_show_nikud';

  FontSize _fontSize = FontSize.medium;
  bool _showNikud = true;
  bool _initialized = false;

  /// Gets the current font size preference.
  FontSize get fontSize => _fontSize;

  /// Gets the current nikud display preference.
  bool get showNikud => _showNikud;

  /// Initialize from SharedPreferences. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final fontSizeIndex = prefs.getInt(_fontSizeKey);
    if (fontSizeIndex != null && fontSizeIndex < FontSize.values.length) {
      _fontSize = FontSize.values[fontSizeIndex];
    }
    _showNikud = prefs.getBool(_showNikudKey) ?? true;
    _initialized = true;
  }

  /// Sets the font size preference and persists it.
  Future<void> setFontSize(FontSize size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontSizeKey, size.index);
  }

  /// Sets the nikud display preference and persists it.
  Future<void> setShowNikud(bool value) async {
    _showNikud = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showNikudKey, value);
  }

  /// Resets to default preferences.
  void reset() {
    _fontSize = FontSize.medium;
    _showNikud = true;
    _initialized = false;
  }
}
