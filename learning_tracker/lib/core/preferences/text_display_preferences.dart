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
/// Currently in-memory; can be upgraded to SharedPreferences or Drift later.
class TextDisplayPreferences {
  TextDisplayPreferences._();

  static final TextDisplayPreferences instance = TextDisplayPreferences._();

  FontSize _fontSize = FontSize.medium;

  /// Gets the current font size preference.
  FontSize get fontSize => _fontSize;

  /// Sets the font size preference.
  void setFontSize(FontSize size) {
    _fontSize = size;
  }

  /// Resets to default preferences.
  void reset() {
    _fontSize = FontSize.medium;
  }
}
