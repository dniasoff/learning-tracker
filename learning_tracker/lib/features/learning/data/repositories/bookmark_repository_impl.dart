import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [BookmarkRepository] using Drift database and sync engine.
///
/// Scoped to a single profile so bookmarks on the same curriculum+track
/// are independent across profiles on the account.
///
/// Schema v1 (DNI-322): Bookmarks now reference curriculumTracks by trackId
/// (integer FK) rather than trackType (TEXT). The [_resolveTrackId] helper
/// looks up the track row when only a TrackType enum is available.
class BookmarkRepositoryImpl implements BookmarkRepository {
  final UserDatabase _database;
  final SyncEngine? _syncEngine;
  final ContentRepository _contentRepository;
  final int _profileId;

  BookmarkRepositoryImpl({
    required UserDatabase database,
    required SyncEngine? syncEngine,
    required ContentRepository contentRepository,
    int profileId = 0,
  }) : _database = database,
       _syncEngine = syncEngine,
       _contentRepository = contentRepository,
       _profileId = profileId;

  /// Resolve the integer track ID for a (curriculumId, trackType) pair
  /// scoped to [_profileId]. Returns null if no matching track exists.
  Future<int?> _resolveTrackId(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    final tracks = await _database.trackDao.getActiveTracks(curriculumId);
    final match = tracks
        .where(
          (t) =>
              t.trackType == trackType.storageKey &&
              t.profileId == _profileId,
        )
        .firstOrNull;
    return match?.id;
  }

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
  }) async {
    final trackId = await _resolveTrackId(curriculumId, trackType);
    if (trackId == null) return null;

    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumTrackAndProfile(
          curriculumId.storageKey,
          trackId,
          _profileId,
        );

    if (bookmark == null) return null;

    return _bookmarkFromDb(bookmark, trackType);
  }

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
    required String sefariaRef,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps

    final trackId = await _resolveTrackId(curriculumId, trackType);
    if (trackId == null) {
      throw StateError(
        'No active track found for $curriculumId / $trackType / profile $_profileId',
      );
    }

    final existing = await _database.bookmarkDao
        .getBookmarkByCurriculumTrackAndProfile(
          curriculumId.storageKey,
          trackId,
          _profileId,
        );

    final BookmarkEntity bookmark;

    if (existing != null) {
      await _database.bookmarkDao.updateBookmark(
        BookmarksCompanion(
          id: drift.Value(existing.id),
          profileId: drift.Value(_profileId),
          curriculumId: drift.Value(curriculumId.storageKey),
          trackId: drift.Value(trackId),
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
      await _database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: _profileId,
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
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

    // Offline-first: never block UI on remote bookmark push.
    unawaited(_syncBookmark(bookmark));

    return bookmark;
  }

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
    required String completedSefariaRef,
  }) async {
    final trackId = await _resolveTrackId(curriculumId, trackType);
    if (trackId == null) return;

    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumTrackAndProfile(
          curriculumId.storageKey,
          trackId,
          _profileId,
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
    final remoteBookmarks =
        await _syncEngine?.fetchBookmarksFromFirestore() ?? [];
    for (final remote in remoteBookmarks) {
      await mergeRemoteBookmark(remote);
    }
    return remoteBookmarks.length;
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
    await _syncEngine?.pushBookmark(bookmark.toFirestore());
  }

  /// Convert database model to domain entity.
  ///
  /// Since the Bookmark row no longer stores trackType as text, the caller
  /// must supply the [TrackType] that was used to look up the bookmark.
  BookmarkEntity _bookmarkFromDb(Bookmark bookmark, TrackType trackType) {
    return BookmarkEntity(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == bookmark.curriculumId,
        orElse: () => throw ArgumentError(
          'Unknown curriculumId: ${bookmark.curriculumId}',
        ),
      ),
      trackType: trackType,
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
      // No local bookmark for this profile — need to resolve trackId first.
      final trackId = await _resolveTrackId(
        remote.curriculumId,
        remote.trackType,
      );
      if (trackId == null) return; // Track not yet set up for this profile

      await _database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: _profileId,
          curriculumId: remote.curriculumId.storageKey,
          trackId: trackId,
          sefariaRef: remote.sefariaRef,
          updatedAt: remote.updatedAt,
        ),
      );
    } else {
      if (remote.updatedAt.isAfter(local.updatedAt)) {
        final trackId = await _resolveTrackId(
          remote.curriculumId,
          remote.trackType,
        );
        if (trackId == null) return;

        await _database.bookmarkDao.upsertBookmarkByProfile(
          profileId: _profileId,
          curriculumId: remote.curriculumId.storageKey,
          trackId: trackId,
          sefariaRef: remote.sefariaRef,
          updatedAt: remote.updatedAt,
        );
      }
    }
  }
}
