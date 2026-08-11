import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// Thrown by [FirestoreStageDefinitionRepositoryAdapter]'s write methods
/// when `firestoreStageDefinitionRepositoryProvider` resolves to `null` —
/// see `BookmarkRepositoryNotReadyException`'s doc comment
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// for the read-vs-write split this mirrors: reads reuse the interface's own
/// empty-list value, writes have no such value to reuse and throw instead.
class StageDefinitionRepositoryNotReadyException implements Exception {
  const StageDefinitionRepositoryNotReadyException();

  @override
  String toString() =>
      'StageDefinitionRepositoryNotReadyException: '
      'firestoreStageDefinitionRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet) — cannot complete '
      'a stage-definitions write until one is active.';
}

/// Firestore-backed [StageDefinitionRepository] adapter — second application
/// of the pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// establishes; read that class's doc comment first. This one only
/// calls out what is DIFFERENT for stage definitions.
///
/// ## `null` → the interface's own empty value, not a sentinel
///
/// Every read method here ([getStagesForCurriculum], [getAllStageDefinitions])
/// already returns a `List`, which has an honest "nothing yet" value of its
/// own — `[]` — so "not ready" reuses that exactly the way
/// `FirestoreBookmarkRepositoryAdapter.getBookmark` reuses `null`. The write
/// methods ([initializeDefaults], [resetToDefaults]) have no such value and
/// throw [StageDefinitionRepositoryNotReadyException] instead.
///
/// ## Two methods have no honest Firestore mapping at all — not "not ready",
/// permanently unsupported
///
/// [getStagesByTrack] and [deleteStagesForTrack] both take ONLY a
/// Drift-local `int trackId` — no [CurriculumId] — and
/// `FirestoreStageDefinitionRepository`'s own class doc comment explains why
/// it dropped both: AD-25 retired the per-device track id as this
/// collection's key entirely, `curriculum_id` is the sole canonical stable
/// key post-rewrite, and there is no Drift-free way inside this adapter to
/// resolve a bare `trackId` back to the `curriculumId` it belongs to. Unlike
/// [hasCompletionsForStage] (a genuine "not built yet" gap — see below),
/// this is not something a future task can simply implement: the
/// information the method needs (a curriculum-scoped view of a Drift-local
/// integer) does not exist on the Firestore side by design. Both throw
/// [UnimplementedError] unconditionally — this is a permanent limitation of
/// the target architecture, not a not-ready state, so it is not gated behind
/// [_resolve].
///
/// ## [hasCompletionsForStage] — propagated, not re-solved
///
/// `FirestoreStageDefinitionRepository.hasCompletionsForStage` itself throws
/// [UnimplementedError] — not because a Firestore completions repository is
/// missing (`FirestoreCompletionRepository.hasCompletionsForStage({curriculumId,
/// stageOrder})` now exists and runs exactly this query), but because
/// `stageId` here is a Drift-only concept a real Firestore stage has no
/// integer row id for (see `kFirestoreUnmappedStageId`'s doc comment), with
/// no way to translate it into the `(curriculumId, stageOrder)` pair that
/// repository needs.
/// This method still resolves the provider first ([_resolve], which throws
/// [StageDefinitionRepositoryNotReadyException] when not ready) before
/// delegating, so a genuinely not-ready caller sees that exception rather
/// than the permanently-unimplemented one — but once ready, the
/// [UnimplementedError] propagates unchanged.
///
/// ## [pushStagesForTrack] — no-op, not unsupported
///
/// The Drift-era push-pipeline step ("flush the local write to Firestore")
/// has nothing left to flush here: [initializeDefaults]/[resetToDefaults]
/// already write straight to Firestore. Silently succeeding, not throwing,
/// since callers (e.g. `TrackCreationService.createTrack`) treat it as a
/// fire-and-forget step, not a not-ready-sensitive write.
class FirestoreStageDefinitionRepositoryAdapter
    implements StageDefinitionRepository {
  FirestoreStageDefinitionRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreStageDefinitionRepositoryProvider`, resolving to
  /// `null` exactly when it does (no active account, or no active learner
  /// profile). See `FirestoreBookmarkRepositoryAdapter._resolveOrNull`'s doc
  /// comment for why this re-reads on every call rather than caching.
  Future<FirestoreStageDefinitionRepository?> _resolveOrNull() {
    return _ref.read(firestoreStageDefinitionRepositoryProvider.future);
  }

  /// Like [_resolveOrNull], but throws
  /// [StageDefinitionRepositoryNotReadyException] instead of returning
  /// `null` — for the write methods and [hasCompletionsForStage], which
  /// (once ready) delegates to an always-throwing method of its own; see
  /// the class doc comment.
  Future<FirestoreStageDefinitionRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const StageDefinitionRepositoryNotReadyException();
    }
    return repo;
  }

  @override
  /// Throws [StageDefinitionRepositoryNotReadyException] when the backend
  /// cannot be resolved (owner ruling D-E). It deliberately does NOT return an
  /// empty list: downstream, no stages means the completion calculation returns
  /// 0.0 (`track_progress_service.dart`, `dashboard_providers.dart` both
  /// `if (stages.isEmpty) return 0.0`), so an unresolvable repository rendered
  /// as **0% progress** — to the learner, to the logs, and to every gate,
  /// indistinguishable from a legitimately empty result.
  ///
  /// Note the sibling [_resolve] has always thrown: the WRITE path failed
  /// loudly while this READ path failed silently.
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final repo = await _resolve();
    return repo.getStagesForCurriculum(curriculumId);
  }

  @override
  Future<void> initializeDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  }) async {
    // profileId/trackId dropped — the resolved repository is already
    // profile-scoped (constructor-level), and AD-25 makes curriculumId the
    // sole canonical track key; see FirestoreStageDefinitionRepository's
    // class doc comment ("Kept, still flagged").
    final repo = await _resolve();
    await repo.initializeDefaults(curriculumId);
  }

  @override
  Future<void> resetToDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  }) async {
    final repo = await _resolve();
    // NOTE: unlike the Drift doc comment's "Removes all stages and restores
    // the 3 defaults", the resolved Firestore method can only OVERWRITE the
    // 3 default doc-ids in place — firestore.rules denies delete on this
    // collection. See FirestoreStageDefinitionRepository.resetToDefaults'
    // doc comment for the exact (rare) case this diverges from Drift.
    await repo.resetToDefaults(curriculumId);
  }

  @override
  Future<bool> hasCompletionsForStage(int stageId) async {
    final repo = await _resolve();
    // Always throws UnimplementedError once ready — see the class doc
    // comment's "hasCompletionsForStage" section.
    return repo.hasCompletionsForStage(stageId);
  }

  @override
  Future<List<StageDefinition>> getStagesByTrack(int trackId) {
    throw UnimplementedError(
      'StageDefinitionRepository.getStagesByTrack(int trackId) has no '
      'Firestore mapping: FirestoreStageDefinitionRepository dropped it '
      'outright (AD-25 retired the per-device trackId as this collection\'s '
      'key; curriculum_id is now the sole canonical key), and this adapter '
      'has no Drift-free way to resolve a bare trackId back to a '
      'curriculumId. Callers must migrate to getStagesForCurriculum '
      '(CurriculumId) instead. Known callers this breaks: '
      'CalendarPositionProviders, DashboardProviders, '
      'DailyTaskProjectionService (two call sites), TrackProgressService, '
      'PointConfigScreen (three call sites).',
    );
  }

  @override
  Future<void> deleteStagesForTrack(int trackId) {
    throw UnimplementedError(
      'StageDefinitionRepository.deleteStagesForTrack(int trackId) has no '
      'Firestore mapping — same AD-25 gap as getStagesByTrack: no '
      'trackId->curriculumId resolution is available here. Known caller '
      'this breaks: TrackCreationService.createTrack\'s stage-reseed step '
      '(it deletes then reseeds stages for a possibly-restored track).',
    );
  }

  @override
  Future<void> pushStagesForTrack({
    required int trackId,
    required CurriculumId curriculumId,
  }) async {
    // No-op — see the class doc comment's "pushStagesForTrack" section.
  }

  @override
  /// Throws [StageDefinitionRepositoryNotReadyException] when the backend
  /// cannot be resolved — see [getStagesForCurriculum] for why an empty list is
  /// the wrong answer here (D-E).
  Future<List<StageDefinition>> getAllStageDefinitions() async {
    final repo = await _resolve();
    return repo.getAllStageDefinitions();
  }
}
