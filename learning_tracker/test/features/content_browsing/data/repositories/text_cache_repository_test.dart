import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockCurriculumContentFetcher extends Mock
    implements CurriculumContentFetcher {}

void main() {
  late AppDatabase database;
  late MockCurriculumContentFetcher mockFetcher;
  late TextCacheRepository repository;

  setUp(() {
    database = createTestDatabase();
    mockFetcher = MockCurriculumContentFetcher();
    repository = TextCacheRepository(
      textCacheDao: database.textCacheDao,
      contentFetcher: mockFetcher,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('TextCacheRepository.getText', () {
    const sefariaRef = 'Mishnah Berakhot 1.1';
    const hebrewText = 'מֵאֵימָתַי קוֹרִין אֶת שְׁמַע בָּעֲרָבִית';
    const englishText = 'From when may one recite the Shema in the evening?';

    test('returns null for uncached ref when offline', () async {
      // Arrange - Mock API failure
      when(() => mockFetcher.fetchText(sefariaRef, lang: 'he'))
          .thenThrow(const SefariaApiException('Network error'));

      // Act
      final result = await repository.getText(sefariaRef);

      // Assert
      expect(result, isNull);
      verify(() => mockFetcher.fetchText(sefariaRef, lang: 'he')).called(1);
    });

    test('returns cached text without calling API', () async {
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

      // Verify API was NOT called
      verifyNever(() => mockFetcher.fetchText(any(), lang: any(named: 'lang')));
    });

    test('fetches from API and caches when not cached', () async {
      // Arrange - Mock successful API calls
      when(() => mockFetcher.fetchText(sefariaRef, lang: 'he'))
          .thenAnswer((_) async => hebrewText);
      when(() => mockFetcher.fetchText(sefariaRef, lang: 'en'))
          .thenAnswer((_) async => englishText);

      // Act
      final result = await repository.getText(sefariaRef);

      // Assert - Returns fetched text
      expect(result, isNotNull);
      expect(result!.sefariaRef, sefariaRef);
      expect(result.hebrewText, hebrewText);
      expect(result.englishText, englishText);

      // Verify API was called
      verify(() => mockFetcher.fetchText(sefariaRef, lang: 'he')).called(1);
      verify(() => mockFetcher.fetchText(sefariaRef, lang: 'en')).called(1);

      // Verify text was stored in cache
      final cached = await database.textCacheDao.getText(sefariaRef);
      expect(cached, isNotNull);
      expect(cached!.hebrewText, hebrewText);
      expect(cached.englishText, englishText);
    });

    test('subsequent calls use cache after first fetch', () async {
      // Arrange - Mock API for first call
      when(() => mockFetcher.fetchText(sefariaRef, lang: 'he'))
          .thenAnswer((_) async => hebrewText);
      when(() => mockFetcher.fetchText(sefariaRef, lang: 'en'))
          .thenAnswer((_) async => englishText);

      // Act - First call
      final result1 = await repository.getText(sefariaRef);
      expect(result1, isNotNull);

      // Act - Second call
      final result2 = await repository.getText(sefariaRef);

      // Assert - Both calls return same data
      expect(result2, isNotNull);
      expect(result2!.hebrewText, hebrewText);
      expect(result2.englishText, englishText);

      // Verify API was only called once
      verify(() => mockFetcher.fetchText(sefariaRef, lang: 'he')).called(1);
      verify(() => mockFetcher.fetchText(sefariaRef, lang: 'en')).called(1);
    });

    test('handles API exception gracefully', () async {
      // Arrange - Mock API failure
      when(() => mockFetcher.fetchText(sefariaRef, lang: 'he'))
          .thenThrow(const SefariaApiException('API error', statusCode: 404));

      // Act
      final result = await repository.getText(sefariaRef);

      // Assert - Returns null on error
      expect(result, isNull);

      // Verify nothing was cached
      final cached = await database.textCacheDao.getText(sefariaRef);
      expect(cached, isNull);
    });

    test('handles partial API failure (Hebrew succeeds, English fails)', () async {
      // Arrange - Hebrew succeeds, English fails
      when(() => mockFetcher.fetchText(sefariaRef, lang: 'he'))
          .thenAnswer((_) async => hebrewText);
      when(() => mockFetcher.fetchText(sefariaRef, lang: 'en'))
          .thenThrow(const SefariaApiException('English text unavailable'));

      // Act
      final result = await repository.getText(sefariaRef);

      // Assert - Returns null on any fetch failure
      expect(result, isNull);

      // Verify nothing was cached
      final cached = await database.textCacheDao.getText(sefariaRef);
      expect(cached, isNull);
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
