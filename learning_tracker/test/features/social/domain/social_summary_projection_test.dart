import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/social/domain/social_summary_projection.dart';

void main() {
  test('uses the learner civil Sunday as the week boundary', () {
    final payload = socialSummaryPayload(
      LearnerState.empty(DateTime.utc(2026, 11, 10)),
    );

    expect(payload['weekly_learning'], {
      'week_start': '2026-11-08',
      'by_curriculum': <Map<String, Object?>>[],
      'overall': {'limudim': 0, 'chazaros': 0},
    });
  });

  test('Sunday remains the current week start without a timezone shift', () {
    final payload = socialSummaryPayload(
      LearnerState.empty(DateTime.utc(2026, 11, 8, 23, 59)),
    );

    expect((payload['weekly_learning'] as Map)['week_start'], '2026-11-08');
    expect(payload.keys.toSet(), {
      'streak',
      'current_tracks',
      'weekly_learning',
      'siyumim',
    });
  });

  test('projects the canonical overall streak and weekly totals', () {
    final payload = socialSummaryPayload(
      LearnerState(
        nowUtc: DateTime.utc(2026, 11, 10),
        curricula: const {},
        overallStreak: const CurriculumStreak(
          current: 5,
          best: 11,
          lastDay: '2026-11-10',
        ),
      ),
    );

    expect((payload['streak'] as Map)['overall'], {
      'current_days': 5,
      'best_days': 11,
    });
    expect((payload['weekly_learning'] as Map)['overall'], {
      'limudim': 0,
      'chazaros': 0,
    });
  });
}
