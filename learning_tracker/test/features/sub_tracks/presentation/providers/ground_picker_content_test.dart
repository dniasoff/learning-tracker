// Mirror test for
// `lib/features/sub_tracks/presentation/providers/ground_picker_content.dart`
// (Story 2.7 / DNI-498 AC-2): every corpus node resolves to its own
// curriculum's ContentIndex row by `{level, ref}` identity, never to a
// colliding ref of another curriculum or another level, and to the level
// labels of its depth under its book's overrides.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_picker_content.dart';

import '../../../../helpers/learner_state/chumash_fixtures.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

ContentItem _item(
  String curriculumId,
  List<String> path,
  String ref,
  int order, {
  String? en,
  bool leaf = false,
}) => ContentItem(
  curriculumId: curriculumId,
  level1: path[0],
  level2: path.length > 1 ? path[1] : null,
  level3: path.length > 2 ? path[2] : null,
  level4: path.length > 3 ? path[3] : null,
  displayNameHe: ref,
  displayNameEn: en ?? ref,
  sefariaRef: ref,
  sortOrder: order,
  isLeaf: leaf,
);

GroundPickerContent _content(
  Corpus corpus,
  List<ContentItem> items, {
  CurriculumId? curriculum,
}) => GroundPickerContent.of(
  corpus: corpus,
  items: items,
  levels: curriculumLevelLabels(curriculum),
);

void main() {
  test('rows of another curriculum never match a colliding ref', () {
    final corpus = chumashCorpus();
    final tanachGenesis = _item(
      'tanach',
      ['Torah', 'Genesis'],
      'Genesis',
      0,
      en: 'Tanach Genesis',
    );
    final tanachTop = _item('tanach', ['Genesis'], 'Genesis', 1, en: 'Top');
    expect(
      _content(corpus, [tanachGenesis, tanachTop]).itemOf(genesis),
      isNull,
    );
    final both = _content(corpus, [
      tanachGenesis,
      tanachTop,
      ...contentItemsOf(corpus),
    ]);
    expect(both.itemOf(genesis)?.curriculumId, chumashCurriculum);
    expect(both.itemOf(genesis)?.displayNameEn, 'Genesis');
  });

  test('a ref at two levels of one curriculum resolves per level', () {
    const book = NodeEntry(level: 'book', ref: 'Berakhot');
    const tractate = NodeEntry(level: 'tractate', ref: 'Berakhot');
    const leaf = NodeEntry(level: 'mishnah', ref: 'Berakhot 1:1');
    final corpus = InMemoryCorpus('mishnayos', [
      const CorpusNode(book, [
        CorpusNode(tractate, [CorpusNode(leaf)]),
      ]),
    ]);
    final content = _content(corpus, [
      _item('mishnayos', ['Berakhot', 'Berakhot'], 'Berakhot', 1, en: 'T'),
      _item('mishnayos', ['Berakhot'], 'Berakhot', 0, en: 'B'),
    ], curriculum: CurriculumId.mishnayos);
    expect(content.itemOf(book)?.displayNameEn, 'B');
    expect(content.itemOf(tractate)?.displayNameEn, 'T');
    expect(content.itemOf(leaf), isNull);
    expect(content.levelOf(book)?.en, 'Seder');
    expect(content.levelOf(tractate)?.en, 'Masechta');
  });

  test('a duplicate row in one curriculum: the first in order wins', () {
    final corpus = chumashCorpus();
    final content = _content(corpus, [
      _item(chumashCurriculum, ['Genesis'], 'Genesis', 5, en: 'Later'),
      _item(chumashCurriculum, ['Genesis'], 'Genesis', 1, en: 'First'),
    ]);
    expect(content.itemOf(genesis)?.displayNameEn, 'First');
  });

  test('levels follow depth and the book override, not the level key', () {
    const c = 'mussar';
    final items = [
      _item(c, ['Tanya'], 'Tanya', 0),
      _item(c, ['Tanya', 'Part I'], 'Tanya, Part I', 1),
      _item(c, ['Tanya', 'Part I', '1'], 'Tanya, Part I 1', 2),
      _item(
        c,
        ['Tanya', 'Part I', '1', '1'],
        'Tanya, Part I 1:1',
        3,
        leaf: true,
      ),
      _item(c, ['Mesillat Yesharim'], 'Mesillat Yesharim', 4),
      _item(c, ['Mesillat Yesharim', '1'], 'Mesillat Yesharim 1', 5),
      _item(
        c,
        ['Mesillat Yesharim', '1', '1'],
        'Mesillat Yesharim 1:1',
        6,
        leaf: true,
      ),
    ];
    final corpus = corpusOf(CurriculumId.mussar, items);
    final content = _content(corpus, items, curriculum: CurriculumId.mussar);
    String? en(String ref) => content
        .levelOf(
          nodeEntryOf(
            CurriculumId.mussar,
            items.firstWhere((i) => i.sefariaRef == ref),
          ),
        )
        ?.en;
    expect(en('Tanya'), 'Sefer');
    expect(en('Tanya, Part I'), 'Part');
    expect(en('Tanya, Part I 1'), 'Perek');
    expect(en('Tanya, Part I 1:1'), 'Pasuk');
    expect(en('Mesillat Yesharim 1'), 'Perek');
    expect(en('Mesillat Yesharim 1:1'), 'Pasuk');
  });

  test('no level for an unknown node, curriculum or depth', () {
    final corpus = chumashCorpus();
    final content = _content(
      corpus,
      const [],
      curriculum: CurriculumId.chumash,
    );
    expect(
      content.levelOf(const NodeEntry(level: 'x', ref: 'Nowhere')),
      isNull,
    );
    expect(content.levelOf(genesis)?.en, 'Sefer');
    expect(_content(corpus, const []).levelOf(genesis), isNull);
    expect(curriculumLevelLabels(CurriculumId.chumash)(4, null), isNull);
    expect(curriculumLevelLabels(CurriculumId.chumash)(0, null), isNull);
  });
}
