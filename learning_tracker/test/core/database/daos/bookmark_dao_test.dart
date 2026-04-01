import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

void main() {
  late UserDatabase database;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('BookmarkDao', () {
    test('getAllBookmarks returns empty list initially', () async {
      final bookmarks = await database.bookmarkDao.getAllBookmarks();
      expect(bookmarks, isEmpty);
    });

    test('insertBookmark and getBookmarkById', () async {
      final now = DateTime.now();
      final id = await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'bavli',
          trackType: 'amud',
          sefariaRef: 'Berakhot.2a',
          updatedAt: now,
        ),
      );

      final bookmark = await database.bookmarkDao.getBookmarkById(id);
      expect(bookmark, isNotNull);
      expect(bookmark!.curriculumId, 'bavli');
      expect(bookmark.trackType, 'amud');
      expect(bookmark.sefariaRef, 'Berakhot.2a');
    });

    test('getBookmarkByCurriculumAndTrack returns matching bookmark', () async {
      final now = DateTime.now();
      await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'bavli',
          trackType: 'amud',
          sefariaRef: 'Berakhot.2a',
          updatedAt: now,
        ),
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('bavli', 'amud');
      expect(bookmark, isNotNull);
      expect(bookmark!.sefariaRef, 'Berakhot.2a');
    });

    test(
      'getBookmarkByCurriculumAndTrack returns null when not found',
      () async {
        final bookmark = await database.bookmarkDao
            .getBookmarkByCurriculumAndTrack('bavli', 'amud');
        expect(bookmark, isNull);
      },
    );

    test('updateBookmark modifies existing bookmark', () async {
      final now = DateTime.now();
      final id = await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'bavli',
          trackType: 'amud',
          sefariaRef: 'Berakhot.2a',
          updatedAt: now,
        ),
      );

      await database.bookmarkDao.updateBookmark(
        BookmarksCompanion(
          id: Value(id),
          curriculumId: const Value('bavli'),
          trackType: const Value('amud'),
          sefariaRef: const Value('Berakhot.2b'),
          updatedAt: Value(now),
        ),
      );

      final updated = await database.bookmarkDao.getBookmarkById(id);
      expect(updated!.sefariaRef, 'Berakhot.2b');
    });

    test('deleteBookmark removes the bookmark', () async {
      final now = DateTime.now();
      final id = await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'bavli',
          trackType: 'amud',
          sefariaRef: 'Berakhot.2a',
          updatedAt: now,
        ),
      );

      final deleted = await database.bookmarkDao.deleteBookmark(id);
      expect(deleted, 1);

      final bookmark = await database.bookmarkDao.getBookmarkById(id);
      expect(bookmark, isNull);
    });

    test('upsertBookmark inserts when no existing bookmark', () async {
      final now = DateTime.now();
      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackType: 'amud',
        sefariaRef: 'Berakhot.2a',
        updatedAt: now,
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('bavli', 'amud');
      expect(bookmark, isNotNull);
      expect(bookmark!.sefariaRef, 'Berakhot.2a');
    });

    test('upsertBookmark updates when newer timestamp', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackType: 'amud',
        sefariaRef: 'Berakhot.2a',
        updatedAt: older,
      );

      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackType: 'amud',
        sefariaRef: 'Berakhot.3a',
        updatedAt: newer,
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('bavli', 'amud');
      expect(bookmark!.sefariaRef, 'Berakhot.3a');
    });

    test('upsertBookmark does not update when older timestamp', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackType: 'amud',
        sefariaRef: 'Berakhot.3a',
        updatedAt: newer,
      );

      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackType: 'amud',
        sefariaRef: 'Berakhot.2a',
        updatedAt: older,
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('bavli', 'amud');
      expect(bookmark!.sefariaRef, 'Berakhot.3a');
    });
  });
}
