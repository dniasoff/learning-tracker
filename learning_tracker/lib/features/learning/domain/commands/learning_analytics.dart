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
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

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

/// Low-cardinality source category required by SM-1/SM-2.
enum CaptureSourceType {
  /// Main track.
  main('main'),

  /// School-year sub-track.
  schoolYear('school_year'),

  /// Ongoing sub-track.
  ongoing('ongoing');

  const CaptureSourceType(this.storage);

  /// The analytics parameter value.
  final String storage;
}

/// Capture gesture categories used to aggregate SM-4 effort.
enum CaptureGesture {
  /// One plus-one tap.
  plusOne('plus_one'),

  /// Confirming an up-to selection.
  upTo('up_to'),

  /// A task checkbox tick.
  taskTick('task_tick');

  const CaptureGesture(this.storage);

  /// The analytics parameter value.
  final String storage;
}

/// The `action` of a `subtrack_lifecycle` event (AD-47). Story 2.1 emits
/// the four lifecycle commands; Story 2.8 (DNI-499) adds *Add next year*;
/// later stories add ground add, reorder and remove.
enum SubTrackLifecycleAction {
  /// A sub-track was created.
  create('create'),

  /// A sub-track was edited.
  edit('edit'),

  /// A sub-track was ended.
  end('end'),

  /// A sub-track was deleted (tombstoned).
  delete('delete'),

  /// A school-year sub-track was rolled into the next academic year: a
  /// create from the detail's *Add next year* (Story 2.8 / DNI-499).
  addNextYear('add_next_year');

  const SubTrackLifecycleAction(this.storage);

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

  /// A sub-track lifecycle command succeeded (AD-47 `subtrack_lifecycle`):
  /// enums and counts only — no name, ref, date or profile id.
  /// [groundEntries] is the number of ground entries after the change.
  void subTrackLifecycle({
    required String curriculumId,
    required SubTrackType type,
    required SubTrackLifecycleAction action,
    required int groundEntries,
  });

  /// AC-1 capture summary; content and identity are excluded.
  void captureSummary({
    required String curriculumId,
    required CaptureSourceType sourceType,
    required CaptureGesture gesture,
    required int eventCount,
    required int skippedCount,
    required int taps,
  });

  /// AC-2 lifecycle summary with the resulting track counts.
  void subTrackLifecycleSummary({
    required String curriculumId,
    required SubTrackType type,
    required SubTrackLifecycleAction action,
    required int groundEntries,
    required int leaves,
  });

  /// AC-3 close-window forecast comparison.
  void subTrackForecastVsActual({
    required SubTrackType type,
    required int forecast,
    required int actual,
    required int windowWeeks,
  });
}

/// The learning analytics events, each registered in `AnalyticsEvent`.
enum LearningAnalyticsEvent {
  /// `AnalyticsEvent.capture`.
  capture,

  /// `AnalyticsEvent.subTrackLifecycle`.
  subTrackLifecycle,

  /// `AnalyticsEvent.subTrackForecastVsActual`.
  subTrackForecastVsActual,
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

  @override
  void subTrackLifecycle({
    required String curriculumId,
    required SubTrackType type,
    required SubTrackLifecycleAction action,
    required int groundEntries,
  }) => sink(LearningAnalyticsEvent.subTrackLifecycle, {
    'curriculum_id': curriculumId,
    'track_type': type.storage,
    'action': action.storage,
    'ground_entries': groundEntries,
  });

  @override
  void captureSummary({
    required String curriculumId,
    required CaptureSourceType sourceType,
    required CaptureGesture gesture,
    required int eventCount,
    required int skippedCount,
    required int taps,
  }) {
    assert(eventCount >= 0 && skippedCount >= 0 && taps >= 0);
    sink(LearningAnalyticsEvent.capture, {
      'curriculum_id': curriculumId,
      'source_type': sourceType.storage,
      'gesture': gesture.storage,
      'event_count': eventCount,
      'skipped_count': skippedCount,
      'taps': taps,
    });
  }

  @override
  void subTrackLifecycleSummary({
    required String curriculumId,
    required SubTrackType type,
    required SubTrackLifecycleAction action,
    required int groundEntries,
    required int leaves,
  }) {
    assert(groundEntries >= 0 && leaves >= 0);
    sink(LearningAnalyticsEvent.subTrackLifecycle, {
      'curriculum_id': curriculumId,
      'type': type.storage,
      'action': action.storage,
      'ground_entries': groundEntries,
      'leaves': leaves,
    });
  }

  @override
  void subTrackForecastVsActual({
    required SubTrackType type,
    required int forecast,
    required int actual,
    required int windowWeeks,
  }) {
    assert(forecast >= 0 && actual >= 0 && windowWeeks >= 0);
    sink(LearningAnalyticsEvent.subTrackForecastVsActual, {
      'type': type.storage,
      'forecast': forecast,
      'actual': actual,
      'window_weeks': windowWeeks,
    });
  }
}
