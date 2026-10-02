// Mirror test for
// `lib/features/sub_tracks/presentation/widgets/ground_picker_labels.dart`
// (Story 2.7 / DNI-498 AC-2, `prd-deviations` #12): node names and level
// units come from ContentIndex and the curriculum's level metadata, with
// safe fallbacks for unknown nodes and levels.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_labels.dart';

import '../../../../helpers/learner_state/chumash_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

GroundPickerLabels _labels(
  Corpus corpus, {
  CurriculumId? curriculum,
  bool useHebrew = false,
  ContentIndex? index,
}) => GroundPickerLabels(
  curriculum: curriculum,
  curriculumId: corpus.curriculumId,
  index: index ?? ContentIndex.fromCurricula(const {}),
  corpus: corpus,
  useHebrew: useHebrew,
  variant: TransliterationVariant.ashkenazi,
);

void main() {
  test('a level key ContentIndex names resolves to its label', () {
    final labels = _labels(
      mishnayosCorpus(),
      curriculum: CurriculumId.mishnayos,
    );
    expect(labels.unitOf(berakhot, 1), 'Masechta');
    expect(labels.unitOf(berakhot, 2), 'Masechtos');
    expect(labels.unitOf(zeraim, 3), 'Sedarim');
  });

  test('a level key the labels do not name resolves by depth', () {
    // The fixture's `chapter` is depth 3 of Mishnayos: Perek.
    final labels = _labels(
      mishnayosCorpus(),
      curriculum: CurriculumId.mishnayos,
    );
    expect(labels.unitOf(berakhot1, 1), 'Perek');
    expect(labels.unitOf(berakhot1, 9), 'Perakim');
    final chumash = _labels(chumashCorpus(), curriculum: CurriculumId.chumash);
    expect(chumash.unitOf(genesis1, 2), 'Perakim');
    expect(chumash.unitOf(verse('Genesis 1:1'), 3), 'Pesukim');
  });

  test('Hebrew terms render the Hebrew unit', () {
    final labels = _labels(
      chumashCorpus(),
      curriculum: CurriculumId.chumash,
      useHebrew: true,
    );
    expect(labels.unitOf(genesis, 2), 'חומשים');
  });

  test('an unknown curriculum or node falls back to the raw level key', () {
    final labels = _labels(mishnayosCorpus());
    expect(labels.unitOf(berakhot, 2), 'masechta');
    expect(
      _labels(
        mishnayosCorpus(),
        curriculum: CurriculumId.mishnayos,
      ).unitOf(const NodeEntry(level: 'odd', ref: 'Nowhere'), 1),
      'odd',
    );
  });

  test('names come from ContentIndex of this curriculum, else the ref', () {
    final corpus = chumashCorpus();
    final labels = _labels(
      corpus,
      curriculum: CurriculumId.chumash,
      index: ContentIndex.fromCurricula({
        CurriculumId.chumash: contentItemsOf(
          corpus,
          hebrew: {'Genesis': 'בראשית'},
        ),
      }),
    );
    expect(labels.itemOf(genesis), isNotNull);
    expect(labels.nameOf(genesis), 'Bereishis');
    expect(labels.searchLabelsOf(genesis), containsAll(['Genesis', 'בראשית']));
    expect(_labels(corpus).nameOf(genesis), 'Genesis');
    expect(_labels(corpus).searchLabelsOf(genesis), ['Genesis']);
  });
}
