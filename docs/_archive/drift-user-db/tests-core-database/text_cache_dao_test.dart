import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';

ContentDatabase _createInMemoryDatabase() {
  return ContentDatabase(NativeDatabase.memory());
}

void main() {
  late ContentDatabase db;

  setUp(() {
    db = _createInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('ContentTextCacheDao (read-only)', () {
    test('returns null for uncached text', () async {
      final result = await db.contentTextCacheDao.getText(
        'Mishnah Berakhot 1.1',
      );
      expect(result, isNull);
    });

    test('getAllCachedRefs returns empty list on fresh database', () async {
      final refs = await db.contentTextCacheDao.getAllCachedRefs();
      expect(refs, isEmpty);
    });
  });
}
