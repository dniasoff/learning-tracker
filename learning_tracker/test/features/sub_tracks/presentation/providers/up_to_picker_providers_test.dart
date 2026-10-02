// Story 2.10 (DNI-501) T1: the picker's lazy data adapter over the engine
// state and the complete sub-track read.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/up_to_selection_service.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

SubTrack _sub(
  int id,
  String name, {
  String start = '2026-09-01',
  bool ended = false,
  String curriculumId = engineCurriculum,
}) => SubTrack(
  id: engineUlid(id),
  curriculumId: curriculumId,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: start,
  ratePerWeek: 2,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [berakhot],
  lastChangeId: engineUlid(id + 1),
  endedAt: ended ? engineAt(1) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

SubTrackState _state(int id, {bool onHome = true, String? position}) =>
    SubTrackState(
      subTrackId: engineUlid(id),
      holdsGround: true,
      inForecast: true,
      onHome: onHome,
      position: position ?? 'Mishnah Berakhot 1:1',
      remainingPath: [position ?? 'Mishnah Berakhot 1:1'],
    );

void main() {
  final rebbe = _sub(20, 'Rebbe');
  final school = _sub(10, 'School');
  final future = _sub(30, 'Camp', start: '2027-01-01');
  final ended = _sub(40, 'Old', ended: true);

  LearnerState state() => fakeLearnerState(
    curricula: {
      engineCurriculum: FakeCurriculumState(
        curriculumId: engineCurriculum,
        schedulableRefs: const ['Mishnah Peah 1:1'],
        mainTrackPosition: 'Mishnah Peah 1:1',
        subTracks: {
          rebbe.id: _state(20),
          school.id: _state(10),
          future.id: _state(30, onHome: false),
          ended.id: _state(40),
        },
      ),
    },
  );

  ProviderContainer container({
    required InMemorySubTrackRepository repo,
    LearnerState? learner,
  }) {
    final c = ProviderContainer(
      overrides: [
        ...learnerStateOverrides(scope: c0Scope(), state: learner),
        subTrackRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('onHome sub-tracks in hub order; future, ended and other '
      'curricula left out', () async {
    final repo = InMemorySubTrackRepository()
      ..seed(c0Scope(), [rebbe, school, future, ended]);
    final c = container(repo: repo, learner: state());
    final rows = await settledAsync(c, onHomeSubTracksProvider);
    expect(
      [for (final r in rows.requireValue) r.track.name],
      ['Rebbe', 'School'],
    );
  });

  test('no sub-tracks: empty without consulting the engine', () async {
    final c = container(repo: InMemorySubTrackRepository());
    final rows = await settledAsync(c, onHomeSubTracksProvider);
    expect(rows.requireValue, isEmpty);
  });

  test('a read with rejected rows is an error, never the valid rows '
      'alone', () async {
    final repo = InMemorySubTrackRepository()
      ..seed(c0Scope(), [school])
      ..seedRejected(c0Scope(), [const RejectedRow('bad', 'x')]);
    final c = container(repo: repo, learner: state());
    final rows = await settledAsync(c, onHomeSubTracksProvider);
    expect(rows.error, isA<SubTrackReadRejectedException>());
  });

  test('the engine stub error is forwarded to the picker (AC-7)', () async {
    final repo = InMemorySubTrackRepository()..seed(c0Scope(), [school]);
    final c = container(repo: repo);
    final slice = await settledAsync(
      c,
      upToSliceProvider(
        SubTrackUpToRequest(
          subTrackId: school.id,
          curriculumId: engineCurriculum,
          name: 'School',
        ),
      ),
    );
    expect(slice.hasError, isTrue);
  });

  test('sub-track and main-track slices come from the engine state', () async {
    final c = container(repo: InMemorySubTrackRepository(), learner: state());
    final sub = await settledAsync(
      c,
      upToSliceProvider(
        SubTrackUpToRequest(
          subTrackId: school.id,
          curriculumId: engineCurriculum,
          name: 'School',
        ),
      ),
    );
    expect(sub.requireValue.source, school.id);
    expect(sub.requireValue.availability, UpToAvailability.ready);
    final main = await settledAsync(
      c,
      upToSliceProvider(
        MainTrackUpToRequest(
          curriculumId: engineCurriculum,
          name: 'Mishnayos',
          leadRefs: const ['Mishnah Peah 1:1'],
          stage: 1,
        ),
      ),
    );
    expect(
      [for (final r in main.requireValue.rows) r.ref],
      ['Mishnah Peah 1:1'],
    );
  });

  test('an unknown sub-track or curriculum is an error', () async {
    final c = container(repo: InMemorySubTrackRepository(), learner: state());
    final missing = await settledAsync(
      c,
      upToSliceProvider(
        const SubTrackUpToRequest(
          subTrackId: '01ARZ3NDEKTSV4RRFFQ69G5ZZZ',
          curriculumId: engineCurriculum,
          name: 'X',
        ),
      ),
    );
    expect(missing.error, isA<UpToUnavailableException>());
    final other = await settledAsync(
      c,
      upToSliceProvider(
        MainTrackUpToRequest(
          curriculumId: 'bavli',
          name: 'Bavli',
          leadRefs: const [],
        ),
      ),
    );
    expect(other.error, isA<UpToUnavailableException>());
  });

  test('requests are value-equal (family keys)', () {
    expect(
      MainTrackUpToRequest(
        curriculumId: 'm',
        name: 'n',
        leadRefs: const ['a'],
        stage: 1,
      ),
      MainTrackUpToRequest(
        curriculumId: 'm',
        name: 'n',
        leadRefs: const ['a'],
        stage: 1,
      ),
    );
  });
}
