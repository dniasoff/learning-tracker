import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';

/// Thrown by [SchedulerFirestoreCompletionRepositoryAdapter] when
/// `firestoreCompletionRepositoryProvider` resolves to `null` — i.e. no
/// active account, or no active learner profile, yet.
///
/// Owner ruling D-E: completions are achievement data. Returning `[]` when
/// the provider is unresolved would be indistinguishable from a learner who
/// has completed nothing, so daily-task generation would wrongly schedule
/// every item as new learning. Mirrors
/// `CompletionRepositoryNotReadyException`
/// (`lib/features/learning/data/repositories/completion_repository_impl.dart`),
/// which makes the same D-E call for the same data.
class SchedulerCompletionRepositoryNotReadyException implements Exception {
  const SchedulerCompletionRepositoryNotReadyException();

  @override
  String toString() =>
      'SchedulerCompletionRepositoryNotReadyException: '
      'firestoreCompletionRepositoryProvider resolved to null (no active '
      'account, or no active learner profile, yet) — cannot read '
      'completions until one is active.';
}

/// Firestore-backed [SchedulerCompletionRepository] adapter.
///
/// Replaces the Drift-backed `CompletionDao`/`StageDao` implementation the
/// Drift user DB deletion removed (archived under
/// `docs/_archive/drift-user-db/`). Built to the same resolved-`Ref`-per-call
/// pattern as `SchedulerFirestoreLearningOrderRepositoryAdapter`
/// (`scheduler_learning_order_repository_impl.dart`) and
/// `FirestoreCompletionRepositoryAdapter`
/// (`lib/features/learning/data/repositories/completion_repository_impl.dart`)
/// — see those class doc comments for the pattern in full.
///
/// ## No stage-id/stage-order reconciliation (AUD-scheduler-15 is obsolete)
///
/// The Drift implementation carried `resolveStageOrder`: a Drift
/// `completion_events.stageId` could mean either a `stage_definitions.id` or
/// a `stageOrder` ordinal, disambiguated by the v37 `stageIdFormat` marker.
/// Every Firestore [CompletionEntity.stageId] is a `stage_order` value by
/// construction (see that class's class doc comment) — there is no legacy
/// format to disambiguate, so `SchedulerCompletion.stageOrder` maps directly
/// from [CompletionEntity.stageId], and no completion can be dropped for an
/// unresolvable stage.
///
/// ## Not-ready reads throw, not `[]` (D-E)
///
/// Completions are achievement data: an empty list is indistinguishable from
/// a learner who has completed nothing and would silently skew the daily
/// schedule. [getCompletions] therefore throws
/// [SchedulerCompletionRepositoryNotReadyException] when the provider is
/// unresolved, rather than returning `[]`.
class SchedulerFirestoreCompletionRepositoryAdapter
    implements SchedulerCompletionRepository {
  SchedulerFirestoreCompletionRepositoryAdapter({required Ref ref})
    : _ref = ref;

  final Ref _ref;

  /// Resolves `firestoreCompletionRepositoryProvider`, re-read on every call
  /// rather than cached so a profile switch is picked up without rebuilding
  /// this adapter — same rationale as the sibling adapters above. Throws
  /// [SchedulerCompletionRepositoryNotReadyException] when it resolves to
  /// `null` (no active account, or no active learner profile).
  Future<FirestoreCompletionRepository> _resolve() async {
    final repo = await _ref.read(firestoreCompletionRepositoryProvider.future);
    if (repo == null) {
      throw const SchedulerCompletionRepositoryNotReadyException();
    }
    return repo;
  }

  @override
  Future<List<SchedulerCompletion>> getCompletions(
    CurriculumId curriculumId,
  ) async {
    final repo = await _resolve();
    final completions = await repo.getCompletionsForCurriculum(curriculumId);
    return [
      for (final c in completions)
        SchedulerCompletion(
          sefariaRef: c.sefariaRef,
          stageOrder: c.stageId,
          trackType: c.trackType,
          completedAt: c.completedAt,
        ),
    ];
  }
}
