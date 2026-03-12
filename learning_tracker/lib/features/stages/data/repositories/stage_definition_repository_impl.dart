import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart' as db;
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/stage_limit_exceeded_exception.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/stages/domain/repositories/stage_definition_repository.dart';

/// Maximum number of stages allowed per curriculum.
const _maxStages = 10;

/// Default stage definitions (Learn, Chazara 1, Chazara 2).
const _defaults = [
  (stageOrder: 1, stageName: 'Learn', delayDays: 0),
  (stageOrder: 2, stageName: 'Chazara 1', delayDays: 1),
  (stageOrder: 3, stageName: 'Chazara 2', delayDays: 7),
];

/// Concrete implementation of [StageDefinitionRepository].
///
/// Uses Drift [StageDao] for local persistence and calls a Firestore push
/// callback after every mutation (same pattern as CurriculumActivationService).
class StageDefinitionRepositoryImpl implements StageDefinitionRepository {
  StageDefinitionRepositoryImpl({
    required StageDao stageDao,
    required CompletionDao completionDao,
    required Future<void> Function(Map<String, dynamic>) pushSettings,
  }) : _stageDao = stageDao,
       _completionDao = completionDao,
       _pushSettings = pushSettings;

  final StageDao _stageDao;
  final CompletionDao _completionDao;
  final Future<void> Function(Map<String, dynamic>) _pushSettings;

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
    int delayDays,
  ) async {
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
        curriculumId: curriculumId.storageKey,
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
        curriculumId: Value(existing.curriculumId),
        stageOrder: Value(existing.stageOrder),
        stageName: Value(name ?? existing.stageName),
        delayDays: Value(delayDays ?? existing.delayDays),
        isDefault: Value(existing.isDefault),
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
          curriculumId: Value(existing.curriculumId),
          stageOrder: Value(-(i + 1)),
          stageName: Value(existing.stageName),
          delayDays: Value(existing.delayDays),
          isDefault: Value(existing.isDefault),
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
          curriculumId: Value(existing.curriculumId),
          stageOrder: Value(i + 1),
          stageName: Value(existing.stageName),
          delayDays: Value(existing.delayDays),
          isDefault: Value(existing.isDefault),
        ),
      );
    }
    await _pushStages(curriculumId);
  }

  @override
  Future<void> initializeDefaults(CurriculumId curriculumId) async {
    final existing = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    if (existing.isNotEmpty) return;

    for (final d in _defaults) {
      await _stageDao.insertStageDefinition(
        db.StageDefinitionsCompanion.insert(
          curriculumId: curriculumId.storageKey,
          stageOrder: d.stageOrder,
          stageName: d.stageName,
          delayDays: d.delayDays,
          isDefault: const Value(true),
        ),
      );
    }
  }

  @override
  Future<void> resetToDefaults(CurriculumId curriculumId) async {
    await _stageDao.deleteAllForCurriculum(curriculumId.storageKey);
    for (final d in _defaults) {
      await _stageDao.insertStageDefinition(
        db.StageDefinitionsCompanion.insert(
          curriculumId: curriculumId.storageKey,
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
    );
  }

  CurriculumId _curriculumFromStorageKey(String key) =>
      CurriculumId.values.firstWhere((c) => c.storageKey == key);

  Future<void> _pushStages(CurriculumId curriculumId) async {
    final stages = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    await _pushSettings({
      'curriculum_id': curriculumId.storageKey,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'stages': stages
          .map(
            (s) => {
              'stage_order': s.stageOrder,
              'stage_name': s.stageName,
              'delay_days': s.delayDays,
              'is_default': s.isDefault,
            },
          )
          .toList(),
    });
  }
}
