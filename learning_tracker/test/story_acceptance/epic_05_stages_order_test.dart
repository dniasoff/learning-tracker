/// Story acceptance coverage for Epic 5.
@Tags(['epic_5'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'Story 5.2 — custom learning order',
    tags: ['story_5_2'],
    skip:
        'Blocked: LearningOrderRepositoryImpl still writes through the '
        'archived Drift DAO. The Firestore learning-order adapter is not '
        'exposed through this feature seam yet.',
    () {
      test('placeholder for the pending Firestore learning-order seam', () {});
    },
  );
}
