import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';

/// One verse translation or one comment in a parallel reading source.
final class ParallelText {
  const ParallelText({
    required this.sourceKey,
    required this.sefariaRef,
    required this.hebrewText,
    required this.englishText,
    required this.versionTitle,
    required this.license,
  });

  final String sourceKey;
  final String sefariaRef;
  final String hebrewText;
  final String englishText;
  final String versionTitle;
  final String license;
}

/// Cache-only lookup for the third reading in Shnayim Mikra.
///
/// No network fallback is used: the complete Onkelos and Rashi data is
/// bundled in the read-only content database for offline reading.
final class ParallelTextRepository {
  const ParallelTextRepository(this._database);

  final ContentDatabase _database;

  /// Returns the Onkelos verse or all Rashi comments for [chumashVerseRef].
  /// Rashi results are ordered by the numeric comment suffix in their refs.
  Future<List<ParallelText>> getForVerse({
    required String sourceKey,
    required String chumashVerseRef,
  }) async {
    if (sourceKey != 'onkelos' && sourceKey != 'rashi') {
      throw ArgumentError.value(sourceKey, 'sourceKey', 'unsupported source');
    }
    final rows = await _database
        .customSelect(
          sourceKey == 'onkelos'
              ? 'SELECT source_key, sefaria_ref, hebrew_text, english_text, '
                    'version_title, license FROM parallel_text '
                    'WHERE source_key = ? AND sefaria_ref = ?'
              : 'SELECT source_key, sefaria_ref, hebrew_text, english_text, '
                    'version_title, license FROM parallel_text '
                    'WHERE source_key = ? AND sefaria_ref LIKE ? '
                    'ORDER BY sefaria_ref',
          variables: [
            Variable.withString(sourceKey),
            Variable.withString(
              sourceKey == 'onkelos'
                  ? 'Onkelos $chumashVerseRef'
                  : 'Rashi on $chumashVerseRef:%',
            ),
          ],
          readsFrom: {_database.parallelText},
        )
        .get();
    final result = [
      for (final row in rows)
        ParallelText(
          sourceKey: row.read<String>('source_key'),
          sefariaRef: row.read<String>('sefaria_ref'),
          hebrewText: HebrewUtils.decodeHtmlEntities(
            row.read<String>('hebrew_text'),
          ),
          englishText: HebrewUtils.cleanSefariaText(
            row.read<String>('english_text'),
          ),
          versionTitle: row.read<String>('version_title'),
          license: row.read<String>('license'),
        ),
    ];
    if (sourceKey == 'rashi') {
      result.sort(
        (a, b) => _commentNumber(
          a.sefariaRef,
        ).compareTo(_commentNumber(b.sefariaRef)),
      );
    }
    return result;
  }

  static int _commentNumber(String ref) =>
      int.tryParse(ref.substring(ref.lastIndexOf(':') + 1)) ?? 0;
}
