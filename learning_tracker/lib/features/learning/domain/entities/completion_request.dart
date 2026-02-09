/// Request to mark a content item as completed.
///
/// Immutable value object containing all data needed to create a completion record.
class CompletionRequest {
  final String curriculumId;
  final int contentItemId;
  final int stageId;
  final String trackType;

  const CompletionRequest({
    required this.curriculumId,
    required this.contentItemId,
    required this.stageId,
    required this.trackType,
  });
}

/// Request to mark multiple content items as completed (bulk operation).
class BulkCompletionRequest {
  final String curriculumId;
  final List<int> contentItemIds;
  final int stageId;
  final String trackType;

  const BulkCompletionRequest({
    required this.curriculumId,
    required this.contentItemIds,
    required this.stageId,
    required this.trackType,
  });
}
