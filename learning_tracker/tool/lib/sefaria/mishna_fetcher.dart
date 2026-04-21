import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

import 'sefaria_fetcher_base.dart';

/// Fetches Mishnah content from Sefaria.
///
/// Parses the Sefaria Mishnah shape API into a 4-level hierarchy:
/// seder -> masechta -> perek -> mishna (4,192 leaf items).
class MishnaFetcher extends SefariaFetcherBase {
  MishnaFetcher({required super.dio});

  @override
  String get curriculumId => CurriculumId.mishnayos.storageKey;

  @override
  Future<FetchResult> fetchAllContent() async {
    final shapeData = await fetchShape('Mishnah');

    final items = <ContentItem>[];
    var sortOrder = 0;
    var leafCount = 0;

    // Track sedarim we've already added as container items.
    final addedSedarim = <String>{};

    for (final tractate in shapeData) {
      final sederName = tractate['section'] as String? ?? '';
      final title = tractate['title'] as String? ?? '';
      final heTitle = tractate['heTitle'] as String? ?? '';
      final chapters = tractate['chapters'] as List<dynamic>? ?? [];

      // Add seder container if new.
      if (sederName.isNotEmpty && addedSedarim.add(sederName)) {
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: sederName,
            displayNameHe: _sederHebrewName(sederName),
            displayNameEn: sederName,
            sefariaRef: sederName,
            sortOrder: sortOrder++,
            isLeaf: false,
          ),
        );
      }

      // Sefaria shape titles already include "Mishnah" (e.g.,
      // "Mishnah Berakhot") and "Pirkei Avot" — use as-is.
      final refPrefix = title;

      // Add masechta container.
      items.add(
        ContentItem(
          curriculumId: curriculumId,
          level1: sederName,
          level2: title,
          displayNameHe: heTitle,
          displayNameEn: title,
          sefariaRef: refPrefix,
          sortOrder: sortOrder++,
          isLeaf: false,
        ),
      );

      // Add perakim and mishnayot.
      for (var perekIdx = 0; perekIdx < chapters.length; perekIdx++) {
        final perekNum = perekIdx + 1;
        final mishnaCount = (chapters[perekIdx] as num?)?.toInt() ?? 0;

        // Add perek container.
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: sederName,
            level2: title,
            level3: perekNum.toString(),
            displayNameHe: '\u05E4\u05E8\u05E7 $perekNum',
            displayNameEn: 'Chapter $perekNum',
            sefariaRef: '$refPrefix $perekNum',
            sortOrder: sortOrder++,
            isLeaf: false,
          ),
        );

        // Add individual mishnayot (leaf nodes).
        for (var mishnaNum = 1; mishnaNum <= mishnaCount; mishnaNum++) {
          items.add(
            ContentItem(
              curriculumId: curriculumId,
              level1: sederName,
              level2: title,
              level3: perekNum.toString(),
              level4: mishnaNum.toString(),
              displayNameHe: '$heTitle $perekNum:$mishnaNum',
              displayNameEn: '$title $perekNum:$mishnaNum',
              sefariaRef: '$refPrefix $perekNum.$mishnaNum',
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
        levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
        totalItems: leafCount,
      ),
    );
  }

  static String _sederHebrewName(String sederName) {
    const mapping = {
      'Seder Zeraim': '\u05E1\u05D3\u05E8 \u05D6\u05E8\u05E2\u05D9\u05DD',
      'Seder Moed': '\u05E1\u05D3\u05E8 \u05DE\u05D5\u05E2\u05D3',
      'Seder Nashim': '\u05E1\u05D3\u05E8 \u05E0\u05E9\u05D9\u05DD',
      'Seder Nezikin':
          '\u05E1\u05D3\u05E8 \u05E0\u05D6\u05D9\u05E7\u05D9\u05DF',
      'Seder Kodashim': '\u05E1\u05D3\u05E8 \u05E7\u05D3\u05E9\u05D9\u05DD',
      'Seder Tahorot': '\u05E1\u05D3\u05E8 \u05D8\u05D4\u05E8\u05D5\u05EA',
    };
    return mapping[sederName] ?? sederName;
  }
}
