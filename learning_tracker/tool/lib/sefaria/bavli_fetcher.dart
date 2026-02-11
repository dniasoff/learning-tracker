import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

import 'sefaria_fetcher_base.dart';

/// Fetches Talmud Bavli content from Sefaria.
///
/// Parses the Sefaria Bavli shape API into a 3-level hierarchy:
/// masechta -> daf -> amud (~2,711 dapim / ~5,422 amudim).
///
/// Bavli daf numbering starts at 2a (there is no daf 1 in printed editions).
/// Each daf has two amudim: a (recto) and b (verso).
class BavliFetcher extends SefariaFetcherBase {
  BavliFetcher({required super.dio});

  @override
  String get curriculumId => CurriculumId.bavli.storageKey;

  @override
  Future<FetchResult> fetchAllContent() async {
    final shapeData = await fetchShape('Bavli');

    final items = <ContentItem>[];
    var sortOrder = 0;
    var leafCount = 0;

    for (final tractate in shapeData) {
      final title = tractate['title'] as String? ?? '';
      final heTitle = tractate['heTitle'] as String? ?? '';
      final chapters = tractate['chapters'] as List<dynamic>? ?? [];

      // The shape data for Bavli returns an array where each element is
      // the line count for one amud. The total number of elements equals
      // the total number of amudim in the tractate.
      final amudCount = chapters.length;

      // Add masechta container.
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

      // Generate daf/amud entries. Bavli starts at daf 2a.
      for (var amudIdx = 0; amudIdx < amudCount; amudIdx++) {
        final dafNum = (amudIdx ~/ 2) + 2; // Starts at daf 2
        final amud = amudIdx.isEven ? 'a' : 'b';
        final dafRef = '$dafNum$amud';

        // Add daf container for first amud of each daf.
        if (amud == 'a') {
          items.add(
            ContentItem(
              curriculumId: curriculumId,
              level1: title,
              level2: dafNum.toString(),
              displayNameHe: '$heTitle ${_toHebrewNumeral(dafNum)}',
              displayNameEn: '$title $dafNum',
              sefariaRef: '$title $dafNum',
              sortOrder: sortOrder++,
              isLeaf: false,
            ),
          );
        }

        // Add amud leaf.
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: title,
            level2: dafNum.toString(),
            level3: amud,
            displayNameHe: '$heTitle ${_toHebrewNumeral(dafNum)}$amud',
            displayNameEn: '$title $dafRef',
            sefariaRef: '$title $dafRef',
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
        levelLabels: const ['Masechta', 'Daf', 'Amud'],
        totalItems: leafCount,
      ),
    );
  }

  /// Converts an integer to a basic Hebrew numeral representation.
  static String _toHebrewNumeral(int num) {
    // Simple Hebrew numeral mapping for common Talmud daf numbers.
    const ones = [
      '',
      '\u05D0',
      '\u05D1',
      '\u05D2',
      '\u05D3',
      '\u05D4',
      '\u05D5',
      '\u05D6',
      '\u05D7',
      '\u05D8',
    ];
    const tens = [
      '',
      '\u05D9',
      '\u05DB',
      '\u05DC',
      '\u05DE',
      '\u05E0',
      '\u05E1',
      '\u05E2',
      '\u05E4',
      '\u05E6',
    ];
    const hundreds = ['', '\u05E7', '\u05E8', '\u05E9', '\u05EA'];

    if (num <= 0 || num > 499) return num.toString();

    final h = num ~/ 100;
    final t = (num % 100) ~/ 10;
    final o = num % 10;

    return '${hundreds[h]}${tens[t]}${ones[o]}';
  }
}
