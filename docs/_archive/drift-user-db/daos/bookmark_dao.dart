import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'bookmark_dao.g.dart';

@DriftAccessor(tables: [Bookmarks])
class BookmarkDao extends DatabaseAccessor<UserDatabase>
    with _$BookmarkDaoMixin, BaseDao<$BookmarksTable, Bookmark, UserDatabase> {
  BookmarkDao(super.db);

  @override
  TableInfo<$BookmarksTable, Bookmark> get table => bookmarks;

  @override
  Expression<int> idColumn($BookmarksTable t) => t.id;

  @override
  Expression<int> profileIdColumn($BookmarksTable t) => t.profileId;

  Future<List<Bookmark>> getAllBookmarks() => select(bookmarks).get();

  Future<Bookmark?> getBookmarkById(int id) =>
      (select(bookmarks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get a bookmark by curriculum and track ID.
  Future<Bookmark?> getBookmarkByCurriculumAndTrack(
    String curriculumId,
    int trackId,
  ) =>
      (select(bookmarks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId) & t.trackId.equals(trackId),
          ))
          .getSingleOrNull();

  Future<int> insertBookmark(BookmarksCompanion entry) =>
      into(bookmarks).insert(entry);

  Future<bool> updateBookmark(BookmarksCompanion entry) =>
      update(bookmarks).replace(entry);

  Future<int> deleteBookmark(int id) =>
      (delete(bookmarks)..where((t) => t.id.equals(id))).go();

  // ========== Profile-Scoped Queries ==========

  /// Get a bookmark by curriculum, track ID, and profile.
  Future<Bookmark?> getBookmarkByCurriculumTrackAndProfile(
    String curriculumId,
    int trackId,
    int profileId,
  ) =>
      (select(bookmarks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId) &
                t.trackId.equals(trackId) &
                t.profileId.equals(profileId),
          ))
          .getSingleOrNull();

  /// Get all bookmarks for a specific profile.
  Future<List<Bookmark>> getBookmarksByProfile(int profileId) =>
      (select(bookmarks)..where((t) => t.profileId.equals(profileId))).get();

  /// Upsert a bookmark by curriculum, track ID, and profile (last-write-wins).
  Future<void> upsertBookmarkByProfile({
    required String curriculumId,
    required int trackId,
    required String sefariaRef,
    required DateTime updatedAt,
    required int profileId,
  }) async {
    final existing = await getBookmarkByCurriculumTrackAndProfile(
      curriculumId,
      trackId,
      profileId,
    );

    if (existing == null) {
      await insertBookmark(
        BookmarksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
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

  /// Upsert a bookmark by curriculum and track ID (last-write-wins per D4).
  ///
  /// Inserts if no bookmark exists for the curriculum+trackId pair,
  /// or updates if the existing bookmark is older than [updatedAt].
  Future<void> upsertBookmark({
    required String curriculumId,
    required int trackId,
    required int profileId,
    required String sefariaRef,
    required DateTime updatedAt,
  }) async {
    final existing = await getBookmarkByCurriculumAndTrack(
      curriculumId,
      trackId,
    );

    if (existing == null) {
      await insertBookmark(
        BookmarksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
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
