import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late TextCacheRepository repository;

  setUp(() {
    database = createTestDatabase();
    repository = TextCacheRepository(textCacheDao: database.textCacheDao);
  });

  tearDown(() async {
    await database.close();
  });

  group('Text Display Integration Tests', () {
    test(
      'Full flow: pre-cache text -> getText returns it -> cache hit on second call',
      () async {
        const sefariaRef = 'Mishnah Berakhot 1.1';
        const hebrewText =
            '\u05DE\u05B5\u05D0\u05B5\u05D9\u05DE\u05B8\u05EA\u05B7\u05D9 \u05E7\u05D5\u05B9\u05E8\u05B4\u05D9\u05DF \u05D0\u05B6\u05EA \u05E9\u05B0\u05C1\u05DE\u05B7\u05E2 \u05D1\u05B8\u05BC\u05E2\u05B2\u05E8\u05B8\u05D1\u05B4\u05D9\u05EA';
        const englishText =
            'From when may one recite the Shema in the evening?';

        // Arrange - Pre-cache text (simulates download service)
        await database.textCacheDao.storeText(
          sefariaRef: sefariaRef,
          hebrewText: hebrewText,
          englishText: englishText,
        );

        // Act - First call: should return cached text
        final firstResult = await repository.getText(sefariaRef);

        // Assert - Text was returned from cache
        expect(firstResult, isNotNull);
        expect(firstResult!.hebrewText, hebrewText);
        expect(firstResult.englishText, englishText);

        // Act - Second call: also returns from cache
        final secondResult = await repository.getText(sefariaRef);

        // Assert - Same text returned from cache
        expect(secondResult, isNotNull);
        expect(secondResult!.hebrewText, hebrewText);
        expect(secondResult.englishText, englishText);
      },
    );

    test(
      'Cache-only scenario: uncached text returns null (no API fallback)',
      () async {
        const cachedRef = 'Mishnah Berakhot 1.1';
        const uncachedRef = 'Mishnah Berakhot 1.2';
        const hebrewText =
            '\u05DE\u05B5\u05D0\u05B5\u05D9\u05DE\u05B8\u05EA\u05B7\u05D9';
        const englishText = 'From when';

        // Arrange - Pre-cache one text
        await database.textCacheDao.storeText(
          sefariaRef: cachedRef,
          hebrewText: hebrewText,
          englishText: englishText,
        );

        // Act - Cached text returns successfully
        final cachedResult = await repository.getText(cachedRef);

        // Assert
        expect(cachedResult, isNotNull);
        expect(cachedResult!.hebrewText, hebrewText);
        expect(cachedResult.englishText, englishText);

        // Act - Uncached text returns null
        final uncachedResult = await repository.getText(uncachedRef);

        // Assert - Returns null for uncached text (no API fallback)
        expect(uncachedResult, isNull);
      },
    );

    test(
      'Navigate away and return: text loads from cache consistently',
      () async {
        const sefariaRef = 'Mishnah Berakhot 1.1';
        const hebrewText = 'hebrew text';
        const englishText = 'english text';

        // Arrange - Pre-cache text
        await database.textCacheDao.storeText(
          sefariaRef: sefariaRef,
          hebrewText: hebrewText,
          englishText: englishText,
        );

        // Act - Initial view
        final initialResult = await repository.getText(sefariaRef);
        expect(initialResult, isNotNull);

        // Simulate navigation away (no action needed)
        // Act - Return to same text
        final returnResult = await repository.getText(sefariaRef);

        // Assert - Text loaded from cache consistently
        expect(returnResult, isNotNull);
        expect(returnResult!.hebrewText, hebrewText);
        expect(returnResult.englishText, englishText);
      },
    );
  });
}
