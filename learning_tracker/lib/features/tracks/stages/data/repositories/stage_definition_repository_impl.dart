import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// Default stage definitions (לימוד, חזרה א׳, חזרה ב׳).
const _defaults = [
  (stageOrder: 1, stageName: kLimudStageName, delayDays: 0),
  (stageOrder: 2, stageName: 'חזרה א׳', delayDays: 1),
  (stageOrder: 3, stageName: 'חזרה ב׳', delayDays: 7),
];

/// Signature for the dedicated stage-definitions push path used by
/// [StageDefinitionRepositoryImpl] (Plan §F Phase 5 deliverable 6).
///
/// Each stage in [stages] is a fully-formed payload (`stage_order`,
/// `stage_name`, `schedule`, …). The implementation routes the call to the
/// outbox with kind=`stage_definition` so the `PushPipeline.pushStageDefinition`
/// gateway method writes deterministic `{trackId}_{stageOrder}` doc ids —
/// replaces the legacy `pushSettings` piggyback route.
typedef PushStageDefinitionsFn =
    Future<void> Function({
      required int trackId,
      required String curriculumId,
      required List<Map<String, dynamic>> stages,
      required DateTime updatedAt,
    });

/// Concrete implementation of [StageDefinitionRepository].
///
/// Uses Drift [StageDao] for local persistence and calls a Firestore push
/// callback after every mutation (same pattern as CurriculumActivationService).
///
/// W3.27: reads/writes the single JSON `schedule` column instead of the
/// former quartet (scheduleType / delayDays / daysOfWeek / rollingWindowSize).
/// The [StageDefinition] domain model still carries the quartet fields so that
/// all downstream consumers (validator, scheduler, UI) remain unaffected.
///
/// Plan §F Phase 5 deliverable 6 — the push path now routes through the
/// dedicated `stage_definition` outbox kind (`pushStageDefinitions`), not
/// the legacy `pushSettings` piggyback. The old constructor parameter has
/// been removed; the only push contract is the [pushStageDefinitions] fn.
class StageDefinitionRepositoryImpl implements StageDefinitionRepository {
  StageDefinitionRepositoryImpl({
    required StageDao stageDao,
    required CompletionDao completionDao,
    required PushStageDefinitionsFn? pushStageDefinitions,
  }) : _stageDao = stageDao,
       _completionDao = completionDao,
       _pushStageDefinitions = pushStageDefinitions;

  final StageDao _stageDao;
  final CompletionDao _completionDao;
  final PushStageDefinitionsFn? _pushStageDefinitions;

  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final rows = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    return rows.map(_rowToModel).toList();
  }

  // AUD-tracks-12: addStage/updateStage/deleteStage/reorderStages were
  // removed here — zero UI callers (repo-wide grep); the live
  // stage-configuration path is the chazara wizard's
  // LearningProcessWizardService.applyWizardResult. The
  // ProtectedStageException/StageLimitExceededException leaf exceptions
  // these methods threw were deleted as part of the same fix since they had
  // no other callers. StageValidator (which addStage/updateStage used to
  // consult) is kept — unlike the exceptions, it has independent acceptance
  // coverage decoupled from this repository
  // (test/story_acceptance/epic_15_multi_profile_test.dart, group "AC:
  // Stage validation -- each type requires its specific fields").

  @override
  Future<void> initializeDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  }) async {
    final existing = await _stageDao.getStagesByTrack(trackId);
    if (existing.isNotEmpty) return;

    for (final d in _defaults) {
      await _stageDao.insertStageDefinition(
        db.StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
          stageOrder: d.stageOrder,
          stageName: d.stageName,
          isDefault: const Value(true),
          schedule: Value(_encodeSchedule(DelaySchedule(d.delayDays))),
        ),
      );
    }
  }

  @override
  Future<void> resetToDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  }) async {
    // R6-12: use track-scoped delete so other profiles' stage definitions for
    // the same curriculum are not affected.
    await _stageDao.deleteStagesForTrack(trackId);
    for (final d in _defaults) {
      await _stageDao.insertStageDefinition(
        db.StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
          stageOrder: d.stageOrder,
          stageName: d.stageName,
          isDefault: const Value(true),
          schedule: Value(_encodeSchedule(DelaySchedule(d.delayDays))),
        ),
      );
    }
    await _pushStages(curriculumId);
  }

  @override
  Future<bool> hasCompletionsForStage(int stageId) =>
      _completionDao.hasCompletionsForStage(stageId);

  @override
  Future<List<StageDefinition>> getStagesByTrack(int trackId) async {
    final rows = await _stageDao.getStagesByTrack(trackId);
    return rows.map(_rowToModel).toList();
  }

  @override
  Future<void> deleteStagesForTrack(int trackId) async {
    // No pushSettings call here — callers (track creation/deletion) are
    // responsible for syncing after the full replacement is complete.
    await _stageDao.deleteStagesForTrack(trackId);
  }

  @override
  Future<List<StageDefinition>> getAllStageDefinitions() async {
    final rows = await _stageDao.getAllStageDefinitions();
    return rows.map(_rowToModel).toList();
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Decode the JSON `schedule` column into a [ScheduleSpec].
  ///
  /// Accepts both the canonical long-form keys (`days_of_week`,
  /// `rolling_window_size`) and the old short-form keys (`days`, `window_size`)
  /// for backwards-compat with rows written before W3.27 standardised the names.
  static ScheduleSpec _decodeSchedule(String scheduleJson) {
    try {
      final map = jsonDecode(scheduleJson) as Map<String, dynamic>;
      final type = map['type'] as String? ?? 'delay';
      return switch (type) {
        'weekly' => ScheduleSpec.weekly(
          ((map['days_of_week'] ?? map['days']) as List<dynamic>? ?? [])
              .cast<int>(),
        ),
        'rolling' => ScheduleSpec.rolling(
          ((map['rolling_window_size'] ?? map['window_size']) as num? ?? 1)
              .toInt(),
        ),
        _ => ScheduleSpec.delay((map['delay_days'] as num? ?? 0).toInt()),
      };
    } catch (_) {
      return const DelaySchedule(0);
    }
  }

  /// Encode a [ScheduleSpec] to the JSON string stored in the `schedule` column.
  ///
  /// Uses the canonical long-form key names (`days_of_week`,
  /// `rolling_window_size`) so that tests and Firestore readers see consistent
  /// field names.
  static String _encodeSchedule(ScheduleSpec spec) => switch (spec) {
    WeeklySchedule(:final daysOfWeek) => jsonEncode({
      'type': 'weekly',
      'days_of_week': daysOfWeek,
    }),
    RollingSchedule(:final windowSize) => jsonEncode({
      'type': 'rolling',
      'rolling_window_size': windowSize,
    }),
    DelaySchedule(:final delayDays) => jsonEncode({
      'type': 'delay',
      'delay_days': delayDays,
    }),
  };

  StageDefinition _rowToModel(db.StageDefinition row) {
    final spec = _decodeSchedule(row.schedule);
    return StageDefinition(
      id: row.id,
      curriculumId: _curriculumFromStorageKey(row.curriculumId),
      stageOrder: row.stageOrder,
      stageName: row.stageName,
      delayDays: spec.delayDays,
      isDefault: row.isDefault,
      scheduleType: ScheduleType.fromStorageKey(spec.storageKey),
      daysOfWeek: spec.daysOfWeek,
      rollingWindowSize: spec.rollingWindowSize,
    );
  }

  CurriculumId _curriculumFromStorageKey(String key) =>
      CurriculumId.values.firstWhere((c) => c.storageKey == key);

  static const _codec = StageDefinitionCodec();

  @override
  Future<void> pushStagesForTrack({
    required int trackId,
    required CurriculumId curriculumId,
  }) async {
    final push = _pushStageDefinitions;
    if (push == null) return;

    final stages = await _stageDao.getStagesByTrack(trackId);
    if (stages.isEmpty) return;

    final now = DateTimeFactory.nowUtc();
    final stagePayloads = stages
        .map((s) => _stagePushPayload(s, curriculumId, now))
        .toList();
    await push(
      trackId: trackId,
      curriculumId: curriculumId.storageKey,
      stages: stagePayloads,
      updatedAt: now,
    );
  }

  Future<void> _pushStages(CurriculumId curriculumId) async {
    final push = _pushStageDefinitions;
    if (push == null) return;

    final stages = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    if (stages.isEmpty) return;

    // All stages in a curriculum share the same trackId (one track per
    // curriculum per profile post-W3.22). Pick the first row's trackId.
    final trackId = stages.first.trackId;
    final now = DateTimeFactory.nowUtc();
    final stagePayloads = stages
        .map((s) => _stagePushPayload(s, curriculumId, now))
        .toList();

    await push(
      trackId: trackId,
      curriculumId: curriculumId.storageKey,
      stages: stagePayloads,
      updatedAt: now,
    );
  }

  /// Builds the Firestore push payload for one stage row via the canonical
  /// [StageDefinitionCodec].
  ///
  /// Phase B unification: routes through [StageDefinitionCodec.encode] so the
  /// push shape is identical to the codec's canonical write shape (schedule as
  /// a JSON String, no legacy quartet). The facade's [pushStageDefinitions]
  /// method redundantly spreads `track_id`, `curriculum_id`, and `updated_at`
  /// on top — those are already present and match, so the spread is a no-op.
  static Map<String, dynamic> _stagePushPayload(
    db.StageDefinition s,
    CurriculumId curriculumId,
    DateTime updatedAt,
  ) {
    return _codec.encode(
      StageDefinitionRow(
        curriculumId: curriculumId.storageKey,
        trackId: s.trackId,
        stageOrder: s.stageOrder,
        stageName: s.stageName,
        schedule: s.schedule,
        isDefault: s.isDefault,
        updatedAt: updatedAt,
      ),
    );
  }
}

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
/// establishes; read that class's doc comment first. This one only calls
/// out what is DIFFERENT for stage definitions.
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
