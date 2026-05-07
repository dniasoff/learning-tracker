import 'package:learning_tracker/core/database/content/daos/daily_content_dao.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';

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
///
/// Lookup chain (cache-only — returns null if no source has it):
/// 1. [textCacheDao] — atomic curriculum content keyed by exact ref.
/// 2. [dailyContentDao] — pre-resolved bilingual text for refs emitted by
///    calendar programs (e.g. `Chullin 7` daf-level rather than the
///    `Chullin 7a` / `Chullin 7b` atomic pair text_cache stores).
class TextCacheRepository {
  TextCacheRepository({
    required this.textCacheDao,
    required this.dailyContentDao,
  });

  final ContentTextCacheDao textCacheDao;
  final DailyContentDao dailyContentDao;

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
    final daily = await dailyContentDao.getByRef(sefariaRef);
    if (daily != null) {
      return TextContent(
        sefariaRef: daily.sefariaRef,
        hebrewText: daily.hebrewText,
        englishText: daily.englishText,
      );
    }
    return null;
  }

  /// Returns list of all cached Sefaria references.
  Future<List<String>> getCachedRefs() => textCacheDao.getAllCachedRefs();
}
