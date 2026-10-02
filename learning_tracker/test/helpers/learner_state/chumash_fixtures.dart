/// A non-Mishnayos corpus fixture for the sub-track engine tests (DNI-493
/// AC-7, `prd-deviations` #12): Chumash-shaped, sefer → chapter → verse,
/// whose FR-12a unit is the sefer. Nothing in it is a masechta or mishna.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// The fixture curriculum id.
const chumashCurriculum = 'chumash';

/// Sefer Genesis.
const genesis = NodeEntry(level: 'sefer', ref: 'Genesis');

/// Genesis chapter 1.
const genesis1 = NodeEntry(level: 'chapter', ref: 'Genesis 1');

/// Genesis chapter 2.
const genesis2 = NodeEntry(level: 'chapter', ref: 'Genesis 2');

/// Sefer Exodus.
const exodus = NodeEntry(level: 'sefer', ref: 'Exodus');

/// Exodus chapter 1.
const exodus1 = NodeEntry(level: 'chapter', ref: 'Exodus 1');

/// A verse leaf.
NodeEntry verse(String ref) => NodeEntry(level: 'verse', ref: ref);

/// The fixture Chumash corpus, in ContentIndex order:
///
/// * Genesis: chapter 1 (1:1, 1:2, 1:3), chapter 2 (2:1, 2:2)
/// * Exodus: chapter 1 (1:1, 1:2)
///
/// `unitLevels` is `[sefer]`, as the ContentIndex adapter resolves it for
/// `chumash.json` (`Sefer`, `Chapter`, `Verse`).
InMemoryCorpus chumashCorpus() => InMemoryCorpus(
  chumashCurriculum,
  [
    CorpusNode(genesis, [
      CorpusNode(genesis1, [
        CorpusNode(verse('Genesis 1:1')),
        CorpusNode(verse('Genesis 1:2')),
        CorpusNode(verse('Genesis 1:3')),
      ]),
      CorpusNode(genesis2, [
        CorpusNode(verse('Genesis 2:1')),
        CorpusNode(verse('Genesis 2:2')),
      ]),
    ]),
    CorpusNode(exodus, [
      CorpusNode(exodus1, [
        CorpusNode(verse('Exodus 1:1')),
        CorpusNode(verse('Exodus 1:2')),
      ]),
    ]),
  ],
  unitLevels: const ['sefer'],
);

/// An active main-track intent for [chumashCurriculum].
MainTrackIntent chumashIntent() => MainTrackIntent(
  curriculumId: chumashCurriculum,
  track: MainTrack(
    curriculumId: chumashCurriculum,
    state: MainTrackState.active,
  ),
);
