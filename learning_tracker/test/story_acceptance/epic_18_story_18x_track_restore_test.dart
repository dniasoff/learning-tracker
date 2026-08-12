/// Story acceptance coverage for Epic 18x — track restore.
@Tags(['epic_18', 'story_18x'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'Story 18x — restoreOrCreate',
    tags: ['story_18x'],
    skip:
        'Blocked: restoreOrCreate is still a Drift TrackDao operation. The '
        'Firestore curriculum-track repository has no equivalent restore '
        'contract that can be exercised without changing production code.',
    () {
      test('placeholder for the pending Firestore restore contract', () {});
    },
  );
}
