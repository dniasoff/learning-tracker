/// Story 2.1 (DNI-492) T1: the curriculum-scoped sub-track views over the
/// complete read (`watchByCurriculum`, `watchActiveByCurriculum`,
/// `watchEndedByCurriculum`).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';

SubTrack _track(String id, String curriculumId, {bool ended = false}) =>
    SubTrack(
      id: id,
      curriculumId: curriculumId,
      name: 'Track $id',
      type: SubTrackType.ongoing,
      windowStart: '2026-09-01',
      ratePerWeek: 5,
      weeksPerYear: 40,
      learnsOnShabbos: false,
      ground: const [NodeEntry(level: 'masechta', ref: 'Berakhot')],
      lastChangeId: ulidE,
      endedAt: ended ? t1 : null,
      endReason: ended ? SubTrackEndReason.ended : null,
    );

List<String> _ids(CompleteRead<SubTrack> read) => switch (read) {
  CompleteReadReady(:final items) => [for (final t in items) t.id],
  CompleteReadLoading() => const ['<loading>'],
};

void main() {
  late InMemorySubTrackRepository repo;
  final scope = c0Scope();

  setUp(() {
    repo = InMemorySubTrackRepository()
      ..seed(scope, [
        _track(ulidA, 'shas'),
        _track(ulidB, 'shas', ended: true),
        _track(ulidC, 'mishnayos'),
      ]);
  });

  tearDown(() => repo.dispose());

  test('watchByCurriculum keeps loading first, then live and ended rows', () {
    expect(
      repo.watchByCurriculum(scope, 'shas').map(_ids),
      emitsInOrder([
        ['<loading>'],
        [ulidA, ulidB],
      ]),
    );
  });

  test('watchActiveByCurriculum excludes tombstones and other curricula', () {
    expect(
      repo.watchActiveByCurriculum(scope, 'shas').map(_ids),
      emitsInOrder([
        ['<loading>'],
        [ulidA],
      ]),
    );
  });

  test('watchEndedByCurriculum yields only tombstoned rows', () {
    expect(
      repo.watchEndedByCurriculum(scope, 'shas').map(_ids),
      emitsInOrder([
        ['<loading>'],
        [ulidB],
      ]),
    );
    expect(
      repo.watchEndedByCurriculum(scope, 'mishnayos').map(_ids),
      emitsInOrder([
        ['<loading>'],
        <String>[],
      ]),
    );
  });

  test('a change re-emits the filtered view', () async {
    final views = repo
        .watchActiveByCurriculum(scope, 'mishnayos')
        .map(_ids)
        .take(3)
        .toList();
    await Future<void>.delayed(Duration.zero);
    repo.seed(scope, [_track(ulidD, 'mishnayos')]);
    expect(await views, [
      ['<loading>'],
      [ulidC],
      [ulidC, ulidD],
    ]);
  });

  test('rejected rows are carried through every view', () async {
    final source = _RejectingRepository();
    final read = await source
        .watchActiveByCurriculum(scope, 'shas')
        .firstWhere((r) => r is CompleteReadReady<SubTrack>);
    final ready = read as CompleteReadReady<SubTrack>;
    expect(ready.items.map((t) => t.id), [ulidA]);
    expect(ready.rejected, const [RejectedRow(ulidD, 'bad')]);
  });
}

final class _RejectingRepository implements SubTrackRepository {
  @override
  Stream<CompleteRead<SubTrack>> watchAll(_) => Stream.fromIterable([
    const CompleteReadLoading(),
    CompleteReadReady(
      [_track(ulidA, 'shas'), _track(ulidC, 'mishnayos')],
      rejected: const [RejectedRow(ulidD, 'bad')],
    ),
  ]);

  @override
  Future<void> applyGovernedChange(_, _) => throw UnimplementedError();
}
