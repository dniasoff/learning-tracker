// Extra coverage for TextCacheRepository — exercises the text_cache hit path,
// child-verse aggregation, and daily_content fallback that the baseline test
// leaves uncovered.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ContentDatabase database;
  late TextCacheRepository repository;

  setUp(() {
    database = createTestContentDatabase();
    repository = TextCacheRepository(
      textCacheDao: database.contentTextCacheDao,
      dailyContentDao: database.dailyContentDao,
    );
  });

  tearDown(() async {
    await database.close();
  });

  // Insert a row into text_cache.
  Future<void> insertTextCache({
    required String sefariaRef,
    required String hebrewText,
    String englishText = '',
  }) async {
    await database
        .into(database.textCache)
        .insert(
          TextCacheCompanion.insert(
            sefariaRef: sefariaRef,
            hebrewText: hebrewText,
            englishText: englishText,
            fetchedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  // Insert a row into daily_content.
  Future<void> insertDailyContent({
    required String sefariaRef,
    String hebrewText = '',
    String englishText = '',
  }) async {
    await database
        .into(database.dailyContent)
        .insert(
          DailyContentCompanion.insert(
            sefariaRef: sefariaRef,
            hebrewText: Value(hebrewText),
            englishText: Value(englishText),
          ),
        );
  }

  // =========================================================================
  // text_cache hit path
  // =========================================================================

  group('TextCacheRepository.getText — text_cache hit', () {
    test('returns TextContent when ref is in text_cache', () async {
      await insertTextCache(
        sefariaRef: 'Genesis 1:1',
        hebrewText: 'בְּרֵאשִׁית',
        englishText: 'In the beginning',
      );

      final result = await repository.getText('Genesis 1:1');

      expect(result, isNotNull);
      expect(result!.sefariaRef, 'Genesis 1:1');
      expect(result.segments, hasLength(1));
      expect(result.segments.first.englishText, 'In the beginning');
    });

    test('decodes HTML entities in hebrewText', () async {
      await insertTextCache(
        sefariaRef: 'Genesis 1:2',
        hebrewText: '&amp;test&amp;',
        englishText: '',
      );

      final result = await repository.getText('Genesis 1:2');

      expect(result, isNotNull);
      // HebrewUtils.decodeHtmlEntities should decode &amp; → &
      expect(result!.hebrewText, contains('&'));
    });

    test('segment has correct verse number for colon-separated ref', () async {
      await insertTextCache(sefariaRef: 'Genesis 1:5', hebrewText: 'some text');

      final result = await repository.getText('Genesis 1:5');

      expect(result, isNotNull);
      expect(result!.segments.first.number, 5);
    });

    test('segment number is null for ref without colon', () async {
      await insertTextCache(
        sefariaRef: 'Berakhot 2a',
        hebrewText: 'talmud text',
      );

      final result = await repository.getText('Berakhot 2a');

      expect(result, isNotNull);
      expect(result!.segments.first.number, isNull);
    });
  });

  // =========================================================================
  // child-verse aggregation
  // =========================================================================

  group('TextCacheRepository.getText — child-verse aggregation', () {
    test('aggregates child verse rows when chapter ref is requested', () async {
      await insertTextCache(
        sefariaRef: 'Genesis 1:1',
        hebrewText: 'פסוק א',
        englishText: 'Verse 1',
      );
      await insertTextCache(
        sefariaRef: 'Genesis 1:2',
        hebrewText: 'פסוק ב',
        englishText: 'Verse 2',
      );
      await insertTextCache(
        sefariaRef: 'Genesis 1:3',
        hebrewText: 'פסוק ג',
        englishText: 'Verse 3',
      );

      // Request the chapter ref — no exact match, has child rows.
      final result = await repository.getText('Genesis 1');

      expect(result, isNotNull);
      expect(result!.sefariaRef, 'Genesis 1');
      // All 3 child rows aggregated.
      expect(result.segments, hasLength(3));
    });

    test('child verses are sorted by verse number', () async {
      // Insert out of order.
      await insertTextCache(sefariaRef: 'Pirkei Avot 1:3', hebrewText: 'ג');
      await insertTextCache(sefariaRef: 'Pirkei Avot 1:1', hebrewText: 'א');
      await insertTextCache(sefariaRef: 'Pirkei Avot 1:2', hebrewText: 'ב');

      final result = await repository.getText('Pirkei Avot 1');

      expect(result, isNotNull);
      final numbers = result!.segments.map((s) => s.number).toList();
      expect(numbers, [1, 2, 3]);
    });

    test('skips child segments where both he and en text are empty', () async {
      await insertTextCache(
        sefariaRef: 'Mishnah Berakhot 1:1',
        hebrewText: 'text',
        englishText: '',
      );
      await insertTextCache(
        sefariaRef: 'Mishnah Berakhot 1:2',
        hebrewText: '',
        englishText: '',
      ); // both empty → skipped

      final result = await repository.getText('Mishnah Berakhot 1');

      expect(result, isNotNull);
      // Only one segment (the empty one is dropped).
      expect(result!.segments, hasLength(1));
      expect(result.segments.first.sefariaRef, 'Mishnah Berakhot 1:1');
    });

    test(
      'falls through to daily_content when all children are empty',
      () async {
        // Insert a child row where both texts are empty.
        await insertTextCache(
          sefariaRef: 'Chullin 7:1',
          hebrewText: '',
          englishText: '',
        );
        // Also insert a daily_content fallback.
        await insertDailyContent(
          sefariaRef: 'Chullin 7',
          hebrewText: 'daily he',
          englishText: 'daily en',
        );

        final result = await repository.getText('Chullin 7');

        expect(result, isNotNull);
        // Because child aggregation produced 0 valid segments, daily_content
        // is the fallback.
        expect(result!.englishText, 'daily en');
      },
    );
  });

  // =========================================================================
  // daily_content fallback
  // =========================================================================

  group('TextCacheRepository.getText — daily_content fallback', () {
    test('returns daily_content when text_cache misses', () async {
      await insertDailyContent(
        sefariaRef: 'Chullin 7',
        hebrewText: 'חולין',
        englishText: 'Chullin chapter 7',
      );

      final result = await repository.getText('Chullin 7');

      expect(result, isNotNull);
      expect(result!.sefariaRef, 'Chullin 7');
      expect(result.englishText, 'Chullin chapter 7');
    });

    test('daily_content segment has null number for non-colon ref', () async {
      await insertDailyContent(sefariaRef: 'Shabbat 2', hebrewText: 'שבת');

      final result = await repository.getText('Shabbat 2');

      expect(result, isNotNull);
      expect(result!.segments.first.number, isNull);
    });
  });

  // =========================================================================
  // getCachedRefs
  // =========================================================================

  group('TextCacheRepository.getCachedRefs', () {
    test('returns all cached refs after insertions', () async {
      await insertTextCache(sefariaRef: 'ref_A', hebrewText: 'A');
      await insertTextCache(sefariaRef: 'ref_B', hebrewText: 'B');

      final refs = await repository.getCachedRefs();

      expect(refs, containsAll(['ref_A', 'ref_B']));
    });
  });

  // =========================================================================
  // TextContent helpers
  // =========================================================================

  group('TextContent.single constructor', () {
    test('creates single-segment TextContent', () {
      final tc = TextContent.single(
        sefariaRef: 'test_ref',
        hebrewText: 'שלום',
        englishText: 'Hello',
      );
      expect(tc.sefariaRef, 'test_ref');
      expect(tc.segments, hasLength(1));
      expect(tc.hebrewText, 'שלום');
      expect(tc.englishText, 'Hello');
    });
  });
}
