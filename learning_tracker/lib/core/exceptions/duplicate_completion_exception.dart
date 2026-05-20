import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Exception thrown when attempting to create a duplicate completion.
///
/// This is thrown when a user tries to mark an item as complete for a
/// stage that has already been completed under any track.
class DuplicateCompletionException extends ConflictException {
  /// The curriculum ID where the duplicate was attempted
  final String curriculumId;

  /// The Sefaria reference of the content item that was already completed
  final String sefariaRef;

  /// The stage ID that was already completed
  final int stageId;

  /// Display name of the track under which this item+stage was originally
  /// completed. Callers must resolve the label before constructing this
  /// exception (e.g. via the label accessors in `core/labels/`) so that
  /// this class stays import-free.
  final String existingTrackName;

  DuplicateCompletionException({
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.existingTrackName,
  }) : super(
         'Item $sefariaRef stage $stageId in curriculum $curriculumId is '
         'already completed under $existingTrackName track',
       );

  /// User-facing error message for display in snackbars/dialogs
  String get userMessage {
    return 'Already completed under $existingTrackName track';
  }
}
