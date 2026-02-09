import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [BookmarkRepository] using Drift database and sync engine.
class BookmarkRepositoryImpl implements BookmarkRepository {
  final AppDatabase _database;
  final SyncEngine _syncEngine;

  BookmarkRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
  }) : _database = database,
       _syncEngine = syncEngine;

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
  }) async {
    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumAndTrack(
          curriculumId.storageKey,
          trackType.value,
        );

    if (bookmark == null) return null;

    return _bookmarkFromDb(bookmark);
  }

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
    required int contentItemId,
  }) async {
    final now = DateTime.now().toUtc(); // P5: UTC timestamps

    // Check if bookmark exists
    final existing = await _database.bookmarkDao
        .getBookmarkByCurriculumAndTrack(
          curriculumId.storageKey,
          trackType.value,
        );

    final BookmarkEntity bookmark;

    if (existing != null) {
      // Update existing bookmark
      await _database.bookmarkDao.updateBookmark(
        BookmarksCompanion(
          id: drift.Value(existing.id),
          curriculumId: drift.Value(curriculumId.storageKey),
          trackType: drift.Value(trackType.value),
          contentItemId: drift.Value(contentItemId),
          updatedAt: drift.Value(now),
        ),
      );

      bookmark = BookmarkEntity(
        curriculumId: curriculumId,
        trackType: trackType,
        contentItemId: contentItemId,
        updatedAt: now,
      );
    } else {
      // Create new bookmark
      await _database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: curriculumId.storageKey,
          trackType: trackType.value,
          contentItemId: contentItemId,
          updatedAt: now,
        ),
      );

      bookmark = BookmarkEntity(
        curriculumId: curriculumId,
        trackType: trackType,
        contentItemId: contentItemId,
        updatedAt: now,
      );
    }

    // Sync to Firestore
    await _syncBookmark(bookmark);

    return bookmark;
  }

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
    required int completedItemId,
  }) async {
    // Get current bookmark
    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumAndTrack(
          curriculumId.storageKey,
          trackType.value,
        );

    if (bookmark == null) {
      // No bookmark exists yet, create one pointing to the next item
      final nextItemId = await _getNextItemId(
        curriculumId: curriculumId,
        currentItemId: completedItemId,
      );

      if (nextItemId != null) {
        await setBookmark(
          curriculumId: curriculumId,
          trackType: trackType,
          contentItemId: nextItemId,
        );
      }
    } else if (bookmark.contentItemId == completedItemId) {
      // Bookmark is on this item, advance it
      final nextItemId = await _getNextItemId(
        curriculumId: curriculumId,
        currentItemId: completedItemId,
      );

      if (nextItemId != null) {
        await setBookmark(
          curriculumId: curriculumId,
          trackType: trackType,
          contentItemId: nextItemId,
        );
      }
    }
    // else: bookmark is on a different item, don't change it
  }

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
  }) async {
    // Get the first item in learning order
    final firstItemId = await _getFirstItemId(curriculumId: curriculumId);

    if (firstItemId == null) {
      throw StateError(
        'Cannot initialize bookmark: no content items found for $curriculumId',
      );
    }

    return await setBookmark(
      curriculumId: curriculumId,
      trackType: trackType,
      contentItemId: firstItemId,
    );
  }

  @override
  Future<int> syncFromFirestore() async {
    // This would be called by the sync engine
    // For now, return 0 as a placeholder
    // The actual implementation will be in sync engine's _mergeBookmarks
    return 0;
  }

  /// Get the next content item ID in learning order.
  ///
  /// Respects custom learning order if it exists, otherwise uses sort_order.
  Future<int?> _getNextItemId({
    required CurriculumId curriculumId,
    required int currentItemId,
  }) async {
    // Check if custom learning order exists for this curriculum
    final customOrder = await _database.learningOrderDao
        .getLearningOrderByCurriculum(curriculumId.storageKey);

    if (customOrder.isNotEmpty) {
      // Use custom learning order
      final currentIndex = customOrder.indexWhere(
        (item) => item.contentItemId == currentItemId,
      );

      if (currentIndex == -1 || currentIndex == customOrder.length - 1) {
        return null; // Current item not found or is the last item
      }

      return customOrder[currentIndex + 1].contentItemId;
    } else {
      // Use default sort_order
      final allItems =
          await (_database.select(_database.contentItems)
                ..where(
                  (t) =>
                      t.curriculumId.equals(curriculumId.storageKey) &
                      t.isLeaf.equals(true),
                )
                ..orderBy([(t) => drift.OrderingTerm.asc(t.sortOrder)]))
              .get();

      final currentIndex = allItems.indexWhere(
        (item) => item.id == currentItemId,
      );

      if (currentIndex == -1 || currentIndex == allItems.length - 1) {
        return null; // Current item not found or is the last item
      }

      return allItems[currentIndex + 1].id;
    }
  }

  /// Get the first content item ID in learning order.
  Future<int?> _getFirstItemId({required CurriculumId curriculumId}) async {
    // Check if custom learning order exists for this curriculum
    final customOrder = await _database.learningOrderDao
        .getLearningOrderByCurriculum(curriculumId.storageKey);

    if (customOrder.isNotEmpty) {
      return customOrder.first.contentItemId;
    } else {
      // Use default sort_order
      final firstItem =
          await (_database.select(_database.contentItems)
                ..where(
                  (t) =>
                      t.curriculumId.equals(curriculumId.storageKey) &
                      t.isLeaf.equals(true),
                )
                ..orderBy([(t) => drift.OrderingTerm.asc(t.sortOrder)])
                ..limit(1))
              .getSingleOrNull();

      return firstItem?.id;
    }
  }

  /// Queue bookmark for Firestore sync.
  Future<void> _syncBookmark(BookmarkEntity bookmark) async {
    await _syncEngine.pushBookmark(bookmark.toFirestore());
  }

  /// Convert database model to domain entity.
  BookmarkEntity _bookmarkFromDb(Bookmark bookmark) {
    return BookmarkEntity(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == bookmark.curriculumId,
      ),
      trackType: TrackType.fromStorageKey(bookmark.trackType),
      contentItemId: bookmark.contentItemId,
      updatedAt: bookmark.updatedAt,
    );
  }

  /// Merge remote bookmark with local (conflict resolution).
  ///
  /// Uses last-write-wins strategy based on UTC timestamps (P5).
  /// Called by sync engine during pull operations.
  Future<void> mergeRemoteBookmark(Map<String, dynamic> remoteData) async {
    final remote = BookmarkEntity.fromFirestore(remoteData);

    // Get local bookmark
    final local = await getBookmark(
      curriculumId: remote.curriculumId,
      trackType: remote.trackType,
    );

    if (local == null) {
      // No local bookmark, just insert remote
      await _database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: remote.curriculumId.storageKey,
          trackType: remote.trackType.value,
          contentItemId: remote.contentItemId,
          updatedAt: remote.updatedAt,
        ),
      );
    } else {
      // Compare timestamps: remote wins if newer
      if (remote.updatedAt.isAfter(local.updatedAt)) {
        await _database.bookmarkDao.updateBookmark(
          BookmarksCompanion(
            id: drift.Value(
              (await _database.bookmarkDao.getBookmarkByCurriculumAndTrack(
                local.curriculumId.storageKey,
                local.trackType.value,
              ))!.id,
            ),
            curriculumId: drift.Value(remote.curriculumId.storageKey),
            trackType: drift.Value(remote.trackType.value),
            contentItemId: drift.Value(remote.contentItemId),
            updatedAt: drift.Value(remote.updatedAt),
          ),
        );
      }
      // else: local is newer or same, keep local
    }
  }
}
