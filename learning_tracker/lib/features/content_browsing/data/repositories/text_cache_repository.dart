import 'package:learning_tracker/core/database/content/daos/daily_content_dao.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';

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
  ///
  /// Lookup order:
  /// 1. Exact match in text_cache (pasuk/amud level)
  /// 2. Exact match in daily_content (calendar-assigned daf/chapter text)
  /// 3. Child-verse aggregation: combine all verses LIKE '$sefariaRef:%'
  ///
  /// Hebrew text is decoded (HTML entities, parasha markers) before returning.
  Future<TextContent?> getText(String sefariaRef) async {
    final cached = await textCacheDao.getText(sefariaRef);
    if (cached != null) {
      return TextContent(
        sefariaRef: cached.sefariaRef,
        hebrewText: HebrewUtils.decodeHtmlEntities(cached.hebrewText),
        englishText: cached.englishText,
      );
    }

    final daily = await dailyContentDao.getByRef(sefariaRef);
    if (daily != null) {
      return TextContent(
        sefariaRef: daily.sefariaRef,
        hebrewText: HebrewUtils.decodeHtmlEntities(daily.hebrewText),
        englishText: daily.englishText,
      );
    }

    // Chapter-level fallback: aggregate child verse rows.
    final children = await textCacheDao.getChildTexts(sefariaRef);
    if (children.isNotEmpty) {
      children.sort((a, b) {
        final numA = _verseNumber(a.sefariaRef);
        final numB = _verseNumber(b.sefariaRef);
        return numA.compareTo(numB);
      });
      final he = children
          .map((c) => HebrewUtils.decodeHtmlEntities(c.hebrewText))
          .where((t) => t.isNotEmpty)
          .join('\n');
      final en = children
          .map((c) => c.englishText)
          .where((t) => t.isNotEmpty)
          .join('\n');
      if (he.isNotEmpty || en.isNotEmpty) {
        return TextContent(sefariaRef: sefariaRef, hebrewText: he, englishText: en);
      }
    }

    return null;
  }

  static int _verseNumber(String sefariaRef) {
    final colonIdx = sefariaRef.lastIndexOf(':');
    if (colonIdx < 0) return 0;
    return int.tryParse(sefariaRef.substring(colonIdx + 1)) ?? 0;
  }

  /// Returns list of all cached Sefaria references.
  Future<List<String>> getCachedRefs() => textCacheDao.getAllCachedRefs();
}
