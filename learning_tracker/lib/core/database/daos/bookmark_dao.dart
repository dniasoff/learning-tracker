import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';

part 'bookmark_dao.g.dart';

@DriftAccessor(tables: [Bookmarks])
class BookmarkDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarkDaoMixin {
  BookmarkDao(super.db);

  Future<List<Bookmark>> getAllBookmarks() =>
      select(bookmarks).get();

  Future<Bookmark?> getBookmarkById(int id) =>
      (select(bookmarks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Bookmark?> getBookmarkByCurriculumAndTrack(
    String curriculumId,
    String trackType,
  ) =>
      (select(bookmarks)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.trackType.equals(trackType),
            ))
          .getSingleOrNull();

  Future<int> insertBookmark(BookmarksCompanion entry) =>
      into(bookmarks).insert(entry);

  Future<bool> updateBookmark(BookmarksCompanion entry) =>
      update(bookmarks).replace(entry);

  Future<int> deleteBookmark(int id) =>
      (delete(bookmarks)..where((t) => t.id.equals(id))).go();
}
