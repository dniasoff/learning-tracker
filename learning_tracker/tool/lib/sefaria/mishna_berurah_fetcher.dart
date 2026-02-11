import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

import 'sefaria_fetcher_base.dart';

/// Fetches Mishna Berurah content from Sefaria.
///
/// Parses the Sefaria Mishna Berurah shape API into a 3-level hierarchy:
/// siman -> seif -> seif katan (697 simanim).
///
/// The Mishna Berurah is a commentary on Shulchan Aruch Orach Chaim.
/// On Sefaria, references use siman:seif_katan format
/// (e.g., "Mishnah Berurah 1:1"). The seif (clause of Shulchan Aruch)
/// is derived from the corresponding Shulchan Aruch Orach Chaim
/// structure, which provides the middle hierarchy level.
class MishnaBerurahFetcher extends SefariaFetcherBase {
  MishnaBerurahFetcher({required super.dio});

  @override
  String get curriculumId => CurriculumId.mishnaBerurah.storageKey;

  @override
  Future<FetchResult> fetchAllContent() async {
    // Fetch Mishna Berurah shape (siman -> seif katan counts).
    final mbShape = await fetchBookShape('Mishnah Berurah');

    // Fetch Shulchan Aruch OC shape (siman -> seif counts) for the
    // middle "seif" hierarchy level.
    final saShape = await fetchBookShape('Shulchan Arukh, Orach Chayyim');

    final mbChapters = mbShape['chapters'] as List<dynamic>? ?? [];
    final saChapters = saShape['chapters'] as List<dynamic>? ?? [];

    final items = <ContentItem>[];
    var sortOrder = 0;
    var leafCount = 0;

    for (var simanIdx = 0; simanIdx < mbChapters.length; simanIdx++) {
      final simanNum = simanIdx + 1;
      final seifKatanCount = (mbChapters[simanIdx] as num?)?.toInt() ?? 0;
      final seifCount = simanIdx < saChapters.length
          ? (saChapters[simanIdx] as num?)?.toInt() ?? 1
          : 1;

      // Add siman container.
      items.add(
        ContentItem(
          curriculumId: curriculumId,
          level1: simanNum.toString(),
          displayNameHe: '\u05E1\u05D9\u05DE\u05DF $simanNum',
          displayNameEn: 'Siman $simanNum',
          sefariaRef: 'Mishnah Berurah $simanNum',
          sortOrder: sortOrder++,
          isLeaf: false,
        ),
      );

      // Distribute seif katan across seifim. Each seif gets an
      // approximately equal share of the seif katan range.
      final skPerSeif = seifCount > 0
          ? (seifKatanCount / seifCount).ceil()
          : seifKatanCount;
      var skOffset = 1;

      for (var seifNum = 1; seifNum <= seifCount; seifNum++) {
        // Skip seifim when all seif katan are already distributed.
        if (skOffset > seifKatanCount) break;

        final seifSkStart = skOffset;
        final seifSkEnd = seifNum == seifCount
            ? seifKatanCount
            : (skOffset + skPerSeif - 1).clamp(1, seifKatanCount);

        // Add seif container.
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: simanNum.toString(),
            level2: seifNum.toString(),
            displayNameHe:
                '\u05E1\u05D9\u05DE\u05DF $simanNum \u05E1\u05E2\u05D9\u05E3 $seifNum',
            displayNameEn: 'Siman $simanNum Seif $seifNum',
            sefariaRef: 'Shulchan Arukh, Orach Chayyim $simanNum.$seifNum',
            sortOrder: sortOrder++,
            isLeaf: false,
          ),
        );

        // Add seif katan leaf nodes.
        for (var sk = seifSkStart; sk <= seifSkEnd; sk++) {
          items.add(
            ContentItem(
              curriculumId: curriculumId,
              level1: simanNum.toString(),
              level2: seifNum.toString(),
              level3: sk.toString(),
              displayNameHe:
                  '\u05DE\u05E9\u05E0\u05D4 \u05D1\u05E8\u05D5\u05E8\u05D4 $simanNum:$sk',
              displayNameEn: 'Mishnah Berurah $simanNum:$sk',
              sefariaRef: 'Mishnah Berurah $simanNum.$sk',
              sortOrder: sortOrder++,
              isLeaf: true,
            ),
          );
          leafCount++;
        }

        skOffset = seifSkEnd + 1;
      }
    }

    return FetchResult(
      items: items,
      hierarchyConfig: CurriculumHierarchyConfig(
        curriculumId: curriculumId,
        levelLabels: const ['Siman', 'Seif', 'Seif Katan'],
        totalItems: leafCount,
      ),
    );
  }
}
