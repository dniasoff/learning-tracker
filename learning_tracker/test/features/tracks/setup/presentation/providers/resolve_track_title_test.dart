// Unit test — resolveTrackTitle (track_management_providers.dart)
//
// Finding 4 (B-EDIT-NAME): the user-entered track name (stored in
// Goal.description) must win over the curriculum label; a blank / whitespace /
// null custom name falls back to the curriculum label.

@Tags(['tracks'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';

void main() {
  group('resolveTrackTitle', () {
    test('non-blank custom name wins over the curriculum fallback', () {
      expect(
        resolveTrackTitle(
          customName: 'My Shas Journey',
          curriculumFallback: 'Mishnayos',
        ),
        'My Shas Journey',
      );
    });

    test('null custom name falls back to the curriculum label', () {
      expect(
        resolveTrackTitle(customName: null, curriculumFallback: 'Mishnayos'),
        'Mishnayos',
      );
    });

    test('empty custom name falls back to the curriculum label', () {
      expect(
        resolveTrackTitle(customName: '', curriculumFallback: 'Chumash'),
        'Chumash',
      );
    });

    test('whitespace-only custom name falls back to the curriculum label', () {
      expect(
        resolveTrackTitle(customName: '   ', curriculumFallback: 'Bavli'),
        'Bavli',
      );
    });

    test('custom name is trimmed when surfaced', () {
      expect(
        resolveTrackTitle(
          customName: '  Daily Daf  ',
          curriculumFallback: 'Bavli',
        ),
        'Daily Daf',
      );
    });
  });
}
