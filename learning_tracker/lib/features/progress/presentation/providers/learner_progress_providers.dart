/// Riverpod glue between the progress surfaces and the engine's
/// [LearnerState] (DNI-474): every progress reader awaits the ONE active
/// learner state through [watchActiveLearnerState] and reads corpora from
/// [progressCorpusProvider]; none of them reads completions, the learning
/// ledger or `learning_events`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';

/// The active learner's state from inside an async provider body: the
/// state (null with no active learner), the state's error, or a future that
/// stays pending while it loads (the watching provider rebuilds and stays
/// loading until a complete state arrives — never a partial one).
///
/// A refreshing state keeps its previous value, so a re-page does not
/// blank a screen.
Future<LearnerState?> watchActiveLearnerState(Ref ref) {
  final value = ref.watch(activeLearnerStateProvider);
  if (value.hasError) return Future.error(value.error!, value.stackTrace);
  if (value.hasValue) return Future.value(value.value);
  return Completer<LearnerState?>().future;
}

/// The unscoped ContentIndex corpus of [CurriculumId] (AD-42), from
/// [corporaProvider]; null when the curriculum has no bundled hierarchy.
final progressCorpusProvider = FutureProvider.family<Corpus?, CurriculumId>(
  (ref, curriculum) async =>
      (await ref.watch(corporaProvider.future))[curriculum.storageKey],
);

/// Every unscoped corpus by curriculum id, for readers that span curricula.
Future<Map<String, Corpus>> watchCorpora(Ref ref) =>
    ref.watch(corporaProvider.future);

/// The active learner's [CurriculumProgressIndex] of one curriculum: the
/// engine's learnt set (with subset curricula for a composite, I-4) and
/// per-leaf counted learning, for per-node tri-state lookups.
final curriculumProgressIndexProvider = FutureProvider.autoDispose
    .family<CurriculumProgressIndex?, CurriculumId>((ref, curriculum) async {
      final state = await watchActiveLearnerState(ref);
      final corpus = await ref.watch(progressCorpusProvider(curriculum).future);
      if (corpus == null) return null;
      return CurriculumProgressIndex.of(
        state,
        corpus,
        subsetIds: [for (final s in subsetsOf(curriculum)) s.storageKey],
      );
    });
