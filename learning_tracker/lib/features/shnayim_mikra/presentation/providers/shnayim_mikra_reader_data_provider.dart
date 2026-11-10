import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/parallel_text_repository.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/parsha_aliyah_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';

/// Verse refs grouped by aliyah for progress projection and the reader.
final shnayimMikraParshaVerseRefsProvider = FutureProvider.autoDispose
    .family<List<List<String>>, (String, bool)>((ref, request) async {
      final (portionKey, inIsrael) = request;
      final database = await ref.watch(contentDatabaseProvider.future);
      final aliyot = await ParshaAliyahRepository(
        database,
      ).getForPortion(portionKey, inIsrael: inIsrael);
      final content = await ref.watch(
        curriculumContentProvider(CurriculumId.chumash).future,
      );
      final refs = [
        for (final item in content.where((item) => item.isLeaf))
          item.sefariaRef,
      ];
      final indexes = {for (var i = 0; i < refs.length; i++) refs[i]: i};
      return List.unmodifiable([
        for (final aliyah in aliyot)
          () {
            final start = indexes[aliyah.startRef];
            final end = indexes[aliyah.endRef];
            if (start == null || end == null || end < start) {
              throw StateError(
                'Bundled aliyah range has unknown refs ${aliyah.startRef}–${aliyah.endRef}',
              );
            }
            return List<String>.unmodifiable(refs.sublist(start, end + 1));
          }(),
      ]);
    });

/// A Chumash verse with its offline parallel reading.
final class ShnayimMikraVerseReading {
  const ShnayimMikraVerseReading({required this.text, required this.parallel});

  final TextSegment text;
  final List<ParallelText> parallel;
}

/// One aliyah in the selected parsha, ordered by verse.
final class ShnayimMikraAliyahReading {
  const ShnayimMikraAliyahReading({
    required this.aliyahNumber,
    required this.verses,
  });

  final int aliyahNumber;
  final List<ShnayimMikraVerseReading> verses;
}

/// Offline-first text for one parsha and selected third-reading source.
final shnayimMikraReaderDataProvider = FutureProvider.autoDispose
    .family<List<ShnayimMikraAliyahReading>, (String, bool, String)>((
      ref,
      request,
    ) async {
      final (portionKey, inIsrael, sourceKey) = request;
      final database = await ref.watch(contentDatabaseProvider.future);
      final aliyaRows = await ParshaAliyahRepository(
        database,
      ).getForPortion(portionKey, inIsrael: inIsrael);
      if (aliyaRows.isEmpty) {
        throw StateError('No bundled aliyah ranges for $portionKey');
      }

      final content = await ref.watch(
        curriculumContentProvider(CurriculumId.chumash).future,
      );
      final verseRefs = [
        for (final item in content.where((item) => item.isLeaf))
          item.sefariaRef,
      ];
      final verseIndexes = {
        for (var i = 0; i < verseRefs.length; i++) verseRefs[i]: i,
      };
      final ranges = <List<String>>[];
      for (final row in aliyaRows) {
        final start = verseIndexes[row.startRef];
        final end = verseIndexes[row.endRef];
        if (start == null || end == null || end < start) {
          throw StateError(
            'Bundled aliyah range has unknown refs ${row.startRef}–${row.endRef}',
          );
        }
        ranges.add(verseRefs.sublist(start, end + 1));
      }

      final textCache = await ref.watch(textCacheRepositoryProvider.future);
      final parallelText = ParallelTextRepository(database);
      final uniqueRefs = ranges.expand((range) => range).toSet();
      final verseData = <String, ShnayimMikraVerseReading>{};
      await Future.wait([
        for (final verseRef in uniqueRefs)
          () async {
            final text = await textCache.getText(verseRef);
            if (text == null || text.segments.isEmpty) {
              throw StateError('Bundled Chumash text missing for $verseRef');
            }
            final parallel = await parallelText.getForVerse(
              sourceKey: sourceKey,
              chumashVerseRef: verseRef,
            );
            if (sourceKey == 'onkelos' && parallel.isEmpty) {
              throw StateError('Bundled Onkelos text missing for $verseRef');
            }
            verseData[verseRef] = ShnayimMikraVerseReading(
              text: text.segments.first,
              parallel: parallel,
            );
          }(),
      ]);
      return List.unmodifiable([
        for (var i = 0; i < ranges.length; i++)
          ShnayimMikraAliyahReading(
            aliyahNumber: aliyaRows[i].aliyahNumber,
            verses: List.unmodifiable([
              for (final verseRef in ranges[i]) verseData[verseRef]!,
            ]),
          ),
      ]);
    });
