import 'package:learning_tracker/core/database/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';

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

/// Repository for fetching and caching Sefaria text content.
/// Implements cache-first strategy: check cache, then fetch from API if needed.
class TextCacheRepository {
  TextCacheRepository({
    required this.textCacheDao,
    required this.contentFetcher,
  });

  final TextCacheDao textCacheDao;
  final CurriculumContentFetcher contentFetcher;

  /// Retrieves text for a given Sefaria reference.
  /// Cache-first: returns cached text if available, otherwise fetches from API.
  /// Returns null if offline and text is not cached.
  Future<TextContent?> getText(String sefariaRef) async {
    // Check cache first
    final cached = await textCacheDao.getText(sefariaRef);
    if (cached != null) {
      return TextContent(
        sefariaRef: cached.sefariaRef,
        hebrewText: cached.hebrewText,
        englishText: cached.englishText,
      );
    }

    // Not cached - fetch from API
    try {
      final hebrewText = await contentFetcher.fetchText(sefariaRef, lang: 'he');
      final englishText = await contentFetcher.fetchText(
        sefariaRef,
        lang: 'en',
      );

      // Store in cache
      await textCacheDao.storeText(
        sefariaRef: sefariaRef,
        hebrewText: hebrewText,
        englishText: englishText,
      );

      return TextContent(
        sefariaRef: sefariaRef,
        hebrewText: hebrewText,
        englishText: englishText,
      );
    } on SefariaApiException {
      // Network error or API failure - return null
      return null;
    }
  }

  /// Clears all cached text.
  Future<void> clearCache() => textCacheDao.clearCache();

  /// Returns list of all cached Sefaria references.
  Future<List<String>> getCachedRefs() => textCacheDao.getAllCachedRefs();
}
