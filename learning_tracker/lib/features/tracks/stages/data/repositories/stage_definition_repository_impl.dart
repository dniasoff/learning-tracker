import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/tracks/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/tracks/stages/domain/exceptions/stage_limit_exceeded_exception.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/services/stage_validator.dart';

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
///
/// W3.27: reads/writes the single JSON `schedule` column instead of the
/// former quartet (scheduleType / delayDays / daysOfWeek / rollingWindowSize).
/// The [StageDefinition] domain model still carries the quartet fields so that
/// all downstream consumers (validator, scheduler, UI) remain unaffected.
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
    String name, {
    required int profileId,
    required int trackId,
    ScheduleSpec schedule = const DelaySchedule(0),
  }) async {
    final count = await _stageDao.countStagesForCurriculum(
      curriculumId.storageKey,
    );
    if (count >= _maxStages) {
      throw StageLimitExceededException(maxStages: _maxStages);
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
      delayDays: schedule.delayDays,
      isDefault: false,
      scheduleType: ScheduleType.fromStorageKey(schedule.storageKey),
      daysOfWeek: schedule.daysOfWeek,
      rollingWindowSize: schedule.rollingWindowSize,
    );
    final validationError = StageValidator.validate(candidate);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final id = await _stageDao.insertStageDefinition(
      db.StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId.storageKey,
        trackId: trackId,
        stageOrder: newOrder,
        stageName: name,
        isDefault: const Value(false),
        schedule: Value(_encodeSchedule(schedule)),
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
    final existingSpec = _decodeSchedule(existing.schedule);

    // Apply the delayDays update (only meaningful for DelaySchedule).
    final updatedSpec = delayDays != null
        ? DelaySchedule(delayDays)
        : existingSpec;

    // Validate the updated stage definition.
    final candidate = StageDefinition(
      id: id,
      curriculumId: curriculumId,
      stageOrder: existing.stageOrder,
      stageName: name ?? existing.stageName,
      delayDays: updatedSpec.delayDays,
      isDefault: existing.isDefault,
      scheduleType: ScheduleType.fromStorageKey(updatedSpec.storageKey),
      daysOfWeek: updatedSpec.daysOfWeek,
      rollingWindowSize: updatedSpec.rollingWindowSize,
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
        isDefault: Value(existing.isDefault),
        schedule: Value(_encodeSchedule(updatedSpec)),
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
            isDefault: Value(existing.isDefault),
            schedule: Value(existing.schedule),
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
            isDefault: Value(existing.isDefault),
            schedule: Value(existing.schedule),
          ),
        );
      }
    });
    await _pushStages(curriculumId);
  }

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
    await _stageDao.deleteAllForCurriculum(curriculumId.storageKey);
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

  Future<void> _pushStages(CurriculumId curriculumId) async {
    final stages = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    await _pushSettings?.call({
      'curriculum_id': curriculumId.storageKey,
      'updated_at': DateTimeFactory.nowUtc().toIso8601String(),
      'stages': stages.map((s) {
        final spec = _decodeSchedule(s.schedule);
        return {
          'stage_order': s.stageOrder,
          'stage_name': s.stageName,
          'schedule': jsonDecode(s.schedule),
          'is_default': s.isDefault,
          // Legacy fields for backwards-compat with old Firestore readers.
          'delay_days': spec.delayDays,
          'schedule_type': spec.storageKey,
          if (spec.daysOfWeek != null) 'days_of_week': spec.daysOfWeek,
          if (spec.rollingWindowSize != null)
            'rolling_window_size': spec.rollingWindowSize,
        };
      }).toList(),
    });
  }
}
