import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/network/sefaria/sefaria_fetcher_base.dart';

/// Fetches Talmud Yerushalmi content from Sefaria.
///
/// Parses the Sefaria Yerushalmi shape API into a 3-level hierarchy:
/// masechta → daf → halacha.
///
/// On Sefaria, Yerushalmi references use chapter:halacha format
/// (e.g., "Jerusalem Talmud Berakhot 1:1"). The "daf" level in this
/// hierarchy corresponds to chapters in the Sefaria schema.
class YerushalmiFetcher extends SefariaFetcherBase {
  YerushalmiFetcher({required super.dio});

  @override
  String get curriculumId => CurriculumId.yerushalmi.storageKey;

  @override
  Future<FetchResult> fetchAllContent() async {
    final shapeData = await fetchShape('Yerushalmi');

    final items = <ContentItem>[];
    var sortOrder = 0;
    var leafCount = 0;

    for (final tractate in shapeData) {
      final title = tractate['title'] as String? ?? '';
      final heTitle = tractate['heTitle'] as String? ?? '';
      final chapters = tractate['chapters'] as List<dynamic>? ?? [];

      // Sefaria prefixes Yerushalmi titles with "Jerusalem Talmud ".
      final sefariaTitle = title.startsWith('Jerusalem Talmud')
          ? title
          : 'Jerusalem Talmud $title';

      // Add masechta container.
      items.add(
        ContentItem(
          curriculumId: curriculumId,
          level1: title,
          displayNameHe: heTitle,
          displayNameEn: title,
          sefariaRef: sefariaTitle,
          sortOrder: sortOrder++,
          isLeaf: false,
        ),
      );

      // Add chapters (daf) and halachot.
      for (var chapterIdx = 0; chapterIdx < chapters.length; chapterIdx++) {
        final chapterNum = chapterIdx + 1;
        final halachaCount = (chapters[chapterIdx] as num?)?.toInt() ?? 0;

        // Add chapter/daf container.
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: title,
            level2: chapterNum.toString(),
            displayNameHe: '$heTitle \u05E4\u05E8\u05E7 $chapterNum',
            displayNameEn: '$title Chapter $chapterNum',
            sefariaRef: '$sefariaTitle $chapterNum',
            sortOrder: sortOrder++,
            isLeaf: false,
          ),
        );

        // Add individual halachot (leaf nodes).
        for (var halachaNum = 1; halachaNum <= halachaCount; halachaNum++) {
          items.add(
            ContentItem(
              curriculumId: curriculumId,
              level1: title,
              level2: chapterNum.toString(),
              level3: halachaNum.toString(),
              displayNameHe: '$heTitle $chapterNum:$halachaNum',
              displayNameEn: '$title $chapterNum:$halachaNum',
              sefariaRef: '$sefariaTitle $chapterNum.$halachaNum',
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
        levelLabels: const ['Masechta', 'Daf', 'Halacha'],
        totalItems: leafCount,
      ),
    );
  }
}
