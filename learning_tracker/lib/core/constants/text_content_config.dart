/// Configuration for downloading text content.
class TextContentConfig {
  TextContentConfig._();

  static const String textVersion = 'text-v1.0';

  /// Base URL for text content downloads.
  /// Text files are hosted on GitHub Releases.
  static const String baseUrl =
      'https://github.com/dniasoff/learning-tracker/releases/download';

  /// Returns the download URL for a curriculum's text content.
  static String downloadUrl(String curriculumStorageKey) =>
      '$baseUrl/$textVersion/${curriculumStorageKey}_text.json.gz';
}
