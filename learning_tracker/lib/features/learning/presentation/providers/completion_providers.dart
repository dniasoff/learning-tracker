/// Per-item learning reads for the Browse and text screens (AD-35 "Reads").
///
/// Story 1.21 (DNI-483) moved these off the retired `completions` store
/// (R1): every answer here is derived from the active learner's
/// [LearnerState], never from a query of its own. A stage of a leaf counts
/// as learnt when the state has a counted main-track `learn` event for
/// exactly that `ref` with that `stage` — the same leaf/stage key the
/// legacy completion rows used. A main-track learn without a `stage` counts
/// as the first stage ([kDefaultFirstStageOrder]), as `LearningCommands`
/// prices it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/optimistic_completion_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'completion_providers.g.dart';

/// Internal storage key written to the `track_type` column of the completion
/// event log. There is exactly one track per (profile, curriculum), so this is
/// a fixed constant — it is never surfaced as a user-facing "track type" label.
final trackStorageKeyForTrackIdProvider = FutureProvider.autoDispose
    .family<String, CurriculumId>((ref, curriculumId) async {
      return 'personal';
    });

/// The active learner's [LearnerState] as a future: `null` while no learner
/// is active. Rebuilds whenever the state does, so a capture shows up
/// without an explicit invalidation.
final activeLearnerStateFutureProvider =
    FutureProvider.autoDispose<LearnerState?>((ref) async {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      if (scope == null) return null;
      return ref.watch(learnerStateProvider(scope).future);
    });

/// The stage order a main-track learn without a `stage` stands for.
const kDefaultFirstStageOrder = 1;

/// The stage [event] completes: its `stage`, or [firstStageOrder] for a
/// main-track learn without one. Null for a sub-track learn (no stage).
int? stageOfLearn(
  LearningEvent event, {
  int firstStageOrder = kDefaultFirstStageOrder,
}) {
  if (event.source != LearningEvent.sourceMain) return null;
  return event.stage ?? firstStageOrder;
}

/// Whether [state] has a counted main-track learn of [sefariaRef] at
/// [stageOrder] (in any curriculum when [curriculumId] is null).
bool hasCountedStageLearn(
  LearnerState? state, {
  required String sefariaRef,
  required int stageOrder,
  String? curriculumId,
}) {
  if (state == null) return false;
  return state.countedLearns.any(
    (e) =>
        e.ref == sefariaRef &&
        stageOfLearn(e) == stageOrder &&
        (curriculumId == null || e.curriculumId == curriculumId),
  );
}

/// Counted main-track learns of [sefariaRef] in [curriculumId], by stage
/// order. Sub-track learns have no stage and are left out.
Map<int, int> stageBreakdownOf(
  LearnerState? state, {
  required String curriculumId,
  required String sefariaRef,
}) {
  final breakdown = <int, int>{};
  if (state == null) return breakdown;
  for (final e in state.countedLearns) {
    if (e.curriculumId != curriculumId || e.ref != sefariaRef) continue;
    final stage = stageOfLearn(e);
    if (stage == null) continue;
    breakdown[stage] = (breakdown[stage] ?? 0) + 1;
  }
  return breakdown;
}

/// Provider family to check whether a specific stage is already completed.
///
/// Checks optimistic state first (instant), then the active learner's
/// [LearnerState]. `trackType` is part of the optimistic key only; there is
/// one track per curriculum.
final isStageCompletedProvider = FutureProvider.autoDispose
    .family<bool, ({String sefariaRef, int stageId, String trackType})>((
      ref,
      params,
    ) async {
      final optimistic = ref.watch(optimisticCompletionStateProvider);
      final key = optimisticKey(
        sefariaRef: params.sefariaRef,
        stageId: params.stageId,
        trackType: params.trackType,
      );
      if (optimistic.contains(key)) return true;

      final state = await ref.watch(activeLearnerStateFutureProvider.future);
      return hasCountedStageLearn(
        state,
        sefariaRef: params.sefariaRef,
        stageOrder: params.stageId,
      );
    });

/// Per-stage breakdown for a single item (AC-1, AC-5).
@riverpod
Future<Map<int, int>> itemStageBreakdown(
  Ref ref,
  ({String curriculumId, String sefariaRef}) params,
) async {
  final state = await ref.watch(activeLearnerStateFutureProvider.future);
  return stageBreakdownOf(
    state,
    curriculumId: params.curriculumId,
    sefariaRef: params.sefariaRef,
  );
}

/// Provides the legacy completion repository (R1). No screen reads it any
/// more; Story 1.21 (DNI-483) deletes it with its tests.
@riverpod
CompletionRepository completionRepository(Ref ref) {
  return FirestoreCompletionRepositoryAdapter(ref: ref);
}

/// Legacy per-item completion count (R1, no production reader); deleted
/// with [completionRepository].
@riverpod
Future<int> completionCount(
  Ref ref, {
  required String curriculumId,
  required String sefariaRef,
}) async {
  final repository = ref.watch(completionRepositoryProvider);
  final completions = await repository.getCompletionsForContentItem(sefariaRef);
  return completions
      .where((c) => c.curriculumId.storageKey == curriculumId)
      .length;
}
