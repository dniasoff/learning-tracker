import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/daos/profile_program_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';

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
class LearningProcessWizardService {
  LearningProcessWizardService({
    required StageDao stageDao,
    required LearningProgramRepository learningProgramRepo,
    required ProfileProgramDao profileProgramDao,
  }) : _stageDao = stageDao,
       _learningProgramRepo = learningProgramRepo,
       _profileProgramDao = profileProgramDao;

  final StageDao _stageDao;
  final LearningProgramRepository _learningProgramRepo;
  final ProfileProgramDao _profileProgramDao;

  /// Get active programs filtered by curriculum type.
  List<LearningProgramData> getPresetsForCurriculum(CurriculumId curriculumId) {
    return _learningProgramRepo.getProgramsByCurriculumType(
      curriculumId.storageKey,
    );
  }

  /// Apply the wizard result — creates stages for the curriculum.
  ///
  /// [profileId] identifies the profile to associate with the preset program.
  /// [trackId] is the FK to curriculum_tracks.id for the target track.
  ///
  /// Pass [clearFirst] = false when the caller has already superseded the old
  /// stage rows (edit-track flow) and must not hard-delete them — those rows
  /// are retained so completions.stageId FKs stay valid.
  ///
  /// AUD-onboarding-06 (DB-2): the delete, the optional preset-association
  /// write, and every stage insert run inside a single [StageDao.runTransaction]
  /// call so a crash mid-sequence (process death, backgrounding) rolls back
  /// to the pre-call state instead of leaving zero or partially-written
  /// review stages. All the actual Drift writes happen directly in this
  /// method's own body (not scattered across the `_build*Stages` helpers,
  /// which are pure) so the atomic unit is easy to audit in one place.
  Future<void> applyWizardResult(
    WizardResult result, {
    required int profileId,
    required int trackId,
    bool clearFirst = true,
  }) async {
    await _stageDao.runTransaction(() async {
      if (clearFirst) {
        // Replace stages for this track only — other active tracks for the
        // same curriculum keep their own stage rows (Story 20.2
        // track-scoping).
        await _stageDao.deleteStagesForTrack(trackId);
      }

      final stages = switch (result.choice) {
        WizardChoice.preset => await _buildPresetStages(
          result,
          profileId: profileId,
          trackId: trackId,
        ),
        WizardChoice.custom => _buildCustomStages(
          result,
          profileId: profileId,
          trackId: trackId,
        ),
        WizardChoice.noReview => _buildNoReviewStages(
          result,
          profileId: profileId,
          trackId: trackId,
        ),
      };

      for (final stage in stages) {
        await _stageDao.insertStageDefinition(stage);
      }
    });
  }

  /// Stores the preset-program association (if [result.programId] resolves
  /// to a real program) and returns the stage rows to insert. The
  /// association write is performed here — not by the caller — because it
  /// must land inside the same transaction as the stage inserts.
  ///
  /// Returns an empty list (writing nothing) when [result.programId] does
  /// not resolve to a known program.
  Future<List<db.StageDefinitionsCompanion>> _buildPresetStages(
    WizardResult result, {
    required int profileId,
    required int trackId,
  }) async {
    final program = _learningProgramRepo.getProgramById(result.programId!);
    if (program == null) return const [];

    // Store the preset association.
    await _profileProgramDao.setProfileProgram(
      profileId: profileId,
      curriculumType: result.curriculumId.storageKey,
      programId: program.id,
    );

    // Parse stages_config JSON and build stage definitions.
    final stages = (jsonDecode(program.stagesConfig) as List)
        .cast<Map<String, dynamic>>();
    final companions = <db.StageDefinitionsCompanion>[];
    for (var i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final scheduleType = _parseScheduleType(stage);
      final daysOfWeek = stage['days'] != null
          ? _parseDaysOfWeek(stage['days'] as List)
          : null;

      final scheduleJson = switch (scheduleType) {
        ScheduleType.weekly => jsonEncode({
          'type': 'weekly',
          'days_of_week': daysOfWeek ?? [],
        }),
        ScheduleType.rolling => jsonEncode({
          'type': 'rolling',
          'rolling_window_size': (stage['window'] as int?) ?? 7,
        }),
        _ => jsonEncode({
          'type': 'delay',
          'delay_days': (stage['delay_days'] as int?) ?? 0,
        }),
      };
      companions.add(
        db.StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: result.curriculumId.storageKey,
          trackId: trackId,
          stageOrder: i + 1,
          stageName: stage['label'] as String,
          isDefault: const Value(false),
          schedule: Value(scheduleJson),
        ),
      );
    }
    return companions;
  }

  /// Builds the stage rows for a custom wizard result (לימוד + N custom
  /// chazarah rounds). Pure — no Drift writes — so the caller can insert the
  /// result inside its own transaction.
  List<db.StageDefinitionsCompanion> _buildCustomStages(
    WizardResult result, {
    required int profileId,
    required int trackId,
  }) {
    final companions = <db.StageDefinitionsCompanion>[
      db.StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: result.curriculumId.storageKey,
        trackId: trackId,
        stageOrder: 1,
        stageName: kLimudStageName,
        isDefault: const Value(false),
        schedule: const Value('{"type":"delay","delay_days":0}'),
      ),
    ];

    // Custom chazarah rounds.
    final rounds = result.customRounds ?? [];
    for (var i = 0; i < rounds.length; i++) {
      final round = rounds[i];
      final roundScheduleJson = switch (round.scheduleType) {
        ScheduleType.weekly => jsonEncode({
          'type': 'weekly',
          'days_of_week': round.daysOfWeek ?? [],
        }),
        ScheduleType.rolling => jsonEncode({
          'type': 'rolling',
          'rolling_window_size': round.rollingWindowSize ?? 7,
        }),
        _ => jsonEncode({'type': 'delay', 'delay_days': round.delayDays ?? 0}),
      };
      companions.add(
        db.StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: result.curriculumId.storageKey,
          trackId: trackId,
          stageOrder: i + 2,
          stageName: round.label,
          isDefault: const Value(false),
          schedule: Value(roundScheduleJson),
        ),
      );
    }
    return companions;
  }

  /// Builds the single לימוד-only stage row for a no-review wizard result.
  /// Pure — no Drift writes.
  List<db.StageDefinitionsCompanion> _buildNoReviewStages(
    WizardResult result, {
    required int profileId,
    required int trackId,
  }) {
    return [
      db.StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: result.curriculumId.storageKey,
        trackId: trackId,
        stageOrder: 1,
        stageName: kLimudStageName,
        isDefault: const Value(false),
        schedule: const Value('{"type":"delay","delay_days":0}'),
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
