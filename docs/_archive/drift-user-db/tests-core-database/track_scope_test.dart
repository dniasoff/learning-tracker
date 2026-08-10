/// Tests for [TrackScope] — DNI-338.
library;

import 'package:learning_tracker/core/database/track_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:test/test.dart';

void main() {
  group('TrackScope', () {
    test('exposes profileId, trackId, curriculumId fields', () {
      const scope = TrackScope(
        profileId: 7,
        trackId: 3,
        curriculumId: CurriculumId.mishnayos,
      );

      expect(scope.profileId, 7);
      expect(scope.trackId, 3);
      expect(scope.curriculumId, CurriculumId.mishnayos);
    });

    test('value equality (freezed) — same fields compare equal', () {
      const a = TrackScope(
        profileId: 1,
        trackId: 2,
        curriculumId: CurriculumId.mishnayos,
      );
      const b = TrackScope(
        profileId: 1,
        trackId: 2,
        curriculumId: CurriculumId.mishnayos,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('value equality — different profileId compares unequal', () {
      const a = TrackScope(
        profileId: 1,
        trackId: 2,
        curriculumId: CurriculumId.mishnayos,
      );
      const b = TrackScope(
        profileId: 2,
        trackId: 2,
        curriculumId: CurriculumId.mishnayos,
      );
      expect(a, isNot(equals(b)));
    });

    test('copyWith returns a new instance with the overridden field', () {
      const a = TrackScope(
        profileId: 1,
        trackId: 2,
        curriculumId: CurriculumId.mishnayos,
      );
      final b = a.copyWith(profileId: 99);
      expect(b.profileId, 99);
      expect(b.trackId, 2);
      expect(b.curriculumId, CurriculumId.mishnayos);
    });
  });
}
