import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';

import '../../../../helpers/test_database.dart';

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

  group('TextCacheRepository.getText', () {
    const sefariaRef = 'Mishnah Berakhot 1.1';
    const hebrewText =
        '\u05DE\u05B5\u05D0\u05B5\u05D9\u05DE\u05B8\u05EA\u05B7\u05D9 \u05E7\u05D5\u05B9\u05E8\u05B4\u05D9\u05DF \u05D0\u05B6\u05EA \u05E9\u05B0\u05C1\u05DE\u05B7\u05E2 \u05D1\u05B8\u05BC\u05E2\u05B2\u05E8\u05B8\u05D1\u05B4\u05D9\u05EA';
    const englishText = 'From when may one recite the Shema in the evening?';

    test('returns null for uncached ref', () async {
      final result = await repository.getText(sefariaRef);
      expect(result, isNull);
    });

    test('returns cached text when available', () async {
      // Arrange - Pre-cache text
      await database.textCacheDao.storeText(
        sefariaRef: sefariaRef,
        hebrewText: hebrewText,
        englishText: englishText,
      );

      // Act
      final result = await repository.getText(sefariaRef);

      // Assert
      expect(result, isNotNull);
      expect(result!.sefariaRef, sefariaRef);
      expect(result.hebrewText, hebrewText);
      expect(result.englishText, englishText);
    });

    test('returns null when text is not cached (no API fallback)', () async {
      // Cache-only: never fetches from API, just returns null
      final result = await repository.getText('nonexistent_ref');
      expect(result, isNull);
    });
  });

  group('TextCacheRepository.clearCache', () {
    test('clears all cached text', () async {
      // Arrange - Cache multiple texts
      await database.textCacheDao.storeText(
        sefariaRef: 'Mishnah Berakhot 1.1',
        hebrewText: 'text1',
        englishText: 'text1',
      );
      await database.textCacheDao.storeText(
        sefariaRef: 'Mishnah Berakhot 1.2',
        hebrewText: 'text2',
        englishText: 'text2',
      );

      // Act
      await repository.clearCache();

      // Assert
      final refs = await repository.getCachedRefs();
      expect(refs, isEmpty);
    });
  });

  group('TextCacheRepository.getCachedRefs', () {
    test('returns list of all cached references', () async {
      // Arrange - Cache multiple texts
      await database.textCacheDao.storeText(
        sefariaRef: 'Mishnah Berakhot 1.1',
        hebrewText: 'text1',
        englishText: 'text1',
      );
      await database.textCacheDao.storeText(
        sefariaRef: 'Bavli Berakhot 2a',
        hebrewText: 'text2',
        englishText: 'text2',
      );

      // Act
      final refs = await repository.getCachedRefs();

      // Assert
      expect(refs.length, 2);
      expect(refs, contains('Mishnah Berakhot 1.1'));
      expect(refs, contains('Bavli Berakhot 2a'));
    });

    test('returns empty list when no text is cached', () async {
      // Act
      final refs = await repository.getCachedRefs();

      // Assert
      expect(refs, isEmpty);
    });
  });
}
