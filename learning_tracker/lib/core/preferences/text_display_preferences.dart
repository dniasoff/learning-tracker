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
