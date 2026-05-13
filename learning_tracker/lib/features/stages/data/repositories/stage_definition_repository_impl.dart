import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/stage_limit_exceeded_exception.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/stages/domain/services/stage_validator.dart';

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
    ScheduleType scheduleType = ScheduleType.delay,
    List<int>? daysOfWeek,
    int? rollingWindowSize,
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

    // Validate the stage definition before persisting.
    final candidate = StageDefinition(
      id: 0,
      curriculumId: curriculumId,
      stageOrder: newOrder,
      stageName: name,
      delayDays: delayDays,
      isDefault: false,
      scheduleType: scheduleType,
      daysOfWeek: daysOfWeek,
      rollingWindowSize: rollingWindowSize,
    );
    final validationError = StageValidator.validate(candidate);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final id = await _stageDao.insertStageDefinition(
      db.StageDefinitionsCompanion.insert(
        profileId: 0, // TODO(DNI-322): wire real profileId from caller
        curriculumId: curriculumId.storageKey,
        trackId: trackId,
        stageOrder: newOrder,
        stageName: name,
        delayDays: delayDays,
        isDefault: const Value(false),
        scheduleType: Value(scheduleType.storageKey),
        daysOfWeek: Value(daysOfWeek != null ? jsonEncode(daysOfWeek) : null),
        rollingWindowSize: Value(rollingWindowSize),
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

    final curriculumId = _curriculumFromStorageKey(existing.curriculumId);

    // Validate the updated stage definition.
    final candidate = StageDefinition(
      id: id,
      curriculumId: curriculumId,
      stageOrder: existing.stageOrder,
      stageName: name ?? existing.stageName,
      delayDays: delayDays ?? existing.delayDays,
      isDefault: existing.isDefault,
      scheduleType: ScheduleType.fromStorageKey(existing.scheduleType),
      daysOfWeek: existing.daysOfWeek != null
          ? (jsonDecode(existing.daysOfWeek!) as List).cast<int>()
          : null,
      rollingWindowSize: existing.rollingWindowSize,
    );
    final validationError = StageValidator.validate(candidate);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

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
    // Guard: Learn stage (stageOrder == 1) must remain at position 1.
    // Fetch the current Learn stage for this curriculum.
    final allStages = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    final learnStage = allStages.isNotEmpty
        ? allStages.firstWhere(
            (s) => s.stageOrder == 1,
            orElse: () => allStages.first,
          )
        : null;
    if (learnStage != null &&
        orderedIds.isNotEmpty &&
        orderedIds.first != learnStage.id) {
      throw const ProtectedStageException();
    }

    // Run the two-pass reorder inside a single transaction so a mid-loop
    // failure leaves all stages at their original positions.
    await _stageDao.runTransaction(() async {
      // Pass 1: set all to negative temporary orders to avoid UNIQUE
      // constraint violations on (curriculumId, stageOrder).
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
    });
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
      'updated_at': DateTimeFactory.nowUtc().toIso8601String(),
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
