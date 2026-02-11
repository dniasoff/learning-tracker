/// Utilities for Hebrew text processing.
class HebrewUtils {
  HebrewUtils._();

  /// Unicode ranges for Hebrew nikud (vowel/cantillation marks):
  /// U+0591-U+05BD, U+05BF, U+05C1-U+05C2, U+05C4-U+05C5, U+05C7
  static final RegExp _nikudPattern = RegExp(
    '[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]',
  );

  /// Strips all nikud (vowel marks) from Hebrew text.
  static String stripNikud(String text) {
    return text.replaceAll(_nikudPattern, '');
  }

  /// Returns true if the text contains any nikud characters.
  static bool hasNikud(String text) {
    return _nikudPattern.hasMatch(text);
  }
}
