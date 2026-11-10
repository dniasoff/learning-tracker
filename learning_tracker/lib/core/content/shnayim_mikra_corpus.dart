import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';

/// Gives Shnayim Mikra its own learner-state namespace over Chumash pesukim.
/// Learning events remain under Shnayim Mikra and cannot mark Chumash learnt.
Corpus shnayimMikraCorpusFromChumash(List<ContentItem> chumashItems) =>
    contentIndexCorpus(
      curriculumId: CurriculumId.shnayimMikra.storageKey,
      items: [
        for (final item in chumashItems)
          item.copyWith(curriculumId: CurriculumId.shnayimMikra.storageKey),
      ],
      levelLabels: CurriculumLabels.labelsEn(CurriculumId.chumash),
    );
