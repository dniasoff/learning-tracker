import 'package:learning_tracker/core/database/content/content_database.dart';
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
  /// 1. Child-verse aggregation for chapter-level refs with cached children.
  /// 2. Exact match in text_cache (pasuk/amud level or chapter fallback).
  /// 3. Exact match in daily_content (calendar-assigned daf/chapter text).
  ///
  /// Hebrew text is decoded (HTML entities, parasha markers) before returning.
  Future<TextContent?> getText(String sefariaRef) async {
    // Prefer child rows for chapter-level refs so Hebrew and English remain
    // paired per pasuk in the reader. A cached parent row may contain both
    // languages as whole-chapter blocks and would otherwise hide those rows.
    final children = await textCacheDao.getChildTexts(sefariaRef);
    if (_verseNumberOrNull(sefariaRef) == null && children.isNotEmpty) {
      final content = _contentFromChildren(sefariaRef, children);
      if (content != null) return content;
    }

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
    if (children.isNotEmpty) {
      final content = _contentFromChildren(sefariaRef, children);
      if (content != null) return content;
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

  TextContent? _contentFromChildren(
    String sefariaRef,
    List<TextCacheData> children,
  ) {
    children.sort((a, b) {
      final numA = _verseNumber(a.sefariaRef);
      final numB = _verseNumber(b.sefariaRef);
      return numA.compareTo(numB);
    });
    final segments = <TextSegment>[];
    for (final child in children) {
      final hebrew = HebrewUtils.decodeHtmlEntities(child.hebrewText);
      if (hebrew.isEmpty && child.englishText.isEmpty) continue;
      segments.add(
        TextSegment(
          sefariaRef: child.sefariaRef,
          hebrewText: hebrew,
          englishText: HebrewUtils.cleanSefariaText(child.englishText),
          number: _verseNumberOrNull(child.sefariaRef),
        ),
      );
    }
    if (segments.isEmpty) return null;
    return TextContent(sefariaRef: sefariaRef, segments: segments);
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
