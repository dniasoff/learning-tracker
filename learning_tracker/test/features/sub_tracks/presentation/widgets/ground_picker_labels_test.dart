// Mirror test for
// `lib/features/sub_tracks/presentation/widgets/ground_picker_labels.dart`
// and `lib/features/sub_tracks/presentation/providers/ground_picker_content.dart`
// (Story 2.7 / DNI-498 AC-2, `prd-deviations` #12): node names come from
// the sub-track curriculum's own ContentIndex rows, matched by `{level,
// ref}` node identity, and level units from the curriculum's hierarchy
// metadata, with safe fallbacks for unknown nodes and levels.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_picker_content.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_labels.dart';

import '../../../../helpers/learner_state/chumash_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

GroundPickerLabels _labels(
  Corpus corpus, {
  CurriculumId? curriculum,
  GroundLevelLabels? levels,
  List<ContentItem> items = const [],
  bool useHebrew = false,
}) => GroundPickerLabels(
  content: GroundPickerContent.of(
    corpus: corpus,
    items: items,
    levels: levels ?? curriculumLevelLabels(curriculum),
  ),
  useHebrew: useHebrew,
  variant: TransliterationVariant.ashkenazi,
);

ContentItem _item(
  String curriculumId,
  List<String> path,
  String ref,
  int order, {
  String? en,
  String? he,
  bool leaf = false,
}) => ContentItem(
  curriculumId: curriculumId,
  level1: path[0],
  level2: path.length > 1 ? path[1] : null,
  level3: path.length > 2 ? path[2] : null,
  level4: path.length > 3 ? path[3] : null,
  displayNameHe: he ?? ref,
  displayNameEn: en ?? ref,
  sefariaRef: ref,
  sortOrder: order,
  isLeaf: leaf,
);

/// A Mussar slice through the production ContentIndex adapter: Tanya is
/// four levels deep (Sefer, Part, Perek, Pasuk) and Mesillat Yesharim three
/// (Sefer, Perek, Pasuk), so the adapter's level keys repeat (`pasuk` at
/// depths 3 and 4) and Tanya's depth-2 key `perek` names a Part.
List<ContentItem> _mussarItems() {
  const c = 'mussar';
  var o = 0;
  return [
    _item(c, ['Tanya'], 'Tanya', o++),
    _item(c, ['Tanya', 'Part I'], 'Tanya, Part I', o++),
    _item(c, ['Tanya', 'Part I', '1'], 'Tanya, Part I 1', o++),
    _item(
      c,
      ['Tanya', 'Part I', '1', '1'],
      'Tanya, Part I 1:1',
      o++,
      leaf: true,
    ),
    _item(
      c,
      ['Tanya', 'Part I', '1', '2'],
      'Tanya, Part I 1:2',
      o++,
      leaf: true,
    ),
    _item(c, ['Mesillat Yesharim'], 'Mesillat Yesharim', o++),
    _item(c, ['Mesillat Yesharim', '1'], 'Mesillat Yesharim 1', o++),
    _item(
      c,
      ['Mesillat Yesharim', '1', '1'],
      'Mesillat Yesharim 1:1',
      o++,
      leaf: true,
    ),
  ];
}

void main() {
  group('level units come from hierarchy metadata', () {
    test('Mishnayos levels by depth', () {
      final labels = _labels(
        mishnayosCorpus(),
        curriculum: CurriculumId.mishnayos,
      );
      expect(labels.unitOf(zeraim, 3), 'Sedarim');
      expect(labels.unitOf(berakhot, 1), 'Masechta');
      expect(labels.unitOf(berakhot, 2), 'Masechtos');
      // The fixture's `chapter` key is depth 3 of Mishnayos: Perek.
      expect(labels.unitOf(berakhot1, 1), 'Perek');
      expect(labels.unitOf(berakhot1, 9), 'Perakim');
    });

    test('Chumash levels, in English and Hebrew', () {
      final labels = _labels(chumashCorpus(), curriculum: CurriculumId.chumash);
      expect(labels.unitOf(genesis1, 2), 'Perakim');
      expect(labels.unitOf(verse('Genesis 1:1'), 3), 'Pesukim');
      final hebrew = _labels(
        chumashCorpus(),
        curriculum: CurriculumId.chumash,
        useHebrew: true,
      );
      expect(hebrew.unitOf(genesis, 2), 'חומשים');
    });

    test('a book-specific level structure uses its own labels', () {
      final items = _mussarItems();
      final corpus = corpusOf(CurriculumId.mussar, items);
      final labels = _labels(
        corpus,
        curriculum: CurriculumId.mussar,
        items: items,
      );
      NodeEntry node(String ref) => nodeEntryOf(
        CurriculumId.mussar,
        items.firstWhere((i) => i.sefariaRef == ref),
      );
      // Tanya: Part at depth 2 and Perek at depth 3 (per-book overrides),
      // although the adapter keys them `perek` and `pasuk`.
      expect(node('Tanya, Part I').level, 'perek');
      expect(labels.unitOf(node('Tanya, Part I'), 2), 'Parts');
      expect(node('Tanya, Part I 1').level, 'pasuk');
      expect(labels.unitOf(node('Tanya, Part I 1'), 2), 'Perakim');
      expect(labels.unitOf(node('Tanya, Part I 1:1'), 2), 'Pesukim');
      // Mesillat Yesharim keeps the curriculum defaults.
      expect(labels.unitOf(node('Mesillat Yesharim 1'), 2), 'Perakim');
      expect(labels.unitOf(node('Mesillat Yesharim 1:1'), 2), 'Pesukim');
    });

    test('a curriculum with custom levels uses its injected metadata', () {
      const gate = LevelLabels(
        en: 'Gate',
        enPlural: 'Gates',
        he: 'שער',
        hePlural: 'שערים',
        valueKind: LevelValueKind.named,
        prefixLabelInDisplay: false,
      );
      const line = LevelLabels(
        en: 'Line',
        enPlural: 'Lines',
        he: 'שורה',
        hePlural: 'שורות',
        valueKind: LevelValueKind.ordinal,
        prefixLabelInDisplay: true,
      );
      const top = NodeEntry(level: 'x1', ref: 'Gate A');
      const leaf = NodeEntry(level: 'x2', ref: 'Gate A 1');
      final corpus = InMemoryCorpus('custom', [
        const CorpusNode(top, [CorpusNode(leaf)]),
      ]);
      final labels = _labels(
        corpus,
        levels: (depth, _) => switch (depth) {
          1 => gate,
          2 => line,
          _ => null,
        },
      );
      expect(labels.unitOf(top, 2), 'Gates');
      expect(labels.unitOf(leaf, 1), 'Line');
    });

    test('a node or level the metadata does not name keeps its raw key', () {
      expect(_labels(mishnayosCorpus()).unitOf(berakhot, 2), 'masechta');
      expect(
        _labels(
          mishnayosCorpus(),
          curriculum: CurriculumId.mishnayos,
        ).unitOf(const NodeEntry(level: 'odd', ref: 'Nowhere'), 1),
        'odd',
      );
      // Deeper than the curriculum names: Chumash has three levels.
      const deep = NodeEntry(level: 'level4', ref: 'Genesis 1:1 a');
      final corpus = InMemoryCorpus(chumashCurriculum, [
        CorpusNode(genesis, [
          CorpusNode(genesis1, [
            CorpusNode(verse('Genesis 1:1'), [const CorpusNode(deep)]),
          ]),
        ]),
      ]);
      expect(
        _labels(corpus, curriculum: CurriculumId.chumash).unitOf(deep, 2),
        'level4',
      );
    });
  });

  group('node names come from this curriculum, by node identity', () {
    test('names from this curriculum, else the ref', () {
      final corpus = chumashCorpus();
      final labels = _labels(
        corpus,
        curriculum: CurriculumId.chumash,
        items: contentItemsOf(corpus, hebrew: {'Genesis': 'בראשית'}),
      );
      expect(labels.itemOf(genesis), isNotNull);
      expect(labels.nameOf(genesis), 'Bereishis');
      expect(
        labels.searchLabelsOf(genesis),
        containsAll(['Genesis', 'בראשית']),
      );
      expect(_labels(corpus).nameOf(genesis), 'Genesis');
      expect(_labels(corpus).searchLabelsOf(genesis), ['Genesis']);
    });

    test('a colliding ref never resolves to another curriculum', () {
      final corpus = chumashCorpus();
      // Tanach's `Genesis` row comes first in the list and in sortOrder.
      final tanach = _item('tanach', ['Torah'], 'Torah', 0);
      final tanachGenesis = _item(
        'tanach',
        ['Torah', 'Genesis'],
        'Genesis',
        1,
        en: 'Tanach Genesis',
        he: 'תורה בראשית',
      );
      final onlyTanach = _labels(
        corpus,
        curriculum: CurriculumId.chumash,
        items: [tanach, tanachGenesis],
      );
      expect(onlyTanach.itemOf(genesis), isNull);
      expect(onlyTanach.nameOf(genesis), 'Genesis');
      expect(onlyTanach.searchLabelsOf(genesis), ['Genesis']);

      final both = _labels(
        corpus,
        curriculum: CurriculumId.chumash,
        items: [tanach, tanachGenesis, ...contentItemsOf(corpus)],
      );
      expect(both.itemOf(genesis)?.curriculumId, chumashCurriculum);
      expect(both.searchLabelsOf(genesis), isNot(contains('תורה בראשית')));
    });
  });
}
