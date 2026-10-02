/// The learning analytics seam `LearningCommands` reports through.
///
/// DNI-469 (1.7) binds it to `AnalyticsService` and registers `capture`
/// in the catalog. Later stories add methods under the C0 contract-change
/// protocol (for example DNI-507 adds `catchupCompleted`).
library;

import 'package:learning_tracker/domain/learner_state/learning_event.dart';

/// Where a capture came from.
enum CaptureSourceKind {
  /// The main track.
  main('main'),

  /// A sub-track.
  subTrack('sub_track');

  const CaptureSourceKind(this.storage);

  /// The analytics parameter value.
  final String storage;
}

/// Reports learning analytics.
abstract interface class LearningAnalytics {
  /// [count] leaves were captured for [curriculumId].
  void capture({
    required String curriculumId,
    required CaptureSourceKind sourceKind,
    required DateState dateState,
    required int count,
  });
}
