import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late ContentDatabase database;
  late TextCacheRepository repository;

  setUp(() {
    database = createTestContentDatabase();
    repository = TextCacheRepository(
      textCacheDao: database.contentTextCacheDao,
      dio: Dio(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Text Display Integration Tests', () {
    test(
      'Cache-only scenario: uncached text returns null (no API fallback)',
      () async {
        // Uncached text returns null
        final uncachedResult = await repository.getText('Mishnah Berakhot 1.2');
        expect(uncachedResult, isNull);
      },
    );

    test(
      'Consistent null for same uncached ref across calls',
      () async {
        const sefariaRef = 'Mishnah Berakhot 1.1';

        // First call
        final firstResult = await repository.getText(sefariaRef);
        expect(firstResult, isNull);

        // Second call — same result
        final secondResult = await repository.getText(sefariaRef);
        expect(secondResult, isNull);
      },
    );
  });
}
