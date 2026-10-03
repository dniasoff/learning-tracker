/// The learning analytics seam `LearningCommands` reports through.
///
/// DNI-469 (1.7) binds it to `AnalyticsService` and registers `capture`
/// in the catalog. Later stories add methods under the C0 contract-change
/// protocol (for example DNI-507 adds `catchupCompleted`), plus a
/// [LearningAnalyticsEvent] value and its catalog mapping.
///
/// AD-47: `LearningCommands` (and `TutorWriteService` after a successful
/// callable) emit through this one emitter; payloads carry enums
/// (including `curriculum_id`) and counts only — never a ref, profile id,
/// learner name or free text.
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

/// The learning analytics events, each registered in `AnalyticsEvent`.
enum LearningAnalyticsEvent {
  /// `AnalyticsEvent.capture`.
  capture,
}

/// Receives one event with its enum/count-only [parameters].
typedef LearningAnalyticsSink =
    void Function(LearningAnalyticsEvent event, Map<String, Object> parameters);

/// The production [LearningAnalytics]: builds each AD-47 payload from an
/// allowlist of enum and count parameters and hands it to a [sink] (bound
/// to `AnalyticsService.logEvent` in `learning_command_providers.dart`).
final class SinkLearningAnalytics implements LearningAnalytics {
  /// Creates the emitter.
  const SinkLearningAnalytics(this.sink);

  /// Where events go.
  final LearningAnalyticsSink sink;

  @override
  void capture({
    required String curriculumId,
    required CaptureSourceKind sourceKind,
    required DateState dateState,
    required int count,
  }) => sink(LearningAnalyticsEvent.capture, {
    'curriculum_id': curriculumId,
    'source_kind': sourceKind.storage,
    'date_state': dateState.storage,
    'count': count,
  });
}
