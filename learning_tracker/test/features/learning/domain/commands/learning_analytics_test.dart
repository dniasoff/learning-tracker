// Mirror test for
// `lib/features/learning/domain/commands/learning_analytics.dart`
// (C0 DNI-524; DNI-469 AC-8: the `capture` event is catalogued and
// privacy-bounded).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';
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
    expect(sent.single.$1, LearningAnalyticsEvent.capture);
    expect(sent.single.$2, {
      'curriculum_id': 'mishnayos',
      'source_type': 'school_year',
      'gesture': 'up_to',
      'event_count': 4,
      'skipped_count': 1,
      'taps': 3,
    });
    expect(sent.single.$2.keys.toSet(), {
      'curriculum_id',
      'source_type',
      'gesture',
      'event_count',
      'skipped_count',
      'taps',
    });
    expect(sent.single.$2['source_type'], 'school_year');
    expect(sent.single.$2['gesture'], 'up_to');
    expect(sent.single.$2['event_count'], isA<int>());
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
    expect(sent.map((e) => e.$1), [
      LearningAnalyticsEvent.subTrackLifecycle,
      LearningAnalyticsEvent.subTrackForecastVsActual,
    ]);
    expect(sent.map((e) => e.$2).toList(), [
      {
        'curriculum_id': 'mishnayos',
        'type': 'ongoing',
        'action': 'end',
        'ground_entries': 2,
        'leaves': 15,
      },
      {'type': 'ongoing', 'forecast': 12, 'actual': 9, 'window_weeks': 8},
    ]);
    for (final (_, parameters) in sent) {
      expect(
        parameters.keys,
        everyElement(
          isNot(
            anyOf(
              contains('profile'),
              contains('ref'),
              contains('name'),
              contains('date'),
            ),
          ),
        ),
      );
      for (final value in parameters.values) {
        expect(value, anyOf(isA<int>(), isA<String>()));
      }
    }
  });

  test('forecast comparison is registered in the AnalyticsEvent catalog', () {
    expect(
      AnalyticsEvent.subTrackForecastVsActual,
      'subtrack_forecast_vs_actual',
    );
  });

  group('DNI-506 AC-9: catchup_completed', () {
    test('carries exactly the six enum, count and flag parameters', () {
      final sent = <(LearningAnalyticsEvent, Map<String, Object>)>[];
      SinkLearningAnalytics((e, p) => sent.add((e, p))).catchupCompleted(
        curriculumId: 'mishnayos',
        mode: CatchUpMode.all,
        lockedDaysOffered: 3,
        lockedDaysRecorded: 2,
        eventCount: 7,
        withinWindow: true,
      );
      final (event, params) = sent.single;
      expect(event, LearningAnalyticsEvent.catchupCompleted);
      expect(params, {
        'curriculum_id': 'mishnayos',
        'mode': 'all',
        'locked_days_offered': 3,
        'locked_days_recorded': 2,
        'event_count': 7,
        'within_window': true,
      });
      for (final value in params.values) {
        expect(value is int || value is bool || value is String, isTrue);
      }
    });

    test('mode storage values and catalog registration', () {
      expect(CatchUpMode.all.storage, 'all');
      expect(CatchUpMode.adjusted.storage, 'adjusted');
      expect(AnalyticsEvent.catchupCompleted, 'catchup_completed');
    });
  });
}
