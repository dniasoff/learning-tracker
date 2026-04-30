import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/services/track_service.dart';

void main() {
  late TrackService service;

  setUp(() {
    service = TrackService();
  });

  group('TrackService (v1 — personal only)', () {
    test('returns personal track by default for new curriculum', () async {
      final tracks = await service.getActiveTracks('mishnayos');
      expect(tracks, [TrackType.personal]);
    });

    test(
      'deactivateTrack throws when attempting to remove personal track',
      () async {
        expect(
          () => service.deactivateTrack('mishnayos', TrackType.personal),
          throwsA(isA<InvalidOperationException>()),
        );
      },
    );

    test('getAutoAssignedTrack returns personal (the only track)', () async {
      final track = await service.getAutoAssignedTrack('mishnayos');
      expect(track, TrackType.personal);
    });

    test('tracks are scoped per curriculum', () async {
      final mishnayosTracks = await service.getActiveTracks('mishnayos');
      final bavliTracks = await service.getActiveTracks('bavli');

      expect(mishnayosTracks, [TrackType.personal]);
      expect(bavliTracks, [TrackType.personal]);
    });
  });
}
