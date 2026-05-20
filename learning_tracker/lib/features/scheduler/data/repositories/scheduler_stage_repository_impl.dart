import 'dart:convert';

import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

/// Adapts [StageDao] for scheduler consumption.
///
/// W3.27: reads the JSON `schedule` column and expands it back into the
/// [SchedulerStage] quartet fields expected by the scheduler engine.
class SchedulerStageRepositoryImpl implements SchedulerStageRepository {
  SchedulerStageRepositoryImpl({required StageDao stageDao})
    : _stageDao = stageDao;

  final StageDao _stageDao;

  @override
  Future<List<SchedulerStage>> getStages(CurriculumId curriculumId) async {
    final rows = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    return rows.map(_rowToSchedulerStage).toList();
  }

  /// Decode the JSON `schedule` column and reconstruct a [SchedulerStage].
  static SchedulerStage _rowToSchedulerStage(db.StageDefinition r) {
    Map<String, dynamic> sched;
    try {
      sched = jsonDecode(r.schedule) as Map<String, dynamic>;
    } catch (_) {
      sched = {'type': 'delay', 'delay_days': 0};
    }

    final type = sched['type'] as String? ?? 'delay';
    final delayDays = (sched['delay_days'] as num?)?.toInt() ?? 0;
    // Accept both key variants: 'days_of_week' (wizard-created) and 'days'
    // (legacy/manual entries and seed data).
    final daysOfWeek =
        (sched['days_of_week'] as List?)?.cast<int>() ??
        (sched['days'] as List?)?.cast<int>();
    // Accept both key variants: 'rolling_window_size' (wizard-created) and
    // 'window_size' (legacy/manual entries).
    final rollingWindowSize =
        (sched['rolling_window_size'] as num?)?.toInt() ??
        (sched['window_size'] as num?)?.toInt();

    return SchedulerStage(
      id: r.id,
      stageOrder: r.stageOrder,
      stageName: r.stageName,
      delayDays: delayDays,
      scheduleType: ScheduleType.fromStorageKey(type),
      daysOfWeek: daysOfWeek,
      rollingWindowSize: rollingWindowSize,
    );
  }
}
