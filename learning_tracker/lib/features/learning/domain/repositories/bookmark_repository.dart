import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';

/// Repository interface for bookmark operations.
///
/// Defines the contract for managing user bookmarks (current position
/// in each curriculum/track combination).
abstract class BookmarkRepository {
  /// Get the bookmark for a specific curriculum and track.
  ///
  /// Returns null if no bookmark exists yet.
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
  });

  /// Create or update a bookmark to point to a specific content item.
  ///
  /// This is used for manual bookmark jumps. It does NOT create completion
  /// records - it only updates the pointer.
  ///
  /// If a bookmark already exists for this curriculum/track, it will be updated.
  /// Otherwise, a new bookmark will be created.
  ///
  /// Syncs to Firestore automatically.
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
    required int contentItemId,
  });

  /// Advance the bookmark to the next item in learning order.
  ///
  /// This is called automatically after marking a completion. It:
  /// - Follows custom learning_order if it exists for this curriculum
  /// - Otherwise follows natural sort_order from content_items table
  /// - Does nothing if bookmark is already on a different item
  /// - Does nothing if the completed item is the last item
  ///
  /// Only advances if the bookmark is currently on the completed item.
  /// Syncs to Firestore automatically.
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
    required int completedItemId,
  });

  /// Initialize bookmark for a new curriculum/track combination.
  ///
  /// Points the bookmark to the first item in learning order.
  /// Called when a user starts a new curriculum or track for the first time.
  ///
  /// Syncs to Firestore automatically.
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
  });

  /// Sync bookmarks with Firestore (pull remote updates).
  ///
  /// Performs conflict resolution using last-write-wins strategy based on
  /// updatedAt timestamps (P5: UTC timestamps).
  ///
  /// Returns the number of bookmarks updated from remote.
  Future<int> syncFromFirestore();
}
