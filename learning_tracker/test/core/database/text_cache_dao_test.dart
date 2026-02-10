import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';

AppDatabase _createInMemoryDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('TextCacheDao CRUD', () {
    test('returns null for uncached text', () async {
      final result = await db.textCacheDao.getText('Mishnah Berakhot 1.1');
      expect(result, isNull);
    });

    test('stores and retrieves cached text', () async {
      const ref = 'Mishnah Berakhot 1.1';
      const hebrewText = 'מֵאֵימָתַי קוֹרִין אֶת שְׁמַע בָּעֲרָבִית';
      const englishText = 'From when may one recite the Shema in the evening?';

      await db.textCacheDao.storeText(
        sefariaRef: ref,
        hebrewText: hebrewText,
        englishText: englishText,
      );

      final cached = await db.textCacheDao.getText(ref);
      expect(cached, isNotNull);
      expect(cached!.sefariaRef, ref);
      expect(cached.hebrewText, hebrewText);
      expect(cached.englishText, englishText);
      expect(cached.fetchedAt, isA<DateTime>());
    });

    test('updates existing cached text on conflict', () async {
      const ref = 'Mishnah Berakhot 1.1';

      // Store initial version
      await db.textCacheDao.storeText(
        sefariaRef: ref,
        hebrewText: 'old hebrew',
        englishText: 'old english',
      );

      // Store updated version
      await db.textCacheDao.storeText(
        sefariaRef: ref,
        hebrewText: 'new hebrew',
        englishText: 'new english',
      );

      final cached = await db.textCacheDao.getText(ref);
      expect(cached, isNotNull);
      expect(cached!.hebrewText, 'new hebrew');
      expect(cached.englishText, 'new english');

      // Verify only one entry exists
      final allRefs = await db.textCacheDao.getAllCachedRefs();
      expect(allRefs.length, 1);
    });

    test('deletes cached text', () async {
      const ref = 'Mishnah Berakhot 1.1';

      await db.textCacheDao.storeText(
        sefariaRef: ref,
        hebrewText: 'hebrew',
        englishText: 'english',
      );

      await db.textCacheDao.deleteText(ref);

      final cached = await db.textCacheDao.getText(ref);
      expect(cached, isNull);
    });

    test('returns all cached refs', () async {
      await db.textCacheDao.storeText(
        sefariaRef: 'Mishnah Berakhot 1.1',
        hebrewText: 'text1',
        englishText: 'text1',
      );
      await db.textCacheDao.storeText(
        sefariaRef: 'Mishnah Berakhot 1.2',
        hebrewText: 'text2',
        englishText: 'text2',
      );
      await db.textCacheDao.storeText(
        sefariaRef: 'Bavli Berakhot 2a',
        hebrewText: 'text3',
        englishText: 'text3',
      );

      final refs = await db.textCacheDao.getAllCachedRefs();
      expect(refs.length, 3);
      expect(refs, contains('Mishnah Berakhot 1.1'));
      expect(refs, contains('Mishnah Berakhot 1.2'));
      expect(refs, contains('Bavli Berakhot 2a'));
    });

    test('clears all cached text', () async {
      await db.textCacheDao.storeText(
        sefariaRef: 'Mishnah Berakhot 1.1',
        hebrewText: 'text1',
        englishText: 'text1',
      );
      await db.textCacheDao.storeText(
        sefariaRef: 'Mishnah Berakhot 1.2',
        hebrewText: 'text2',
        englishText: 'text2',
      );

      final deleted = await db.textCacheDao.clearCache();
      expect(deleted, 2);

      final refs = await db.textCacheDao.getAllCachedRefs();
      expect(refs, isEmpty);
    });

    test('enforces primary key uniqueness on sefariaRef', () async {
      const ref = 'Mishnah Berakhot 1.1';

      // First insert should succeed
      await db.textCacheDao.storeText(
        sefariaRef: ref,
        hebrewText: 'first',
        englishText: 'first',
      );

      // Second insert with same ref should update (insertOnConflictUpdate)
      // No exception should be thrown
      await db.textCacheDao.storeText(
        sefariaRef: ref,
        hebrewText: 'second',
        englishText: 'second',
      );

      final cached = await db.textCacheDao.getText(ref);
      expect(cached!.hebrewText, 'second');
    });
  });
}
