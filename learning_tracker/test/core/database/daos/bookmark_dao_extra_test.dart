// Extra tests for BookmarkDao — covers getBookmarksByProfile (line 64-65)
// and upsertBookmarkByProfile insert path (lines 82-95).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  const profileId = 1;
  const curriculumId = 'mishnayos';

  setUp(() async {
    db = inMemoryDb();

    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // BookmarkDao.getBookmarksByProfile
  // =========================================================================

  group('BookmarkDao.getBookmarksByProfile', () {
    test('returns empty list when no bookmarks for profile', () async {
      final result = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(result, isEmpty);
    });

    test('returns bookmarks only for the given profile', () async {
      final now = DateTime.utc(2026, 3, 15);

      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1:1',
          updatedAt: now,
        ),
      );

      // Different profile — should not appear in results
      const otherProfileId = 99;
      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: otherProfileId,
          curriculumId: curriculumId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1:2',
          updatedAt: now,
        ),
      );

      final result = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(result, hasLength(1));
      expect(result.first.sefariaRef, 'Berakhot 1:1');
    });
  });

  // =========================================================================
  // BookmarkDao.upsertBookmarkByProfile — insert path
  // =========================================================================

  group('BookmarkDao.upsertBookmarkByProfile', () {
    test('inserts a new bookmark when none exists', () async {
      final now = DateTime.utc(2026, 3, 15);

      await db.bookmarkDao.upsertBookmarkByProfile(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        sefariaRef: 'Berakhot 2:1',
        updatedAt: now,
      );

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first.sefariaRef, 'Berakhot 2:1');
    });

    test('updates existing bookmark to newer ref', () async {
      final earlier = DateTime.utc(2026, 3, 10);
      final later = DateTime.utc(2026, 3, 15);

      await db.bookmarkDao.upsertBookmarkByProfile(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        sefariaRef: 'Berakhot 1:1',
        updatedAt: earlier,
      );

      await db.bookmarkDao.upsertBookmarkByProfile(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        sefariaRef: 'Berakhot 5:1',
        updatedAt: later,
      );

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first.sefariaRef, 'Berakhot 5:1');
    });
  });
}
