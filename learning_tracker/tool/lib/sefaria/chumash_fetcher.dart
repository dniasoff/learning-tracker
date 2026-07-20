import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

import 'sefaria_fetcher_base.dart';

/// Fetches Chumash (Five Books of Moses) content from Sefaria.
///
/// Parses the Sefaria Tanakh shape API into a 4-level hierarchy:
/// sefer -> parsha -> perek -> pasuk (5,845 verses).
///
/// Parsha boundaries are well-known fixed data and are defined inline.
class ChumashFetcher extends SefariaFetcherBase {
  ChumashFetcher({required super.dio});

  @override
  String get curriculumId => CurriculumId.chumash.storageKey;

  @override
  Future<FetchResult> fetchAllContent() async {
    final shapeData = await fetchShape('Tanakh');

    final items = <ContentItem>[];
    var sortOrder = 0;
    var leafCount = 0;

    // Filter to Torah books only (first 5 books in Tanakh).
    final torahBooks = shapeData
        .where(
          (book) => SefariaFetcherBase.torahTitles.contains(
            book['title'] as String? ?? '',
          ),
        )
        .toList();

    for (final book in torahBooks) {
      final title = book['title'] as String? ?? '';
      final heTitle = book['heTitle'] as String? ?? '';
      final chapters = book['chapters'] as List<dynamic>? ?? [];

      // Add sefer container.
      items.add(
        ContentItem(
          curriculumId: curriculumId,
          level1: title,
          displayNameHe: heTitle,
          displayNameEn: title,
          sefariaRef: title,
          sortOrder: sortOrder++,
          isLeaf: false,
        ),
      );

      // Get parsha boundaries for this book.
      final parshiyot = _parshaBoundaries[title] ?? [];

      // Track current parsha index for assigning chapters to parshiyot.
      var parshaIdx = 0;

      for (var chapterIdx = 0; chapterIdx < chapters.length; chapterIdx++) {
        final chapterNum = chapterIdx + 1;
        final verseCount = (chapters[chapterIdx] as num?)?.toInt() ?? 0;

        // Advance to next parsha if this chapter starts one.
        while (parshaIdx < parshiyot.length - 1 &&
            chapterNum >= parshiyot[parshaIdx + 1].startChapter) {
          parshaIdx++;
        }

        final parsha = parshaIdx < parshiyot.length
            ? parshiyot[parshaIdx]
            : const _ParshaInfo('Unknown', 'Unknown', 1);

        // Add parsha container (only on first chapter of parsha).
        if (chapterNum == parsha.startChapter) {
          items.add(
            ContentItem(
              curriculumId: curriculumId,
              level1: title,
              level2: parsha.nameEn,
              displayNameHe: parsha.nameHe,
              displayNameEn: parsha.nameEn,
              sefariaRef: '$title ${parsha.startChapter}',
              sortOrder: sortOrder++,
              isLeaf: false,
            ),
          );
        }

        // Add perek container.
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: title,
            level2: parsha.nameEn,
            level3: chapterNum.toString(),
            displayNameHe: '$heTitle \u05E4\u05E8\u05E7 $chapterNum',
            displayNameEn: '$title Chapter $chapterNum',
            sefariaRef: '$title $chapterNum',
            sortOrder: sortOrder++,
            isLeaf: false,
          ),
        );

        // Add pesukim (leaf nodes).
        for (var verseNum = 1; verseNum <= verseCount; verseNum++) {
          items.add(
            ContentItem(
              curriculumId: curriculumId,
              level1: title,
              level2: parsha.nameEn,
              level3: chapterNum.toString(),
              level4: verseNum.toString(),
              displayNameHe: '$heTitle $chapterNum:$verseNum',
              displayNameEn: '$title $chapterNum:$verseNum',
              sefariaRef: '$title $chapterNum.$verseNum',
              sortOrder: sortOrder++,
              isLeaf: true,
            ),
          );
          leafCount++;
        }
      }
    }

    return FetchResult(
      items: items,
      hierarchyConfig: CurriculumHierarchyConfig(
        curriculumId: curriculumId,
        levelLabels: const ['Sefer', 'Parsha', 'Perek', 'Pasuk'],
        totalItems: leafCount,
      ),
    );
  }

  /// Weekly Torah portion boundaries by book.
  static const Map<String, List<_ParshaInfo>> _parshaBoundaries = {
    'Genesis': [
      _ParshaInfo('Bereshit', '\u05D1\u05E8\u05D0\u05E9\u05D9\u05EA', 1),
      _ParshaInfo('Noach', '\u05E0\u05D7', 6),
      _ParshaInfo('Lech Lecha', '\u05DC\u05DA \u05DC\u05DA', 12),
      _ParshaInfo('Vayera', '\u05D5\u05D9\u05E8\u05D0', 18),
      _ParshaInfo('Chayei Sara', '\u05D7\u05D9\u05D9 \u05E9\u05E8\u05D4', 23),
      _ParshaInfo('Toldot', '\u05EA\u05D5\u05DC\u05D3\u05D5\u05EA', 25),
      _ParshaInfo('Vayetzei', '\u05D5\u05D9\u05E6\u05D0', 28),
      _ParshaInfo('Vayishlach', '\u05D5\u05D9\u05E9\u05DC\u05D7', 32),
      _ParshaInfo('Vayeshev', '\u05D5\u05D9\u05E9\u05D1', 37),
      _ParshaInfo('Miketz', '\u05DE\u05E7\u05E5', 41),
      _ParshaInfo('Vayigash', '\u05D5\u05D9\u05D2\u05E9', 44),
      _ParshaInfo('Vayechi', '\u05D5\u05D9\u05D7\u05D9', 47),
    ],
    'Exodus': [
      _ParshaInfo('Shemot', '\u05E9\u05DE\u05D5\u05EA', 1),
      _ParshaInfo('Vaera', '\u05D5\u05D0\u05E8\u05D0', 6),
      _ParshaInfo('Bo', '\u05D1\u05D0', 10),
      _ParshaInfo('Beshalach', '\u05D1\u05E9\u05DC\u05D7', 13),
      _ParshaInfo('Yitro', '\u05D9\u05EA\u05E8\u05D5', 18),
      _ParshaInfo('Mishpatim', '\u05DE\u05E9\u05E4\u05D8\u05D9\u05DD', 21),
      _ParshaInfo('Terumah', '\u05EA\u05E8\u05D5\u05DE\u05D4', 25),
      _ParshaInfo('Tetzaveh', '\u05EA\u05E6\u05D5\u05D4', 27),
      _ParshaInfo('Ki Tisa', '\u05DB\u05D9 \u05EA\u05E9\u05D0', 30),
      _ParshaInfo('Vayakhel', '\u05D5\u05D9\u05E7\u05D4\u05DC', 35),
      _ParshaInfo('Pekudei', '\u05E4\u05E7\u05D5\u05D3\u05D9', 38),
    ],
    'Leviticus': [
      _ParshaInfo('Vayikra', '\u05D5\u05D9\u05E7\u05E8\u05D0', 1),
      _ParshaInfo('Tzav', '\u05E6\u05D5', 6),
      _ParshaInfo('Shemini', '\u05E9\u05DE\u05D9\u05E0\u05D9', 9),
      _ParshaInfo('Tazria', '\u05EA\u05D6\u05E8\u05D9\u05E2', 12),
      _ParshaInfo('Metzora', '\u05DE\u05E6\u05D5\u05E8\u05E2', 14),
      _ParshaInfo(
        'Acharei Mot',
        '\u05D0\u05D7\u05E8\u05D9 \u05DE\u05D5\u05EA',
        16,
      ),
      _ParshaInfo('Kedoshim', '\u05E7\u05D3\u05D5\u05E9\u05D9\u05DD', 19),
      _ParshaInfo('Emor', '\u05D0\u05DE\u05D5\u05E8', 21),
      _ParshaInfo('Behar', '\u05D1\u05D4\u05E8', 25),
      _ParshaInfo('Bechukotai', '\u05D1\u05D7\u05E7\u05D5\u05EA\u05D9', 26),
    ],
    'Numbers': [
      _ParshaInfo('Bamidbar', '\u05D1\u05DE\u05D3\u05D1\u05E8', 1),
      _ParshaInfo('Naso', '\u05E0\u05E9\u05D0', 4),
      _ParshaInfo(
        'Behaalotecha',
        '\u05D1\u05D4\u05E2\u05DC\u05D5\u05EA\u05DA',
        8,
      ),
      _ParshaInfo('Shelach', '\u05E9\u05DC\u05D7', 13),
      _ParshaInfo('Korach', '\u05E7\u05E8\u05D7', 16),
      _ParshaInfo('Chukat', '\u05D7\u05E7\u05EA', 19),
      _ParshaInfo('Balak', '\u05D1\u05DC\u05E7', 22),
      _ParshaInfo('Pinchas', '\u05E4\u05D9\u05E0\u05D7\u05E1', 25),
      _ParshaInfo('Matot', '\u05DE\u05D8\u05D5\u05EA', 30),
      _ParshaInfo('Masei', '\u05DE\u05E1\u05E2\u05D9', 33),
    ],
    'Deuteronomy': [
      _ParshaInfo('Devarim', '\u05D3\u05D1\u05E8\u05D9\u05DD', 1),
      _ParshaInfo('Vaetchanan', '\u05D5\u05D0\u05EA\u05D7\u05E0\u05DF', 3),
      _ParshaInfo('Eikev', '\u05E2\u05E7\u05D1', 7),
      _ParshaInfo('Re\'eh', '\u05E8\u05D0\u05D4', 11),
      _ParshaInfo('Shoftim', '\u05E9\u05D5\u05E4\u05D8\u05D9\u05DD', 16),
      _ParshaInfo('Ki Teitzei', '\u05DB\u05D9 \u05EA\u05E6\u05D0', 21),
      _ParshaInfo('Ki Tavo', '\u05DB\u05D9 \u05EA\u05D1\u05D5\u05D0', 26),
      _ParshaInfo('Nitzavim', '\u05E0\u05E6\u05D1\u05D9\u05DD', 29),
      _ParshaInfo('Vayeilech', '\u05D5\u05D9\u05DC\u05DA', 31),
      _ParshaInfo('Haazinu', '\u05D4\u05D0\u05D6\u05D9\u05E0\u05D5', 32),
      _ParshaInfo(
        'V\'Zot HaBracha',
        '\u05D5\u05D6\u05D0\u05EA \u05D4\u05D1\u05E8\u05DB\u05D4',
        33,
      ),
    ],
  };
}

class _ParshaInfo {
  const _ParshaInfo(this.nameEn, this.nameHe, this.startChapter);

  final String nameEn;
  final String nameHe;
  final int startChapter;
}
