import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

/// Provider for CurriculumImportService used during onboarding.
final curriculumImportServiceProvider = Provider<CurriculumImportService>((
  ref,
) {
  final activationService = ref.watch(curriculumActivationServiceProvider);
  return CurriculumImportService(activationService: activationService);
});

/// Provider for GoalRepository used during onboarding goal setup.
///
/// `syncEngine` MUST be wired here — without it `GoalRepositoryImpl._syncGoal`
/// bails on its first line (`if (_syncEngine == null) return;`) and every
/// goal create/update/delete silently never reaches Firestore. `syncEngine`
/// is null for local-born accounts, which is the intended no-op.
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  return GoalRepositoryImpl(
    database: db,
    profileId: profileId,
    syncEngine: syncFacade,
  );
});

/// Provider for BulkPriorCompletionService used during onboarding.
final bulkPriorCompletionServiceProvider = Provider<BulkPriorCompletionService>(
  (ref) {
    final contentRepo = ref.watch(contentRepositoryProvider);
    final completionRepo = ref.watch(completionRepositoryProvider);
    final bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    // AUD-onboarding-08 (SM-7): the delegated-profile bookmark write inside
    // execute() (a parent bulk-marking prior learning for a specific child)
    // goes through this factory instead of a bare `new BookmarkRepositoryImpl`
    // — same seam completionRepositoryProvider already wires into
    // CompletionRepositoryImpl for the identical delegated-profile scenario.
    final bookmarkRepoFactory = ref.watch(bookmarkRepositoryFactoryProvider);
    final db = ref.watch(userDatabaseProvider);
    final syncFacade = ref.watch(syncWriteFacadeProvider);
    final analytics = ref.watch(analyticsServiceProvider);
    // B6: inject StageDefinitionRepository so execute() can enumerate all
    // configured stages and write completion records for learn + every chazara.
    final stageRepo = StageDefinitionRepositoryImpl(
      stageDao: db.stageDao,
      completionDao: db.completionDao,
      // Plan §F Phase 5 deliverable 6 — dedicated stage_definition outbox
      // kind replaces the legacy pushSettings piggyback.
      pushStageDefinitions: syncFacade?.pushStageDefinitions,
    );
    return BulkPriorCompletionService(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      bookmarkRepository: bookmarkRepo,
      bookmarkRepositoryFactory: bookmarkRepoFactory,
      database: db,
      syncEngine: syncFacade,
      analytics: analytics,
      stageRepository: stageRepo,
      outboxDao: db.outboxDao,
    );
  },
);

/// Provider for LearningProcessWizardService used during onboarding.
final learningProcessWizardServiceProvider =
    Provider<LearningProcessWizardService>((ref) {
      final db = ref.watch(userDatabaseProvider);
      return LearningProcessWizardService(
        stageDao: db.stageDao,
        learningProgramRepo: ref.read(learningProgramRepositoryProvider),
        profileProgramDao: db.profileProgramDao,
      );
    });
