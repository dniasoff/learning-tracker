# Hebrew Fonts

This directory is reserved for custom Hebrew fonts if the system default font proves insufficient for Hebrew text rendering.

## Current Status

Currently using the system default Roboto font, which provides adequate Hebrew support.

## Adding Custom Fonts

To add a custom Hebrew font:

1. Place the font file(s) (e.g., `.ttf` or `.otf`) in this directory
2. Update `pubspec.yaml` with the font configuration:

```yaml
flutter:
  fonts:
    - family: CustomHebrew
      fonts:
        - asset: assets/fonts/CustomHebrew-Regular.ttf
        - asset: assets/fonts/CustomHebrew-Bold.ttf
          weight: 700
```

3. Update `lib/core/theme/text_styles.dart` to use the custom font:

```dart
static const String _hebrewFontFamily = 'CustomHebrew';
```

## Recommended Fonts for Torah Learning

- **Frank Ruehl CLM**: Traditional Hebrew serif font
- **Taamey David CLM**: Includes cantillation marks
- **SBL Hebrew**: Academic Hebrew font
