/// Story acceptance coverage for profile isolation.
@Tags(['epic_27', 'story_27_7'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'Story 27.7 — isolation and canonical layout',
    tags: ['story_27_7'],
    skip:
        'Blocked: this suite asserts CompletionDao/TrackDao query methods '
        'directly. A Firestore-native fixture can seed documents, but the '
        'production query surface is still the archived Drift DAO and has no '
        'adapter equivalent in scope.',
    () {
      test('placeholder for the pending Firestore isolation seam', () {});
    },
  );
}
