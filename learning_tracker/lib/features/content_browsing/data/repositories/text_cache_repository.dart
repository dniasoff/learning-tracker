import 'package:learning_tracker/core/database/content/daos/daily_content_dao.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';

/// One inner sub-leaf within a [TextContent] — a single pasuk, mishna,
/// halacha, seif, amud, etc. When the user opens a perek/daf/siman, the
/// repository aggregates its child leaves into a list of [TextSegment]
/// so the reader can render each with a small in-line number badge
/// (e.g. `א ` before its pasuk).
class TextSegment {
  TextSegment({
    required this.sefariaRef,
    required this.hebrewText,
    required this.englishText,
    this.number,
  });

  final String sefariaRef;
  final String hebrewText;
  final String englishText;

  /// 1-based sub-position parsed from the ref (e.g. `Genesis 1:5` → 5,
  /// `Mishnah Berakhot 1:3` → 3). `null` when the ref carries no
  /// numeric suffix (e.g. `Berakhot 2a` for a Bavli amud, where there
  /// is only ever one segment anyway).
  final int? number;
}

/// Model for fetched text content.
class TextContent {
  TextContent({required this.sefariaRef, required this.segments});

  /// Convenience constructor for callers that have a single block of
  /// Hebrew + English text (no per-verse split). Mostly used by tests
  /// and legacy code paths.
  factory TextContent.single({
    required String sefariaRef,
    required String hebrewText,
    required String englishText,
  }) {
    return TextContent(
      sefariaRef: sefariaRef,
      segments: [
        TextSegment(
          sefariaRef: sefariaRef,
          hebrewText: hebrewText,
          englishText: englishText,
        ),
      ],
    );
  }

  final String sefariaRef;

  /// Ordered list of inner segments (1+). Single-segment for direct
  /// leaf opens; multi-segment for chapter-/perek-level aggregation.
  final List<TextSegment> segments;

  /// Convenience: joined Hebrew text (newline-separated). Preserved for
  /// callers that need a flat string — e.g. nikud stripping. The new
  /// per-segment renderer reads [segments] directly.
  String get hebrewText =>
      segments.map((s) => s.hebrewText).where((t) => t.isNotEmpty).join('\n');

  String get englishText =>
      segments.map((s) => s.englishText).where((t) => t.isNotEmpty).join('\n');
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
        segments: [
          TextSegment(
            sefariaRef: cached.sefariaRef,
            hebrewText: HebrewUtils.decodeHtmlEntities(cached.hebrewText),
            englishText: cached.englishText,
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
            englishText: c.englishText,
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
            englishText: daily.englishText,
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
