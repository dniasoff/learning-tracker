import 'dart:convert';

import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

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
    this.rollingWindowSize,
  });

  final String label;
  final ScheduleType scheduleType;
  final int? delayDays;
  final List<int>? daysOfWeek;
  final int? rollingWindowSize;
}

/// Orchestrates stage creation based on wizard selections.
///
/// Three paths:
/// 1. Preset — look up program stages_config, create stages from it
/// 2. Custom — create Learn + N custom chazarah rounds
/// 3. No review — create Learn stage only
///
/// AD-25: one track per curriculum, so [WizardResult.curriculumId] alone is
/// the target — there is no separate per-device track id to key stages on
/// any more (see [StageDefinitionRepository.replaceStagesForCurriculum]'s
/// doc comment).
class LearningProcessWizardService {
  LearningProcessWizardService({
    required StageDefinitionRepository stageRepository,
    required LearningProgramRepository learningProgramRepo,
    required ProfileProgramRepository profileProgramRepository,
  }) : _stageRepository = stageRepository,
       _learningProgramRepo = learningProgramRepo,
       _profileProgramRepository = profileProgramRepository;

  final StageDefinitionRepository _stageRepository;
  final LearningProgramRepository _learningProgramRepo;
  final ProfileProgramRepository _profileProgramRepository;

  /// Get active programs filtered by curriculum type.
  List<LearningProgramData> getPresetsForCurriculum(CurriculumId curriculumId) {
    return _learningProgramRepo.getProgramsByCurriculumType(
      curriculumId.storageKey,
    );
  }

  /// Apply the wizard result — replaces [result.curriculumId]'s stage set.
  ///
  /// Not atomic across the preset-program association write and the stage
  /// replacement (Firestore has no cross-collection transaction available
  /// here — see the module doc comment); the two run sequentially, program
  /// association first.
  Future<void> applyWizardResult(WizardResult result) async {
    final stages = switch (result.choice) {
      WizardChoice.preset => await _buildPresetStages(result),
      WizardChoice.custom => _buildCustomStages(result),
      WizardChoice.noReview => _buildNoReviewStages(result),
    };

    await _stageRepository.replaceStagesForCurriculum(
      result.curriculumId,
      stages,
    );
  }

  /// Stores the preset-program association (if [result.programId] resolves
  /// to a real program) and returns the stage rows to write.
  ///
  /// Returns an empty list (writing nothing) when [result.programId] does
  /// not resolve to a known program.
  Future<List<StageDefinition>> _buildPresetStages(WizardResult result) async {
    final program = _learningProgramRepo.getProgramById(result.programId!);
    if (program == null) return const [];

    await _profileProgramRepository.setProgram(
      curriculumId: result.curriculumId,
      programId: program.id,
    );

    // Parse stages_config JSON and build stage definitions.
    final stages = (jsonDecode(program.stagesConfig) as List)
        .cast<Map<String, dynamic>>();
    final definitions = <StageDefinition>[];
    for (var i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final scheduleType = _parseScheduleType(stage);
      final daysOfWeek = stage['days'] != null
          ? _parseDaysOfWeek(stage['days'] as List)
          : null;

      definitions.add(
        StageDefinition(
          curriculumId: result.curriculumId,
          stageOrder: i + 1,
          stageName: stage['label'] as String,
          delayDays: scheduleType == ScheduleType.delay
              ? ((stage['delay_days'] as int?) ?? 0)
              : 0,
          isDefault: false,
          scheduleType: scheduleType,
          daysOfWeek: daysOfWeek,
          rollingWindowSize: scheduleType == ScheduleType.rolling
              ? ((stage['window'] as int?) ?? 7)
              : null,
        ),
      );
    }
    return definitions;
  }

  /// Builds the stage rows for a custom wizard result (לימוד + N custom
  /// chazarah rounds).
  List<StageDefinition> _buildCustomStages(WizardResult result) {
    final definitions = <StageDefinition>[
      StageDefinition(
        curriculumId: result.curriculumId,
        stageOrder: 1,
        stageName: kLimudStageName,
        delayDays: 0,
        isDefault: false,
      ),
    ];

    // Custom chazarah rounds.
    final rounds = result.customRounds ?? [];
    for (var i = 0; i < rounds.length; i++) {
      final round = rounds[i];
      definitions.add(
        StageDefinition(
          curriculumId: result.curriculumId,
          stageOrder: i + 2,
          stageName: round.label,
          delayDays: round.scheduleType == ScheduleType.delay
              ? (round.delayDays ?? 0)
              : 0,
          isDefault: false,
          scheduleType: round.scheduleType,
          daysOfWeek: round.daysOfWeek,
          rollingWindowSize: round.scheduleType == ScheduleType.rolling
              ? (round.rollingWindowSize ?? 7)
              : null,
        ),
      );
    }
    return definitions;
  }

  /// Builds the single לימוד-only stage row for a no-review wizard result.
  List<StageDefinition> _buildNoReviewStages(WizardResult result) {
    return [
      StageDefinition(
        curriculumId: result.curriculumId,
        stageOrder: 1,
        stageName: kLimudStageName,
        delayDays: 0,
        isDefault: false,
      ),
    ];
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
