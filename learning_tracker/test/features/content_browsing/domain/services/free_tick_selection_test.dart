// Mirror test for
// `lib/features/content_browsing/domain/services/free_tick_selection.dart`
// (Story 1.11, DNI-473; UX-DR-20): which leaves a Browse tick and a "Tick up
// to here" record.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/content_browsing/domain/services/free_tick_selection.dart';

ContentItem _c(String ref, int order, List<String> path, {bool leaf = false}) =>
    ContentItem(
      curriculumId: 'mishnayos',
      level1: path[0],
      level2: path.length > 1 ? path[1] : null,
      level3: path.length > 2 ? path[2] : null,
      level4: path.length > 3 ? path[3] : null,
      displayNameHe: ref,
      displayNameEn: ref,
      sefariaRef: ref,
      sortOrder: order,
      isLeaf: leaf,
    );

/// Zeraim › Berakhot (named masechta: level2 == ref) › perakim 1, 2;
/// Zeraim › Peah › perek 1. Leaves are mishnayos.
final _items = [
  _c('Zeraim', 0, ['Zeraim']),
  _c('Berakhot', 1, ['Zeraim', 'Berakhot']),
  _c('Berakhot 1', 2, ['Zeraim', 'Berakhot', '1']),
  _c('Berakhot 1:1', 3, ['Zeraim', 'Berakhot', '1', '1'], leaf: true),
  _c('Berakhot 1:2', 4, ['Zeraim', 'Berakhot', '1', '2'], leaf: true),
  _c('Berakhot 2', 5, ['Zeraim', 'Berakhot', '2']),
  _c('Berakhot 2:1', 6, ['Zeraim', 'Berakhot', '2', '1'], leaf: true),
  _c('Berakhot 2:2', 7, ['Zeraim', 'Berakhot', '2', '2'], leaf: true),
  _c('Peah', 8, ['Zeraim', 'Peah']),
  _c('Peah 1', 9, ['Zeraim', 'Peah', '1']),
  _c('Peah 1:1', 10, ['Zeraim', 'Peah', '1', '1'], leaf: true),
  _c('Peah 1:2', 11, ['Zeraim', 'Peah', '1', '2'], leaf: true),
];

ContentItem _at(String ref) => _items.singleWhere((i) => i.sefariaRef == ref);

List<String> _refs(List<ContentItem> items) => [
  for (final i in items) i.sefariaRef,
];

void main() {
  test('leavesUnder: a node covers its leaves in corpus order; a leaf is '
      'itself', () {
    expect(_refs(leavesUnder(_items, _at('Berakhot'))), [
      'Berakhot 1:1',
      'Berakhot 1:2',
      'Berakhot 2:1',
      'Berakhot 2:2',
    ]);
    expect(_refs(leavesUnder(_items, _at('Peah 1:2'))), ['Peah 1:2']);
  });

  test('leavesUnder matches a grouped row by its path, not its ref', () {
    // groupItemsByNextLevel may stamp a row with a descendant's ref.
    final grouped = _c('Berakhot 1:1', 2, ['Zeraim', 'Berakhot', '1']);
    expect(_refs(leavesUnder(_items, grouped)), [
      'Berakhot 1:1',
      'Berakhot 1:2',
    ]);
    expect(containerOf(_items, grouped)?.sefariaRef, 'Berakhot 1');
    expect(containerOf(_items, _at('Peah 1:1')), isNull);
  });

  test('the Mishnayos unit is the masechta (depth 2)', () {
    expect(unitDepthOf(CurriculumId.mishnayos, _items), 2);
  });

  group('leavesUpToHere', () {
    test('a mishna and every earlier one of its masechta, inclusive, in '
        'corpus order', () {
      expect(_refs(leavesUpToHere(_items, _at('Berakhot 2:1'), unitDepth: 2)), [
        'Berakhot 1:1',
        'Berakhot 1:2',
        'Berakhot 2:1',
      ]);
    });

    test('never crosses into the previous masechta', () {
      expect(_refs(leavesUpToHere(_items, _at('Peah 1:1'), unitDepth: 2)), [
        'Peah 1:1',
      ]);
    });

    test('on a perek: through the end of that perek', () {
      expect(_refs(leavesUpToHere(_items, _at('Berakhot 1'), unitDepth: 2)), [
        'Berakhot 1:1',
        'Berakhot 1:2',
      ]);
    });
  });

  test('triStateOf: empty, partial, complete', () {
    final leaves = leavesUnder(_items, _at('Berakhot 1'));
    expect(triStateOf(leaves, (_) => false), TriState.empty);
    expect(triStateOf(leaves, (r) => r == 'Berakhot 1:1'), TriState.partial);
    expect(triStateOf(leaves, (_) => true), TriState.complete);
    expect(triStateOf(const [], (_) => true), TriState.empty);
  });
}
