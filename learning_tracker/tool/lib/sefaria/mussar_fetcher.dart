import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

import 'sefaria_fetcher_base.dart';

/// Fetches Mussar content from Sefaria.
///
/// Parses multiple mussar sefarim into a 2-level hierarchy:
/// sefer -> section/chapter. Each section is a leaf node representing
/// a unit of study.
class MussarFetcher extends SefariaFetcherBase {
  MussarFetcher({required super.dio});

  @override
  String get curriculumId => CurriculumId.mussar.storageKey;

  @override
  Future<FetchResult> fetchAllContent() async {
    final items = <ContentItem>[];
    var sortOrder = 0;
    var leafCount = 0;

    for (final sefer in _mussarSefarim) {
      final shape = await fetchBookShape(sefer.sefariaTitle);
      final chapters = shape['chapters'] as List<dynamic>? ?? [];
      final heTitle = shape['heTitle'] as String? ?? sefer.heTitle;

      // Add sefer container.
      items.add(
        ContentItem(
          curriculumId: curriculumId,
          level1: sefer.sefariaTitle,
          displayNameHe: heTitle,
          displayNameEn: sefer.sefariaTitle,
          sefariaRef: sefer.sefariaTitle,
          sortOrder: sortOrder++,
          isLeaf: false,
        ),
      );

      // Each chapter is a leaf node (unit of study).
      for (var i = 0; i < chapters.length; i++) {
        final chapterNum = i + 1;
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: sefer.sefariaTitle,
            level2: chapterNum.toString(),
            displayNameHe: '$heTitle \u05E4\u05E8\u05E7 $chapterNum',
            displayNameEn: '${sefer.sefariaTitle} Chapter $chapterNum',
            sefariaRef: '${sefer.sefariaTitle} $chapterNum',
            sortOrder: sortOrder++,
            isLeaf: true,
          ),
        );
        leafCount++;
      }
    }

    return FetchResult(
      items: items,
      hierarchyConfig: CurriculumHierarchyConfig(
        curriculumId: curriculumId,
        levelLabels: const ['Sefer', 'Section'],
        totalItems: leafCount,
      ),
    );
  }

  static const _mussarSefarim = [
    _MussarSefer('Mesillat Yesharim', '\u05DE\u05E1\u05D9\u05DC\u05EA \u05D9\u05E9\u05E8\u05D9\u05DD'),
    _MussarSefer('Orchot Tzaddikim', '\u05D0\u05D5\u05E8\u05D7\u05D5\u05EA \u05E6\u05D3\u05D9\u05E7\u05D9\u05DD'),
    _MussarSefer('Chovot HaLevavot', '\u05D7\u05D5\u05D1\u05D5\u05EA \u05D4\u05DC\u05D1\u05D1\u05D5\u05EA'),
  ];
}

class _MussarSefer {
  const _MussarSefer(this.sefariaTitle, this.heTitle);

  final String sefariaTitle;
  final String heTitle;
}
