// Mirror test for
// `lib/features/learning/domain/commands/learning_analytics.dart`
// (C0 DNI-524; DNI-469 AC-8: the `capture` event is catalogued and
// privacy-bounded).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
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
}
