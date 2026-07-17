import 'package:learning_tracker/core/database/content/daos/daily_content_dao.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';

export 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';

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
        segments: [
          TextSegment(
            sefariaRef: cached.sefariaRef,
            hebrewText: HebrewUtils.decodeHtmlEntities(cached.hebrewText),
            englishText: HebrewUtils.cleanSefariaText(cached.englishText),
            number: _verseNumberOrNull(cached.sefariaRef),
          ),
        ],
      );
    }

    // Chapter-level aggregation: try child verse rows before the daily_content
    // blob. If individual rows exist (e.g. "Pirkei Avot 1:1"…"1:18" for
    // "Pirkei Avot 1"), use them so each verse gets a number badge.
    // daily_content is the fallback for refs without child rows (e.g. Talmud
    // chapter blobs like "Berakhot 1").
    final children = await textCacheDao.getChildTexts(sefariaRef);
    if (children.isNotEmpty) {
      children.sort((a, b) {
        final numA = _verseNumber(a.sefariaRef);
        final numB = _verseNumber(b.sefariaRef);
        return numA.compareTo(numB);
      });
      final segments = <TextSegment>[];
      for (final c in children) {
        final he = HebrewUtils.decodeHtmlEntities(c.hebrewText);
        if (he.isEmpty && c.englishText.isEmpty) continue;
        segments.add(
          TextSegment(
            sefariaRef: c.sefariaRef,
            hebrewText: he,
            englishText: HebrewUtils.cleanSefariaText(c.englishText),
            number: _verseNumberOrNull(c.sefariaRef),
          ),
        );
      }
      if (segments.isNotEmpty) {
        return TextContent(sefariaRef: sefariaRef, segments: segments);
      }
    }

    // Last resort: daily_content blob (e.g. Talmud chapter or program refs
    // that have no individual child rows in text_cache).
    final daily = await dailyContentDao.getByRef(sefariaRef);
    if (daily != null) {
      return TextContent(
        sefariaRef: daily.sefariaRef,
        segments: [
          TextSegment(
            sefariaRef: daily.sefariaRef,
            hebrewText: HebrewUtils.decodeHtmlEntities(daily.hebrewText),
            englishText: HebrewUtils.cleanSefariaText(daily.englishText),
            number: _verseNumberOrNull(daily.sefariaRef),
          ),
        ],
      );
    }

    return null;
  }

  static int _verseNumber(String sefariaRef) {
    return _verseNumberOrNull(sefariaRef) ?? 0;
  }

  static int? _verseNumberOrNull(String sefariaRef) {
    final colonIdx = sefariaRef.lastIndexOf(':');
    if (colonIdx < 0) return null;
    return int.tryParse(sefariaRef.substring(colonIdx + 1));
  }

  /// Returns list of all cached Sefaria references.
  Future<List<String>> getCachedRefs() => textCacheDao.getAllCachedRefs();
}
