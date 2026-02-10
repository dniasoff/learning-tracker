/// Request to mark a content item as completed.
///
/// Immutable value object containing all data needed to create a completion record.
class CompletionRequest {
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;

  const CompletionRequest({
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
  });
}

/// Request to mark multiple content items as completed (bulk operation).
class BulkCompletionRequest {
  final String curriculumId;
  final List<String> sefariaRefs;
  final int stageId;
  final String trackType;

  const BulkCompletionRequest({
    required this.curriculumId,
    required this.sefariaRefs,
    required this.stageId,
    required this.trackType,
  });
}
