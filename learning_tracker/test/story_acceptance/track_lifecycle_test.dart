/// Track-lifecycle acceptance tests. The pure-projection overdue group is
/// deleted with the legacy projection (DNI-477, AD-49); the planner on
/// LearnerState is covered by daily_task_projection_service_test.dart.
@Tags(['track_lifecycle'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'B–E — persisted track lifecycle',
    tags: ['track_lifecycle'],
    skip:
        'Blocked: delete/restore, daily-plan cache, aggregate-count, and multi-profile isolation tests directly call Drift TrackDao/CompletionDao/DailyPlanDao. Firestore track/ledger repositories do not expose these aggregate lifecycle contracts yet.',
    () {
      test('placeholder for the pending Firestore track-lifecycle seam', () {});
    },
  );
}
