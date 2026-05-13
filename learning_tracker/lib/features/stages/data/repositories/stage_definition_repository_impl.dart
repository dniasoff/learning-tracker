import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/stage_limit_exceeded_exception.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/stages/domain/repositories/stage_definition_repository.dart';

/// Maximum number of stages allowed per curriculum.
const _maxStages = 10;

/// Default stage definitions (לימוד, חזרה א׳, חזרה ב׳).
const _defaults = [
  (stageOrder: 1, stageName: 'לימוד', delayDays: 0),
  (stageOrder: 2, stageName: 'חזרה א׳', delayDays: 1),
  (stageOrder: 3, stageName: 'חזרה ב׳', delayDays: 7),
];

/// Concrete implementation of [StageDefinitionRepository].
///
/// Uses Drift [StageDao] for local persistence and calls a Firestore push
/// callback after every mutation (same pattern as CurriculumActivationService).
class StageDefinitionRepositoryImpl implements StageDefinitionRepository {
  StageDefinitionRepositoryImpl({
    required StageDao stageDao,
    required CompletionDao completionDao,
    required Future<void> Function(Map<String, dynamic>)? pushSettings,
  }) : _stageDao = stageDao,
       _completionDao = completionDao,
       _pushSettings = pushSettings;

  final StageDao _stageDao;
  final CompletionDao _completionDao;
  final Future<void> Function(Map<String, dynamic>)? _pushSettings;

  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final rows = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    return rows.map(_rowToModel).toList();
  }

  @override
  Future<StageDefinition> addStage(
    CurriculumId curriculumId,
    String name,
    int delayDays, {
    required int trackId,
  }) async {
    final count = await _stageDao.countStagesForCurriculum(
      curriculumId.storageKey,
    );
    if (count >= _maxStages) {
      throw const StageLimitExceededException(maxStages: _maxStages);
    }

    final maxOrder =
        await _stageDao.getMaxStageOrder(curriculumId.storageKey) ?? 0;
    final newOrder = maxOrder + 1;

    final id = await _stageDao.insertStageDefinition(
      db.StageDefinitionsCompanion.insert(
        profileId: 0, // TODO(DNI-322): wire real profileId from caller
        curriculumId: curriculumId.storageKey,
        trackId: trackId,
        stageOrder: newOrder,
        stageName: name,
        delayDays: delayDays,
        isDefault: const Value(false),
      ),
    );

    await _pushStages(curriculumId);

    final row = await _stageDao.getStageDefinitionById(id);
    return _rowToModel(row!);
  }

  @override
  Future<void> updateStage(int id, {String? name, int? delayDays}) async {
    final existing = await _stageDao.getStageDefinitionById(id);
    if (existing == null) return;

    await _stageDao.updateStageDefinition(
      db.StageDefinitionsCompanion(
        id: Value(id),
        profileId: Value(existing.profileId),
        curriculumId: Value(existing.curriculumId),
        trackId: Value(existing.trackId),
        stageOrder: Value(existing.stageOrder),
        stageName: Value(name ?? existing.stageName),
        delayDays: Value(delayDays ?? existing.delayDays),
        isDefault: Value(existing.isDefault),
        scheduleType: Value(existing.scheduleType),
        daysOfWeek: Value(existing.daysOfWeek),
        rollingWindowSize: Value(existing.rollingWindowSize),
      ),
    );

    final curriculumId = _curriculumFromStorageKey(existing.curriculumId);
    await _pushStages(curriculumId);
  }

  @override
  Future<void> deleteStage(int id) async {
    final existing = await _stageDao.getStageDefinitionById(id);
    if (existing == null) return;

    if (existing.stageOrder == 1) {
      throw const ProtectedStageException();
    }

    await _stageDao.deleteStageDefinition(id);

    final curriculumId = _curriculumFromStorageKey(existing.curriculumId);
    await _pushStages(curriculumId);
  }

  @override
  Future<void> reorderStages(
    CurriculumId curriculumId,
    List<int> orderedIds,
  ) async {
    // Two-pass to avoid UNIQUE constraint on (curriculumId, stageOrder).
    // Pass 1: set all to negative temporary orders.
    for (var i = 0; i < orderedIds.length; i++) {
      final stageId = orderedIds[i];
      final existing = await _stageDao.getStageDefinitionById(stageId);
      if (existing == null) continue;
      await _stageDao.updateStageDefinition(
        db.StageDefinitionsCompanion(
          id: Value(stageId),
          profileId: Value(existing.profileId),
          curriculumId: Value(existing.curriculumId),
          trackId: Value(existing.trackId),
          stageOrder: Value(-(i + 1)),
          stageName: Value(existing.stageName),
          delayDays: Value(existing.delayDays),
          isDefault: Value(existing.isDefault),
          scheduleType: Value(existing.scheduleType),
          daysOfWeek: Value(existing.daysOfWeek),
          rollingWindowSize: Value(existing.rollingWindowSize),
        ),
      );
    }
    // Pass 2: set to final positive orders.
    for (var i = 0; i < orderedIds.length; i++) {
      final stageId = orderedIds[i];
      final existing = await _stageDao.getStageDefinitionById(stageId);
      if (existing == null) continue;
      await _stageDao.updateStageDefinition(
        db.StageDefinitionsCompanion(
          id: Value(stageId),
          profileId: Value(existing.profileId),
          curriculumId: Value(existing.curriculumId),
          trackId: Value(existing.trackId),
          stageOrder: Value(i + 1),
          stageName: Value(existing.stageName),
          delayDays: Value(existing.delayDays),
          isDefault: Value(existing.isDefault),
          scheduleType: Value(existing.scheduleType),
          daysOfWeek: Value(existing.daysOfWeek),
          rollingWindowSize: Value(existing.rollingWindowSize),
        ),
      );
    }
    await _pushStages(curriculumId);
  }

  @override
  Future<void> initializeDefaults(
    CurriculumId curriculumId, {
    required int trackId,
  }) async {
    final existing = await _stageDao.getStagesByTrack(trackId);
    if (existing.isNotEmpty) return;

    for (final d in _defaults) {
      await _stageDao.insertStageDefinition(
        db.StageDefinitionsCompanion.insert(
          profileId: 0, // TODO(DNI-322): wire real profileId from caller
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
          stageOrder: d.stageOrder,
          stageName: d.stageName,
          delayDays: d.delayDays,
          isDefault: const Value(true),
        ),
      );
    }
  }

  @override
  Future<void> resetToDefaults(
    CurriculumId curriculumId, {
    required int trackId,
  }) async {
    await _stageDao.deleteAllForCurriculum(curriculumId.storageKey);
    for (final d in _defaults) {
      await _stageDao.insertStageDefinition(
        db.StageDefinitionsCompanion.insert(
          profileId: 0, // TODO(DNI-322): wire real profileId from caller
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
          stageOrder: d.stageOrder,
          stageName: d.stageName,
          delayDays: d.delayDays,
          isDefault: const Value(true),
        ),
      );
    }
    await _pushStages(curriculumId);
  }

  @override
  Future<bool> hasCompletionsForStage(int stageId) =>
      _completionDao.hasCompletionsForStage(stageId);

  // ── Private helpers ──────────────────────────────────────────────────────

  StageDefinition _rowToModel(db.StageDefinition row) {
    return StageDefinition(
      id: row.id,
      curriculumId: _curriculumFromStorageKey(row.curriculumId),
      stageOrder: row.stageOrder,
      stageName: row.stageName,
      delayDays: row.delayDays,
      isDefault: row.isDefault,
      scheduleType: ScheduleType.fromStorageKey(row.scheduleType),
      daysOfWeek: row.daysOfWeek != null
          ? (jsonDecode(row.daysOfWeek!) as List).cast<int>()
          : null,
      rollingWindowSize: row.rollingWindowSize,
    );
  }

  CurriculumId _curriculumFromStorageKey(String key) =>
      CurriculumId.values.firstWhere((c) => c.storageKey == key);

  Future<void> _pushStages(CurriculumId curriculumId) async {
    final stages = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    await _pushSettings?.call({
      'curriculum_id': curriculumId.storageKey,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'stages': stages
          .map(
            (s) => {
              'stage_order': s.stageOrder,
              'stage_name': s.stageName,
              'delay_days': s.delayDays,
              'is_default': s.isDefault,
              'schedule_type': s.scheduleType,
              if (s.daysOfWeek != null) 'days_of_week': s.daysOfWeek,
              if (s.rollingWindowSize != null)
                'rolling_window_size': s.rollingWindowSize,
            },
          )
          .toList(),
    });
  }
}
