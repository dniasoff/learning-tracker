import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart'
    as content_db;
import 'package:learning_tracker/core/database/content/daos/learning_program_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/database/daos/profile_program_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

/// Result of the learning process wizard for a single curriculum.
class WizardResult {
  const WizardResult({
    required this.curriculumId,
    required this.choice,
    this.programId,
    this.customRounds,
  });

  final CurriculumId curriculumId;
  final WizardChoice choice;

  /// Non-null when choice == preset.
  final int? programId;

  /// Non-null when choice == custom.
  final List<CustomRound>? customRounds;
}

enum WizardChoice { preset, custom, noReview }

/// A single custom chazarah round definition.
class CustomRound {
  const CustomRound({
    required this.label,
    required this.scheduleType,
    this.delayDays,
    this.daysOfWeek,
  });

  final String label;
  final ScheduleType scheduleType;
  final int? delayDays;
  final List<int>? daysOfWeek;
}

/// Orchestrates stage creation based on wizard selections.
///
/// Three paths:
/// 1. Preset — look up program stages_config, create stages from it
/// 2. Custom — create Learn + N custom chazarah rounds
/// 3. No review — create Learn stage only
class LearningProcessWizardService {
  LearningProcessWizardService({
    required StageDao stageDao,
    required ContentLearningProgramDao learningProgramDao,
    required ProfileProgramDao profileProgramDao,
  }) : _stageDao = stageDao,
       _learningProgramDao = learningProgramDao,
       _profileProgramDao = profileProgramDao;

  final StageDao _stageDao;
  final ContentLearningProgramDao _learningProgramDao;
  final ProfileProgramDao _profileProgramDao;

  /// Get active programs filtered by curriculum type.
  Future<List<content_db.LearningProgram>> getPresetsForCurriculum(
    CurriculumId curriculumId,
  ) {
    return _learningProgramDao.getProgramsByCurriculumType(
      curriculumId.storageKey,
    );
  }

  /// Apply the wizard result — creates stages for the curriculum.
  ///
  /// [profileId] identifies the profile to associate with the preset program.
  Future<void> applyWizardResult(
    WizardResult result, {
    required int profileId,
  }) async {
    // Clear any existing stages for this curriculum first.
    await _stageDao.deleteAllForCurriculum(result.curriculumId.storageKey);

    switch (result.choice) {
      case WizardChoice.preset:
        await _applyPreset(result, profileId: profileId);
      case WizardChoice.custom:
        await _applyCustom(result);
      case WizardChoice.noReview:
        await _applyNoReview(result);
    }
  }

  Future<void> _applyPreset(
    WizardResult result, {
    required int profileId,
  }) async {
    final program = await _learningProgramDao.getProgramById(result.programId!);
    if (program == null) return;

    // Store the preset association.
    await _profileProgramDao.setProfileProgram(
      profileId: profileId,
      curriculumType: result.curriculumId.storageKey,
      programId: program.id,
    );

    // Parse stages_config JSON and create stage definitions.
    final stages = (jsonDecode(program.stagesConfig) as List)
        .cast<Map<String, dynamic>>();
    for (var i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final scheduleType = _parseScheduleType(stage);
      final daysOfWeek = stage['days'] != null
          ? _parseDaysOfWeek(stage['days'] as List)
          : null;

      await _stageDao.insertStageDefinition(
        db.StageDefinitionsCompanion.insert(
          curriculumId: result.curriculumId.storageKey,
          stageOrder: i + 1,
          stageName: stage['label'] as String,
          delayDays: (stage['delay_days'] as int?) ?? 0,
          isDefault: const Value(false),
          scheduleType: Value(scheduleType.storageKey),
          daysOfWeek: Value(daysOfWeek != null ? jsonEncode(daysOfWeek) : null),
          rollingWindowSize: Value(stage['window'] as int?),
        ),
      );
    }
  }

  Future<void> _applyCustom(WizardResult result) async {
    // Always create לימוד as stage 1.
    await _stageDao.insertStageDefinition(
      db.StageDefinitionsCompanion.insert(
        curriculumId: result.curriculumId.storageKey,
        stageOrder: 1,
        stageName: 'לימוד',
        delayDays: 0,
        isDefault: const Value(false),
      ),
    );

    // Create custom chazarah rounds.
    final rounds = result.customRounds ?? [];
    for (var i = 0; i < rounds.length; i++) {
      final round = rounds[i];
      await _stageDao.insertStageDefinition(
        db.StageDefinitionsCompanion.insert(
          curriculumId: result.curriculumId.storageKey,
          stageOrder: i + 2,
          stageName: round.label,
          delayDays: round.delayDays ?? 0,
          isDefault: const Value(false),
          scheduleType: Value(round.scheduleType.storageKey),
          daysOfWeek: Value(
            round.daysOfWeek != null ? jsonEncode(round.daysOfWeek) : null,
          ),
        ),
      );
    }
  }

  Future<void> _applyNoReview(WizardResult result) async {
    await _stageDao.insertStageDefinition(
      db.StageDefinitionsCompanion.insert(
        curriculumId: result.curriculumId.storageKey,
        stageOrder: 1,
        stageName: 'לימוד',
        delayDays: 0,
        isDefault: const Value(false),
      ),
    );
  }

  ScheduleType _parseScheduleType(Map<String, dynamic> stage) {
    final type = stage['type'] as String?;
    if (type == 'rolling') return ScheduleType.rolling;
    final frequency = stage['frequency'] as String?;
    if (frequency == 'weekly') return ScheduleType.weekly;
    return ScheduleType.delay;
  }

  /// Convert day name strings to day-of-week integers (1=Monday, 7=Sunday).
  List<int> _parseDaysOfWeek(List<dynamic> days) {
    const dayMap = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'shabbos': 6,
      'saturday': 6,
      'sunday': 7,
    };
    return days.map((d) => dayMap[(d as String).toLowerCase()] ?? 1).toList();
  }
}
