import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/services/track_service.dart';

void main() {
  late TrackService service;

  setUp(() {
    service = TrackService();
  });

  group('TrackService', () {
    test('returns personal track by default for new curriculum', () async {
      final tracks = await service.getActiveTracks('mishnayos');
      expect(tracks, [TrackType.personal]);
    });

    test('activateTrack adds track to active tracks', () async {
      await service.activateTrack('mishnayos', TrackType.school);
      final tracks = await service.getActiveTracks('mishnayos');
      expect(tracks, containsAll([TrackType.personal, TrackType.school]));
    });

    test('deactivateTrack removes track from active tracks', () async {
      await service.activateTrack('mishnayos', TrackType.school);
      await service.activateTrack('mishnayos', TrackType.tutor);
      await service.deactivateTrack('mishnayos', TrackType.school);

      final tracks = await service.getActiveTracks('mishnayos');
      expect(tracks, containsAll([TrackType.personal, TrackType.tutor]));
      expect(tracks, isNot(contains(TrackType.school)));
    });

    test('deactivateTrack throws when attempting to remove personal track', () async {
      expect(
        () => service.deactivateTrack('mishnayos', TrackType.personal),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('getAutoAssignedTrack returns personal when only one track active', () async {
      final track = await service.getAutoAssignedTrack('mishnayos');
      expect(track, TrackType.personal);
    });

    test('getAutoAssignedTrack returns null when multiple tracks active', () async {
      await service.activateTrack('mishnayos', TrackType.school);
      final track = await service.getAutoAssignedTrack('mishnayos');
      expect(track, isNull);
    });

    test('tracks are scoped per curriculum', () async {
      await service.activateTrack('mishnayos', TrackType.school);
      await service.activateTrack('bavli', TrackType.tutor);

      final mishnayosTracks = await service.getActiveTracks('mishnayos');
      final bavliTracks = await service.getActiveTracks('bavli');

      expect(mishnayosTracks, containsAll([TrackType.personal, TrackType.school]));
      expect(bavliTracks, containsAll([TrackType.personal, TrackType.tutor]));
      expect(mishnayosTracks, isNot(contains(TrackType.tutor)));
      expect(bavliTracks, isNot(contains(TrackType.school)));
    });
  });
}
