// Mirror test for
// `lib/features/progress/domain/services/siyum_milestones.dart`
// (DNI-474 AC-4: the siyumim journey lays out engine completed units).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/domain/services/siyum_milestones.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

void main() {
  final corpus = progressCorpus();
  final itemsByRef = <String, ContentItem>{
    for (final i in progressContent())
      if (!i.isLeaf) i.sefariaRef: i,
  };

  List<MilestoneAchievement> milestones(List<Object> events) => siyumMilestones(
    curriculum: CurriculumId.mishnayos,
    state: progressState(events.cast())[engineCurriculum],
    corpus: corpus,
    itemsByRef: itemsByRef,
    curriculumDisplayName: 'Mishnayos',
  );

  test('the corpus siyum levels give the tiers', () {
    expect(milestoneLevelOf(corpus, 'seder'), MilestoneLevel.aggregate);
    expect(milestoneLevelOf(corpus, 'masechta'), MilestoneLevel.unit);
    expect(unitTierCount(corpus), 3);
  });

  test('one masechta completion is a unit milestone with its label keys', () {
    final list = milestones([
      progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
    ]);
    final m = list.single;
    expect(m.level, MilestoneLevel.unit);
    expect(m.unitKey, 'Mishnah Peah');
    expect(m.unitScope, 'masechta');
    expect(m.parentAggregateKey, 'Zeraim');
    expect(m.achievedAt, engineAt(2));
    expect(m.completionNumber, 1);
  });

  test('a second full completion adds a timeline row with k = 2', () {
    final list = milestones([
      progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
      progressLearn(3, 'Mishnah Peah 1:1', minutes: 3),
      progressLearn(4, 'Mishnah Peah 1:2', minutes: 4),
    ]);
    expect(list.map((m) => (m.completionNumber, m.achievedAt)), [
      (2, engineAt(4)),
      (1, engineAt(2)),
    ]);
  });

  test('a completed seder is an aggregate milestone over its masechtos, and '
      'every top-level unit complete is the curriculum siyum', () {
    final list = milestones([
      progressGround(1, 'Seder Zeraim', 'seder', minutes: 1),
      progressGround(2, 'Seder Moed', 'seder', minutes: 5),
    ]);
    final seder = list.firstWhere((m) => m.aggregateKey == 'Zeraim');
    expect(seder.level, MilestoneLevel.aggregate);
    expect(seder.containedUnitKeys, ['Mishnah Berakhot', 'Mishnah Peah']);
    final whole = list.firstWhere((m) => m.level == MilestoneLevel.curriculum);
    expect(whole.achievedAt, engineAt(5));
    expect(whole.displayName, 'Mishnayos');
  });

  test('unit completions list every completion number', () {
    final completions = unitCompletions(
      state: progressState([
        progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
        progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
      ])[engineCurriculum],
      itemsByRef: itemsByRef,
    );
    expect(completions.single.entryKey, 'Mishnah Peah');
    expect(completions.single.entryScope, 'masechta');
    expect(completions.single.completionNumber, 1);
  });

  test('no state has no milestones', () {
    expect(
      siyumMilestones(
        curriculum: CurriculumId.mishnayos,
        state: null,
        corpus: corpus,
        itemsByRef: itemsByRef,
        curriculumDisplayName: 'Mishnayos',
      ),
      isEmpty,
    );
  });

  test('curriculum Siyum walk resolves the legacy Mishnah Berurah root', () {
    const root = NodeEntry(level: 'book', ref: 'Mishnah Berurah');
    final corpus = InMemoryCorpus(
      'mishna_berurah',
      [
        const CorpusNode(root, [
          CorpusNode(
            NodeEntry(level: 'section', ref: 'Mishnah Berurah|section|Shabbos'),
            [
              CorpusNode(
                NodeEntry(level: 'siman', ref: 'Mishnah Berurah 242'),
                [
                  CorpusNode(
                    NodeEntry(level: 'seif', ref: 'Mishnah Berurah 242:1'),
                  ),
                ],
              ),
            ],
          ),
        ]),
      ],
      unitLevels: const ['book'],
    );
    const rootItem = ContentItem(
      curriculumId: 'mishna_berurah',
      level1: 'Mishnah Berurah',
      displayNameHe: 'משנה ברורה',
      displayNameEn: 'Mishnah Berurah',
      sefariaRef: 'Mishnah Berurah',
      sortOrder: 0,
      isLeaf: false,
    );
    final completed = [
      CompletedUnit(
        unit: root,
        completionNumber: 1,
        firstCompletedAt: {1: engineAt(7)},
      ),
    ];

    expect(unitLabelKeys(root, {root.ref: rootItem}), (
      key: 'Mishnah Berurah',
      parentL1: null,
    ));
    expect(curriculumCompletedAt(completed, corpus), engineAt(7));
  });
}
