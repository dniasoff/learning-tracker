/// Story acceptance coverage for bulk prior marking.
@Tags(['epic_27', 'story_27_5'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'Story 27.5 — bulk prior completions',
    skip:
        'Blocked: BulkPriorCompletionService and streak assertions still '
        'depend on Drift completion_events/streak_events DAOs. The Firestore '
        'writer exists, but no production bulk-mark read/write seam is wired '
        'for this acceptance flow.',
    () {
      test('placeholder for the pending Firestore bulk-mark seam', () {});
    },
  );
}
