/// Items Learned ("Track learning only") and Lifetime View ("All
/// sources") summaries for the Lifetime Knowledge screen (DNI-474).
///
/// Both read the active learner's [LearnerState] only: the engine's learnt
/// set and its counted learn events. "Track learning only" keeps the leaves
/// learnt while tracking (`dated` / `catch_up`); "All sources" is the
/// engine's whole learnt set, before-tracking marks included (FR-14).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';
import 'package:learning_tracker/features/progress/presentation/providers/learner_progress_providers.dart';

/// Summary of per-curriculum learning for the Items Learned / Lifetime
/// View screens.
class CurriculumCompletionSummary {
  const CurriculumCompletionSummary({
    required this.curriculumId,
    required this.learnedLeafCount,
    required this.totalLeafCount,
    required this.tree,
  });

  final CurriculumId curriculumId;
  final int learnedLeafCount;
  final int totalLeafCount;
  final List<LifetimeTreeNode> tree;

  double get percentage =>
      totalLeafCount > 0 ? learnedLeafCount / totalLeafCount : 0.0;
}

// ---------------------------------------------------------------------------
// Testable service functions — used by providers below and by tests directly.
// ---------------------------------------------------------------------------

/// The "Track learning only" summary of [curriculum]: the leaves of the
/// engine's learnt set with at least one counted `dated` / `catch_up` learn
/// event. Returns `null` when there is none (so an untouched curriculum
/// never loads its content) or the curriculum has no content.
Future<CurriculumCompletionSummary?> computeItemsLearnedSummary({
  required LearnerState state,
  required Corpus corpus,
  required ContentRepository repo,
  required CurriculumId curriculum,
}) async {
  final activity = leafActivityOf(state, corpus);
  final learnt = state[curriculum.storageKey]?.learntLeaves ?? const {};
  final tracked = {
    for (final MapEntry(:key, :value) in activity.entries)
      if (value.trackedEvents > 0 && learnt.contains(key)) key,
  };
  if (tracked.isEmpty) return null;
  return _summary(
    repo: repo,
    curriculum: curriculum,
    learnt: tracked,
    provenance: LifetimeTreeBuilder.provenanceFromActivity({
      for (final ref in tracked) ref: activity[ref]!,
    }),
  );
}

/// The "All sources" summary of [curriculum]: the engine's whole learnt
/// set. Returns `null` when nothing is learnt or there is no content.
Future<CurriculumCompletionSummary?> computeLifetimeViewSummary({
  required LearnerState state,
  required Corpus corpus,
  required ContentRepository repo,
  required CurriculumId curriculum,
}) async {
  final learnt = state[curriculum.storageKey]?.learntLeaves ?? const {};
  if (learnt.isEmpty) return null;
  return _summary(
    repo: repo,
    curriculum: curriculum,
    learnt: learnt,
    provenance: LifetimeTreeBuilder.provenanceFromActivity(
      leafActivityOf(state, corpus),
    ),
  );
}

Future<CurriculumCompletionSummary?> _summary({
  required ContentRepository repo,
  required CurriculumId curriculum,
  required Set<String> learnt,
  required Map<String, LifetimeLeafProvenance> provenance,
}) async {
  final content = await repo.getContentForCurriculum(curriculum);
  final leaves = content.where((item) => item.isLeaf).toList();
  if (leaves.isEmpty) return null;
  final summary = const LifetimeTreeBuilder().build(
    curriculum: curriculum,
    leaves: leaves,
    learnedRefs: learnt,
    heLabelLookup: LifetimeTreeBuilder.buildHeLabelLookup(content),
    leafProvenance: provenance,
  );
  return CurriculumCompletionSummary(
    curriculumId: curriculum,
    learnedLeafCount: summary.learnedLeafCount,
    totalLeafCount: summary.totalLeafCount,
    tree: summary.tree,
  );
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Thrown when a provider in this file runs with no active learner.
class ItemsLearnedNoActiveProfileException implements Exception {
  const ItemsLearnedNoActiveProfileException();

  @override
  String toString() =>
      'ItemsLearnedNoActiveProfileException: an Items Learned / Lifetime '
      'View provider was read with no active learner — there is no learner '
      'state to read without one.';
}

Future<(LearnerState, Corpus?)> _inputs(Ref ref, CurriculumId c) async {
  final state = await watchActiveLearnerState(ref);
  if (state == null) throw const ItemsLearnedNoActiveProfileException();
  final corpus = await ref.watch(progressCorpusProvider(c).future);
  return (state, corpus);
}

/// "Track learning only" summary of one curriculum.
final itemsLearnedDataProvider = FutureProvider.autoDispose
    .family<CurriculumCompletionSummary?, CurriculumId>((
      ref,
      curriculumId,
    ) async {
      final (state, corpus) = await _inputs(ref, curriculumId);
      if (corpus == null) return null;
      return computeItemsLearnedSummary(
        state: state,
        corpus: corpus,
        repo: ref.watch(contentRepositoryProvider),
        curriculum: curriculumId,
      );
    });

/// "Track learning only" summaries of every curriculum with tracked
/// learning.
final itemsLearnedSummariesProvider =
    FutureProvider.autoDispose<List<CurriculumCompletionSummary>>((ref) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) =>
              ref.watch(itemsLearnedDataProvider(curriculum).future),
        ),
      );
      return results.whereType<CurriculumCompletionSummary>().toList();
    });

/// "All sources" summary of one curriculum.
final lifetimeViewDataProvider = FutureProvider.autoDispose
    .family<CurriculumCompletionSummary?, CurriculumId>((
      ref,
      curriculumId,
    ) async {
      final (state, corpus) = await _inputs(ref, curriculumId);
      if (corpus == null) return null;
      return computeLifetimeViewSummary(
        state: state,
        corpus: corpus,
        repo: ref.watch(contentRepositoryProvider),
        curriculum: curriculumId,
      );
    });

/// "All sources" summaries of every curriculum with learning.
final lifetimeViewSummariesProvider =
    FutureProvider.autoDispose<List<CurriculumCompletionSummary>>((ref) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) =>
              ref.watch(lifetimeViewDataProvider(curriculum).future),
        ),
      );
      return results.whereType<CurriculumCompletionSummary>().toList();
    });
