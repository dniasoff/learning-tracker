/// Extended tests for TextCacheRepository covering paths that are
/// uncovered in the existing text_cache_repository_test.dart:
///   - exact match in textCacheDao (lines 96-103)
///   - child-verse aggregation (lines 116-135)
///   - daily_content fallback (lines 141-150)
///   - _verseNumberOrNull helper logic (lines 163-166)
///   - getCachedRefs with data (line 170)
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> insertTextCache({
    required String sefariaRef,
    required String hebrewText,
    String englishText = '',
  }) async {
    await database
        .into(database.textCache)
        .insertOnConflictUpdate(
          TextCacheCompanion.insert(
            sefariaRef: sefariaRef,
            hebrewText: hebrewText,
            englishText: englishText,
            fetchedAt: DateTime.utc(2026, 5, 14),
          ),
        );
  }

  Future<void> insertDailyContent({
    required String sefariaRef,
    required String hebrewText,
    String englishText = '',
  }) async {
    await database
        .into(database.dailyContent)
        .insertOnConflictUpdate(
          DailyContentCompanion.insert(
            sefariaRef: sefariaRef,
            hebrewText: Value(hebrewText),
            englishText: Value(englishText),
          ),
        );
  }

  // ── Exact match in textCacheDao ───────────────────────────────────────────

  group('getText — exact match from textCacheDao', () {
    test('returns content when ref is cached in text_cache', () async {
      await insertTextCache(
        sefariaRef: 'Genesis 1:1',
        hebrewText: 'בראשית',
        englishText: 'In the beginning',
      );

      final result = await repository.getText('Genesis 1:1');

      expect(result, isNotNull);
      expect(result!.sefariaRef, 'Genesis 1:1');
      expect(result.hebrewText, 'בראשית');
      expect(result.englishText, 'In the beginning');
      expect(result.segments, hasLength(1));
    });

    test(
      'cached segment has correct verse number for colon-suffixed ref',
      () async {
        await insertTextCache(
          sefariaRef: 'Genesis 1:5',
          hebrewText: 'יום',
          englishText: 'day',
        );

        final result = await repository.getText('Genesis 1:5');

        expect(result, isNotNull);
        expect(result!.segments.first.number, 5);
      },
    );

    test('cached segment has null number for ref without colon', () async {
      await insertTextCache(
        sefariaRef: 'Berakhot 2a',
        hebrewText: 'מאימתי',
        englishText: 'From when',
      );

      final result = await repository.getText('Berakhot 2a');

      expect(result, isNotNull);
      expect(result!.segments.first.number, isNull);
    });

    test('exact match is preferred over child aggregation', () async {
      await insertTextCache(
        sefariaRef: 'Pirkei Avot 1',
        hebrewText: 'whole chapter',
        englishText: 'chapter en',
      );
      await insertTextCache(
        sefariaRef: 'Pirkei Avot 1:1',
        hebrewText: 'first mishna',
        englishText: 'first mishna en',
      );

      final result = await repository.getText('Pirkei Avot 1');

      expect(result, isNotNull);
      // Exact match: single segment with the chapter text.
      expect(result!.segments, hasLength(1));
      expect(result.segments.first.hebrewText, 'whole chapter');
    });
  });

  // ── Child-verse aggregation ───────────────────────────────────────────────

  group('getText — child-verse aggregation', () {
    test('aggregates child verses and sorts by verse number', () async {
      await insertTextCache(
        sefariaRef: 'Genesis 1:3',
        hebrewText: 'ויאמר',
        englishText: 'And God said verse 3',
      );
      await insertTextCache(
        sefariaRef: 'Genesis 1:1',
        hebrewText: 'בראשית',
        englishText: 'In the beginning',
      );
      await insertTextCache(
        sefariaRef: 'Genesis 1:2',
        hebrewText: 'והארץ',
        englishText: 'And the earth',
      );

      final result = await repository.getText('Genesis 1');

      expect(result, isNotNull);
      expect(result!.sefariaRef, 'Genesis 1');
      expect(result.segments, hasLength(3));
      // Sorted by verse number ascending:
      expect(result.segments[0].sefariaRef, 'Genesis 1:1');
      expect(result.segments[0].number, 1);
      expect(result.segments[1].sefariaRef, 'Genesis 1:2');
      expect(result.segments[2].sefariaRef, 'Genesis 1:3');
    });

    test('child aggregation sets verse numbers correctly', () async {
      await insertTextCache(
        sefariaRef: 'Mishnah Berakhot 1:2',
        hebrewText: 'text2',
      );

      final result = await repository.getText('Mishnah Berakhot 1');

      expect(result, isNotNull);
      expect(result!.segments.first.number, 2);
    });

    test('skips segments where both hebrew and english are empty', () async {
      await insertTextCache(
        sefariaRef: 'Test 1:1',
        hebrewText: '',
        englishText: '',
      );
      await insertTextCache(
        sefariaRef: 'Test 1:2',
        hebrewText: 'content',
        englishText: 'content en',
      );

      final result = await repository.getText('Test 1');

      expect(result, isNotNull);
      // Empty segment (1:1) is skipped.
      expect(result!.segments, hasLength(1));
      expect(result.segments.first.sefariaRef, 'Test 1:2');
    });

    test('returns null when all child segments are empty', () async {
      await insertTextCache(
        sefariaRef: 'Empty 1:1',
        hebrewText: '',
        englishText: '',
      );

      final result = await repository.getText('Empty 1');

      // All segments empty → falls through to daily_content → returns null.
      expect(result, isNull);
    });

    // Regression test for the "no English Translation tab" bug:
    // When the bundled content.db has english_text for individual pasuk rows
    // (e.g. 'Genesis 1:1', 'Genesis 1:2', …) but NOT a direct row for
    // the chapter ref ('Genesis 1'), the repository must aggregate the child
    // rows and expose a non-empty TextContent.englishText so the reader shows
    // the "English Translation" card.
    test(
      'chapter-level ref: englishText is non-empty when child rows have english',
      () async {
        await insertTextCache(
          sefariaRef: 'Genesis 1:1',
          hebrewText: 'בְּרֵאשִׁית בָּרָא',
          englishText: 'When God began to create heaven and earth—',
        );
        await insertTextCache(
          sefariaRef: 'Genesis 1:2',
          hebrewText: 'וְהָאָרֶץ הָיְתָה',
          englishText: 'the earth being unformed and void',
        );

        final result = await repository.getText('Genesis 1');

        expect(
          result,
          isNotNull,
          reason: 'chapter ref must resolve via child aggregation',
        );
        expect(
          result!.englishText,
          isNotEmpty,
          reason:
              'TextContent.englishText must be non-empty so the reader shows '
              'the English Translation card — this was the root of the '
              'Chumash no-English-tab regression',
        );
        expect(result.segments, hasLength(2));
        expect(
          result.segments.every((s) => s.englishText.isNotEmpty),
          isTrue,
          reason: 'each pasuk segment carries its own english text',
        );
      },
    );
  });

  // ── daily_content fallback ────────────────────────────────────────────────

  group('getText — daily_content fallback', () {
    test(
      'returns daily_content when textCache and children are absent',
      () async {
        await insertDailyContent(
          sefariaRef: 'Chullin 7',
          hebrewText: 'daf text',
          englishText: 'daf en',
        );

        final result = await repository.getText('Chullin 7');

        expect(result, isNotNull);
        expect(result!.sefariaRef, 'Chullin 7');
        expect(result.hebrewText, 'daf text');
        expect(result.englishText, 'daf en');
      },
    );

    test('daily_content verse number is null for non-colon ref', () async {
      await insertDailyContent(sefariaRef: 'Chullin 7', hebrewText: 'text');

      final result = await repository.getText('Chullin 7');

      expect(result!.segments.first.number, isNull);
    });

    test('daily_content verse number is parsed for colon ref', () async {
      await insertDailyContent(sefariaRef: 'Psalms 1:3', hebrewText: 'והיה');

      final result = await repository.getText('Psalms 1:3');

      expect(result!.segments.first.number, 3);
    });
  });

  // ── getCachedRefs ─────────────────────────────────────────────────────────

  group('getCachedRefs', () {
    test('returns all inserted refs', () async {
      await insertTextCache(sefariaRef: 'Genesis 1:1', hebrewText: 'A');
      await insertTextCache(sefariaRef: 'Genesis 1:2', hebrewText: 'B');

      final refs = await repository.getCachedRefs();

      expect(refs, containsAll(['Genesis 1:1', 'Genesis 1:2']));
      expect(refs, hasLength(2));
    });
  });

  // ── TextContent helpers ───────────────────────────────────────────────────

  group('TextContent', () {
    test('hebrewText joins multiple segments with newline', () async {
      await insertTextCache(sefariaRef: 'Gen 1:1', hebrewText: 'line one');
      await insertTextCache(sefariaRef: 'Gen 1:2', hebrewText: 'line two');

      final result = await repository.getText('Gen 1');

      expect(result!.hebrewText, 'line one\nline two');
    });

    test('TextContent.single factory creates single-segment content', () {
      final content = TextContent.single(
        sefariaRef: 'Test 1',
        hebrewText: 'Hebrew',
        englishText: 'English',
      );

      expect(content.sefariaRef, 'Test 1');
      expect(content.segments, hasLength(1));
      expect(content.hebrewText, 'Hebrew');
      expect(content.englishText, 'English');
    });
  });
}
