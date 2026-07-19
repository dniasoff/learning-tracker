import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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
