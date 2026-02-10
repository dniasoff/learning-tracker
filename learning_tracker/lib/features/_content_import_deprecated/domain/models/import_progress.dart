import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_progress.freezed.dart';

/// Import progress state for curriculum content import.
@freezed
class ImportProgress with _$ImportProgress {
  const factory ImportProgress.idle() = _Idle;

  const factory ImportProgress.fetching({required String curriculumId}) =
      _Fetching;

  const factory ImportProgress.parsing({
    required String curriculumId,
    required int itemsFetched,
  }) = _Parsing;

  const factory ImportProgress.storing({
    required String curriculumId,
    required int totalItems,
    required int storedItems,
  }) = _Storing;

  const factory ImportProgress.completed({
    required String curriculumId,
    required int totalItems,
  }) = _Completed;

  const factory ImportProgress.error({
    required String curriculumId,
    required String message,
    String? errorCode,
  }) = _Error;

  const factory ImportProgress.cancelled({required String curriculumId}) =
      _Cancelled;
}
