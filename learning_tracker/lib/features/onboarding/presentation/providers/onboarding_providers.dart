import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart'
    show firestoreGatewayProvider;
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_providers.g.dart';

@Riverpod(keepAlive: true)
UserProfileService userProfileService(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final gateway = ref.watch(firestoreGatewayProvider);
  return UserProfileService(
    userProfileDao: db.userProfileDao,
    pushUserProfile: createFirestorePushFromGateway(gateway),
  );
}

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
    final db = ref.watch(userDatabaseProvider);
    final syncFacade = ref.watch(syncWriteFacadeProvider);
    final analytics = ref.watch(analyticsServiceProvider);
    // B6: inject StageDefinitionRepository so execute() can enumerate all
    // configured stages and write completion records for learn + every chazara.
    final stageRepo = StageDefinitionRepositoryImpl(
      stageDao: db.stageDao,
      completionDao: db.completionDao,
      pushSettings: syncFacade?.pushSettings,
    );
    return BulkPriorCompletionService(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      bookmarkRepository: bookmarkRepo,
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
        learningProgramRepo: LearningProgramRepository.instance,
        profileProgramDao: db.profileProgramDao,
      );
    });
