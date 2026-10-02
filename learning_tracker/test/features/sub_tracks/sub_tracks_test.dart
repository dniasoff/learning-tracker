// DNI-500 — the sub-tracks barrel exposes the surfaces other features use.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';

void main() {
  test('barrel exports the Learn/Dashboard surface', () {
    expect(const AlsoLearningSection(), isA<AlsoLearningSection>());
    expect(homeSubTracksProvider, isNotNull);
    expect(subTrackViewerRoleProvider, isNotNull);
    expect(subTrackCaptureControllerProvider, isNotNull);
    expect(subTrackDisabledOpacity, 0.4);
    expect(SubTrackRowKind.values, hasLength(3));
  });
}
