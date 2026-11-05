// Mirror test for `lib/core/content/content_index_corpus.dart` (DNI-465:
// the production Corpus adapter over ContentIndex hierarchy data).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

ContentItem _item(
  int sortOrder,
  String ref, {
  required String level1,
  String? level2,
  String? level3,
  bool isLeaf = false,
  String curriculumId = 'c',
}) => ContentItem(
  curriculumId: curriculumId,
  level1: level1,
  level2: level2,
  level3: level3,
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: isLeaf,
);

/// The bundled hierarchy of [curriculumId] (ContentIndex source data).
Corpus _bundled(String curriculumId) {
  final file = File('assets/content/hierarchy/$curriculumId.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final config = json['hierarchyConfig']! as Map<String, Object?>;
  final items = [
    for (final raw in json['items']! as List<Object?>)
      if (raw case final Map<String, Object?> m)
        ContentItem(
          curriculumId: m['curriculumId']! as String,
          level1: m['level1']! as String,
          level2: m['level2'] as String?,
          level3: m['level3'] as String?,
          level4: m['level4'] as String?,
          displayNameHe: m['displayNameHe']! as String,
          displayNameEn: m['displayNameEn']! as String,
          sefariaRef: m['sefariaRef']! as String,
          sortOrder: m['sortOrder']! as int,
          isLeaf: m['isLeaf']! as bool,
        ),
  ];
  return contentIndexCorpus(
    curriculumId: curriculumId,
    items: items,
    levelLabels: (config['levelLabels']! as List<Object?>).cast<String>(),
  );
}

void main() {
  const labels = ['Seder', 'Masechta', 'Chapter'];

  test('builds the tree in sortOrder with lower-cased label levels', () {
    final corpus = contentIndexCorpus(
      curriculumId: 'c',
      levelLabels: labels,
      items: [
        _item(3, 'B 1', level1: 'S', level2: 'B', level3: '1', isLeaf: true),
        _item(0, 'S', level1: 'S'),
        _item(1, 'A', level1: 'S', level2: 'A'),
        _item(2, 'A 1', level1: 'S', level2: 'A', level3: '1', isLeaf: true),
        _item(2, 'B', level1: 'S', level2: 'B'),
        _item(9, 'X', level1: 'S', curriculumId: 'other'),
      ],
    );
    const seder = NodeEntry(level: 'seder', ref: 'S');
    expect(corpus.roots, [seder]);
    expect(corpus.childrenOf(seder), const [
      NodeEntry(level: 'masechta', ref: 'A'),
      NodeEntry(level: 'masechta', ref: 'B'),
    ]);
    expect(corpus.leaves, ['A 1', 'B 1']);
    expect(
      corpus.nodeForRef('A 1'),
      const NodeEntry(level: 'chapter', ref: 'A 1'),
    );
    expect(corpus.unitLevels, ['seder', 'masechta']);
  });

  test('a skipped level nests under the matching ancestor', () {
    final corpus = contentIndexCorpus(
      curriculumId: 'c',
      levelLabels: labels,
      items: [
        _item(0, 'S', level1: 'S'),
        _item(1, 'A', level1: 'S', level2: 'A'),
        _item(2, 'A 1', level1: 'S', level2: 'A', level3: '1', isLeaf: true),
        _item(3, 'S 9', level1: 'S', level3: '9', isLeaf: true),
      ],
    );
    expect(
      corpus.parentOf(const NodeEntry(level: 'chapter', ref: 'S 9')),
      const NodeEntry(level: 'seder', ref: 'S'),
    );
  });

  test('duplicate refs keep the first subtree; empty containers drop', () {
    final corpus = contentIndexCorpus(
      curriculumId: 'c',
      levelLabels: labels,
      items: [
        _item(0, 'S', level1: 'S'),
        _item(1, 'A', level1: 'S', level2: 'A'),
        _item(2, 'A 1', level1: 'S', level2: 'A', level3: '1', isLeaf: true),
        _item(3, 'T', level1: 'T'),
        _item(4, 'A', level1: 'T', level2: 'A2'),
        _item(5, 'A 1', level1: 'T', level2: 'A2', level3: '1', isLeaf: true),
        _item(6, 'E', level1: 'E'),
      ],
    );
    expect(corpus.leaves, ['A 1']);
    expect(corpus.roots, const [NodeEntry(level: 'seder', ref: 'S')]);
  });

  test('positional depth-2 values are not unit levels', () {
    final corpus = contentIndexCorpus(
      curriculumId: 'c',
      levelLabels: const ['Sefer', 'Chapter', 'Verse'],
      items: [
        _item(0, 'Genesis', level1: 'Genesis'),
        _item(1, 'Genesis 1', level1: 'Genesis', level2: '1'),
        _item(
          2,
          'Genesis 1:1',
          level1: 'Genesis',
          level2: '1',
          level3: '1',
          isLeaf: true,
        ),
      ],
    );
    expect(corpus.unitLevels, ['sefer']);
  });

  test('levels deeper than the labels are named level<depth>', () {
    expect(contentLevelName(const ['Book'], 3), 'level3');
    expect(contentLevelName(const ['Book'], 1), 'book');
  });

  group('Story 1.11 (DNI-473) capture helpers', () {
    ContentItem item(String ref, int order, List<String> path, bool leaf) =>
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
    final items = [
      item('Seder Zeraim', 0, ['Zeraim'], false),
      item('Mishnah Berakhot', 1, ['Zeraim', 'Mishnah Berakhot'], false),
      item('Mishnah Berakhot 1', 2, ['Zeraim', 'Mishnah Berakhot', '1'], false),
      item('Mishnah Berakhot 1:1', 3, [
        'Zeraim',
        'Mishnah Berakhot',
        '1',
        '1',
      ], true),
    ];

    test('contentDepthOf is the deepest non-null level', () {
      expect(items.map(contentDepthOf), [1, 2, 3, 4]);
    });

    test('nodeEntryOf names a container exactly as corpusOf does, so a '
        'before_tracking node event expands to its leaves', () {
      final corpus = corpusOf(CurriculumId.mishnayos, items);
      for (final container in items.where((i) => !i.isLeaf)) {
        final entry = nodeEntryOf(CurriculumId.mishnayos, container);
        expect(corpus.nodeForRef(container.sefariaRef), entry);
        expect(corpus.leavesUnder(entry), ['Mishnah Berakhot 1:1']);
      }
      expect(corpus.unitLevels, hasLength(2), reason: 'seder and masechta');
    });
  });

  group('bundled hierarchies', () {
    test('Mishnayos: seder and masechta are the units', () {
      final corpus = _bundled('mishnayos');
      expect(corpus.unitLevels, ['seder', 'masechta']);
      const berakhot = NodeEntry(level: 'masechta', ref: 'Mishnah Berakhot');
      expect(corpus.parentOf(berakhot)?.level, 'seder');
      expect(corpus.leavesUnder(berakhot).first, 'Mishnah Berakhot 1:1');
      expect(
        corpus.nodeForRef('Mishnah Berakhot 1:1'),
        const NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:1'),
      );
    });

    test('other curricula resolve their equivalents from metadata', () {
      expect(_bundled('bavli').unitLevels, ['seder', 'masechta']);
      expect(_bundled('yerushalmi').unitLevels, ['seder', 'masechta']);
      expect(_bundled('nach').unitLevels, ['section', 'sefer']);
      expect(_bundled('mishneh_torah').unitLevels, ['sefer', 'hilchot']);
      expect(_bundled('chumash').unitLevels, ['sefer']);
      expect(_bundled('mishna_berurah').unitLevels, ['book']);
    });
  });
}
