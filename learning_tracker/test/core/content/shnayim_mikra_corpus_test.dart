import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/content/shnayim_mikra_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('Shnayim Mikra has Chumash verse leaves in its own curriculum id', () {
    const chumash = [
      ContentItem(
        curriculumId: 'chumash',
        level1: 'Genesis',
        level2: 'Genesis 1',
        level3: 'Genesis 1:1',
        displayNameHe: 'בראשית א:א',
        displayNameEn: 'Genesis 1:1',
        sefariaRef: 'Genesis 1:1',
        sortOrder: 1,
        isLeaf: true,
      ),
      ContentItem(
        curriculumId: 'chumash',
        level1: 'Genesis',
        level2: 'Genesis 1',
        level3: 'Genesis 1:2',
        displayNameHe: 'בראשית א:ב',
        displayNameEn: 'Genesis 1:2',
        sefariaRef: 'Genesis 1:2',
        sortOrder: 2,
        isLeaf: true,
      ),
    ];

    final corpus = shnayimMikraCorpusFromChumash(chumash);

    expect(corpus.curriculumId, CurriculumId.shnayimMikra.storageKey);
    expect(corpus.leaves, ['Genesis 1:1', 'Genesis 1:2']);
    expect(corpus.nodeForRef('Genesis 1:1')?.ref, 'Genesis 1:1');
  });

  test('Shnayim completions earn in their own curriculum, not Chumash', () {
    const chumash = [
      ContentItem(
        curriculumId: 'chumash',
        level1: 'Genesis',
        level2: 'Genesis 1',
        level3: 'Genesis 1:1',
        displayNameHe: 'בראשית א:א',
        displayNameEn: 'Genesis 1:1',
        sefariaRef: 'Genesis 1:1',
        sortOrder: 1,
        isLeaf: true,
      ),
    ];
    final shnayimCorpus = shnayimMikraCorpusFromChumash(chumash);
    final chumashCorpus = contentIndexCorpus(
      curriculumId: CurriculumId.chumash.storageKey,
      items: chumash,
      levelLabels: CurriculumLabels.labelsEn(CurriculumId.chumash),
    );
    final event = LearningEvent.learn(
      id: engineUlid(1),
      curriculumId: CurriculumId.shnayimMikra.storageKey,
      ref: 'Genesis 1:1',
      source: LearningEvent.sourceMain,
      assignmentKey: '2026-09-01:BERESHIT:israel',
      dateState: DateState.dated,
      learnedOn: '2026-09-01',
      recordedAt: engineAt(1),
      actor: parentActor,
    );
    final state = const LearnerStateEngine().run(
      engineInputs(
        events: [event],
        corpora: {
          CurriculumId.chumash.storageKey: chumashCorpus,
          CurriculumId.shnayimMikra.storageKey: shnayimCorpus,
        },
        intents: const {},
        settingsHistory: c0SettingsHistory(),
      ),
    );

    expect(
      state.curricula[CurriculumId.shnayimMikra.storageKey]?.learntLeaves,
      {'Genesis 1:1'},
    );
    expect(
      state.curricula[CurriculumId.chumash.storageKey]?.learntLeaves,
      isEmpty,
    );
    expect(state.earningEventIds, {event.id});
  });
}
