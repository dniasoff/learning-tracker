import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [BookmarkRepository] using Drift database and sync engine.
class BookmarkRepositoryImpl implements BookmarkRepository {
  final AppDatabase _database;
  final SyncEngine _syncEngine;
  final ContentRepository _contentRepository;

  BookmarkRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
    required ContentRepository contentRepository,
  }) : _database = database,
       _syncEngine = syncEngine,
       _contentRepository = contentRepository;

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
  }) async {
    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumAndTrack(
          curriculumId.storageKey,
          trackType.storageKey,
        );

    if (bookmark == null) return null;

    return _bookmarkFromDb(bookmark);
  }

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
    required String sefariaRef,
  }) async {
    final now = DateTime.now().toUtc(); // P5: UTC timestamps

    // Check if bookmark exists
    final existing = await _database.bookmarkDao
        .getBookmarkByCurriculumAndTrack(
          curriculumId.storageKey,
          trackType.storageKey,
        );

    final BookmarkEntity bookmark;

    if (existing != null) {
      // Update existing bookmark
      await _database.bookmarkDao.updateBookmark(
        BookmarksCompanion(
          id: drift.Value(existing.id),
          curriculumId: drift.Value(curriculumId.storageKey),
          trackType: drift.Value(trackType.storageKey),
          sefariaRef: drift.Value(sefariaRef),
          updatedAt: drift.Value(now),
        ),
      );

      bookmark = BookmarkEntity(
        curriculumId: curriculumId,
        trackType: trackType,
        sefariaRef: sefariaRef,
        updatedAt: now,
      );
    } else {
      // Create new bookmark
      await _database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: curriculumId.storageKey,
          trackType: trackType.storageKey,
          sefariaRef: sefariaRef,
          updatedAt: now,
        ),
      );

      bookmark = BookmarkEntity(
        curriculumId: curriculumId,
        trackType: trackType,
        sefariaRef: sefariaRef,
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
    required String completedSefariaRef,
  }) async {
    // Get current bookmark
    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumAndTrack(
          curriculumId.storageKey,
          trackType.storageKey,
        );

    if (bookmark == null) {
      // No bookmark exists yet, create one pointing to the next item
      final nextSefariaRef = await _getNextItemId(
        curriculumId: curriculumId,
        currentSefariaRef: completedSefariaRef,
      );

      if (nextSefariaRef != null) {
        await setBookmark(
          curriculumId: curriculumId,
          trackType: trackType,
          sefariaRef: nextSefariaRef,
        );
      }
    } else if (bookmark.sefariaRef == completedSefariaRef) {
      // Bookmark is on this item, advance it
      final nextSefariaRef = await _getNextItemId(
        curriculumId: curriculumId,
        currentSefariaRef: completedSefariaRef,
      );

      if (nextSefariaRef != null) {
        await setBookmark(
          curriculumId: curriculumId,
          trackType: trackType,
          sefariaRef: nextSefariaRef,
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
      sefariaRef: firstItemId,
    );
  }

  @override
  Future<int> syncFromFirestore() async {
    // This would be called by the sync engine
    // For now, return 0 as a placeholder
    // The actual implementation will be in sync engine's _mergeBookmarks
    return 0;
  }

  /// Get the next content item sefariaRef in learning order.
  ///
  /// Respects custom learning order if it exists, otherwise uses sort_order.
  Future<String?> _getNextItemId({
    required CurriculumId curriculumId,
    required String currentSefariaRef,
  }) async {
    // Check if custom learning order exists for this curriculum
    final customOrder = await _database.learningOrderDao
        .getLearningOrderByCurriculum(curriculumId.storageKey);

    if (customOrder.isNotEmpty) {
      // Use custom learning order
      final currentIndex = customOrder.indexWhere(
        (item) => item.sefariaRef == currentSefariaRef,
      );

      if (currentIndex == -1 || currentIndex == customOrder.length - 1) {
        return null; // Current item not found or is the last item
      }

      return customOrder[currentIndex + 1].sefariaRef;
    } else {
      // Use default sort_order from ContentRepository
      final allItems = await _contentRepository.getContentForCurriculum(
        curriculumId,
      );

      // Filter to only leaf items and sort by sortOrder
      final leafItems = allItems.where((item) => item.isLeaf).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final currentIndex = leafItems.indexWhere(
        (item) => item.sefariaRef == currentSefariaRef,
      );

      if (currentIndex == -1 || currentIndex == leafItems.length - 1) {
        return null; // Current item not found or is the last item
      }

      return leafItems[currentIndex + 1].sefariaRef;
    }
  }

  /// Get the first content item sefariaRef in learning order.
  Future<String?> _getFirstItemId({required CurriculumId curriculumId}) async {
    // Check if custom learning order exists for this curriculum
    final customOrder = await _database.learningOrderDao
        .getLearningOrderByCurriculum(curriculumId.storageKey);

    if (customOrder.isNotEmpty) {
      return customOrder.first.sefariaRef;
    } else {
      // Use default sort_order from ContentRepository
      final allItems = await _contentRepository.getContentForCurriculum(
        curriculumId,
      );

      // Filter to only leaf items and sort by sortOrder
      final leafItems = allItems.where((item) => item.isLeaf).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return leafItems.isNotEmpty ? leafItems.first.sefariaRef : null;
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
      sefariaRef: bookmark.sefariaRef,
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
          trackType: remote.trackType.storageKey,
          sefariaRef: remote.sefariaRef,
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
                local.trackType.storageKey,
              ))!.id,
            ),
            curriculumId: drift.Value(remote.curriculumId.storageKey),
            trackType: drift.Value(remote.trackType.storageKey),
            sefariaRef: drift.Value(remote.sefariaRef),
            updatedAt: drift.Value(remote.updatedAt),
          ),
        );
      }
      // else: local is newer or same, keep local
    }
  }
}
