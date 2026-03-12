import 'package:test/test.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

void main() {
  group('TrackType', () {
    test('has correct storage keys', () {
      expect(TrackType.personal.storageKey, 'personal');
      expect(TrackType.school.storageKey, 'school');
      expect(TrackType.tutor.storageKey, 'tutor');
    });

    test('has correct display names', () {
      expect(TrackType.personal.displayNameEn, 'Personal');
      expect(TrackType.school.displayNameEn, 'School');
      expect(TrackType.tutor.displayNameEn, 'Tutor');
    });

    test('fromStorageKey parses valid keys', () {
      expect(TrackType.fromStorageKey('personal'), TrackType.personal);
      expect(TrackType.fromStorageKey('school'), TrackType.school);
      expect(TrackType.fromStorageKey('tutor'), TrackType.tutor);
    });

    test('fromStorageKey throws on invalid key', () {
      expect(() => TrackType.fromStorageKey('invalid'), throwsArgumentError);
    });
  });
}
