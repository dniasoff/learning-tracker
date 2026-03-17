import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

import 'sefaria_fetcher_base.dart';

/// Fetches Nach (Nevi'im + Ketuvim) content from Sefaria.
///
/// Parses the Sefaria Tanakh shape API into a 3-level hierarchy:
/// sefer -> perek -> pasuk. Excludes the five Torah books.
class NachFetcher extends SefariaFetcherBase {
  NachFetcher({required super.dio});

  @override
  String get curriculumId => CurriculumId.nach.storageKey;

  @override
  Future<FetchResult> fetchAllContent() async {
    final shapeData = await fetchShape('Tanakh');

    final items = <ContentItem>[];
    var sortOrder = 0;
    var leafCount = 0;

    // Filter out Torah books — Nach is everything else in Tanakh.
    final nachBooks = shapeData
        .where(
          (book) => !_torahTitles.contains(book['title'] as String? ?? ''),
        )
        .toList();

    for (final book in nachBooks) {
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

      for (var chapterIdx = 0; chapterIdx < chapters.length; chapterIdx++) {
        final chapterNum = chapterIdx + 1;
        final verseCount = (chapters[chapterIdx] as num?)?.toInt() ?? 0;

        // Add perek container.
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: title,
            level2: chapterNum.toString(),
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
              level2: chapterNum.toString(),
              level3: verseNum.toString(),
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
        levelLabels: const ['Sefer', 'Perek', 'Pasuk'],
        totalItems: leafCount,
      ),
    );
  }

  static const _torahTitles = [
    'Genesis',
    'Exodus',
    'Leviticus',
    'Numbers',
    'Deuteronomy',
  ];
}
