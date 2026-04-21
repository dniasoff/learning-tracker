import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:test/test.dart';

void main() {
  group('TrackType', () {
    test('has correct storage key', () {
      expect(TrackType.personal.storageKey, 'personal');
    });

    test('has correct display name', () {
      expect(TrackType.personal.displayNameEn, 'Personal');
    });

    test('fromStorageKey parses valid key', () {
      expect(TrackType.fromStorageKey('personal'), TrackType.personal);
    });

    test('fromStorageKey throws on invalid key', () {
      expect(() => TrackType.fromStorageKey('invalid'), throwsArgumentError);
      expect(() => TrackType.fromStorageKey('school'), throwsArgumentError);
      expect(() => TrackType.fromStorageKey('tutor'), throwsArgumentError);
    });
  });
}
