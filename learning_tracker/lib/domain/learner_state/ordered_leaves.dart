/// AD-35 main-track leaf order: the corpus reordered by the learner's
/// `track_learning_order` docs.
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';

/// Every leaf of [corpus] in the learner's main-track order.
///
/// C0 stub, filled by DNI-467 (1.5).
List<LeafRef> orderedLeaves(
  Corpus corpus,
  List<MainTrackOrderEntry> orderDocs,
) => c0Stub('DNI-467', 'orderedLeaves');
