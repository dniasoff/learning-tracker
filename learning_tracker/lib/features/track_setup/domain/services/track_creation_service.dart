import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';

/// Default study days: all 7 days active (Sun–Shabbos).
///
/// ISO weekdays: Mon=1 ... Sun=7.
const kDefaultStudyDays = <int, String>{
  7: 'study', // Sunday
  1: 'study', // Monday
  2: 'study', // Tuesday
  3: 'study', // Wednesday
  4: 'study', // Thursday
  5: 'study', // Friday
  6: 'study', // Shabbos (Saturday)
};

/// Creates a track in the database from an [AddTrackResult].
///
/// All DB writes (stages, study days, scopes, goals) are wrapped
/// in a single transaction for atomicity.
class TrackCreationService {
  TrackCreationService({
    required AppDatabase database,
    required CurriculumActivationService activationService,
    required LearningProcessWizardService wizardService,
    required GoalRepository goalRepository,
  }) : _database = database,
       _activationService = activationService,
       _wizardService = wizardService,
       _goalRepository = goalRepository;

  final AppDatabase _database;
  final CurriculumActivationService _activationService;
  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;

  /// Persist all track configuration from the AddTrackFlow result.
  ///
  /// Curriculum activation runs outside the transaction (idempotent).
  /// All subsequent writes run inside a single transaction — if any
  /// step fails, everything rolls back.
  Future<void> createTrack({
    required AddTrackResult result,
    required int profileId,
  }) async {
    final curriculum = result.curriculumId;

    // 1. Ensure curriculum is activated (idempotent, outside transaction)
    try {
      await _activationService.activate(curriculum);
    } catch (_) {
      AppLogger.instance.debug(
        'TrackCreationService: curriculum ${curriculum.storageKey} '
        'activation skipped (likely already active)',
      );
    }

    // 2. All remaining writes in a single transaction
    await _database.transaction(() async {
      // Apply wizard result (stages) if provided
      if (result.wizardResult is LearningProcessWizardResult) {
        final wizard = result.wizardResult! as LearningProcessWizardResult;
        await _wizardService.applyWizardResult(
          wizard.wizardResult,
          profileId: profileId,
        );
      }

      // Save study day configs
      await _saveStudyDays(
        profileId: profileId,
        curriculumId: curriculum,
        studyDays: result.studyDays,
      );

      // Save scope selections if narrowed
      if (result.scopeSelections != null &&
          result.scopeSelections!.isNotEmpty) {
        await _saveScopes(
          profileId: profileId,
          curriculumId: curriculum,
          scopes: result.scopeSelections!,
        );
      }

      // Create goal if provided
      if (result.goalResult is GoalFormResult) {
        final goal = result.goalResult! as GoalFormResult;
        await _goalRepository.createGoal(
          curriculumId: curriculum,
          targetPercent: goal.targetPercent,
          targetDate: goal.targetDate,
          description: goal.description,
          dateType: goal.dateType,
          goalType: goal.goalType,
          paceValue: goal.paceValue,
          paceUnit: goal.paceUnit,
        );
      }

      // Seed default point configs for child mode tracks
      await _seedPointConfigsIfNeeded(
        profileId: profileId,
        curriculumId: curriculum,
      );
    });

    // Link profile to program if one was selected (outside transaction — idempotent)
    if (result.programId != null) {
      await _database.profileProgramDao.setProfileProgram(
        profileId: profileId,
        curriculumType: curriculum.storageKey,
        programId: result.programId!,
      );
    }

    AppLogger.instance.info(
      'TrackCreationService: track "${result.label}" created for '
      '${curriculum.storageKey} (profile=$profileId)',
    );
  }

  Future<void> _saveStudyDays({
    required int profileId,
    required CurriculumId curriculumId,
    required Map<int, String> studyDays,
  }) async {
    final dao = _database.studyDayConfigDao;
    await dao.deleteConfigsByCurriculumAndProfile(
      curriculumId.storageKey,
      profileId,
    );
    for (final entry in studyDays.entries) {
      await dao.upsertDayConfig(
        profileId: profileId,
        curriculumId: curriculumId.storageKey,
        dayOfWeek: entry.key,
        dayType: entry.value,
      );
    }
  }

  Future<void> _saveScopes({
    required int profileId,
    required CurriculumId curriculumId,
    required List<ScopeEntry> scopes,
  }) async {
    final now = DateTime.now().toUtc();
    for (final scope in scopes) {
      await _database
          .into(_database.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: Value(profileId),
              curriculumId: curriculumId.storageKey,
              scopeLevel: scope.level,
              scopeValue: scope.value,
              createdAt: now,
            ),
          );
    }
  }

  Future<void> _seedPointConfigsIfNeeded({
    required int profileId,
    required CurriculumId curriculumId,
  }) async {
    final existing = await _database.pointConfigDao.getConfigsByCurriculum(
      curriculumId.storageKey,
    );
    if (existing.isEmpty) {
      await _database.pointConfigDao.seedDefaults(curriculumId.storageKey);
    }
  }
}
