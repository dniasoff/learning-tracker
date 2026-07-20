import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

import 'sefaria_fetcher_base.dart';

/// Fetches Talmud Bavli content from Sefaria.
///
/// Parses the Sefaria Bavli shape API into a 4-level hierarchy:
/// seder -> masechta -> daf -> amud (~2,711 dapim / ~5,422 amudim).
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

    // Track sedarim we've already added as container items.
    final addedSedarim = <String>{};

    for (final tractate in shapeData) {
      final sederName = tractate['section'] as String? ?? '';
      final title = tractate['title'] as String? ?? '';
      final heTitle = tractate['heTitle'] as String? ?? '';
      final chapters = tractate['chapters'] as List<dynamic>? ?? [];

      // The shape data for Bavli returns an array where each element is
      // the line count for one amud. The total number of elements equals
      // the total number of amudim in the tractate.
      final amudCount = chapters.length;

      // Add seder container if new.
      if (sederName.isNotEmpty && addedSedarim.add(sederName)) {
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: sederName,
            displayNameHe: SefariaFetcherBase.sederHebrewName(sederName),
            displayNameEn: sederName,
            sefariaRef: sederName,
            sortOrder: sortOrder++,
            isLeaf: false,
          ),
        );
      }

      // Add masechta container.
      items.add(
        ContentItem(
          curriculumId: curriculumId,
          level1: sederName,
          level2: title,
          displayNameHe: heTitle,
          displayNameEn: title,
          sefariaRef: title,
          sortOrder: sortOrder++,
          isLeaf: false,
        ),
      );

      // The Sefaria shape API over-reports amudim: it includes 1-3 phantom
      // amudim beyond the actual last daf (Steinsaltz/Koren pagination
      // artifacts). We cap at the known last daf per masechta.
      final maxAmud = _lastDaf[title];
      final maxAmudIdx = maxAmud != null
          ? ((maxAmud.daf - 2) * 2 + (maxAmud.amud == 'b' ? 1 : 0))
          : amudCount - 1;

      // Some masechtos (Tamid) start after daf 2. Use the explicit table;
      // all other masechtos start at daf 2a (index 0).
      final firstAmud = _firstDaf[title];
      final startAmudIdx = firstAmud != null
          ? ((firstAmud.daf - 2) * 2 + (firstAmud.amud == 'b' ? 1 : 0))
          : 0;

      // Generate daf/amud entries. Bavli starts at daf 2a.
      for (var amudIdx = 0; amudIdx < amudCount; amudIdx++) {
        // Skip amudim before the known first daf.
        if (amudIdx < startAmudIdx) continue;

        // Skip amudim beyond the known last daf.
        if (amudIdx > maxAmudIdx) continue;

        final dafNum = (amudIdx ~/ 2) + 2; // Starts at daf 2
        final amud = amudIdx.isEven ? 'a' : 'b';
        final dafRef = '$dafNum$amud';

        // Skip known mid-masechta gaps (amudim that Sefaria lacks).
        if (_skipAmudim.contains('$title $dafRef')) continue;

        // Add daf container for first amud of each daf.
        // For the very first amud (which may be 'b' if 'a' was skipped),
        // or any amud 'a', emit the daf container.
        if (amud == 'a' || amudIdx == startAmudIdx) {
          items.add(
            ContentItem(
              curriculumId: curriculumId,
              level1: sederName,
              level2: title,
              level3: dafNum.toString(),
              displayNameHe: '$heTitle דף ${_toHebrewNumeral(dafNum)}',
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
            level1: sederName,
            level2: title,
            level3: dafNum.toString(),
            level4: amud,
            displayNameHe:
                '$heTitle דף ${_toHebrewNumeral(dafNum)} עמוד ${amud == 'a' ? 'א' : 'ב'}',
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
        levelLabels: const ['Seder', 'Masechta', 'Daf', 'Amud'],
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

  /// Mid-masechta amudim that don't exist on Sefaria's text API.
  static const _skipAmudim = <String>{'Nazir 33b'};

  /// Known first daf for masechtos that don't start at 2a.
  static const _firstDaf = <String, ({int daf, String amud})>{
    'Tamid': (daf: 25, amud: 'b'),
  };

  /// Known last daf per masechta in the standard Vilna Shas.
  ///
  /// The Sefaria shape API over-reports amudim by 1-3 beyond these
  /// (Steinsaltz/Koren pagination artifacts that don't have text).
  static const _lastDaf = <String, ({int daf, String amud})>{
    'Berakhot': (daf: 64, amud: 'a'),
    'Shabbat': (daf: 157, amud: 'b'),
    'Eruvin': (daf: 105, amud: 'a'),
    'Pesachim': (daf: 121, amud: 'b'),
    'Shekalim': (daf: 22, amud: 'a'),
    'Yoma': (daf: 88, amud: 'a'),
    'Sukkah': (daf: 56, amud: 'b'),
    'Beitzah': (daf: 40, amud: 'b'),
    'Rosh Hashanah': (daf: 35, amud: 'a'),
    'Taanit': (daf: 31, amud: 'a'),
    'Megillah': (daf: 32, amud: 'a'),
    'Moed Katan': (daf: 29, amud: 'a'),
    'Chagigah': (daf: 27, amud: 'a'),
    'Yevamot': (daf: 122, amud: 'b'),
    'Ketubot': (daf: 112, amud: 'b'),
    'Nedarim': (daf: 91, amud: 'b'),
    'Nazir': (daf: 66, amud: 'b'),
    'Sotah': (daf: 49, amud: 'b'),
    'Gittin': (daf: 90, amud: 'b'),
    'Kiddushin': (daf: 82, amud: 'b'),
    'Bava Kamma': (daf: 119, amud: 'b'),
    'Bava Metzia': (daf: 119, amud: 'a'),
    'Bava Batra': (daf: 176, amud: 'b'),
    'Sanhedrin': (daf: 113, amud: 'b'),
    'Makkot': (daf: 24, amud: 'b'),
    'Shevuot': (daf: 49, amud: 'b'),
    'Avodah Zarah': (daf: 76, amud: 'b'),
    'Horayot': (daf: 14, amud: 'a'),
    'Zevachim': (daf: 120, amud: 'b'),
    'Menachot': (daf: 110, amud: 'a'),
    'Chullin': (daf: 142, amud: 'a'),
    'Bekhorot': (daf: 61, amud: 'a'),
    'Arakhin': (daf: 34, amud: 'a'),
    'Temurah': (daf: 34, amud: 'a'),
    'Keritot': (daf: 28, amud: 'b'),
    'Meilah': (daf: 22, amud: 'a'),
    'Tamid': (daf: 33, amud: 'b'),
    'Niddah': (daf: 73, amud: 'a'),
  };
}
