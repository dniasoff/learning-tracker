import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';

part 'bookmark_dao.g.dart';

@DriftAccessor(tables: [Bookmarks])
class BookmarkDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarkDaoMixin {
  BookmarkDao(super.db);

  Future<List<Bookmark>> getAllBookmarks() => select(bookmarks).get();

  Future<Bookmark?> getBookmarkById(int id) =>
      (select(bookmarks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Bookmark?> getBookmarkByCurriculumAndTrack(
    String curriculumId,
    String trackType,
  ) =>
      (select(bookmarks)..where(
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

  /// Upsert a bookmark by curriculum and track (last-write-wins per D4).
  ///
  /// Inserts if no bookmark exists for the curriculum+track pair,
  /// or updates if the existing bookmark is older than [updatedAt].
  Future<void> upsertBookmark({
    required String curriculumId,
    required String trackType,
    required String sefariaRef,
    required DateTime updatedAt,
  }) async {
    final existing = await getBookmarkByCurriculumAndTrack(
      curriculumId,
      trackType,
    );

    if (existing == null) {
      await insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: curriculumId,
          trackType: trackType,
          sefariaRef: sefariaRef,
          updatedAt: updatedAt,
        ),
      );
    } else if (updatedAt.isAfter(existing.updatedAt)) {
      await (update(bookmarks)..where((t) => t.id.equals(existing.id))).write(
        BookmarksCompanion(
          sefariaRef: Value(sefariaRef),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }
}
