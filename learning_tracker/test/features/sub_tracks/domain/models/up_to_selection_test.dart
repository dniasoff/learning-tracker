// Story 2.10 (DNI-501) AC-2 / AC-3 unit: the Up to… run selection —
// boundaries, non-contiguous adjustments and already-recorded barriers.
// The engine slices it is built from: domain/services/
// up_to_selection_service_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/up_to_selection.dart';

const _a = 'Mishnah Berakhot 1:3';
const _b = 'Mishnah Berakhot 1:4';
const _c = 'Mishnah Berakhot 1:5';
const _d = 'Mishnah Berakhot 2:1';
const _e = 'Mishnah Berakhot 2:2';

UpToSelection _sel(List<String> refs, {Set<String> recorded = const {}}) =>
    UpToSelection([
      for (final r in refs) UpToRow(r, recorded: recorded.contains(r)),
    ]);

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
}
