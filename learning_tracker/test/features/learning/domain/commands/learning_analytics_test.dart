// Mirror test for
// `lib/features/learning/domain/commands/learning_analytics.dart`
// (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';

void main() {
  test('CaptureSourceKind storage values', () {
    expect(CaptureSourceKind.main.storage, 'main');
    expect(CaptureSourceKind.subTrack.storage, 'sub_track');
  });
}
