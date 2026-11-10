// Story 2.10 (DNI-501): independent row selection and explicit range fill.
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
    test('starts with no selected rows and identifies the next position', () {
      final selection = _sel([_a, _b, _c]);
      expect(selection.target, isNull);
      expect(selection.statusOf(0), UpToRowStatus.nextUp);
      expect(selection.statusOf(1), UpToRowStatus.notSelected);
      expect(selection.count, 0);
      expect(selection.includedRefs, isEmpty);
    });

    test('tapping a later row selects only that row', () {
      final selection = _sel([_a, _b, _c, _d]).tick(2);
      expect(selection.includedRefs, [_c]);
      expect(selection.count, 1);
      expect(selection.statusOf(0), UpToRowStatus.nextUp);
      expect(selection.statusOf(2), UpToRowStatus.included);
      expect(selection.positionAfterRecord, _a);
    });

    test('non-contiguous selections preserve the exact refs and count', () {
      final selection = _sel([_a, _b, _c, _d, _e]).tick(0).tick(4);
      expect(selection.includedRefs, [_a, _e]);
      expect(selection.count, 2);
      expect(selection.positionAfterRecord, _b);
    });

    test('a second tap toggles only the row tapped', () {
      final selection = _sel([_a, _b, _c]).tick(2).tick(2);
      expect(selection.includedRefs, isEmpty);
      expect(selection.statusOf(0), UpToRowStatus.nextUp);
      expect(selection.positionAfterRecord, _a);
    });

    test(
      'explicit range fill includes every selectable row through target',
      () {
        final selection = _sel([_a, _b, _c, _d]).tickAllUpTo(2);
        expect(selection.includedRefs, [_a, _b, _c]);
        expect(selection.count, 3);
        expect(selection.statusOf(3), UpToRowStatus.notSelected);
      },
    );

    test('range fill preserves selected rows after its target', () {
      final selection = _sel([_a, _b, _c, _d, _e]).tick(4).tickAllUpTo(2);
      expect(selection.includedRefs, [_a, _b, _c, _e]);
    });

    test('untick and re-tick update the live count', () {
      final selection = _sel([_a, _b, _c]).tickAllUpTo(2).toggle(1);
      expect(selection.statusOf(1), UpToRowStatus.skipped);
      expect(selection.count, 2);
      expect(selection.includedRefs, [_a, _c]);
      expect(selection.positionAfterRecord, _b);
      expect(selection.toggle(1).statusOf(1), UpToRowStatus.included);
    });

    test('already-recorded rows are unchanged by taps and range fill', () {
      final selection = _sel([_a, _b, _c, _d], recorded: {_b, _d});
      expect(selection.isSelectable(1), isFalse);
      expect(selection.tick(1), same(selection));
      final filled = selection.tickAllUpTo(2);
      expect(filled.statusOf(1), UpToRowStatus.alreadyRecorded);
      expect(filled.toggle(1), same(filled));
      expect(filled.includedRefs, [_a, _c]);
      expect(filled.positionAfterRecord, isNull);
      expect(selection.statusOf(3), UpToRowStatus.alreadyRecorded);
    });

    test('exhausted means no selectable rows remain', () {
      expect(_sel(const []).isExhausted, isTrue);
      expect(_sel([_a], recorded: {_a}).isExhausted, isTrue);
      expect(_sel([_a]).isExhausted, isFalse);
    });

    test('invalid indexes are rejected', () {
      final selection = _sel([_a]);
      expect(selection.tickAllUpTo(-1), same(selection));
      expect(selection.tickAllUpTo(5), same(selection));
      expect(selection.toggle(-1), same(selection));
      expect(selection.toggle(5), same(selection));
    });
  });
}
