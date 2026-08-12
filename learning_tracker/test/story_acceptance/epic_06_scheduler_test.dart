/// Story acceptance coverage for Epic 6.
@Tags(['epic_6'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'Story 6 — scheduler',
    tags: ['story_6_1', 'story_6_2', 'story_6_3', 'story_6_4'],
    skip:
        'Blocked: SchedulerEngine and its completion/stage/order repository '
        'implementations still require Drift DAOs. The Firestore scheduler '
        'adapters are not wired into an acceptance-test construction seam.',
    () {
      test('placeholder for the pending Firestore scheduler seam', () {});
    },
  );
}
