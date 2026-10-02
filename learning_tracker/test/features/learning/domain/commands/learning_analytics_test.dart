// Mirror test for
// `lib/features/learning/domain/commands/learning_analytics.dart`
// (C0 DNI-524; DNI-469 AC-8: the `capture` event is catalogued and
// privacy-bounded).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';

void main() {
  test('CaptureSourceKind storage values', () {
    expect(CaptureSourceKind.main.storage, 'main');
    expect(CaptureSourceKind.subTrack.storage, 'sub_track');
  });

  test('capture carries exactly the enum and count parameters', () {
    final sent = <(LearningAnalyticsEvent, Map<String, Object>)>[];
    SinkLearningAnalytics((e, p) => sent.add((e, p))).capture(
      curriculumId: 'mishnayos',
      sourceKind: CaptureSourceKind.subTrack,
      dateState: DateState.catchUp,
      count: 3,
    );
    final (event, params) = sent.single;
    expect(event, LearningAnalyticsEvent.capture);
    expect(params, {
      'curriculum_id': 'mishnayos',
      'source_kind': 'sub_track',
      'date_state': 'catch_up',
      'count': 3,
    });
  });

  test('capture is registered in the AnalyticsEvent catalog', () {
    expect(AnalyticsEvent.capture, 'capture');
  });

  test('DNI-503 capture summary is enum and count only', () {
    final sent = <(LearningAnalyticsEvent, Map<String, Object>)>[];
    SinkLearningAnalytics((e, p) => sent.add((e, p))).captureSummary(
      curriculumId: 'mishnayos',
      sourceType: CaptureSourceType.schoolYear,
      dateState: DateState.dated,
      gesture: CaptureGesture.upTo,
      eventCount: 4,
      skippedCount: 1,
      taps: 3,
    );
    expect(sent.single, (
      LearningAnalyticsEvent.capture,
      {
        'curriculum_id': 'mishnayos',
        'source_type': 'school_year',
        'gesture': 'up_to',
        'event_count': 4,
        'skipped_count': 1,
        'taps': 3,
      },
    ));
  });

  test('lifecycle summary and forecast have no content identifiers', () {
    final sent = <(LearningAnalyticsEvent, Map<String, Object>)>[];
    final emitter = SinkLearningAnalytics((e, p) => sent.add((e, p)));
    emitter.subTrackLifecycleSummary(
      curriculumId: 'mishnayos',
      type: SubTrackType.ongoing,
      action: SubTrackLifecycleAction.end,
      groundEntries: 2,
      leaves: 15,
    );
    emitter.subTrackForecastVsActual(
      type: SubTrackType.ongoing,
      forecast: 12,
      actual: 9,
      windowWeeks: 8,
    );
    expect(sent, [
      (
        LearningAnalyticsEvent.subTrackLifecycle,
        {
          'curriculum_id': 'mishnayos',
          'type': 'ongoing',
          'action': 'end',
          'ground_entries': 2,
          'leaves': 15,
        },
      ),
      (
        LearningAnalyticsEvent.subTrackForecastVsActual,
        {'type': 'ongoing', 'forecast': 12, 'actual': 9, 'window_weeks': 8},
      ),
    ]);
  });

  test('forecast comparison is registered in the AnalyticsEvent catalog', () {
    expect(
      AnalyticsEvent.subTrackForecastVsActual,
      'subtrack_forecast_vs_actual',
    );
  });
}
