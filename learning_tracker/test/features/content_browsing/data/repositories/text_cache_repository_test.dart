import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ContentDatabase database;
  late TextCacheRepository repository;

  setUp(() {
    database = createTestContentDatabase();
    repository = TextCacheRepository(textCacheDao: database.contentTextCacheDao, dio: Dio());
  });

  tearDown(() async {
    await database.close();
  });

  group('TextCacheRepository.getText', () {
    test('returns null for uncached ref', () async {
      final result = await repository.getText('Mishnah Berakhot 1.1');
      expect(result, isNull);
    });

    test('returns null when text is not cached (no API fallback)', () async {
      // Cache-only: never fetches from API, just returns null
      final result = await repository.getText('nonexistent_ref');
      expect(result, isNull);
    });
  });

  group('TextCacheRepository.getCachedRefs', () {
    test('returns empty list when no text is cached', () async {
      // Act
      final refs = await repository.getCachedRefs();

      // Assert
      expect(refs, isEmpty);
    });
  });
}
