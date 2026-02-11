import 'package:learning_tracker/core/enums/track_type.dart';

/// Exception thrown when attempting to create a duplicate completion.
///
/// This is thrown when a user tries to mark an item as complete for a
/// stage that has already been completed under any track.
class DuplicateCompletionException implements Exception {
  /// The curriculum ID where the duplicate was attempted
  final String curriculumId;

  /// The content item ID that was already completed
  final int contentItemId;

  /// The stage ID that was already completed
  final int stageId;

  /// The track under which this item+stage was originally completed
  final TrackType existingTrack;

  DuplicateCompletionException({
    required this.curriculumId,
    required this.contentItemId,
    required this.stageId,
    required this.existingTrack,
  });

  @override
  String toString() {
    return 'DuplicateCompletionException: Item $contentItemId stage $stageId '
        'in curriculum $curriculumId is already completed under '
        '${existingTrack.displayNameEn} track';
  }

  /// User-facing error message for display in snackbars/dialogs
  String get userMessage {
    return 'Already completed under ${existingTrack.displayNameEn} track';
  }
}
