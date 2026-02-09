import 'package:freezed_annotation/freezed_annotation.dart';

part 'completion_request.freezed.dart';

/// Request to mark a content item as completed.
///
/// Immutable value object containing all data needed to create a completion record.
@freezed
class CompletionRequest with _$CompletionRequest {
  const factory CompletionRequest({
    required String curriculumId,
    required int contentItemId,
    required int stageId,
    required String trackType,
  }) = _CompletionRequest;
}

/// Request to mark multiple content items as completed (bulk operation).
@freezed
class BulkCompletionRequest with _$BulkCompletionRequest {
  const factory BulkCompletionRequest({
    required String curriculumId,
    required List<int> contentItemIds,
    required int stageId,
    required String trackType,
  }) = _BulkCompletionRequest;
}
