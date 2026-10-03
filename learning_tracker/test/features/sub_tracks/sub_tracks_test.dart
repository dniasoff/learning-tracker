// DNI-500 / Story 2.10 (DNI-501): the sub-tracks feature barrel is the surface other
// features (Learn, Browse, history, scheduler) build on; each export is the
// declaring file's own symbol, not a copy.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart'
    as services;
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart'
    as capture;
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart'
    as picker;
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/up_to_picker.dart'
    as widgets;
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart' as barrel;

void main() {
  test('barrel exports the Learn/Dashboard surface (DNI-500)', () {
    expect(
      const barrel.AlsoLearningSection(),
      isA<barrel.AlsoLearningSection>(),
    );
    expect(barrel.homeSubTracksProvider, isNotNull);
    expect(barrel.subTrackViewerRoleProvider, isNotNull);
    expect(barrel.subTrackCaptureControllerProvider, isNotNull);
    expect(barrel.subTrackDisabledOpacity, 0.4);
    expect(barrel.SubTrackRowKind.values, hasLength(3));
  });

  test('capture providers are re-exported, not redeclared', () {
    expect(
      identical(
        barrel.pendingCapturesProvider,
        capture.pendingCapturesProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        barrel.activePendingRefsProvider,
        capture.activePendingRefsProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        barrel.subTrackSourceChoicesProvider,
        capture.subTrackSourceChoicesProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        barrel.subTrackWritesAllowedProvider,
        capture.subTrackWritesAllowedProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        barrel.mainTrackCaptureAllowedProvider,
        capture.mainTrackCaptureAllowedProvider,
      ),
      isTrue,
    );
    expect(identical(barrel.captureLeaves, capture.captureLeaves), isTrue);
  });

  test('the picker entry points are re-exported, not redeclared', () {
    expect(
      identical(barrel.onHomeSubTracksProvider, picker.onHomeSubTracksProvider),
      isTrue,
    );
    expect(identical(barrel.showUpToPicker, widgets.showUpToPicker), isTrue);
    expect(
      identical(barrel.openUpToAndRecord, widgets.openUpToAndRecord),
      isTrue,
    );
    expect(identical(barrel.onHomeSubTracks, services.onHomeSubTracks), isTrue);
  });

  test('the request types are the picker providers\' own', () {
    expect(barrel.SubTrackUpToRequest, picker.SubTrackUpToRequest);
    expect(barrel.MainTrackUpToRequest, picker.MainTrackUpToRequest);
    expect(barrel.UpToRequest, picker.UpToRequest);
    expect(barrel.SubTrackSourceChoice, capture.SubTrackSourceChoice);
    expect(barrel.UpToActionButton, widgets.UpToActionButton);
  });
}
