/// Story acceptance coverage for Epic 8.
@Tags(['epic_8'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'Story 8 — gamification persistence',
    tags: ['story_8_1', 'story_8_2'],
    skip:
        'Blocked: the acceptance services still construct against Drift '
        'tables/DAOs. Firestore points and streak repositories exist, but '
        'the production service wiring required by this story is not exposed '
        'as a Firestore-native test seam.',
    () {
      test('placeholder for the pending Firestore gamification seam', () {});
    },
  );
}
