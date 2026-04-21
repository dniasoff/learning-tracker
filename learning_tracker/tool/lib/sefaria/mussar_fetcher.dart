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
      final isComplex = shape['isComplex'] as bool? ?? false;
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

      if (isComplex) {
        // Complex text (e.g., Chovot HaLevavot / Duties of the Heart):
        // chapters is a list of dicts, each with a title and either a
        // segment count (simple section) or a sub-chapters list.
        final refs = _extractComplexRefs(chapters);
        for (final ref in refs) {
          items.add(
            ContentItem(
              curriculumId: curriculumId,
              level1: sefer.sefariaTitle,
              level2: ref,
              displayNameHe: ref,
              displayNameEn: ref,
              sefariaRef: ref,
              sortOrder: sortOrder++,
              isLeaf: true,
            ),
          );
          leafCount++;
        }
      } else {
        // Simple text: each chapter is a leaf node (unit of study).
        for (var i = 0; i < chapters.length; i++) {
          final chapterNum = i + 1;
          // Skip chapters with 0 segments (e.g., Mesillat Yesharim 27).
          final segmentCount = (chapters[i] as num?)?.toInt() ?? 0;
          if (segmentCount == 0) continue;

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

  /// Extracts flat list of Sefaria refs from a complex text shape.
  static List<String> _extractComplexRefs(List<dynamic> chapters) {
    final refs = <String>[];
    for (final ch in chapters) {
      if (ch is! Map) continue;
      final title = ch['title'] as String? ?? '';
      final subChapters = ch['chapters'];
      if (subChapters is int) {
        // Simple section — the title itself is the ref.
        refs.add(title);
      } else if (subChapters is List) {
        // Has numbered sub-chapters.
        for (var i = 0; i < subChapters.length; i++) {
          refs.add('$title ${i + 1}');
        }
      }
    }
    return refs;
  }

  static const _mussarSefarim = [
    _MussarSefer(
      'Mesillat Yesharim',
      '\u05DE\u05E1\u05D9\u05DC\u05EA \u05D9\u05E9\u05E8\u05D9\u05DD',
    ),
    _MussarSefer(
      'Orchot Tzaddikim',
      '\u05D0\u05D5\u05E8\u05D7\u05D5\u05EA \u05E6\u05D3\u05D9\u05E7\u05D9\u05DD',
    ),
    _MussarSefer(
      'Chovot HaLevavot',
      '\u05D7\u05D5\u05D1\u05D5\u05EA \u05D4\u05DC\u05D1\u05D1\u05D5\u05EA',
    ),
  ];
}

class _MussarSefer {
  const _MussarSefer(this.sefariaTitle, this.heTitle);

  final String sefariaTitle;
  final String heTitle;
}
