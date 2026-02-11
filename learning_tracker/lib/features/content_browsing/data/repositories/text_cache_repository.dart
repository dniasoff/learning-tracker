import 'package:learning_tracker/core/database/daos/text_cache_dao.dart';

/// Model for fetched text content.
class TextContent {
  TextContent({
    required this.sefariaRef,
    required this.hebrewText,
    required this.englishText,
  });

  final String sefariaRef;
  final String hebrewText;
  final String englishText;
}

/// Repository for cached Sefaria text content.
/// Cache-only: returns null if text is not cached.
class TextCacheRepository {
  TextCacheRepository({required this.textCacheDao});

  final TextCacheDao textCacheDao;

  /// Retrieves text for a given Sefaria reference.
  /// Returns cached text if available, otherwise returns null.
  Future<TextContent?> getText(String sefariaRef) async {
    final cached = await textCacheDao.getText(sefariaRef);
    if (cached != null) {
      return TextContent(
        sefariaRef: cached.sefariaRef,
        hebrewText: cached.hebrewText,
        englishText: cached.englishText,
      );
    }
    return null;
  }

  /// Clears all cached text.
  Future<void> clearCache() => textCacheDao.clearCache();

  /// Returns list of all cached Sefaria references.
  Future<List<String>> getCachedRefs() => textCacheDao.getAllCachedRefs();
}
