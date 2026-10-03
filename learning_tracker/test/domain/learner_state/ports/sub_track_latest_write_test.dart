// Mirror test for `lib/domain/learner_state/ports/sub_track_latest_write.dart`
// (Story 2.7 / DNI-498). The port's contract, pinned against the shared
// reference fake every concurrent-append test uses; the Firestore
// transaction implementation is covered by
// `test/data/repositories/firestore_sub_track_latest_write_test.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_latest_write.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';
import '../../../helpers/sub_tracks/latest_write_sub_track_repository.dart';

const _peah1 = NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1');

SubTrack _school({List<NodeEntry> ground = const []}) => SubTrack(
  id: ulidA,
  curriculumId: engineCurriculum,
  name: 'School',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 10,
  weeksPerYear: 39,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: ulidE,
);

void main() {
  final scope = c0Scope();
  late InMemorySubTrackRepository server;
  late LatestWriteSubTrackRepository device;

  setUp(() {
    server = InMemorySubTrackRepository()..seed(scope, [_school()]);
    device = LatestWriteSubTrackRepository(server);
  });

  test('the port is separate from SubTrackRepository, so a repository '
      'without it still compiles and is detectable by type', () {
    expect(server, isA<SubTrackRepository>());
    expect(server, isNot(isA<SubTrackLatestWrite>()));
    expect(device, isA<SubTrackLatestWrite>());
  });

  test('build sees the server row, not the device cache', () async {
    device.freezeCache(scope);
    server.seed(scope, [
      _school(ground: const [_peah1]),
    ]);
    SubTrack? seen;
    final written = await device.applyGovernedChangeToLatest(scope, ulidA, (
      latest,
    ) {
      seen = latest;
      return null;
    });
    expect(seen?.ground, const [_peah1]);
    expect(written, isNull);
  });

  test('a null build writes nothing', () async {
    await device.applyGovernedChangeToLatest(scope, ulidA, (_) => null);
    expect(server.calls, isEmpty);
    expect(server.entries, isEmpty);
  });

  test('an unknown row throws SubTrackNotFoundException', () {
    expect(
      device.applyGovernedChangeToLatest(scope, 'missing', (_) => null),
      throwsA(isA<SubTrackNotFoundException>()),
    );
  });

  test('offline it throws OnlineRequiredException and never builds', () {
    server.offline = true;
    expect(
      device.applyGovernedChangeToLatest(scope, ulidA, (_) => null),
      throwsA(isA<OnlineRequiredException>()),
    );
    expect(device.builds, 0);
  });
}
