// Regression test for AUD-core-content-03: ContentTree.fromCurricula must
// sort each accumulated child list exactly once, AFTER the outer
// `for (final entry in byCurriculum.entries)` loop finishes — not once per
// curriculum iteration inside it.
// See: docs/audits/standards-audit-2026-07-03/delivery/findings/AUD-core-content-03.json
//
// BUG LOG:
//   - RED (pre-fix): the "Sort each child list by sortOrder" block sat
//     INSIDE the curriculum loop, re-sorting the map's full accumulated
//     value set on every iteration. A curriculum processed early (e.g. the
//     first of several) had its already-sorted child list re-sorted again
//     for every curriculum processed afterwards, while a curriculum
//     processed last was only ever sorted once. Two curricula with
//     identically-shaped single-level leaf lists therefore produced
//     DIFFERENT `sortOrder`-getter access counts depending solely on
//     iteration position — proving redundant work, not just extra cycles
//     spent on already-correct output (the final order was always right,
//     which is why the pre-existing ordering assertions in
//     epic_25_schema_core_test.dart passed both before and after this fix).
//   - GREEN (post-fix): the sort loop runs once, after the curriculum loop,
//     so every curriculum's child list is sorted exactly once regardless of
//     its position in `byCurriculum.entries` — the two counts are equal.
//
// Technique: wrap each fixture's ContentItems in a subclass that increments
// a per-curriculum counter on every `sortOrder` getter access (the exact
// property the sort's comparator reads). This observes the number of times
// each curriculum's child list was handed to `List.sort` from OUTSIDE
// ContentTree, via its public `fromCurricula` factory — no production code
// is modified or instrumented for the test. It intentionally does not
// assert an exact comparator-call count (that is a Dart SDK sort-algorithm
// implementation detail); it only asserts the two equally-shaped lists are
// treated identically, which is exactly what "sort once, after the loop"
// guarantees and "sort once per remaining iteration" violates.

@Tags(['content'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Counts every read of [ContentTree]'s only entry point into fixture data:
/// the `sortOrder` getter the child-list sort comparator reads.
class _AccessCounter {
  int value = 0;
}

/// A [ContentItem] whose `sortOrder` getter reports every access to an
/// [_AccessCounter] before delegating to the real field. Constructed only
/// by tests, via ContentTree's public `fromCurricula` API — production code
/// is unaware of this class and unmodified by it.
///
/// Implements (rather than extends) [ContentItem]: since AUD-core-network-01
/// made ContentItem `@freezed` (factory-constructors only, no generative
/// constructor to `super(...)` into), `extends` is no longer possible —
/// `implements` needs no super-constructor call, so it still works and
/// preserves the exact same observation technique (instrumenting the one
/// getter the sort comparator reads) with zero change to what's asserted.
class _CountingContentItem implements ContentItem {
  _CountingContentItem({
    required String curriculumId,
    required String level1,
    required String displayNameHe,
    required String displayNameEn,
    required String sefariaRef,
    required int sortOrder,
    required bool isLeaf,
    required _AccessCounter counter,
  }) : _inner = ContentItem(
         curriculumId: curriculumId,
         level1: level1,
         displayNameHe: displayNameHe,
         displayNameEn: displayNameEn,
         sefariaRef: sefariaRef,
         sortOrder: sortOrder,
         isLeaf: isLeaf,
       ),
       _counter = counter;

  final ContentItem _inner;
  final _AccessCounter _counter;

  @override
  int get sortOrder {
    _counter.value++;
    return _inner.sortOrder;
  }

  @override
  String get curriculumId => _inner.curriculumId;
  @override
  String get level1 => _inner.level1;
  @override
  String? get level2 => _inner.level2;
  @override
  String? get level3 => _inner.level3;
  @override
  String? get level4 => _inner.level4;
  @override
  String get displayNameHe => _inner.displayNameHe;
  @override
  String get displayNameEn => _inner.displayNameEn;
  @override
  String get sefariaRef => _inner.sefariaRef;
  @override
  bool get isLeaf => _inner.isLeaf;

  @override
  $ContentItemCopyWith<ContentItem> get copyWith => _inner.copyWith;
}

/// Builds [count] top-level leaves (level1 only, so they all land under the
/// single root child-list key for [curriculumId] — no nested containers) in
/// deliberately reversed `sortOrder` so a genuine sort has work to do, each
/// instrumented to increment [counter] on every `sortOrder` read.
List<ContentItem> _countedLeaves({
  required String curriculumId,
  required int count,
  required _AccessCounter counter,
}) => [
  for (var i = count - 1; i >= 0; i--)
    _CountingContentItem(
      curriculumId: curriculumId,
      level1: 'Root',
      displayNameHe: '',
      displayNameEn: '$curriculumId leaf $i',
      sefariaRef: '$curriculumId leaf $i',
      sortOrder: i,
      isLeaf: true,
      counter: counter,
    ),
];

void main() {
  group('ContentTree.fromCurricula sort hoist (AUD-core-content-03)', () {
    test('a curriculum processed first is sorted exactly as many times as '
        'one processed last (equal-sized lists get equal sortOrder-getter '
        'access counts)', () {
      final firstCounter = _AccessCounter();
      final lastCounter = _AccessCounter();

      // Insertion order is iteration order for `byCurriculum.entries`
      // (LinkedHashMap): mishnayos is processed FIRST, bavli LAST.
      final byCurriculum = {
        CurriculumId.mishnayos: _countedLeaves(
          curriculumId: 'mishnayos',
          count: 4,
          counter: firstCounter,
        ),
        CurriculumId.bavli: _countedLeaves(
          curriculumId: 'bavli',
          count: 4,
          counter: lastCounter,
        ),
      };

      final tree = ContentTree.fromCurricula(byCurriculum);

      // Snapshot the counts immediately — before any further test-side
      // reads of `.sortOrder` (below) inflate both counters equally.
      final firstCountAfterBuild = firstCounter.value;
      final lastCountAfterBuild = lastCounter.value;

      // The regression: mishnayos (processed first) must be sorted the
      // SAME number of times as bavli (processed last). Before the fix,
      // the sort loop re-ran once per remaining curriculum iteration, so
      // mishnayos — sorted once when processed, then RE-sorted when the
      // outer loop reached bavli — accrued strictly more sortOrder reads
      // than bavli, which was only ever sorted once (nothing follows it).
      expect(
        firstCountAfterBuild,
        equals(lastCountAfterBuild),
        reason:
            'mishnayos (processed first) and bavli (processed last) hold '
            'equal-sized child lists; a single post-loop sort pass must '
            'touch sortOrder the same number of times for both. A higher '
            'count for the first-processed curriculum means its list was '
            'sorted more than once — the redundant per-iteration resort '
            'this finding reports.',
      );

      // Sanity: both lists actually made it into the tree, correctly
      // sorted — the bug never affected final output, only redundant work.
      final mishnayosChildren = tree.children(CurriculumId.mishnayos, []);
      final bavliChildren = tree.children(CurriculumId.bavli, []);
      expect(mishnayosChildren, hasLength(4));
      expect(bavliChildren, hasLength(4));
      expect(
        mishnayosChildren.map((i) => i.sortOrder).toList(),
        equals([0, 1, 2, 3]),
      );
      expect(
        bavliChildren.map((i) => i.sortOrder).toList(),
        equals([0, 1, 2, 3]),
      );
    });
  });
}
