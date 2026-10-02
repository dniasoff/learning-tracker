// Story 2.10 (DNI-501) AC-2 / AC-3 / AC-5 / AC-6 unit: the Up to… run
// selection and the engine slices it is built from.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/up_to_selection.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/up_to_selection_service.dart';

import '../../../helpers/learner_state/fake_learner_state.dart';

const _a = 'Mishnah Berakhot 1:3';
const _b = 'Mishnah Berakhot 1:4';
const _c = 'Mishnah Berakhot 1:5';
const _d = 'Mishnah Berakhot 2:1';
const _e = 'Mishnah Berakhot 2:2';
const _f = 'Mishnah Berakhot 2:3';

UpToSelection _sel(List<String> refs, {Set<String> recorded = const {}}) =>
    UpToSelection([
      for (final r in refs) UpToRow(r, recorded: recorded.contains(r)),
    ]);

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
  group('UpToSelection', () {
    test('before a target the first row is next up and nothing is '
        'included', () {
      final s = _sel([_a, _b, _c]);
      expect(s.target, isNull);
      expect(s.statusOf(0), UpToRowStatus.nextUp);
      expect(s.statusOf(1), UpToRowStatus.notSelected);
      expect(s.count, 0);
      expect(s.includedRefs, isEmpty);
    });

    test('a target includes every row from the position through it', () {
      final s = _sel([_a, _b, _c, _d]).selectTarget(2);
      expect(s.includedRefs, [_a, _b, _c]);
      expect(s.count, 3);
      expect(s.statusOf(3), UpToRowStatus.notSelected);
    });

    test('first-position target records only the position', () {
      final s = _sel([_a, _b]).selectTarget(0);
      expect(s.includedRefs, [_a]);
      expect(s.positionAfterRecord, _b);
    });

    test('final-ground target records through the end; no position is '
        'left', () {
      final s = _sel([_a, _b, _c]).selectTarget(2);
      expect(s.count, 3);
      expect(s.positionAfterRecord, isNull);
    });

    test('untick and re-tick inside the run update the live count', () {
      var s = _sel([_a, _b, _c, _d, _e]).selectTarget(4);
      expect(s.count, 5);
      s = s.toggle(3);
      expect(s.statusOf(3), UpToRowStatus.skipped);
      expect(s.count, 4);
      expect(s.includedRefs, [_a, _b, _c, _e]);
      expect(s.positionAfterRecord, _d);
      s = s.toggle(3);
      expect(s.statusOf(3), UpToRowStatus.included);
      expect(s.count, 5);
    });

    test('non-contiguous skips: the position becomes the first unticked '
        'leaf', () {
      final s = _sel([_a, _b, _c, _d]).selectTarget(3).toggle(0).toggle(2);
      expect(s.includedRefs, [_b, _d]);
      expect(s.positionAfterRecord, _a);
    });

    test('all-skipped: count 0, nothing to record', () {
      final s = _sel([_a, _b]).selectTarget(1).toggle(0).toggle(1);
      expect(s.count, 0);
      expect(s.includedRefs, isEmpty);
      expect(s.positionAfterRecord, _a);
    });

    test('a toggle outside the run is rejected; tick outside the run '
        'extends it', () {
      final s = _sel([_a, _b, _c]).selectTarget(0);
      expect(s.toggle(2), same(s));
      final extended = s.tick(2);
      expect(extended.target, 2);
      expect(extended.count, 3);
      expect(extended.tick(1).statusOf(1), UpToRowStatus.skipped);
    });

    test('moving the target back drops skips past it', () {
      final s = _sel([_a, _b, _c, _d]).selectTarget(3).toggle(3).toggle(1);
      final back = s.selectTarget(2);
      expect(back.skipped, {1});
      expect(back.includedRefs, [_a, _c]);
    });

    test('already-recorded rows are barriers: never selectable, never '
        'included, never written twice', () {
      final s = _sel([_a, _b, _c, _d], recorded: {_b, _d});
      expect(s.isSelectable(1), isFalse);
      expect(s.selectTarget(1), same(s));
      final run = s.selectTarget(2);
      expect(run.statusOf(1), UpToRowStatus.alreadyRecorded);
      expect(run.toggle(1), same(run));
      expect(run.includedRefs, [_a, _c]);
      expect(run.positionAfterRecord, isNull);
      expect(s.statusOf(3), UpToRowStatus.alreadyRecorded);
    });

    test('every row recorded or none: exhausted', () {
      expect(_sel(const []).isExhausted, isTrue);
      expect(_sel([_a], recorded: {_a}).isExhausted, isTrue);
      expect(_sel([_a]).isExhausted, isFalse);
    });

    test('out-of-range indexes are rejected', () {
      final s = _sel([_a]);
      expect(s.selectTarget(-1), same(s));
      expect(s.selectTarget(5), same(s));
    });
  });

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
