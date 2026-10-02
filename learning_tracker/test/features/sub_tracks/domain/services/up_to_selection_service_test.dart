// Story 2.10 (DNI-501) AC-5 / AC-6 unit: the picker rows sliced from the
// engine's sub-track and main-track state.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/up_to_selection.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/up_to_selection_service.dart';

import '../../../../helpers/learner_state/fake_learner_state.dart';

const _a = 'Mishnah Berakhot 1:3';
const _b = 'Mishnah Berakhot 1:4';
const _c = 'Mishnah Berakhot 1:5';
const _d = 'Mishnah Berakhot 2:1';
const _e = 'Mishnah Berakhot 2:2';
const _f = 'Mishnah Berakhot 2:3';

SubTrackState _sub({
  String? position,
  List<String> path = const [],
  Set<String> recordedAhead = const {},
  bool exhausted = false,
}) => SubTrackState(
  subTrackId: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
  holdsGround: true,
  inForecast: true,
  onHome: true,
  position: position,
  groundExhausted: exhausted,
  remainingPath: path,
  recordedAhead: recordedAhead,
);

void main() {
  group('subTrackUpToSlice', () {
    test('rows are the remaining path from the position, recorded-ahead '
        'leaves marked recorded', () {
      final slice = subTrackUpToSlice(
        curriculumId: 'mishnayos',
        state: _sub(position: _a, path: [_a, _b, _c, _d], recordedAhead: {_c}),
      );
      expect(slice.source, '01ARZ3NDEKTSV4RRFFQ69G5FAV');
      expect(slice.rows, [
        const UpToRow(_a),
        const UpToRow(_b),
        const UpToRow(_c, recorded: true),
        const UpToRow(_d),
      ]);
      expect(slice.availability, UpToAvailability.ready);
    });

    test('pending captures read as recorded and move the position', () {
      final state = _sub(position: _a, path: [_a, _b, _c]);
      final slice = subTrackUpToSlice(
        curriculumId: 'mishnayos',
        state: state,
        pending: {_a, _c},
      );
      expect(slice.rows, [
        const UpToRow(_b),
        const UpToRow(_c, recorded: true),
      ]);
      expect(displayedSubTrackPosition(state, pending: {_a}), _b);
      expect(displayedSubTrackPosition(state, pending: {_a, _b, _c}), isNull);
    });

    test('AC-6: a groundless sub-track never opens the picker', () {
      final slice = subTrackUpToSlice(curriculumId: 'mishnayos', state: _sub());
      expect(slice.availability, UpToAvailability.groundless);
      expect(isGroundless(_sub()), isTrue);
    });

    test('AC-6: an exhausted sub-track has no rows', () {
      final slice = subTrackUpToSlice(
        curriculumId: 'mishnayos',
        state: _sub(exhausted: true),
      );
      expect(slice.rows, isEmpty);
      expect(slice.availability, UpToAvailability.exhausted);
    });
  });

  group('mainTrackUpToSlice', () {
    FakeCurriculumState main({
      List<String> schedulable = const [],
      String? position,
    }) => FakeCurriculumState(
      curriculumId: 'mishnayos',
      schedulableRefs: schedulable,
      mainTrackPosition: position,
    );

    test('AC-5: schedulableRefs from the main position, led by today\'s '
        'new-learning tasks', () {
      final slice = mainTrackUpToSlice(
        state: main(schedulable: [_a, _b, _c, _d, _e, _f], position: _a),
        leadRefs: [_a, _b],
      );
      expect(slice.source, LearningEvent.sourceMain);
      expect([for (final r in slice.rows) r.ref], [_a, _b, _c, _d, _e, _f]);
      expect(slice.rows.every((r) => !r.recorded), isTrue);
    });

    test('a lead ref out of order leads; one not schedulable is dropped', () {
      final slice = mainTrackUpToSlice(
        state: main(schedulable: [_a, _b, _c], position: _a),
        leadRefs: [_c, 'Mishnah Peah 1:1'],
      );
      expect([for (final r in slice.rows) r.ref], [_c, _a, _b]);
    });

    test('pending main captures are left out', () {
      final slice = mainTrackUpToSlice(
        state: main(schedulable: [_a, _b, _c], position: _a),
        pending: {_a},
      );
      expect([for (final r in slice.rows) r.ref], [_b, _c]);
    });

    test('nothing schedulable: exhausted', () {
      final slice = mainTrackUpToSlice(state: main());
      expect(slice.availability, UpToAvailability.exhausted);
    });
  });
}
