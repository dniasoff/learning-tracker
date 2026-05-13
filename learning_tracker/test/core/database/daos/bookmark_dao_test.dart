import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

void main() {
  late UserDatabase database;
  late int trackId;

  setUp(() async {
    database = UserDatabase(NativeDatabase.memory());
    trackId = await database.into(database.curriculumTracks).insert(
      CurriculumTracksCompanion.insert(
        profileId: 1,
        curriculumId: 'bavli',
        trackType: 'personal',
        activatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
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
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          sefariaRef: 'Berakhot.2a',
          updatedAt: now,
        ),
      );

      final bookmark = await database.bookmarkDao.getBookmarkById(id);
      expect(bookmark, isNotNull);
      expect(bookmark!.curriculumId, 'bavli');
      expect(bookmark.trackId, trackId);
      expect(bookmark.sefariaRef, 'Berakhot.2a');
    });

    test('getBookmarkByCurriculumAndTrack returns matching bookmark', () async {
      final now = DateTime.now();
      await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          sefariaRef: 'Berakhot.2a',
          updatedAt: now,
        ),
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('bavli', trackId);
      expect(bookmark, isNotNull);
      expect(bookmark!.sefariaRef, 'Berakhot.2a');
    });

    test(
      'getBookmarkByCurriculumAndTrack returns null when not found',
      () async {
        final bookmark = await database.bookmarkDao
            .getBookmarkByCurriculumAndTrack('bavli', trackId);
        expect(bookmark, isNull);
      },
    );

    test('updateBookmark modifies existing bookmark', () async {
      final now = DateTime.now();
      final id = await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          sefariaRef: 'Berakhot.2a',
          updatedAt: now,
        ),
      );

      await database.bookmarkDao.updateBookmark(
        BookmarksCompanion(
          id: Value(id),
          profileId: const Value(1),
          curriculumId: const Value('bavli'),
          trackId: Value(trackId),
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
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
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
        trackId: trackId,
        profileId: 1,
        sefariaRef: 'Berakhot.2a',
        updatedAt: now,
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('bavli', trackId);
      expect(bookmark, isNotNull);
      expect(bookmark!.sefariaRef, 'Berakhot.2a');
    });

    test('upsertBookmark updates when newer timestamp', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackId: trackId,
        profileId: 1,
        sefariaRef: 'Berakhot.2a',
        updatedAt: older,
      );

      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackId: trackId,
        profileId: 1,
        sefariaRef: 'Berakhot.3a',
        updatedAt: newer,
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('bavli', trackId);
      expect(bookmark!.sefariaRef, 'Berakhot.3a');
    });

    test('upsertBookmark does not update when older timestamp', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackId: trackId,
        profileId: 1,
        sefariaRef: 'Berakhot.3a',
        updatedAt: newer,
      );

      await database.bookmarkDao.upsertBookmark(
        curriculumId: 'bavli',
        trackId: trackId,
        profileId: 1,
        sefariaRef: 'Berakhot.2a',
        updatedAt: older,
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack('bavli', trackId);
      expect(bookmark!.sefariaRef, 'Berakhot.3a');
    });
  });
}
