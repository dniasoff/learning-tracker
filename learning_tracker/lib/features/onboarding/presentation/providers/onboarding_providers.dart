import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_providers.g.dart';

@Riverpod(keepAlive: true)
UserProfileService userProfileService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return UserProfileService(
    userProfileDao: db.userProfileDao,
    pushUserProfile: createFirestorePush(firestore),
  );
}

/// Provider for CurriculumImportService used during onboarding.
final curriculumImportServiceProvider = Provider<CurriculumImportService>((
  ref,
) {
  final activationService = ref.watch(curriculumActivationServiceProvider);
  return CurriculumImportService(
    activationService: activationService,
  );
});

/// Provider for GoalRepository used during onboarding goal setup.
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoalRepositoryImpl(database: db);
});

/// Provider for BulkPriorCompletionService used during onboarding.
final bulkPriorCompletionServiceProvider = Provider<BulkPriorCompletionService>(
  (ref) {
    final contentRepo = ref.watch(contentRepositoryProvider);
    final completionRepo = ref.watch(completionRepositoryProvider);
    final bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    return BulkPriorCompletionService(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      bookmarkRepository: bookmarkRepo,
    );
  },
);

/// Provider for LearningProcessWizardService used during onboarding.
final learningProcessWizardServiceProvider =
    Provider<LearningProcessWizardService>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return LearningProcessWizardService(
        stageDao: db.stageDao,
        learningProgramDao: db.learningProgramDao,
        profileProgramDao: db.profileProgramDao,
      );
    });
